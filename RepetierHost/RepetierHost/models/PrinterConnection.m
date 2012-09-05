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


#import "PrinterConnection.h"
#import "RHLogger.h"
#import "AMSerialPortList.h"
#import "AMSerialPortAdditions.h"
#import "StringUtil.h"
#import "RHAppDelegate.h"
#import "EEPROMParameter.h"
#import "ThreadedNotification.h"
#import "TemperatureHistory.h"
#import "SDCardManager.h"
#import "RHSound.h"
#import "../controller/GCodeEditorController.h"
#import "../controller/GCodeView.h"

@implementation PrinterConnection
@synthesize port;
@synthesize config;
@synthesize  machine;
@synthesize firmware;
@synthesize firmwareUrl;
@synthesize protocol;
@synthesize lastPrinterAction;
@synthesize responseDelegate;
@synthesize job;
@synthesize variables;

-(id)init {
    if((self=[super init])) {
        notifyOpen = [[NSNotification notificationWithName:@"RHConnectionOpen" object:nil] retain];
        binaryVersion = 0;
        readyForNextSend = YES;
        sdcardMounted = YES;
        garbageCleared = NO;
        history = [RHLinkedList new];
        resendNode = nil;
        lastAutocheck = 0;
        lastReceived = 0;
        lastline = 0;
        linesSend = 0;
        bytesSend = 0;
        errorsReceived = 0;
        comErrorsReceived = 0;
        resendError = 0;
        lastETA = 0;
        numberExtruder = 1;
        ignoreNextOk = NO;
        lastCommandSend = 0;
        lastProgress = -1000;
        speedMultiply = 100;
        isVirtualActive = NO;
        virtualPrinter = [VirtualPrinter new];
        x = y = z = e = 0;
        extruderTemp = bedTemp = 0;
        extruderOutput = -1;
        injectCommands = [RHLinkedList new];
        nackLines = [RHLinkedList new];
        self.variables = [NSMutableDictionary dictionaryWithCapacity:100];
        read = [[NSMutableString stringWithCapacity:100] retain];
        RHPrintjob *j = [RHPrintjob new];
        [self setJob:j];
        [j release];
        [self setMachine:@"Unknown"];
        [self setFirmware:@""];
        [self setFirmwareUrl:@""];
        [self setProtocol:@""];
        [self setLastPrinterAction:@""];
        eeprom = [EEPROMStorage new];
        nextlineLock = [NSLock new];
        historyLock = [NSLock new];
        injectLock = [NSLock new];
        nackLock = [NSLock new];
        timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self
                selector:@selector(handleTimer:) userInfo:self repeats:YES];
        analyzer = [[GCodeAnalyzer alloc] init];
        tempHistory = [TemperatureHistory new];
        [self setConfig:currentPrinterConfiguration];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(executeHostCommand:) name:@"RHHostCommand" object:nil]; 
    }
    return self;
}
-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [timer invalidate];
    [read release];
    [job release];
    [virtualPrinter release];
    [history release];
    [injectCommands release];
    [nackLines release];
    [machine release];
    [firmware release];
    [firmwareUrl release];
    [protocol release];
    [lastPrinterAction release];
    [nextlineLock release];
    [historyLock release];
    [injectLock release];
    [nackLock release];    
    [notifyOpen release];
    [analyzer release];
    [eeprom release];
    [tempHistory release];
    [super dealloc];
}
-(void)firePrinterState:(NSString*)stateInfo {
    [ThreadedNotification notifyASAP:@"RHPrinterInfo" object:stateInfo];
}
-(void)open {
    if(connected) return;
    isMarlin = NO;
    isRepetier = NO;
    isSprinter = NO;
    [self setConfig:currentPrinterConfiguration];
    closeAfterM112 = NO;
    NSString *deviceName = [config port];
    if ([deviceName compare:@"Virtual printer"]==NSOrderedSame)
    {
        isVirtualActive = YES;
        [virtualPrinter open];
        GCode *gc = [[GCode alloc] initFromString:@"M105"];
        [virtualPrinter receiveLine:gc];
        [gc release];
        connected = YES;
        if (config->protocol < 2)
            binaryVersion = 0;
        else binaryVersion = config->protocol - 1;
        readyForNextSend = YES;
        [nackLines clear];
        ignoreNextOk = NO;
        linesSend = errorsReceived = bytesSend = 0;
        gc = [[GCode alloc] initFromString:@"N0 M110"];
        [virtualPrinter receiveLine:gc];
        [gc release];
        gc = [[GCode alloc] initFromString:@"M115"];
        [virtualPrinter receiveLine:gc];
        [gc release];
        gc = [[GCode alloc] initFromString:@"M105"];
        [virtualPrinter receiveLine:gc];
        [gc release];
        [job updateJobButtons];
        [[NSNotificationQueue defaultQueue] enqueueNotification:notifyOpen postingStyle:NSPostNow];
        return;
    }
    isVirtualActive = NO;
    
    //	if (![deviceName isEqualToString:self.port.name]) {
        if([port isOpen])
            [self.port close];
        self.port = [[AMSerialPortList sharedPortList] serialPortForName:deviceName];
        garbageCleared = NO;
		// register as self as delegate for port
		self.port.readDelegate = self;
    //NSLog(@"ClearDTR: %i",(int)[port clearDTR]);
        [port setHangupOnClose:NO];
    //    [port setDTRInputFlowControl:NO];
        [port commitChanges];
		[rhlog addInfo:@"Attempting to connect to printer"];
		
		// open port - may take a few seconds ...
		if ([self.port open]) {
            // Set connection parameter
            // [port clearDTR];
            //[port setHangupOnClose:NO];
            [port setSpeed:config->baud];
            [port setParity:config->parity];
            [port setStopBits:config->stopBits];
            [port setDataBits:config->databits];
			[port commitChanges];
			[rhlog addInfo:@"Connection opened"];
            
			// listen for data in a separate thread
			[self.port readDataInBackground];

            readyForNextSend = YES;
            [nackLines clear ];
            ignoreNextOk = NO;
            linesSend = errorsReceived = bytesSend = 0;
            connected = YES;
            [self writeString:@"M105\r\n"];
            if (config->protocol < 2)
                binaryVersion = 0;
            else binaryVersion = config->protocol - 1;

            [self getInjectLock ];
            [self injectManualCommand:@"N0 M110" ]; // Make sure we tal about the same linenumbers
            [self injectManualCommand:@"M115"]; // Check firmware
            [self injectManualCommand:@"M105"]; // Read temperature
            [self injectManualCommand:@"M111 S6"]; // Read temperature
            if(speedMultiply!=100) {
                [self injectManualCommand:[NSString stringWithFormat:@"M220 S%d",speedMultiply]];    
            }
            [self returnInjectLock ];
            [job updateJobButtons];
            [[NSNotificationQueue defaultQueue] enqueueNotification:notifyOpen postingStyle:NSPostNow];

		} else { // an error occured while creating port
			[rhlog addInfo:[@"Couldn't open port for device " stringByAppendingString:deviceName]];
            
            self.port.readDelegate = nil;
            self.port = nil;
		}
	//}
    
}

-(void)close {
    if(connected) {
        if (isVirtualActive)
        {
            isVirtualActive = NO;
            connected = false;
            [virtualPrinter close];
        } else {
            connected = NO;
            [self.port close];
            
        }
        [job killJob];
        [history clear];
        [injectCommands clear];
        resendNode = nil;
        comErrorsReceived = 0;
		[rhlog add:@"Connection closed" level:RHLogInfo];
    }
    extruderOutput = -1;
    [ThreadedNotification notifyNow:@"RHConnectionClosed" object:nil]; 
    [self firePrinterState:@"Idle"];
    [job updateJobButtons];
    
}
- (void)pauseDidEnd {
    // Undo moves
    [self injectManualCommand:@"G90"];
    [self injectManualCommand:[NSString stringWithFormat:@"G1 X%f Y%f F%f",pauseX,pauseY,config->travelFeedrate]];
    [self injectManualCommand:[NSString stringWithFormat:@"G1 Z%f F%f",pauseZ,config->travelZFeedrate]];
    [self injectManualCommand:[NSString stringWithFormat:@"G92 E%f",pauseE]];
    if (analyzer->relative != pauseRelative)
    {
        [self injectManualCommand:(pauseRelative ? @"G91" : @"G90")];
    }
    [self injectManualCommand:[NSString stringWithFormat:@"G1 F%f",pauseF]]; // Reset old speed
    paused = NO;
}
-(void)pause:(NSString*) text
{
    if (paused) return;
    paused = YES;
    
    pauseX = analyzer->x;
    pauseY = analyzer->y;
    pauseZ = analyzer->z;
    pauseF = analyzer->f;
    pauseE = analyzer->e;
    pauseRelative = analyzer->relative;

    for (GCodeShort *code in app->gcodeView->pausejob->textArray)
    {
        [self injectManualCommand:code->text];
    }
    
    [app->pausedPanelText setStringValue:text];
    [app->pausedPanel setFloatingPanel:YES];
    [app->pausedPanel makeKeyAndOrderFront:app->mainWindow];
    /*[app->pausePanel setInformativeText:text];
    [app->pausePanel beginSheetModalForWindow:app->mainWindow modalDelegate:self didEndSelector:@selector(pauseDidEnd:returnCode:contextInfo:) contextInfo:nil];*/
}
-(void)writeString:(NSString*)text {
    if(!connected) return;
	[self.port writeString:text usingEncoding:NSASCIIStringEncoding error:NULL];
}
-(void)writeData:(NSData*)data {
    if(!connected) return;
	[self.port writeData:data error:nil];    
}

- (void)serialPort:(AMSerialPort *)sendPort didReadData:(NSData *)data
{
	// this method is called if data arrives 
	if ([data length] > 0) {
		NSString *text = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
        [read appendString:text];
        [read replaceOccurrencesOfString:@"\r" withString:@"\n" options:NSLiteralSearch range:NSMakeRange(0, [read length])];
        do {
            NSRange range = [read rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]];
            if (range.location==NSNotFound) break;
            NSString *response = [read substringWithRange:NSMakeRange(0,range.location)];
            [read deleteCharactersInRange:NSMakeRange(0,range.location+1)];
            if (response.length > 0)
            {
                [self analyzeResponse:response];
            }
            [self trySendNextLine];
        } while (YES);
        lastReceived = CFAbsoluteTimeGetCurrent();
		[text release];
		// continue listening
		[port readDataInBackground];
	} else { // port closed
		[rhlog add:@"Port unexpectedly closed" level:RHLogError];
        [self close];
	}
}
-(void)virtualResponse:(NSString*)response
{
    if (response.length > 0)
    {
        [self analyzeResponse:response];
    }
    [self trySendNextLine];
     lastReceived = CFAbsoluteTimeGetCurrent();
}
-(void)injectManualCommandFirst:(NSString*)command {
    GCode *gc = [[GCode alloc] initFromString:command];
    if(gc->comment) {
        [gc release];
        return;   
    }
    [historyLock lock];
    [injectCommands addFirst:gc];
    [historyLock unlock];
    [gc release];
    if (job->dataComplete == false)
    {
        if (injectCommands->count == 0)
        {
            [self firePrinterState:@"Idle"];
        }
        else
        {
            [self firePrinterState:[NSString stringWithFormat:@"%d commands waiting",injectCommands->count]];
        }
    }    
}
-(void)injectManualCommand:(NSString*)command {
    GCode *gc = [[GCode alloc] initFromString:command];
    if(gc->comment) {
        [gc release];
        return;   
    }
    [historyLock lock];
    [injectCommands addLast:gc];
    [historyLock unlock];
    [gc release];
    if (job->dataComplete == false)
    {
        if (injectCommands->count == 0)
        {
            [self firePrinterState:@"Idle"];
        }
        else
        {
            [self firePrinterState:[NSString stringWithFormat:@"%d commands waiting",injectCommands->count]];
        }
    }
    
}

-(void)doDispose {
    if (analyzer->hasXHome == false || analyzer->hasYHome == false) return; // don't know where we are
    float dx = config->disposeX - analyzer->xOffset-(analyzer->relative?analyzer->x:0);
    float dy = config->disposeY - analyzer->yOffset - (analyzer->relative ? analyzer->y : 0);
    [self getInjectLock];
    [self injectManualCommand:[NSString stringWithFormat:@"G1 X%f Y%f F%f",dx,dy,config->travelFeedrate]];
    if (analyzer->hasZHome && analyzer->z - analyzer->zOffset < config->disposeZ && 
        config->disposeZ > 0 && config->disposeZ < config->height)
    {
        float dz = config->disposeZ - analyzer->zOffset - (analyzer->relative ? analyzer->z : 0);
        [self injectManualCommand:[NSString stringWithFormat:@"G1 Z%f F%f",dz,config->travelZFeedrate]];
    }
    [self returnInjectLock];
    
}
-(BOOL)hasInjectedMCommand:(int)code
{
    BOOL has = NO;
    [historyLock lock];
    for (GCode *co in injectCommands)  {
       if (co.hasM && co.getM == code)  {
           has = true;
           break;
       }
    }
    [historyLock unlock];
    return has;
}
-(void)handleTimer:(NSTimer*)theTimer
{
    if (connected == false || garbageCleared==false) return;
    double actTime = CFAbsoluteTimeGetCurrent();
    if(closeAfterM112) {
        if([self hasInjectedMCommand:112]) {
            [self close];
            return;
        }
    } else
    if (config->autocheckTemp && actTime - lastAutocheck > (double)config->autocheckInterval && job->exclusive==NO)
    {
        //NSLog(@"Temp check %f to %f in %d",lastAutocheck,actTime,config->autocheckInterval);
        lastAutocheck = actTime;
        // only inject temp check, if not present. Some commands
        // take a long time and it makes no sense, to push 30 M105
        // commands as soon as it's ready.
        BOOL found = NO;
        [historyLock lock];
        for(GCode *co in injectCommands)  {
            if (co.hasM && co.getM == 105) {
                found = YES;
                break;
            }
        }
        [historyLock unlock];
        if (!found)
        {
            [self getInjectLock];
            [self injectManualCommand:@"M105"];
            [self returnInjectLock];
        }
    }
    if ((!config->pingPongMode && nackLines->count==0) || (config->pingPongMode && readyForNextSend)) 
        [self trySendNextLine];
    
    // If the reprap starts sending response it should finish soon
    else if (resendError < 4 && read.length > 0 && lastReceived - actTime > 0.4)
    {
        // force response, even if we
        // get a resend request
        [rhlog addError:[NSString stringWithFormat:@"Reset output. After some wait, I got only %@",read]];
        [read setString:@""];
        if (config->pingPongMode)
            readyForNextSend = YES;
        else
        {
            [nackLock lock];
            if (nackLines->count > 0)
                 [nackLines removeFirst];
            [nackLock unlock];
        }
        [self trySendNextLine];
    }
}
-(void)storeHistory:(GCode*) gcode
{
    [history addLast:gcode];
    [rhlog addSend:[gcode getAsciiWithLine:YES withChecksum:YES]];
    if (history->count > 40)
        [history removeFirst];
}
-(int)receivedCount
{
    int n = 0;
    [nackLock lock];
    for(NSNumber *i in nackLines)
        n += [i intValue];
    [nackLock unlock];
    return n;
}
-(void)resendLine:(int)line
{
    resendError++;
    errorsReceived++;
    if(!config->pingPongMode && errorsReceived==3 && config->receiveCacheSize>63) {
        config->receiveCacheSize = 63;
        [rhlog addError:@"You are getting many communication errors. Perhaps your receive cache is is too large. Reduced size to 63 byte."];
    }
    if (config->pingPongMode)
        readyForNextSend = YES;
    else  {
        [nackLock lock];
        [nackLines clear]; // printer flushed all coming commands
        [nackLock unlock];
    }
    
    RHListNode *node = history.lastNode;
    if (resendError > 5 || node==nil)
    {
        [rhlog addError:@"Receiving only error messages. Stopped communication."];
        [self close];
        return; // give up, something is terribly wrong
    }
    line &=65535;
    do
    {
        GCode *gc = node->value;
        if (gc.hasN && (gc.getN & 65535) == line)
        {
            resendNode = node;
            if (binaryVersion != 0)
            {
                int send = self.receivedCount;
               // serial.DiscardOutBuffer();
                [NSThread sleepForTimeInterval:send*10/config->baud];
                uint8  buf[32];
                for (int i = 0; i < 32; i++) buf[i] = 0;
                NSData *dat = [NSData dataWithBytes:buf length:32];
                [self writeData:dat];
                [NSThread sleepForTimeInterval:320/config->baud];
            }
            else
            {
                [NSThread sleepForTimeInterval:config->receiveCacheSize*10/config->baud]; // Wait for buffer to empty
            }
            [self trySendNextLine];
            return;
        }
        if (node->prev == nil) return;
        node = node->prev;
    } while (YES);
}
-(void)executeHostCommand:(NSNotification*)event {
    GCode *gc = [event object];
    NSString *com = gc.hostCommand;
    if ([com compare:@"@info"]==NSOrderedSame)
    {
        [rhlog addInfo:gc.hostParameter];
    }
    else if ([com compare:@"@pause"]==NSOrderedSame)
    {
        [sound playPrintjobPaused:NO];
        [self pause:gc.hostParameter];
    }
    else if ([com compare:@"@sound"]==NSOrderedSame)
    {
        [sound playCommand:NO];
    }
}
-(void)trySendNextLine
{
    if (!garbageCleared) return;
    [nextlineLock lock];
    if (config->pingPongMode && !readyForNextSend) {[nextlineLock unlock];return;}
    if (!connected) {[nextlineLock unlock];return;} // Not ready yet
    GCode *gc = nil;
    // first resolve old communication problems
    if (resendNode != nil) {
        gc = resendNode->value;
        if (binaryVersion == 0)  {
           NSString *cmd = [NSString stringWithFormat:@"%@\r\n",[gc getAsciiWithLine:YES withChecksum:YES]];
            if (!config->pingPongMode && 
                self.receivedCount + cmd.length + 2 > config->receiveCacheSize) {
                [nextlineLock unlock];return;
            } // printer cache full
           if (config->pingPongMode) readyForNextSend = NO;
           else {
               [nackLock lock];
               [nackLines addLast:[NSNumber numberWithInt:(int)(cmd.length + 2)]]; 
               [nackLock unlock];
           }
           [self writeString:[cmd stringByAppendingString:@"\r\n"]];
           bytesSend += cmd.length;
        } else  {
            NSData *cmd = [gc getBinary:binaryVersion];
            if (!config->pingPongMode && self.receivedCount + cmd.length > config->receiveCacheSize) {
                [nextlineLock unlock];
                return; // printer cache full   
            }
            if (config->pingPongMode) readyForNextSend = NO;
            else {
                [nackLock lock];
                [nackLines addLast:[NSNumber numberWithInt:(int)(cmd.length)]]; 
                [nackLock unlock];
                [self writeData:cmd];
                bytesSend += cmd.length;
            }
        }
        linesSend++;
        lastCommandSend = CFAbsoluteTimeGetCurrent();
        resendNode = resendNode->next;
        [rhlog addText:[@"Resend: " stringByAppendingString:[gc getAsciiWithLine:YES withChecksum:YES]]];
        [nextlineLock unlock];
        return;
    }
    if (resendError > 0) resendError--; // Drop error counter
    // then check for manual commands
    if (injectCommands->count > 0)  {
        [historyLock lock];
        gc = injectCommands.peekFirst;
        if (gc->hostCommand)
        {
            [injectCommands removeFirst];
            [historyLock unlock];
            [ThreadedNotification notifyNow:@"RHHostCommand" object:gc];
            [analyzer analyze:gc];
            [nextlineLock unlock];
            return;
        }
        [gc setN:++lastline];
        if (isVirtualActive) {
            [virtualPrinter receiveLine:gc];
            bytesSend += gc.getOriginal.length;
        }
        else
        if (binaryVersion == 0)  {
            NSString *cmd = [NSString stringWithFormat:@"%@\r\n",[gc getAsciiWithLine:YES withChecksum:YES]];
            if (!config->pingPongMode && self.receivedCount + cmd.length + 2 > config->receiveCacheSize) { 
                --lastline;
                [historyLock unlock];
                [nextlineLock unlock];
                return; 
            } // printer cache full
            if (config->pingPongMode) readyForNextSend = NO;
            else { 
                [nackLock lock];
                [nackLines addLast:[NSNumber numberWithInt:(int)(cmd.length)]]; 
                [nackLock unlock];
            }
            [self writeString:cmd];
            bytesSend += cmd.length;                
        } else {
            NSData *cmd = [gc getBinary:binaryVersion];
            if (!config->pingPongMode && self.receivedCount + cmd.length > config->receiveCacheSize) { --lastline; 
                [historyLock unlock];
                [nextlineLock unlock];return; } // printer cache full
            if (config->pingPongMode) readyForNextSend = NO;
            else {
                [nackLock lock];
                [nackLines addLast:[NSNumber numberWithInt:(int)(cmd.length)]]; 
                [nackLock unlock];
            }
            [self writeData:cmd];
            bytesSend += cmd.length;
        }
        [injectCommands removeFirst];
        [historyLock unlock];
        linesSend++;
        lastCommandSend = CFAbsoluteTimeGetCurrent();
        [self storeHistory:gc];
        [analyzer analyze:gc];
        if (job->dataComplete == NO) {
            if (injectCommands->count == 0) {
                [self firePrinterState:@"Idle"];
            } else {
                [self firePrinterState:[NSString stringWithFormat:@"%d commands waiting",injectCommands->count]];
            }
        }
        [nextlineLock unlock];
        return;
    }
    // do we have a printing job?
    if (job->dataComplete && !paused)  {
        [historyLock lock];
        gc = job.peekData;
        if (gc->hostCommand)
        {
            [ThreadedNotification notifyNow:@"RHHostCommand" object:gc];
            [analyzer analyze:gc];
            [historyLock unlock];
            [job popData];
            [nextlineLock unlock];
            return;
        }
        [gc setN:++lastline];
        if (isVirtualActive) {
            [virtualPrinter receiveLine:gc];
            bytesSend += gc.getOriginal.length;
        }
        else
        if (binaryVersion == 0) {
            NSString *cmd = [NSString stringWithFormat:@"%@\r\n",[gc getAsciiWithLine:YES withChecksum:YES]];
            if (!config->pingPongMode && self.receivedCount + cmd.length + 2 > config->receiveCacheSize) { 
                --lastline;
                [historyLock unlock];
                [nextlineLock unlock];
                return; 
            } // printer cache full
            if (config->pingPongMode) readyForNextSend = NO;
            else { 
                [nackLock lock];
                [nackLines addLast:[NSNumber numberWithInt:(int)(cmd.length)]]; 
                [nackLock unlock];
            }
            [self writeString:cmd];
            bytesSend += cmd.length;                
        } else {
            NSData *cmd = [gc getBinary:binaryVersion];
            if (!config->pingPongMode && self.receivedCount + cmd.length > config->receiveCacheSize) {
                --lastline;
                [historyLock unlock];
                [nextlineLock unlock];return; 
            } // printer cache full
            if (config->pingPongMode) readyForNextSend = NO;
            else {
                [nackLock lock];
                [nackLines addLast:[NSNumber numberWithInt:(int)(cmd.length)]]; 
                [nackLock unlock];
            }
            [self writeData:cmd];
            bytesSend += cmd.length;
        }
        [self storeHistory:gc];
        [historyLock unlock];
        [job popData];
        linesSend++;
        lastCommandSend = CFAbsoluteTimeGetCurrent();
        [analyzer analyze:gc];
        if(lastCommandSend-lastETA>1) {
            lastETA = lastCommandSend;
            if(job->maxLayer>0)
                [self firePrinterState:[NSString stringWithFormat:@"Printing...ETA %@ Layer %d/%d",job.ETA,analyzer->layer,(int)job->maxLayer]];
            else
                [self firePrinterState:[@"Printing...ETA " stringByAppendingString:job.ETA]];
        }
        if (job.percentDone >= 0 && fabs(lastProgress-job.percentDone)>0.3) {
            lastProgress = job.percentDone;
            [ThreadedNotification notifyASAP:@"RHProgress" object:[NSNumber numberWithFloat:lastProgress]];
        }
        //logprogress = job.PercentDone;
    }                
    [nextlineLock unlock];
}


-(void)getInjectLock
{
    [injectLock lock];
   /* try
    {
        injectLock.WaitOne();
        injectLock.Reset();
    }
    catch (Exception e)
    {
        firePrinterAction(e.ToString());
    }*/
}
-(void)returnInjectLock
{
    [injectLock unlock];
}
/// <summary>
/// Analyzes a response from the printer.
/// Updates data and sends events according to the data.
/// </summary>
/// <param name="res"></param>
-(void)analyzeResponse:(NSString*) res
{
    RHLogType level=RHLogResponse;
    if (responseDelegate != nil)
    {
        [responseDelegate responseReceived:res];
    }
    if(app->sdcardManager!=nil)
        [app->sdcardManager analyze:res];
    NSString *h = [self extract:res identifier:@"FIRMWARE_NAME:"];
    if (h != nil)
    {
        level = RHLogInfo;
        [self setFirmware:h];
        isRepetier = [h rangeOfString:@"Repetier"].location!=NSNotFound;
        isMarlin = [h rangeOfString:@"Marlin"].location!=NSNotFound;
        [ThreadedNotification notifyASAP:@"RHFirmware" object:h];
    }
    h = [self extract:res identifier:@"FIRMWARE_URL:"];
    if (h != nil)
    {
        level = RHLogInfo;
        [self setFirmwareUrl:h];
    }
    h = [self extract:res identifier:@"PROTOCOL_VERSION:"];
    if (h != nil)
    {
        level = RHLogInfo;
        [self setProtocol:h];
    }
    h = [self extract:res identifier:@"MACHINE_TYPE:"];
    if (h != nil)
    {
        level = RHLogInfo;
        [self setMachine:h];
    }
    h = [self extract:res identifier:@"EXTRUDER_COUNT:"];
    if (h != nil)
    {
        level = RHLogInfo;
        numberExtruder = h.intValue;
    }
    h = [self extract:res identifier:@"X:"];
    if (h != nil)
    {
        level = RHLogInfo;
        x = h.doubleValue;
        analyzer->x = x;
        if(x==0)
            analyzer->hasXHome = true;
    }
    h = [self extract:res identifier:@"Y:"];
    if (h != nil)
    {
        level = RHLogInfo;
        y = h.doubleValue;
        analyzer->y = y;
        if(y==0)
            analyzer->hasYHome = true;
    }
    h = [self extract:res identifier:@"Z:"];
    if (h != nil)
    {
        level = RHLogInfo;
        z = h.doubleValue;
        analyzer->z = z;
        if(z==0)
            analyzer->hasZHome = true;
    }
    h = [self extract:res identifier:@"E:"];
    if (h != nil)
    {
        level = RHLogInfo;
        e = h.doubleValue;
    }
    bool tempChange = false;
    h = [self extract:res identifier:@"T:"];
    if (h != nil)
    {
        level = RHLogText; // dont log, we see result in status
        extruderTemp = h.doubleValue;
        tempChange = true;
        h = [self extract:res identifier:@"@:"];
        if (h != nil)
        {
            extruderOutput = h.intValue;
            if(isMarlin) extruderOutput*=2;
        }
    }
    h = [self extract:res identifier:@"B:"];
    if (h != nil)
    {
        level = RHLogText; // don't log, we see result in status
        bedTemp = h.doubleValue;
        tempChange = true;
    }
    if ([StringUtil string:res startsWith:@"EPR:"])  {
        [eeprom add:res];
    }
    if ((h = [self extract:res identifier:@"SpeedMultiply:"])!=nil)  {
        speedMultiply = h.intValue;
        level = RHLogResponse;
        [ThreadedNotification notifyNow:@"SpeedMultiply" object:h];
    }
    if ((h = [self extract:res identifier:@"TargetExtr0:"])!=nil)  {
        if(analyzer->activeExtruder==0)
            analyzer->extruderTemp = h.intValue;
        [ThreadedNotification notifyNow:@"TargetExtr0" object:h];
    }
    if ((h = [self extract:res identifier:@"TargetExtr1:"])!=nil)  {
        if(analyzer->activeExtruder==1)
            analyzer->extruderTemp = h.intValue;
        [ThreadedNotification notifyNow:@"TargetExtr1" object:h];
    }
    if ((h = [self extract:res identifier:@"TargetBed:"])!=nil)  {
        analyzer->bedTemp = h.intValue;
        [ThreadedNotification notifyNow:@"TargetBed" object:h];
    }
    if ((h = [self extract:res identifier:@"Fanspeed:"])!=nil)  {
        analyzer->fanVoltage = h.intValue;
        [ThreadedNotification notifyNow:@"Fanspeed" object:h];
    }
    if ([StringUtil string:res startsWith:@"MTEMP:"]) // Temperature monitor 
    {
        level = RHLogResponse; // this happens to often to log. Temperture monitor i sthe log
        NSArray *sl = [StringUtil explode:[res substringFromIndex:6] sep:@" "];
        if (sl.count == 4)
        {
            int time = ((NSString*)[sl objectAtIndex:0]).intValue;
            int temp = ((NSString*)[sl objectAtIndex:1]).intValue;
            int target = ((NSString*)[sl objectAtIndex:2]).intValue;
            int output = ((NSString*)[sl objectAtIndex:3]).intValue;
            if (time > 0 && temperatureDelegate != nil)
            {
                [temperatureDelegate monitoredTemperatureAt:time temp:temp target:target output:output];
            }
            TempertureEntry *te = [[TempertureEntry alloc] initWithMonitor:analyzer->tempMonitor temp:temp output:output targetBed:analyzer->bedTemp targetExtruder:analyzer->extruderTemp];
            [ThreadedNotification notifyASAP:@"RHTempMonitor" object:te];
            [te release];

        }
    }
    h = [self extract:res identifier:@"REPETIER_PROTOCOL:"];
    if (h != nil)
    {
        level = RHLogInfo;
        binaryVersion = h.intValue;
        if (config->protocol == 1) binaryVersion = 0; // force ascii transfer
    }
    if ([StringUtil string:res startsWith:@"start"] || 
        (garbageCleared==false && [res rangeOfString:@"start"].location!=NSNotFound))
    {
        level = RHLogInfo;
        lastline = 0;
        [job killJob]; // continuing the old job makes no sense, better save the plastic
        resendNode = nil;
        sdcardMounted = YES;
        [history clear];
        [analyzer start];
        readyForNextSend = YES;
        [nackLines clear];
        garbageCleared = YES;
    }
    if ([self extract:res identifier:@"Error:"]!=nil)
    {
        level = RHLogError;
        [sound playError:NO];
    }
    if (tempChange) {
        if(temperatureDelegate != nil)
            [temperatureDelegate receivedTemperature:extruderTemp bed:bedTemp];
        [ThreadedNotification notifyASAP:@"RHTemperatureRead" object:nil];
        TempertureEntry *te = [[TempertureEntry alloc] initWithExtruder:extruderTemp bed:bedTemp targetBed:analyzer->bedTemp targetExtruder:analyzer->extruderTemp];
        if(extruderOutput>=0)
            te->output = extruderOutput;
        [ThreadedNotification notifyASAP:@"RHTempMonitor" object:te];
        [te release];
    }
    h = [self extract:res identifier:@"Resend:"];
    if (h != nil)
    {
        [rhlog addResponse:res level:RHLogWarning];
        int line = h.intValue;
        ignoreNextOk = config->okAfterResend;
        [self resendLine:line];
    }
    else if ([StringUtil string:res startsWith:@"ok"])
    {
        garbageCleared = YES;
        //if(Main.main.logView.toolACK.Checked)
        //    log(res, true, level);
        if (!ignoreNextOk)  // ok in response of resend?
        {
            if (config->pingPongMode) readyForNextSend = YES;
            else
            {
                [nackLock lock];
                if (nackLines->count > 0)
                   [nackLines removeFirst];
                [nackLock unlock];
            }
            resendError = 0;
            [self trySendNextLine];
        } else
            ignoreNextOk = false;
        if (garbageCleared)
            [rhlog addResponse:res level:RHLogText];
    }
    else if ([res compare:@"wait"]==NSOrderedSame && CFAbsoluteTimeGetCurrent()-lastCommandSend>5)
    {
       // if (Main.main.logView.toolACK.Checked)
       //     log(res, true, level);
        if (config->pingPongMode) readyForNextSend = YES;
        else
        {
            [nackLock lock];
            [nackLines clear];
            [nackLock unlock];
        }
        resendError = 0;
        if (garbageCleared)
            [rhlog addResponse:res level:RHLogText];
        [self trySendNextLine];
    }
    else if (garbageCleared) 
        [rhlog addResponse:res level:level];
    
}
-(NSString*)extract:(NSString*)source identifier:(NSString*)ident
{
    NSRange pos;
    pos.location = 0;
    do
    {
        if(pos.location>0) pos.location++;
        pos = [source rangeOfString:ident options:NSLiteralSearch range:NSMakeRange(pos.location,source.length-pos.location)];
        if (pos.location == NSNotFound) return nil;
        if(pos.location==0) break;
    } while ([source characterAtIndex:pos.location-1] != ' ');
    int start = (int)(pos.location + ident.length);
    int end = start;
    while (end < source.length && [source characterAtIndex:end] != ' ') end++;
    pos.location = start;
    pos.length = end-start;
    return [source substringWithRange:pos];
}
-(NSString*)repairKey:(NSString*)key {
    key = [StringUtil trim:key];
    key = [key stringByReplacingOccurrencesOfString:@" " withString:@"_"];
    key = [key stringByReplacingOccurrencesOfString:@";" withString:@"_"];
    key = [key stringByReplacingOccurrencesOfString:@"}" withString:@"_"];
    return [key stringByReplacingOccurrencesOfString:@":" withString:@"_"];
}
-(void)importVariablesFormDictionary:(NSDictionary*)dict {
    for(NSString *key in [dict allKeys]) {
        NSString *val = [StringUtil trim:[dict objectForKey:key]];
        NSRange r = [val rangeOfString:key];
        if(r.location!=NSNotFound) {
            NSRange re = [val rangeOfString:@"=" options:NSLiteralSearch range:NSMakeRange(r.location+r.length, val.length-r.location-r.length)];
            if(re.location!=NSNotFound) {
                val = [StringUtil trim:[val substringFromIndex:re.location+1]];
            }
        }
        NSString *rkey = [self repairKey:key];
        [variables setObject:val forKey:rkey];
    }
}
-(BOOL)containsVariables:(NSString*)orig {
    NSRange r = [orig rangeOfString:@"${"];
    return r.location!=NSNotFound;
}
-(NSString*)replaceVariables:(NSString*)orig {
    NSMutableString *res = [NSMutableString new];
    NSRange r,r2;
    NSInteger start = 0;
    do {
        r = [orig rangeOfString:@"${" options:NSLiteralSearch range:NSMakeRange(start, orig.length-start)];
        if(r.location == NSNotFound) {
            [res appendString:[orig substringFromIndex:start]];
            break;
        }
        r2 = [orig rangeOfString:@"}" options:NSLiteralSearch range:NSMakeRange(r.location+2, orig.length-r.location-2)];
        if(r2.location == NSNotFound) { // missing closing bracket
            [res appendString:[orig substringFromIndex:start]];
            break;
        }
        [res appendString:[orig substringWithRange:NSMakeRange(start,r.location-start)]];
        NSString *varnamelist = [orig substringWithRange:NSMakeRange(r.location+2,r2.location-r.location-2)];
        NSRange r3 = [varnamelist rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@":"]];
        NSString *defaultval=@"";
        if(r3.location!=NSNotFound) {
            defaultval = [varnamelist substringFromIndex:r3.location+1];
            varnamelist = [varnamelist substringToIndex:r3.location];
        }
        NSArray *varnames = [StringUtil explode:varnamelist sep:@";"];
        BOOL found = NO;
        for(NSString *name in varnames) {
            NSString *val = [variables objectForKey:name];
            if(val) {
                [res appendString:val];
                found = YES;
                break;
            }
        }
        if(!found) [res appendString:defaultval];
        start = r2.location+1;
    } while(YES);
    return [NSString stringWithString:[res autorelease]];
}
@end

PrinterConnection *connection;