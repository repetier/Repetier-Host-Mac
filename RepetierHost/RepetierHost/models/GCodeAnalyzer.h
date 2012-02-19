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
#import "GCode.h"
@class GCodeAnalyzer;

@protocol GCodeAnalyzerDelegate
-(void) printerStateChanged:(GCodeAnalyzer*)analyzer;
-(void) positionChanged:(GCodeAnalyzer*)analyzer;
@end

@interface GCodeAnalyzer : NSObject {
    id <GCodeAnalyzerDelegate> delegate;
@public
    int activeExtruder;
    int extruderTemp;
    BOOL uploading;
    int bedTemp;
    float x, y, z, e,emax;
    float xOffset, yOffset, zOffset, eOffset;
    BOOL fanOn;
    int fanVoltage;
    BOOL powerOn;
    BOOL relative;
    BOOL eRelative;
    int debugLevel;
    int lastline;
    BOOL hasXHome, hasYHome, hasZHome;
    BOOL privateAnalyzer; 
    float printerWidth, printerHeight, printerDepth;
    int tempMonitor;
    BOOL drawing;
    GCode *actCode;
}
@property (retain, nonatomic) id <GCodeAnalyzerDelegate> delegate;
-(void)fireChanged;
-(void) analyze:(GCode*) code;
-(void) start;
@end
