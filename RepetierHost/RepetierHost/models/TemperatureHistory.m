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

#import "TemperatureHistory.h"
#import "DefaultsExtension.h"
#import "RHAppDelegate.h"
#import "RHTempertuareController.h"

@implementation TempertureEntry

-(id)initWithExtruder:(float)ext bed:(float)_bed targetBed:(float)tar targetExtruder:(float)tare {
    if((self=[super init])) {
        time = CFAbsoluteTimeGetCurrent();
        output = avgExtruder = avgBed = avgOutput = -10000;
        bed = _bed;
        extruder = ext;
        targetBed = tar;
        targetExtruder = tare;
    }
    return self;
}
-(id)initWithMonitor:(int)mon temp:(float)tmp output:(float)outp targetBed:(float)tar targetExtruder:(float)tare {
    if((self=[super init])) {
        time = CFAbsoluteTimeGetCurrent();
        output = outp;
        avgExtruder = bed = extruder = avgBed = avgOutput = -10000;
        targetBed = tar;
        targetExtruder = tare;
        switch(mon) {
            case 0:
            case 1:
            case 2:
            case 3:
                extruder = tmp;
                break;
            case 100:
                bed = tmp;
                break;
        }
    }
    return self;
}

@end

@implementation TemperatureList

-(id)init {
    if((self = [super init])) {
        entries = [RHLinkedList new];
    }
    return self;
}
-(void)dealloc {
    [entries release];
    [super dealloc];
}
@end

@implementation TemperatureHistory

@synthesize backgroundColor;
@synthesize gridColor;
@synthesize axisColor;
@synthesize fontColor;
@synthesize extruderColor;
@synthesize avgExtruderColor;
@synthesize bedColor;
@synthesize avgBedColor;
@synthesize targetBedColor;
@synthesize targetExtruderColor;
@synthesize outputColor;
@synthesize avgOutputColor;

-(id)init {
    if((self=[super init])) {        
        [[NSNotificationCenter defaultCenter] addObserver:self                                             selector:@selector(addNotify:) name:@"RHTempMonitor" object:nil];
        history = [TemperatureList new];
        history->maxTime = CFAbsoluteTimeGetCurrent();
        history->minTime = history->maxTime-3600;
        hourHistory = nil;
        lists = [RHLinkedList new];
        currentHour = -1;
        currentHistory = history;
        [self setupColor];
        NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
        NSArray *arr = [NSArray arrayWithObjects:@"tempBackgroundColor",
                        @"tempGridColor",@"tempAxisColor",@"tempFontColor",  
                        @"tempExtruderColor",@"tempAvgExtruderColor",
                        @"tempBedColor",@"tempAvgBedColor",@"tempTargetExtruderColor",@"tempTargetBedColor",
                        @"tempOutputColor",@"tempAvgOutputColor",
                        @"tempShowExtruder",@"tempShowAverage",@"tempShowBed",@"tempAutoscroll",
                        @"tempShowOutput",@"tempShowTarget",@"tempZoomLevel",
                        @"tempAverageSeconds",@"tempExtruderWidth",@"tempAvgExtruderWidth",
                        @"tempTargetExtruderWidth",@"tempBedWidth",@"tempAvgBedWidth",
                        @"tempTargetBedWidth",@"tempAvgOutputWidth",
                        nil];
        bindingsArray = arr.retain;
        zoomLevel = [[NSArray arrayWithObjects:[NSNumber numberWithDouble:3600],
                      [NSNumber numberWithDouble:1800],
                      [NSNumber numberWithDouble:900],[NSNumber numberWithDouble:300],
                      [NSNumber numberWithDouble:100],[NSNumber numberWithDouble:60],
                      nil] retain];
        currentZoomLevel = 3;
        xpos = 100;
        for(NSString *key in arr)
            [d addObserver:self forKeyPath:key options:NSKeyValueObservingOptionNew context:NULL];
        
    }
    return self;
}
-(void)dealloc {
    for(NSString *key in bindingsArray)
        [NSUserDefaults.standardUserDefaults removeObserver:self
                                                 forKeyPath:key];
    [bindingsArray release];
    [zoomLevel release];
    [history release];
    [hourHistory release];
    [lists release];
    [super dealloc];
}
-(void)setupColor {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    currentZoomLevel = (int)[d integerForKey:@"tempZoomLevel"];
    avgPeriod = [d integerForKey:@"tempAverageSeconds"];
    showExtruder = [d boolForKey:@"tempShowExtruder"];
    showAverage = [d boolForKey:@"tempShowAverage"];
    showBed = [d boolForKey:@"tempShowBed"];
    autoscoll = [d boolForKey:@"tempAutoscroll"];
    showOutput = [d boolForKey:@"tempShowOutput"];
    showTarget = [d boolForKey:@"tempShowTarget"];
    extruderWidth = [d doubleForKey:@"tempExtruderWidth"];
    avgExtruderWidth = [d doubleForKey:@"tempAvgExtruderWidth"];
    targetExtruderWidth = [d doubleForKey:@"tempTargetExtruderWidth"];
    bedWidth = [d doubleForKey:@"tempBedWidth"];
    avgBedWidth = [d doubleForKey:@"tempAvgBedWidth"];
    targetBedWidth = [d doubleForKey:@"tempTargetBedWidth"];
    avgOutputWidth = [d doubleForKey:@"tempAvgOutputWidth"];
    [self setBackgroundColor:[d colorForKey:@"tempBackgroundColor"]];
    [self setGridColor:[d colorForKey:@"tempGridColor"]];
    [self setAxisColor:[d colorForKey:@"tempAxisColor"]];
    [self setFontColor:[d colorForKey:@"tempFontColor"]];
    [self setExtruderColor:[d colorForKey:@"tempExtruderColor"]];
    [self setAvgExtruderColor:[d colorForKey:@"tempAvgExtruderColor"]];
    [self setBedColor:[d colorForKey:@"tempBedColor"]];
    [self setAvgBedColor:[d colorForKey:@"tempAvgBedColor"]];
    [self setTargetExtruderColor:[d colorForKey:@"tempTargetExtruderColor"]];
    [self setTargetBedColor:[d colorForKey:@"tempTargetBedColor"]];
    [self setOutputColor:[d colorForKey:@"tempOutputColor"]];
    [self setAvgOutputColor:[d colorForKey:@"tempAvgOutputColor"]];
}
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    [self setupColor];
    [app->temperatureController refresh];
}
-(void)initMenu {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:@"Past 60 minutes" action:@selector(selectPeriod:) keyEquivalent:@""];
    [item setTag:0];
    [item setTarget:app->temperatureController];
    [lists addLast:history];
    [app->temperatureController->timeperiodMenu addItem:item];
    [item release];
}
-(void)addNotify:(NSNotification*)event {
    TempertureEntry * ent = event.object;
    [history->entries addLast:ent];
    // Remove old entries
    double time = CFAbsoluteTimeGetCurrent();
    long ltime = (long)time;
    long lhour = ltime / 3600;
    double mintime = time-3600;
    while(((TempertureEntry*)(history->entries.peekFirstFast))->time<mintime)
        [history->entries removeFirst];
    // Create average values
    int nExtruder = 0,nBed = 0,nOut = 0;
    float sumExtruder = 0,sumBed = 0,sumOutput = 0;
    mintime = CFAbsoluteTimeGetCurrent()-avgPeriod;
    for(TempertureEntry *e in history->entries) {
        if(e->time<mintime) continue;
        if(e->extruder>-1000) {
            nExtruder++;
            sumExtruder+=e->extruder;
        }
        if(e->bed>-1000) {
            nBed++;
            sumBed+=e->bed;
        }
        if(e->output>-1000) {
            nOut++;
            sumOutput+=e->output;
        }
    }
    if(nExtruder>0) 
        ent->avgExtruder = sumExtruder/(float)nExtruder;
    if(nBed>0) 
        ent->avgBed = sumBed/(float)nBed;
    if(nOut>0) 
        ent->avgOutput = sumOutput/(float)nOut;
    history->maxTime = time;
    history->minTime = time-3600;

    if(lhour != currentHour) {
        currentHour = lhour;
        NSString *formatString = [NSDateFormatter dateFormatFromTemplate:@"MMM d, H" options:0 locale:[NSLocale currentLocale]];
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:formatString];
        NSString *time = [dateFormatter stringFromDate:[NSDate date]];                                                         
        NSMenuItem * item = [[NSMenuItem alloc] initWithTitle:time action:@selector(selectPeriod:) keyEquivalent:@""];
        [item setTarget:app->temperatureController];
        [item setTag:lists->count];
        hourHistory = [TemperatureList new];
        hourHistory->minTime = lhour*3600;
        hourHistory->maxTime = hourHistory->minTime+3600;
        [lists addLast:hourHistory];
        [app->temperatureController->timeperiodMenu addItem:item];
        [dateFormatter release];
        [item release];
    }
    [hourHistory->entries addLast:ent];
    [app->temperatureController refresh];
}
@end
