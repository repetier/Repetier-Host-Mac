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

#import "RHPrintjob.h"
#import "RHLogger.h"
#import "PrinterConnection.h"
#import "ThreadedNotification.h"
#import "GCodeShort.h"
#import "RHSound.h"
#import "RHAppDelegate.h"
#import "GCodeEditorController.h"
#import "GCodeView.h"
#import "../controller/RHSlicer.h"

@implementation PrintTime

-(id)initWithLine:(int)linenumber {
    if((self = [super init])) {
        line = linenumber;
        time =  CFAbsoluteTimeGetCurrent();
    }
    return self; 
}
-(void)dealloc {
    [super dealloc];
}
@end

@implementation RHPrintjob

@synthesize jobStarted;
@synthesize jobFinished;
@synthesize ana=_ana;

-(id)init {
    if((self = [super init])) {
        self.ana = [[[GCodeAnalyzer alloc] init] autorelease];
        self.ana->privateAnalyzer = YES;
        jobList = [RHLinkedList new];
        //times = [RHLinkedList new];
        //timeLock = [[NSLock alloc] init];
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
        [dateFormatter setTimeStyle:NSDateFormatterLongStyle];
        timeFormatter = [[NSDateFormatter alloc] init];
        //[timeFormatter setTimeStyle:NSDateFormatterLongStyle];
        [timeFormatter setDateFormat:@"HH:mm:ss"];
        dataComplete = NO;
        totalLines = 0;
        linesSend = 0;
        computedPrintingTime = 0;
        exclusive = NO;
        mode = 0;
        etaTimeLeft = YES;
    }
    return self;
}

-(void)dealloc {
    self.ana=nil;
    [jobList release];
    //[times release];
    //[timeLock release];
    [dateFormatter release];
    [timeFormatter release];
    [super dealloc];
}
-(void) updateJobButtons {
    [ThreadedNotification notifyASAP:@"RHJobChanged" object:self];
}
-(void) beginJob
{
    [app->rightTabView selectTabViewItem:app->printTab];
    [connection firePrinterState:@"Building print job..."];
    dataComplete = NO;
    [self.ana start];
    [jobList clear];
    //[times clear];
    totalLines = 0;
    linesSend = 0;
    computedPrintingTime = 0;
    mode = 1;
    maxLayer = 0;
    [app->rhslicer slicerConfigToVariables];  // Start with fresh variable set
    [connection->analyzer startJob];
    [ThreadedNotification notifyASAP:@"RHJobChanged" object:self];
}
-(void) endJob
{
    if (jobList->count == 0)
    {
        mode = 0;
        [connection firePrinterState:@"Idle"];
        [ThreadedNotification notifyASAP:@"RHJobChanged" object:self];
        return;
    }
    dataComplete = YES;
    [self setJobStarted:[NSDate date]];
    [connection firePrinterState:@"Printing..."];
}
-(void) killJob
{
    if (dataComplete == NO && jobList->count == 0) return;
    dataComplete = NO;
    [self setJobStarted:[NSDate date]];
    [self setJobFinished:[NSDate date]];
    [jobList clear];
    mode = 3;
    exclusive = NO;
    [connection injectManualCommandFirst:@"M29"];
    [ThreadedNotification notifyASAP:@"RHJobChanged" object:self];
    [connection firePrinterState:@"Job killed" ];
    for(GCodeShort *code in app->gcodeView->killjob->textArray) {
        [connection injectManualCommand:code->text];
    }
    [self doEndKillActions];
}
-(void) doEndKillActions
{
    if (exclusive) // not a normal print job
    {
        exclusive = NO;
        return;
    }
    if (currentPrinterConfiguration->afterJobDisableExtruder)
    {
        for(int i=0;i<connection->numberExtruder;i++)
            [connection injectManualCommand:[NSString stringWithFormat:@"M104 S0 T%d",i]];
    }
    if(currentPrinterConfiguration->afterJobDisableHeatedBed) 
        [connection injectManualCommand:@"M140 S0"];
    if (currentPrinterConfiguration->afterJobGoDispose)
        [connection doDispose];
    if (currentPrinterConfiguration->afterJobDisableMotors)
    {
        [connection injectManualCommand:@"M84"];
    }
}
-(void) pushData:(NSString*)code
{
    NSArray *lines = [code componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]; 
    for (NSString *line in lines)
    {
        if (line.length == 0) continue;
        GCode *gcode = [[GCode alloc] initFromString:line];
        if (!gcode->comment)
        {
            [jobList addLast:code];
            totalLines++;
        }
        [gcode release];
    }
}
-(void)pushShortArray:(NSArray*)codes {
    for (GCodeShort *code in codes)
    {
        NSString *line = code->text;        
        if (line.length == 0) continue;
        [self.ana analyzeShort:code];
        GCode *gcode = [[GCode alloc] initFromString:line];
        if (!gcode->comment)
        {
            [jobList addLast:code->text];
            totalLines++;
        }
        [gcode release];
        if(code.hasLayer)
            maxLayer = code.layer;
    }    
    computedPrintingTime = self.ana->printingTime;
}
/// <summary>
/// Check, if more data is stored
/// </summary>
/// <returns></returns>
-(BOOL) hasData
{
    return linesSend < totalLines;
}
-(GCode*) peekData
{
    return [[[GCode alloc] initFromString:jobList.peekFirst] autorelease];
}
-(GCode*)popData
{
    if (jobList->count == 0) return nil;
    linesSend++;
    GCode *gc = [[[GCode alloc] initFromString:[jobList removeFirst]] autorelease];
    /*[timeLock lock];
    [times addLast:[[[PrintTime alloc] initWithLine:linesSend] autorelease]];
    if (times->count > 1500)
        [times removeFirst];
    [timeLock unlock];*/
    if (jobList->count == 0 && dataComplete)
    {
        dataComplete = false;
        mode = 2;
        [self setJobFinished:[NSDate date]];
        double ticks = (jobFinished.timeIntervalSince1970 - jobStarted.timeIntervalSince1970);
        int hours = ticks / 3600;
        ticks -= 3600 * hours;
        int min = ticks / 60;
        ticks -= 60 * min;
        int sec = ticks;
        [rhlog addInfo:[NSString stringWithFormat:@"Printjob finished at %@",[dateFormatter stringFromDate:jobFinished]]];
        NSMutableString *s = [NSMutableString stringWithCapacity:40];
        if (hours > 0)
        {
            [s appendFormat:@"%d",hours];
            [s appendString:@"h:"];
        }
        if (min > 0)
        {
            [s appendFormat:@"%02d",min];
            [s appendString:@"m:"];
        }
        [s appendFormat:@"%02d",sec];
        [s appendString:@"s"];
        [rhlog addInfo:[NSString stringWithFormat:@"Printing time: %@",s]];
        [rhlog addInfo:[NSString stringWithFormat:@"lines send: %d",linesSend]];
        [connection firePrinterState:[NSString stringWithFormat:@"Finished in %@",s]];
        [sound playPrintjobFinished:NO];
        [self doEndKillActions];
        [ThreadedNotification notifyASAP:@"RHJobChanged" object:self];
    }
    return gc;
}
-(float) percentDone {
   if(totalLines==0) return 100;
   return 100*(float)linesSend/(float)totalLines;
}
-(NSString*) ETA {
    if (linesSend < 3) return @"---";
    double ticks = (computedPrintingTime - connection->analyzer->printingTime) * (1.0 + 0.01 * currentPrinterConfiguration->addPrintingTime)*100.0/(double)connection->speedMultiply;
    /*[timeLock lock];
    if (times->count > 100) {
       PrintTime *t1 = times.peekFirst;
       PrintTime *t2 = times.peekLast;
       ticks = (t2->time - t1->time) * (totalLines - linesSend) / (t2->line - t1->line + 1);
    } else
       ticks = (((NSDate*)[NSDate date]).timeIntervalSince1970 - jobStarted.timeIntervalSince1970) * (totalLines - linesSend) / linesSend;
    [timeLock unlock];*/
    if(etaTimeLeft) {
        long hours = ticks / 3600;
        ticks -= 3600 * hours;
        long min = ticks / 60;
        ticks -= 60 * min;
        long sec = ticks;
        NSString *s = [NSString stringWithFormat:@"%ldh:%02ldm:%02lds",hours,min,sec];
        return s;
    } else {
        NSDate *date = [[NSDate date] dateByAddingTimeInterval:ticks];
        return [timeFormatter stringFromDate:date];
    }
}
@end
