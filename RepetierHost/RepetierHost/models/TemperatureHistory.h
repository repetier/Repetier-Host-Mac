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

#import <Foundation/Foundation.h>
#import "RHLinkedList.h"

@interface TempertureEntry : NSObject {
@public
    double time;
    // values <-1000 are not present 
    float output;
    float extruder;
    float bed;
    float avgExtruder;
    float avgBed;
    float avgOutput;
    float targetBed;
    float targetExtruder;
}
-(id)initWithExtruder:(float)ext bed:(float)_bed targetBed:(float)tar targetExtruder:(float)tare;
-(id)initWithMonitor:(int)mon temp:(float)tmp output:(float)outp targetBed:(float)tar targetExtruder:(float)tare;
@end
@interface TemperatureList : NSObject {
@public
    RHLinkedList *entries;
    double minTime,maxTime;
}
@end
@interface TemperatureHistory : NSObject {
    @public
    NSString *name;
    NSColor *backgroundColor;
    NSColor *gridColor;
    NSColor *axisColor;
    NSColor *fontColor;
    NSColor *extruderColor;
    NSColor *avgExtruderColor;
    NSColor *bedColor;
    NSColor *avgBedColor;
    NSColor *targetExtruderColor;
    NSColor *targetBedColor;
    NSColor *outputColor;
    NSColor *avgOutputColor;
    BOOL showOutput;
    BOOL showBed;
    BOOL showExtruder;
    BOOL showTarget;
    BOOL showAverage;
    double xpos;
    BOOL autoscoll;
    TemperatureList *history;
    TemperatureList *hourHistory;
    RHLinkedList *lists;
    TemperatureList *currentHistory;
    int currentPos;
    long currentHour;
    double avgPeriod;
    NSArray *bindingsArray;
    NSArray *zoomLevel;
    int currentZoomLevel;
    double extruderWidth;
    double avgExtruderWidth;
    double targetExtruderWidth;
    double bedWidth;
    double avgBedWidth;
    double targetBedWidth;
    double avgOutputWidth;
}
@property (retain)NSColor *backgroundColor;
@property (retain)NSColor *gridColor;
@property (retain)NSColor *axisColor;
@property (retain)NSColor *fontColor;
@property (retain)NSColor *extruderColor;
@property (retain)NSColor *avgExtruderColor;
@property (retain)NSColor *bedColor;
@property (retain)NSColor *avgBedColor;
@property (retain)NSColor *targetExtruderColor;
@property (retain)NSColor *targetBedColor;
@property (retain)NSColor *outputColor;
@property (retain)NSColor *avgOutputColor;
-(void)addNotify:(NSNotification*)event;
-(void)setupColor;
-(void)initMenu;
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context;
@end
