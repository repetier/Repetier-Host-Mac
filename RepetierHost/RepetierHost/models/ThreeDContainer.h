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
#include <OpenGL/gl.h>
#include "RHLinkedList.h"

@class ThreeDModel;

@interface ThreeDContainer : NSObject {
@public
    float viewCenter[3];
    float userPosition[3];
    double zoom;
    double rotX,rotZ;
    float dist;
    GLfloat white[4];
    GLfloat ambient[4];
    RHLinkedList *models;
    GLuint testPoints[2];
}
-(void)resetView;
-(void)topView;
-(void)setupViewportWidth:(double)width height:(double)height;
-(void)paintWidth:(double)width height:(double)height;
-(void)gluPickMatrix:(float*)mat x:(float)x y:(float)y width:(float)width height:(float)height viewport:(int *)viewport;
-(ThreeDModel*)PicktestX:(float)x Y:(float)y width:(float)width height:(float)height;
@end
