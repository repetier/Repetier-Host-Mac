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

-(id)init {
    if((self = [super init])) {
        jobList = [RHLinkedList new];
        times = [RHLinkedList new];
        timeLock = [[NSLock alloc] init];
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
        [dateFormatter setTimeStyle:NSDateFormatterLongStyle];
        dataComplete = NO;
        totalLines = 0;
        linesSend = 0;
        exclusive = NO;
        mode = 0;
    }
    return self;
}

-(void)dealloc {
    [jobList release];
    [times release];
    [timeLock release];
    [dateFormatter release];
    [super dealloc];
}
-(void) updateJobButtons {
    [ThreadedNotification notifyASAP:@"RHJobChanged" object:self];
}
-(void) beginJob
{
    [connection firePrinterState:@"Building print job..."];
    dataComplete = NO;
    [jobList clear];
    [times clear];
    totalLines = 0;
    linesSend = 0;
    mode = 1;
    maxLayer = 0;
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
        [connection injectManualCommand:@"M104 S0"];
    }
    if(currentPrinterConfiguration->afterJobDisableHeatedBed) 
        [connection injectManualCommand:@"M140 S0"];
    if (currentPrinterConfiguration->afterJobGoDispose)
        [connection doDispose];
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
            [jobList addLast:gcode];
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
        GCode *gcode = [[GCode alloc] initFromString:line];
        if (!gcode->comment)
        {
            [jobList addLast:gcode];
            totalLines++;
        }
        [gcode release];
        if(code.hasLayer)
            maxLayer = code.layer;
    }    
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
    return jobList.peekFirst;
}
-(GCode*)popData
{
    if (jobList->count == 0) return nil;
    linesSend++;
    GCode *gc = [jobList removeFirst];
    [timeLock lock];
    [times addLast:[[[PrintTime alloc] initWithLine:linesSend] autorelease]];
    if (times->count > 1500)
        [times removeFirst];
    [timeLock unlock];
    if (jobList->count == 0)
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
            [s appendFormat:@"%d",min];
            [s appendString:@"m:"];
        }
        [s appendFormat:@"%d",sec];
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
    double ticks = 0;
    [timeLock lock];
    if (times->count > 100) {
       PrintTime *t1 = times.peekFirst;
       PrintTime *t2 = times.peekLast;
       ticks = (t2->time - t1->time) * (totalLines - linesSend) / (t2->line - t1->line + 1);
    } else
       ticks = (((NSDate*)[NSDate date]).timeIntervalSince1970 - jobStarted.timeIntervalSince1970) * (totalLines - linesSend) / linesSend;
    [timeLock unlock];
            long hours = ticks / 3600;
            ticks -= 3600 * hours;
            long min = ticks / 60;
            ticks -= 60 * min;
            long sec = ticks;
    NSString *s = [NSString stringWithFormat:@"%dh:%dm:%ds",hours,min,sec];
    return s;
}
@end
