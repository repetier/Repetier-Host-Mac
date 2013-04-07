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
#import "GCodeShort.h"
#import "RHLinkedList.h"

@class GCodeAnalyzer;

@protocol GCodeAnalyzerDelegate
-(void) printerStateChanged:(GCodeAnalyzer*)analyzer;
-(void) positionChanged:(GCodeAnalyzer*)analyzer  x:(float)xp y:(float)yp z:(float)zp;
-(void) positionChangedFastX:(float)x y:(float)y z:(float)z e:(float)e;
@end

@interface ExtruderData : NSObject
{
@public
    int extruderId;
    float temperature;
    float e;
    float emax;
    float lastE;
    float eOffset;
    bool retracted;
}
-(id)initWithId:(int)_id;
@end

@interface GCodeAnalyzer : NSObject {
    NSMutableDictionary *extruder;
    RHLinkedList *unchangedLayer;
@public
    id <GCodeAnalyzerDelegate> delegate;
    ExtruderData *activeExtruder;
    //float extruderTemp;
    BOOL uploading;
    float bedTemp;
    float x, y, z,f;
    float lastX,lastY,lastZ;
    float xOffset, yOffset, zOffset;
    float lastZPrint;
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
    int layer,lastlayer;
    BOOL isG1Move;
    BOOL eChanged;
    float layerZ;
    float printingTime;
    GCode *actCode;
}
-(bool)isAnyExtruderEnabled;
-(float)getExtruderTemperature:(int)extruder;
-(void)setExtruder:(int)extruder temperature:(float)temp;
-(void)fireChanged;
-(void)analyze:(GCode*) code;
-(void)analyzeShort:(GCodeShort*)code;
-(void) start;
-(void) startJob;
-(ExtruderData*)getExtruderDataFor:(int)ex;
@end
