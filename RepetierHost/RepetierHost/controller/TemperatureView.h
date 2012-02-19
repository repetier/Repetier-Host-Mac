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

#import <Cocoa/Cocoa.h>

@class TemperatureHistory;

@interface TemperatureView : NSView {
    @public
    TemperatureHistory *hist;
    double righttime;
    double lefttime;
    double timeScale;
    double tempY0,tempScale;
    double outScale;
    double minTemp,maxTemp;
    double timeTick;
    double tempTick;
    float axisWidth;
    float tickExtra,spaceExtra;
    NSMutableDictionary *fontAttributes;
    NSFont *drawFont;
    float timeWidth,timeHeight,tempWidth;
    NSDateFormatter *dateFormatter;
    NSPoint down;
}

@end
