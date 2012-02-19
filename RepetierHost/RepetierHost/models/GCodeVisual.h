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
#import "ThreeDModel.h"
#import "GCodeAnalyzer.h"
#import "GCode.h"
#import <OpenGL/OpenGL.h>

@interface GCodePoint : NSObject {
@public
    float e;
    float dist;
    float p[3];
}
@end

@interface GCodePath : NSObject {
@public
    int pointsCount;
    int drawMethod;
    float *positions;
    float *normals;
    GLuint *elements;
    int elementsLength;
    int positionsLength;
    GLuint buf[3];
    BOOL hasBuf;
    RHLinkedList *pointsLists;
    NSLock *pointsLock;
}
-(void)add:(float*)v extruder:(float)e distance:(float)d;
-(void)free;
-(void)refillVBO;
-(void)updateVBO:(BOOL)buffer;
-(float)lastDist;
-(void)join:(GCodePath*)path;
@end

@class GCodeAnalyzer;

@interface GCodeVisual : ThreeDModel<GCodeAnalyzerDelegate> {
@public
    RHLinkedList *segments;
    GCodeAnalyzer *ana;
    GCode *act;
    float lastFilHeight;
    float lastFilWidth;
    float lastFilDiameter;
    BOOL lastFilUseHeight;
    float laste;
    float hotFilamentLength;
    float minHotDist;
    float totalDist;
    float defaultColor[4];
    float hotColor[4];
    float curColor[4];
    BOOL liveView;
    int method;
    GLuint colbuf;
    int colbufSize;
    BOOL recompute;
    float wfac,h,w;
    BOOL fixedH;
    float dfac,lastx,lasty,lastz;
    BOOL changed;
    BOOL startOnClear;
    NSLock *changeLock;
}
-(id)initWithAnalyzer:(GCodeAnalyzer*)a;
-(void)printerStateChanged:(GCodeAnalyzer*)analyzer;
-(void)positionChanged:(GCodeAnalyzer*)analyzer;
-(void)reduce;
-(void)stats;
-(void)addGCode:(GCode*) g;
-(void)parseText:(NSString*)text clear:(BOOL)clear;
-(void)setColor:(float)dist;
-(void)computeColor:(float) dist;
-(void)drawSegment:(GCodePath*)path;
-(void)paint;

@end
