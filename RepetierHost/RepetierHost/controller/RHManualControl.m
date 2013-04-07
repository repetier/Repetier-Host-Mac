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


#import "RHManualControl.h"
#import "PrinterConnection.h"
#import "RHAppDelegate.h"

@implementation RHManualControl

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        if ([NSBundle loadNibNamed:@"ManualControl" owner:self])
        {
            [view setFrame:[self bounds]];
            [self addSubview:view];
            [[NSNotificationCenter defaultCenter] addObserver:self                                             selector:@selector(connectionOpened:) name:@"RHConnectionOpen" object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self                                             selector:@selector(connectionClosed:) name:@"RHConnectionClosed" object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self                                             selector:@selector(printerStateChanged:) name:@"RHPrinterStateChanged" object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self                                             selector:@selector(fanspeedChanged:) name:@"Fanspeed" object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self                                             selector:@selector(speedMultiplyChanged2:) name:@"SpeedMultiply" object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self                                             selector:@selector(flowMultiplyChanged2:) name:@"FlowMultiply" object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self                                             selector:@selector(targetBedChanged:) name:@"TargetBed" object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self                                             selector:@selector(targetExtrChanged:) name:@"TargetExtr0" object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(jobChanged:) name:@"RHJobChanged" object:nil];
            [self updateConnectionStatus:NO];
            [self scrollPoint:NSMakePoint(0,0)];
            lastx = lasty = lastz = -1000;
            dontsend = FALSE;
            [self updateExtruderCount];
            status=disconnected;
            statusSet=CFAbsoluteTimeGetCurrent();
            timer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                     target:self selector:@selector(timerTick:)
                                                userInfo:nil repeats:YES];
            [self updatePrinterState];
        }
    }
    
    return self;
}
-(BOOL)isFlipped {
    return YES;
}
- (void)timerTick:(NSTimer*)theTimer {
    [self updateStatus];
    if(connection->connected==NO) return;
    if (connection->analyzer->x != lastx || lastx==0)
    {
        [xLabel setStringValue:[NSString stringWithFormat:@"X=%.2f",connection->analyzer->x]];
        if (connection->analyzer->hasXHome)
         [xLabel setTextColor:[NSColor blackColor]];
        else
          [xLabel setTextColor:[NSColor redColor]];
        lastx = connection->analyzer->x;
    }
    if (connection->analyzer->y != lasty || lasty==0)
    {
        [yLabel setStringValue:[NSString stringWithFormat:@"Y=%.2f",connection->analyzer->y]];
        if (connection->analyzer->hasYHome)
            [yLabel setTextColor:[NSColor blackColor]];
        else
            [yLabel setTextColor:[NSColor redColor]];
        lasty = connection->analyzer->y;
    }
    if (connection->analyzer->z != lastz || lastz==0)
    {
        [zLabel setStringValue:[NSString stringWithFormat:@"Z=%.2f",connection->analyzer->z]];
        if (connection->analyzer->hasZHome)
            [zLabel setTextColor:[NSColor blackColor]];
        else
            [zLabel setTextColor:[NSColor redColor]];
        lastz = connection->analyzer->z;
    }
}
-(void)updateConnectionStatus:(BOOL)c {
    [debugEchoButton setEnabled:c];
    [debugInfoButton setEnabled:c];
    [debugErrorButton setEnabled:c];
    [debugDryRunButton setEnabled:c];
    [powerButton setEnabled:c];
    [sendButton setEnabled:c];
    [xHomeButton setEnabled:c];
    [xMoveButtons setEnabled:c];
    [yHomeButton setEnabled:c];
    [yMoveButtons setEnabled:c];
    [zHomeButton setEnabled:c];
    [zMoveButtons setEnabled:c];
    [homeAllButton setEnabled:c];
    [goDumpAreaButton setEnabled:c];
    [stopMotorButton setEnabled:c];
    [fakeOkButton setEnabled:c];
    [extruderOnButton setEnabled:c];
    [extruderSetTempButton setEnabled:c];
    [extruderReverseButton setEnabled:c];
    [extruderExtrudeButton setEnabled:c];
    [heatedBedOnButton setEnabled:c];
    [heatedBedSetTempButton setEnabled:c];
    [fanOnButton setEnabled:c];
    [fanSpeedSlider setEnabled:c];
    [extruderLengthSlider setEnabled:c];
    [extruderSpeedSlider setEnabled:c];
    [gcodeText setEnabled:c];
    [extruderTempText setEnabled:c];
    [heatedBedTempText setEnabled:c];
    [extruderSpeedText setEnabled:c];
    [extrudeDistanceText setEnabled:c];
    [retractDistanceText setEnabled:c];
    [retractExtruderButton setEnabled:c];
    [setHomeButton setEnabled:c];
    [speedMultiplySlider setEnabled:c];
    [flowMultiplySlider setEnabled:c];
    [activeExtruderSelector setEnabled:c];
}
-(void)changeStatus:(PrinterStatus)value
{
    double timestamp = CFAbsoluteTimeGetCurrent();
    statusSet = timestamp;
    BOOL changed = value!=status;
    status = value;
    switch (value)
    {
        case disconnected:
            if(changed)
                [statusLabel setStringValue:@"Disconnected"];
            break;
        case heatingBed:
            if(changed)
                [statusLabel setStringValue:@"Heating bed"];
            break;
        case heatingExtruder:
            if(changed)
                [statusLabel setStringValue:@"Heating extruder"];
            break;
        case jobKilled:
            if(changed)
                [statusLabel setStringValue:@"Print job killed"];
            break;
        case jobPaused:
            if(changed)
                [statusLabel setStringValue:@"Print job paused"];
            break;
        case jobFinsihed:
            if(changed)
                [statusLabel setStringValue:@"Print job finished"];
            break;
        case idle:
        default:
            if (connection->job->mode==1)
            {
                if (connection->analyzer->uploading)
                    [statusLabel setStringValue:@"Uploading ..."];
                else
                    [statusLabel setStringValue:[NSString stringWithFormat:@"Printing job ETA %@",connection->job.ETA]];
            }
            else
            {
                if (connection->injectCommands->count == 0)
                    [statusLabel setStringValue:@"Idle"];
                else
                    [statusLabel setStringValue:[NSString stringWithFormat:@"%i commands waiting",connection->injectCommands->count]];
            }
            break;
    }
}

-(void)updateStatus
{
    double timestamp = CFAbsoluteTimeGetCurrent();
    double diff = timestamp - statusSet;
    float et = [connection->analyzer getExtruderTemperature:-1];
    if (connection->connected == NO)
    {
        if (status != disconnected)
            [self changeStatus:disconnected];
    }
    else if (et > 15 && et - [connection getExtruderTemperature:-1] > 5)
        [self changeStatus:heatingExtruder];
    else if (connection->analyzer->bedTemp > 15 && connection->analyzer->bedTemp - connection->bedTemp > 5 && connection->bedTemp > 15) // only if has bed
        [self changeStatus:heatingBed];
    else if (status == heatingBed || status == heatingExtruder)
        [self changeStatus:idle];
    else if (connection->paused && status != jobPaused)
        [self changeStatus:jobPaused];
    else if (status == jobPaused && !connection->paused)
        [self changeStatus:idle];
    else if (status == idle && diff > 0)
        [self changeStatus:idle];
    else if (status == motorStopped || status == jobKilled || status == jobFinsihed)
    {
        if (diff > 30) // remove message after 30 seconds
            [self changeStatus:idle];
    }
    else if (status == disconnected && connection->connected)
        [self changeStatus:idle];
}
-(void)jobChanged:(NSNotification*)notification {
    if(connection->job->mode==2) {
        [self changeStatus:jobFinsihed];
    }
    if(connection->job->mode==3) {
        [self changeStatus:jobKilled];
    }
}
- (void)connectionOpened:(NSNotification *)notification {
    [self updateConnectionStatus:YES];
    [self sendDebug];
}
- (void)connectionClosed:(NSNotification *)notification {
    [self updateConnectionStatus:NO];
}
- (void)fanspeedChanged:(NSNotification *)notification {
    dontsend = TRUE;
    [fanSpeedSlider setIntValue:[notification.object intValue]*100/255];
    [self updatePrinterState];
    dontsend = FALSE;
}
- (void)speedMultiplyChanged2:(NSNotification *)notification {
    int tval = [notification.object intValue];
    int nv = [speedMultiplySlider intValue];
    if(nv!=tval) {
        dontsend = TRUE;
        connection->speedMultiply = tval;
        [speedMultiplySlider setIntValue:tval];
        [speedMultiplyLabel setStringValue:[NSString stringWithFormat:@"%d%%",tval]];
        dontsend = FALSE;
    }
}
- (void)flowMultiplyChanged2:(NSNotification *)notification {
    int tval = [notification.object intValue];
    int nv = [flowMultiplySlider intValue];
    if(nv!=tval) {
        dontsend = TRUE;
        connection->flowMultiply = tval;
        [flowMultiplySlider setIntValue:tval];
        [flowMultiplyLabel setStringValue:[NSString stringWithFormat:@"%d%%",tval]];
        dontsend = FALSE;
    }
}
- (void)targetExtrChanged:(NSNotification *)notification {
    dontsend = TRUE;
    [self updatePrinterState];
    dontsend = FALSE;
}
- (void)targetBedChanged:(NSNotification *)notification {
    dontsend = TRUE;
    [self updatePrinterState];
    dontsend = FALSE;    
}
-(void)updateExtruderCount {
    if(connection->config->numberOfExtruder==activeExtruderSelector.itemArray.count) return;
    dontsend = YES;
    int sidx = connection->analyzer->activeExtruder;
    NSMutableArray *exlist = [NSMutableArray new];
    int n = connection->config->numberOfExtruder,i;
    for(i=0;i<n;i++) {
        [exlist addObject:[NSString stringWithFormat:@"Extruder %d",1+i]];
    }
    [activeExtruderSelector removeAllItems];
    [activeExtruderSelector addItemsWithTitles:exlist];
    if(sidx<n)
        [activeExtruderSelector selectItemAtIndex:sidx];
    dontsend = NO;
    [exlist release];
}
-(void)updatePrinterState {
    GCodeAnalyzer *a = connection->analyzer;
    if(a==nil) return;
    [extruderTargetTempLabel setIntValue:[a getExtruderTemperature:-1]];
    [heatedBedTargetTempLabel setIntValue:a->bedTemp];
    [extruderOnButton setState:[a getExtruderTemperature:-1]];
    [heatedBedOnButton setState:a->bedTemp>0];
    [fanOnButton setState:a->fanOn];
    dontsend = YES;
    if(connection->analyzer!=nil && connection->analyzer->activeExtruder!=nil)
        [activeExtruderSelector selectItemAtIndex:connection->analyzer->activeExtruder->extruderId];
    dontsend = NO;
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if(a->fanOn) 
        [d setInteger:(int)((double)a->fanVoltage/2.55) forKey:@"fanSpeed"];
}
- (void)printerStateChanged:(NSNotification *)notification {
    [self updatePrinterState];
}
- (void)drawRect:(NSRect)dirtyRect
{
    // Drawing code here.
}
-(void)sendDebug {
    int v = 0;
    if ([debugEchoButton state]==1) v += 1;
    if ([debugInfoButton state]==1) v += 2;
    if ([debugErrorButton state]==1) v += 4;
    if ([debugDryRunButton state]==1) v += 8;
    [connection injectManualCommand:[NSString stringWithFormat:@"M111 S%d",v]];
}

- (IBAction)extruderChangeAction:(id)sender {
    if(dontsend) return;
    [connection injectManualCommand:[NSString stringWithFormat:@"T%d",(int)[activeExtruderSelector indexOfSelectedItem]]];
}
- (IBAction)debugEchoAction:(NSButton *)sender {
    [self sendDebug];
}

- (IBAction)debugInfoAction:(NSButton *)sender {
    [self sendDebug];
}

- (IBAction)debugErrorsAction:(NSButton *)sender {
    [self sendDebug];
}

- (IBAction)debugDryRunAction:(NSButton *)sender {
    [self sendDebug];
}

- (IBAction)speedMultiplyChanged:(id)sender {
    if(dontsend) return;
    int nv = [speedMultiplySlider intValue];
    if(nv!=connection->speedMultiply) {
        connection->speedMultiply = nv;
        [connection injectManualCommand:[NSString stringWithFormat:@"M220 S%d",nv]];
        [speedMultiplyLabel setStringValue:[NSString stringWithFormat:@"%d%%",nv]];
    }
}

- (IBAction)flowMultiplyChanged:(id)sender {
    if(dontsend) return;
    int nv = [flowMultiplySlider intValue];
    if(nv!=connection->flowMultiply) {
        connection->flowMultiply = nv;
        [connection injectManualCommand:[NSString stringWithFormat:@"M221 S%d",nv]];
        [flowMultiplyLabel setStringValue:[NSString stringWithFormat:@"%d%%",nv]];
    }
}

- (IBAction)powerAction:(NSButton *)sender {
    if ([powerButton state]==1)
        [connection injectManualCommand:@"M80"];
    else
        [connection injectManualCommand:@"M81"];
}

- (IBAction)sendAction:(NSButton *)sender {
    [gcodeText sendCommand:gcodeText.stringValue];
}

- (IBAction)xHomeAction:(NSButton *)sender {
    [connection getInjectLock];
    [connection injectManualCommand:@"G28 X0"];
    [connection returnInjectLock ];
}

- (IBAction)yHomeAction:(NSButton *)sender {
    [connection getInjectLock];
    [connection injectManualCommand:@"G28 Y0"];
    [connection returnInjectLock ];
}

- (IBAction)zHomeAction:(NSButton *)sender {
    [connection getInjectLock];
    [connection injectManualCommand:@"G28 Z0"];
    [connection returnInjectLock ];
}
-(void) moveHead:(NSString*)axis distance:(double)amount {
    [connection getInjectLock];
    //BOOL wasrel = con.analyzer.relative;
    //if(!wasrel) 
    [connection injectManualCommand:@"G91"];
    if([axis compare:@"Z"]==NSOrderedSame)
        [connection injectManualCommand:[NSString stringWithFormat:@"G1 %@%1.1f F%1.0f",axis,amount,connection->config->travelZFeedrate]];
    else
        [connection injectManualCommand:[NSString stringWithFormat:@"G1 %@%1.1f F%1.0f",axis,amount,connection->config->travelFeedrate]];
    //if (!wasrel) 
    [connection injectManualCommand:@"G90"];
    [connection returnInjectLock ];
}
- (IBAction)xMoveAction:(NSSegmentedControl *)sender {
    switch ([sender selectedSegment]) {
        case 0:
            [self moveHead:@"X" distance:-100];
            break;
        case 1:
            [self moveHead:@"X" distance:-10];
            break;
        case 2:
            [self moveHead:@"X" distance:-1];
            break;
        case 3:
            [self moveHead:@"X" distance:-0.1];
            break;
        case 4:
            [self moveHead:@"X" distance:0.1];
            break;
        case 5:
            [self moveHead:@"X" distance:1];
            break;
        case 6:
            [self moveHead:@"X" distance:10];
            break;
        case 7:
            [self moveHead:@"X" distance:100];
            break;
    }
}

- (IBAction)yMoveAction:(NSSegmentedControl *)sender {
    switch ([sender selectedSegment]) {
        case 0:
            [self moveHead:@"Y" distance:-100];
            break;
        case 1:
            [self moveHead:@"Y" distance:-10];
            break;
        case 2:
            [self moveHead:@"Y" distance:-1];
            break;
        case 3:
            [self moveHead:@"Y" distance:-0.1];
            break;
        case 4:
            [self moveHead:@"Y" distance:0.1];
            break;
        case 5:
            [self moveHead:@"Y" distance:1];
            break;
        case 6:
            [self moveHead:@"Y" distance:10];
            break;
        case 7:
            [self moveHead:@"Y" distance:100];
            break;
    }
}

- (IBAction)zMoveAction:(NSSegmentedControl *)sender {
    switch ([sender selectedSegment]) {
        case 0:
            [self moveHead:@"Z" distance:-100];
            break;
        case 1:
            [self moveHead:@"Z" distance:-10];
            break;
        case 2:
            [self moveHead:@"Z" distance:-1];
            break;
        case 3:
            [self moveHead:@"Z" distance:-0.1];
            break;
        case 4:
            [self moveHead:@"Z" distance:0.1];
            break;
        case 5:
            [self moveHead:@"Z" distance:1];
            break;
        case 6:
            [self moveHead:@"Z" distance:10];
            break;
        case 7:
            [self moveHead:@"Z" distance:100];
            break;
    }
}

- (IBAction)homeAllAction:(NSButton *)sender {
    [connection getInjectLock];
    [connection injectManualCommand:@"G28 X0 Y0 Z0"];
    [connection returnInjectLock ];
}

- (IBAction)goDumpAreaAction:(NSButton *)sender {
    [connection doDispose];
}

- (IBAction)stopMotorAction:(NSButton *)sender {
    [connection injectManualCommand:@"M84" ];
}

- (IBAction)fakeOKAction:(NSButton *)sender {
    [connection analyzeResponse:@"ok"];
}

- (IBAction)heatOnAction:(NSButton *)sender {
    if (connection->connected == false || dontsend) return;
    //if (!createCommands) return;
    [connection getInjectLock];
    if (sender.state)
    {
        [connection injectManualCommand:[NSString stringWithFormat:@"M104 S%d",(int)extruderTempText.intValue]];
    }
    else
    {
        [connection injectManualCommand:@"M104 S0"];
    }
    [connection returnInjectLock];
}

- (IBAction)extruderSetTempAction:(NSButton *)sender {
    if(dontsend) return;
    [connection injectManualCommand:[NSString stringWithFormat:@"M104 S%d",(int)extruderTempText.intValue]];
}


- (IBAction)extruderExtrudeAction:(NSButton *)sender {
    [connection getInjectLock];
    BOOL wasrel = connection->analyzer->relative;
    if (!wasrel) [connection injectManualCommand:@"G91"];
    [connection injectManualCommand:[NSString stringWithFormat:@"G1 E%1.4f F%1f",[extrudeDistanceText doubleValue],[extruderSpeedText doubleValue]]];
    if (!wasrel) [connection injectManualCommand:@"G90"];
    [connection returnInjectLock ];
}

- (IBAction)heatedBedOnAction:(NSButton *)sender {
    if (connection->connected == false || dontsend) return;
    //if (!createCommands) return;
    [connection getInjectLock];
    if (sender.state)
    {
        [connection injectManualCommand:[NSString stringWithFormat:@"M140 S%d",(int)heatedBedTempText.intValue]];
    }
    else
    {
        [connection injectManualCommand:@"M140 S0"];
    }
    [connection returnInjectLock];
}

- (IBAction)heatedBedSetTempAction:(NSButton *)sender {
    if(dontsend) return;
    [connection injectManualCommand:[NSString stringWithFormat:@"M140 S%d",(int)heatedBedTempText.intValue]];
}

- (IBAction)fanOnAction:(NSButton *)sender {
    if (connection->connected == false || dontsend) return;   
    //if (!createCommands) return;
    [connection getInjectLock];
    if (sender.state)
    {
        int speed = 2.56*fanSpeedSlider.doubleValue;
        if(speed>255) speed=255;
        [connection injectManualCommand:[NSString stringWithFormat:@"M106 S%d",speed]];
    }
    else
    {
        [connection injectManualCommand:@"M107"];
    }
    [connection returnInjectLock];
}

- (IBAction)fanSpeedChangedAction:(NSSlider *)sender {
    //[fanOnButton setState:1];    
    [self fanOnAction:fanOnButton];
}

- (IBAction)retractExtruderAction:(NSButton *)sender {
    [connection getInjectLock];
    BOOL wasrel = connection->analyzer->relative;
    if (!wasrel) [connection injectManualCommand:@"G91"];
    [connection injectManualCommand:[NSString stringWithFormat:@"G1 E-%1.4f F%1f",[retractDistanceText doubleValue],[extruderSpeedText doubleValue]]];
    if (!wasrel) [connection injectManualCommand:@"G90"];
    [connection returnInjectLock ];
}

- (IBAction)setHomeAction:(id)sender {
    [connection getInjectLock];
    [connection injectManualCommandFirst:@"G92 X0 Y0 Z0"];
    [connection injectManualCommandFirst:@"@isathome"];
    [connection returnInjectLock ];
}
@end
