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


#import "ThreeDView.h"
#include <OpenGL/gl.h>
#include "RHOpenGLView.h"
#import "RHAppDelegate.h"
#import "RHOpenGLView.h"
#import "STLComposer.h"

@implementation ThreeDView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        if ([NSBundle loadNibNamed:@"ThreeD" owner:self])
        {
            act = [ThreeDContainer new];
            [view setFrame:[self bounds]];
            [self addSubview:view];
            ((RHOpenGLView*)glView)->topView = self;
        }
    }
    
    return self;
}

-(void) drawRect: (NSRect) bounds
{
 }
-(void)redraw {
    [glView setNeedsDisplay:YES];
}
-(void)updateButtons {
    int mode = glView->mode;
    [rotateButton setBordered:mode==0];
    [moveCameraButton setBordered:mode==1];
    [moveViewpointButton setBordered:mode==2];
    [zoomButton setBordered:mode==3];
    [moveObjectButton setBordered:mode==4];
    [moveObjectButton setEnabled:act == app->stlView];
    if(act != app->codePreview) {
        if(act==app->stlView) {
            [deleteButton setEnabled:app->composer->actSTL!=nil];
        } else {
            [deleteButton setEnabled:YES];            
        }
    } else {
        [deleteButton setEnabled:NO];
    }
}
- (IBAction)rotateAction:(id)sender {
    glView->mode = 0;
    [self updateButtons];
}

- (IBAction)moveCameraAction:(id)sender {
    glView->mode = 1;
    [self updateButtons];
}

- (IBAction)moveViewpointAction:(id)sender {
    glView->mode = 2;
    [self updateButtons];
}

- (IBAction)zoomAction:(id)sender {
    glView->mode = 3;
    [self updateButtons];
}

- (IBAction)fronViewAction:(id)sender {
    [act resetView];
    [glView setNeedsDisplay:YES];
}

- (IBAction)topViewAction:(id)sender {
    [act topView];
    [glView setNeedsDisplay:YES];
}

- (IBAction)moveObjectAction:(id)sender {
    glView->mode = 4;
    [self updateButtons];
}

- (IBAction)deleteAction:(id)sender {
    if(act==app->stlView) {
        [app->composer removeSTLFile:nil];
    } else {
        [app->printVisual clear];
        [app->openGLView redraw];
    }
}
@end
