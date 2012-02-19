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


#import <AppKit/AppKit.h>
#import "ThreeDView.h"

@interface RHPoint : NSObject {
@public
    float x,y,z,w;
}
+(id)withX:(float)x Y:(float)y;

@end

@interface RHOpenGLView : NSView {
@public
    IBOutlet ThreeDView *topView;
    NSPoint last,down;
    double startRotX,startRotZ;
    double startUserPosition[3];
    double startViewCenter[3];
    int mode;
    NSThread *glThread;
    NSCondition *glLock;
    BOOL updateGLView;
    NSOpenGLContext *glContext;
    NSOpenGLPixelFormat *pixelFormat;
    NSTimer *timer;
    BOOL _needsReshape;
}
- (id) initWithFrame:(NSRect)frameRect;
- (id) initWithFrame:(NSRect)frameRect shareContext:(NSOpenGLContext*)context;
- (void) reshape;
- (void)update;
- (void)prepareOpenGL;
- (void)lockFocus;
-(void) drawRect: (NSRect) bounds;
-(void)glThreadLoop:(id)obj;
-(void)timerAction:(NSTimer*)timer;

@end
