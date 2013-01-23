/*
 Copyright 2011 repetier repetierdev@googlemail.com
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "VirtualPrinter.h"
#import "PrinterConnection.h"

@implementation VirtualPrinter

-(id)init {
    if((self = [super init])) {
        bedTemp = 20;
        extruderTemp[0] = extruderTemp[1] = extruderTemp[2] = 20;
        cnt = cnt2 = 0;
        monitor = -1;
        output = [RHLinkedList new];
        ana = [[GCodeAnalyzer alloc] init];
        ana->privateAnalyzer = YES; 
        writeThread = nil;
        outputLock = [NSLock new];
    }
    return self;
}
-(void)dealloc {
    [output release];
    [ana release];
    [super dealloc];
}
-(void) writeThread
{
    while (!exit)
    {
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        [NSThread sleepForTimeInterval:0.002];
        [self tick];
        [pool release];
   }
}

-(void)tick
{
    NSString *res = nil;
    do
    {
        res = nil;
        [outputLock lock];
        if (output->count > 0)
        {
            res = [output removeFirst];
        }
        [outputLock unlock];
        if (res != nil)
            [connection virtualResponse:res];
    } while (res != nil);
    cnt++;
    if (cnt > 125)
    {
        cnt = 0;
        if(bedTemp!=ana->bedTemp)
            bedTemp = bedTemp + (ana->bedTemp - bedTemp>0 ? 0.5 : -0.5);
        if (ana->bedTemp > 20 && bedTemp > ana->bedTemp) bedTemp = ana->bedTemp;
        if (bedTemp < 20) bedTemp = 20;
        for(int e=0;e<3;e++) {
            if(extruderTemp[e]!=[ana getExtruderTemperature:e]);
            extruderTemp[e] += ([ana getExtruderTemperature:e] - extruderTemp[e]>0? 1 : -1);
            if ([ana getExtruderTemperature:e] > 20 && extruderTemp[e] > [ana getExtruderTemperature:e]) extruderTemp[e] = [ana getExtruderTemperature:e];
            if (extruderTemp[e] < 20) extruderTemp[e] = 20;
        }
    }
    cnt2++;
    if(cnt2>=250) {
        cnt2 = 0;
        NSString *epr;
        double time = CFAbsoluteTimeGetCurrent();
        double outp;
        unsigned int millis = (unsigned int)((time-floor(time/2000000.0)*2000000.0)*1000.0);
        switch(ana->tempMonitor) {
            case 0:
            case 1:
            case 2:
                outp = ([ana getExtruderTemperature:ana->tempMonitor]-20.0)*255.0/350*(1.0+0.05*sin((millis % 7000)*0.000897));
                if(outp<0) outp = 0;
                if(outp>255) outp = 255;
                epr = [NSString stringWithFormat:@"MTEMP:%d %d %d %d",millis,(int)extruderTemp[ana->tempMonitor],(int)[ana getExtruderTemperature:ana->tempMonitor],(int)outp];
                [connection virtualResponse:epr];
                break;
            case 100:
                outp = (ana->bedTemp-20.0)*255.0/110*(1.0+0.05*sin((millis % 7000)*0.000897)); 
                if(outp<0) outp = 0;
                if(outp>255) outp = 255;
                epr = [NSString stringWithFormat:@"MTEMP:%d %d %d %d",millis,(int)bedTemp,(int)ana->bedTemp,(int)outp];
                [connection virtualResponse:epr];
                break;
        }
    }
}

-(void) open
{
    [ana start];
    [output addLast:@"start"];
    exit = false;
    writeThread = [[NSThread alloc] initWithTarget:self
                selector:@selector(writeThread) object:nil];
    [writeThread start];
}

-(void)close
{
    exit = true;
    while(!writeThread.isFinished) {
        [NSThread sleepForTimeInterval:0.002];
    };
    [writeThread release];
    writeThread = nil;
}
-(void) receiveLine:(GCode*)code
{
    [ana analyze:code];
    [outputLock lock];
    if (code.hasM) switch (code.getM) {
        case 20:
            [output addLast:@"Begin file list"];
            [output addLast:@"DUMMY1.GCO 77288"];
            [output addLast:@"DUMMY2.GCO 53445"];
            [output addLast:@"End file list"];
            break;
        case 27:
            [output addLast:@"Not SD printing"];
            break;
        case 28:
            [output addLast:[NSString stringWithFormat:@"Writing to file: %@",code->text]];
            break;
        case 29:
            [output addLast:@"Done saving file."];
            break;
        case 115: // Firmware
            [output addLast:@"FIRMWARE_NAME:RepetierVirtualPrinter FIRMWARE_URL:https://github.com/repetier/Repetier-Firmware/ PROTOCOL_VERSION:1.0 MACHINE_TYPE:Mendel EXTRUDER_COUNT:1 REPETIER_PROTOCOL:1"];
            break;
        case 105: // Print Temperatures
            {
                double time = CFAbsoluteTimeGetCurrent();
                unsigned int millis = (unsigned int)((time-floor(time/2000000.0)*2000000.0)*1000.0);
                int outp = ([ana getExtruderTemperature:-1]-20.0)*255.0/350*(1.0+0.05*sin((millis % 7000)*0.000897));
                if(outp<0) outp = 0;
                if(outp>255) outp = 255;
                [output addLast:[NSString stringWithFormat:@"T:%.2f B:%d @:%d T0:%.2f @0:%d T1:%.2f @1:%d T2:%.2f @2:%d",extruderTemp[ana->activeExtruder],(int)bedTemp,outp,extruderTemp[0],outp,extruderTemp[1],outp,extruderTemp[2],outp]];
            }
            break;
        case 205: // EEPROM Settings
            [output addLast:@"EPR:2 75 76800 Baudrate"];
            [output addLast:@"EPR:2 79 0 Max. inactive time [ms,0=off]" ];
            [output addLast:@"EPR:2 83 60000 Stop stepper afer inactivity [ms,0=off]"];
            [output addLast:@"EPR:3 3 40.00 X-axis steps per mm"];
            [output addLast:@"EPR:3 7 40.00 Y-axis steps per mm"];
            [output addLast:@"EPR:3 11 3333.59 Z-axis steps per mm"];
            [output addLast:@"EPR:3 15 20000.00 X-axis max. feedrate [mm/min]" ];
            [output addLast:@"EPR:3 19 20000.00 Y-axis max. feedrate [mm/min]"];
            [output addLast:@"EPR:3 23 2.00 Z-axis max. feedrate [mm/min]"];
            [output addLast:@"EPR:3 27 1500.00 X-axis homing feedrate [mm/min]"];
            [output addLast:@"EPR:3 31 1500.00 Y-axis homing feedrate [mm/min]"];
            [output addLast:@"EPR:3 35 100.00 Z-axis homing feedrate [mm/min]"];
            [output addLast:@"EPR:3 39 20.00 X-axis start speed [mm/s]"];
            [output addLast:@"EPR:3 43 20.00 Y-axis start speed [mm/s]"];
            [output addLast:@"EPR:3 47 1.00 Z-axis start speed [mm/s]"];
            [output addLast:@"EPR:3 51 750.00 X-axis acceleration [mm/s^2]"];
            [output addLast:@"EPR:3 55 750.00 Y-axis acceleration [mm/s^2]"];
            [output addLast:@"EPR:3 59 50.00 Z-axis acceleration [mm/s^2]"];
            [output addLast:@"EPR:3 63 750.00 X-axis travel acceleration [mm/s^2]"];
            [output addLast:@"EPR:3 67 750.00 Y-axis travel acceleration [mm/s^2]"];
            [output addLast:@"EPR:3 71 50.00 Z-axis travel acceleration [mm/s^2]"];
            [output addLast:@"EPR:3 150 373.00 Extr. steps per mm"];
            [output addLast:@"EPR:3 154 1200.00 Extr. max. feedrate [mm/min]"];
            [output addLast:@"EPR:3 158 10.00 Extr. start feedrate [mm/s]"];
            [output addLast:@"EPR:3 162 10000.00 Extr. acceleration [mm/s^2]"];
            [output addLast:@"EPR:0 166 1 Heat manager [0-1]"];
            [output addLast:@"EPR:0 167 130 PID drive max"];
            [output addLast:@"EPR:2 168 300 PID P-gain [*0.01]"];
            [output addLast:@"EPR:2 172 2 PID I-gain [*0.01]"];
            [output addLast:@"EPR:2 176 2000 PID D-gain [*0.01]"];
            [output addLast:@"EPR:0 180 200 PID max value [0-255]"];
            [output addLast:@"EPR:2 181 0 X-offset [steps]"];
            [output addLast:@"EPR:2 185 0 Y-offset [steps]"];
            [output addLast:@"EPR:2 189 40 Temp. stabilize time [s]"];
            break;
        }
                             
    [output addLast:@"ok"];
    [outputLock unlock];
}
@end
