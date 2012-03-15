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


#import "RHOpenGLView.h"
#import <OpenGL/gl.h>
#import "ThreeDConfig.h"
#import "RHLogger.h"
#import "RHAppDelegate.h"
#import "ThreeDModel.h"
#import "ThreeDView.h"
#import "GCodeEditorController.h"

@implementation RHPoint

+(id)withX:(float)x Y:(float)y {
    RHPoint *p = [RHPoint new];
    p->x = x;
    p->y = y;
    p->z = p->w = 0;
    return p.autorelease;
}


@end
@implementation RHOpenGLView

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewGlobalFrameDidChangeNotification object:self];
    [glThread release];
    [glContext release];
    [super dealloc];
}
/*- (void) reshape
{
	// This method will be called on the main thread when resizing, but we may be drawing on a secondary thread through the display link
	// Add a mutex around to avoid the threads accessing the context simultaneously
	CGLLockContext([glContext CGLContextObj]);
	
	// Delegate to the scene object to update for a change in the view size
    if([glContext view]==self)
        [glContext update];
	
	CGLUnlockContext([glContext CGLContextObj]);
}*/
- (id) initWithFrame:(NSRect)frameRect
{
	if(self = [self initWithFrame:frameRect shareContext:nil])
	{
	}
	return self;
}
- (id) initWithFrame:(NSRect)frameRect shareContext:(NSOpenGLContext*)context
{
	if (self = [super initWithFrame:frameRect]) 
	{
    NSOpenGLPixelFormatAttribute attribs[] =
    {
		NSOpenGLPFAWindow,
		NSOpenGLPFADoubleBuffer,
		NSOpenGLPFAColorSize, 24,
		NSOpenGLPFAAlphaSize, 8,
		NSOpenGLPFADepthSize, 32,
		//NSOpenGLPFANoRecovery,
		NSOpenGLPFAAccelerated,
        NSOpenGLPFAClosestPolicy,
		0
    };
	
    pixelFormat = [[NSOpenGLPixelFormat alloc] initWithAttributes:attribs];
	
    if (!pixelFormat)
		NSLog(@"No OpenGL pixel format");
        _needsReshape = YES;
	// NSOpenGLView does not handle context sharing, so we draw to a custom NSView instead
	glContext = [[NSOpenGLContext alloc] initWithFormat:pixelFormat shareContext:context];
   // [glContext setView:self];
		[glContext makeCurrentContext];
		
		// Synchronize buffer swaps with vertical refresh rate
	//	GLint swapInt = 1;
	//	[glContext setValues:&swapInt forParameter:NSOpenGLCPSwapInterval]; 
		
		//[self setupDisplayLink];
		
		// Look for changes in view size
		// Note, -reshape will not be called automatically on size changes because NSView does not export it to override 
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reshape) 
                name:NSViewGlobalFrameDidChangeNotification object:self];
        mode = 0;
        glLock = [NSCondition new];
        updateGLView = NO;
	}
	
	
	return self;
}
-(void)awakeFromNib {
    //glContext = self.openGLContext;
            
    [glContext makeCurrentContext];
    const char *glversions = (const char*)glGetString(GL_VERSION);
    [rhlog addInfo:[NSString stringWithCString:(const char*)glGetString(GL_VERSION) encoding:NSISOLatin1StringEncoding]];
    conf3d->useVBOs = atof(glversions) >= 1.5;
   // conf3d->useVBOs = false;
    [NSOpenGLContext clearCurrentContext];
    timer = [NSTimer scheduledTimerWithTimeInterval:1.0/25.0
                                             target:self selector:@selector(timerAction:)
                                           userInfo:nil repeats:YES];    

  //  glThread = [[NSThread alloc] initWithTarget:self selector:@selector(glThreadLoop:)  object:nil]; 
  //  [glThread start];
    
}
-(void)timerAction:(NSTimer*)timer {
    if(topView==nil || topView->act==nil) return;
    //if (!autoupdateable) return;
    //if (toolAutoupdate.Checked == false) return;
    for (ThreeDModel *m in topView->act->models)
    {
        if (m.changed || m.hasAnimations)
        {
            [self setNeedsDisplay:YES];
            return;
        }
    }
}
-(void) drawRect: (NSRect) bounds
{
  // [self lockFocus];
   //     [self glThreadLoop:self];
   //     [self unlockFocus];
    
    
    
  //  return;
  //  NSLog(@"Opengl paint");
    double starttime = CFAbsoluteTimeGetCurrent();
    if([glContext view]!=self)
        [glContext setView:self];

  //  [[NSColor redColor] set];
  //  [NSBezierPath fillRect:NSMakeRect(0,0,60,60)];
    if(NO) {
        [glLock lock];
        updateGLView = YES;
        [glLock signal];
        [glLock unlock];
    } else {
       // if([self lockFocusIfCanDraw]) {
       //     CGLLockContext(glContext.CGLContextObj);
            [glContext makeCurrentContext];
            NSSize sz = [self bounds].size;
            if(topView)
                [topView->act paintWidth:sz.width height:sz.height];
            glFlush();
            [glContext flushBuffer];
        //    CGLUnlockContext(glContext.CGLContextObj);
         //   [self unlockFocus];
       // }
    }
    starttime = CFAbsoluteTimeGetCurrent()-starttime;
    [app->printFrames setStringValue:[NSString stringWithFormat:@"%d FPS",(int)(1/starttime)]];
}
-(void)glThreadLoop:(id)obj {
    if([glContext view]!=self)
        [glContext setView:self];
        // Do thread work here.        
        NSSize sz = [self bounds].size;
      //  NSLog(@"gl w %f h %f",sz.width,sz.height);
       // if([self lockFocusIfCanDraw]) {
          //  NSLog(@"In focus");
            CGLLockContext(glContext.CGLContextObj);
            [glContext makeCurrentContext];
         /*   glClearColor(0, 0, 0, 0);
            glClear(GL_COLOR_BUFFER_BIT);
            glColor3f(1.0f, 0.85f, 0.35f);
            glBegin(GL_TRIANGLES);
            {
                glVertex3f(  0.0,  0.6, 0.0);
                glVertex3f( -0.2, -0.3, 0.0);
                glVertex3f(  0.2, -0.3 ,0.0);
            }
            glEnd();*/
            if(topView)
                [topView->act paintWidth:sz.width height:sz.height];
            glFlush();
            [glContext flushBuffer];
            CGLUnlockContext(glContext.CGLContextObj);
         //  [self unlockFocus];
       // }
}
- (BOOL)isOpaque {
    return YES;
}
- (void)update {
    // we don't want to create the context if it doesn't exist
    [glContext update];
}

- (void)reshape {
    // do nothing
}

- (void)prepareOpenGL {
    // do nothing
}

- (void)lockFocus {
    [super lockFocus];
    
    CGLLockContext([glContext CGLContextObj]);
    [glContext setView:self];
    [glContext makeCurrentContext];
    
    if (_needsReshape){
        [self reshape];
        _needsReshape = NO;
    }
}
/*- (BOOL)lockFocusIfCanDraw {
    if([super lockFocusIfCanDraw]) {
    
    CGLLockContext([glContext CGLContextObj]);
    [glContext setView:self];
    [glContext makeCurrentContext];
    
    if (_needsReshape){
        [self reshape];
        _needsReshape = NO;
    }  
        return YES;
    }
    return NO;
}*/
- (void)unlockFocus {
    // Cocoa _does not_ flushBuffer
    // Single buffered contexts need to be updated somehow else
    CGLUnlockContext([glContext CGLContextObj]);
    [super unlockFocus];
}

- (void)clearGLContext {
    [glContext clearDrawable];
    [glContext release];
    glContext=nil;
}

- (void)setFrame:(NSRect)frame {
    [super setFrame:frame];
    _needsReshape = YES;
    [self update];
}
- (BOOL)acceptsFirstResponder
{
    return YES;
}
- (BOOL)becomeFirstResponder
{
    return YES;
}
-(BOOL)acceptsFirstMouse {
    return YES;
}
// handle key down events
// if you don't handle this, the system beeps when you press a key (how annoying)
- (void)keyDown:(NSEvent *)theEvent
{
    //NSLog( @"key down %d",(int)theEvent.keyCode );
}
-(void)mouseDown:(NSEvent*)theEvent {
    ThreeDContainer *c = topView->act;
    NSPoint p = theEvent.locationInWindow;
    p = [self convertPoint:p fromView:nil];
    last = down = p;
    startRotX = c->rotX;
    startRotZ = c->rotZ;
    startViewCenter[0] = c->viewCenter[0];
    startViewCenter[1] = c->viewCenter[1];
    startViewCenter[2] = c->viewCenter[2];
    startUserPosition[0] = c->userPosition[0];
    startUserPosition[1] = c->userPosition[1];
    startUserPosition[2] = c->userPosition[2];
}
-(void)rightMouseDown:(NSEvent *)theEvent {
    ThreeDContainer *c = topView->act;
    [glContext makeCurrentContext];
    NSPoint p = theEvent.locationInWindow;
    p = [self convertPoint:p fromView:nil];
    NSSize sz = [self bounds].size;
    ThreeDModel *selmod = [c PicktestX:p.x Y:p.y width:sz.width height:sz.height];
    last = p;
    if(selmod!=nil) {
        [[NSNotificationQueue defaultQueue] enqueueNotification:[NSNotification notificationWithName:@"RHObjectSelected" object:selmod] postingStyle:NSPostASAP];

    }
   // [glContext flushBuffer];
    [NSOpenGLContext clearCurrentContext];
}
-(void)rightMouseDragged:(NSEvent *)theEvent {
    ThreeDContainer *c = topView->act;
    NSSize bounds = [self bounds].size;
    NSPoint p = theEvent.locationInWindow;
    p = [self convertPoint:p fromView:nil];
    double speedX; // = MAX(-1,MIN(1,(p.x - down.x) / d));
    double speedY; // = -MAX(-1, MIN(1, (p.y - down.y) / d));
    speedX = (p.x - last.x)*200*c->zoom / bounds.width;
    speedY = (p.y - last.y)*200*c->zoom / bounds.height;
    [[NSNotificationQueue defaultQueue] enqueueNotification:[NSNotification notificationWithName:@"RHObjectMoved" object:[RHPoint withX:speedX Y:speedY]] postingStyle:NSPostASAP];
    //  if (eventObjectMoved != null)
    //      eventObjectMoved(speedX,-speedY);
    last = p;
    
}
-(void)mouseDragged:(NSEvent *)theEvent {
    ThreeDContainer *c = topView->act;
    NSPoint p = theEvent.locationInWindow;
    p = [self convertPoint:p fromView:nil];
    NSSize bounds = [self bounds].size;
    double d = MIN(bounds.width, bounds.height) / 3;
    double speedX; // = MAX(-1,MIN(1,(p.x - down.x) / d));
    double speedY; // = -MAX(-1, MIN(1, (p.y - down.y) / d));

    NSInteger k = [NSEvent modifierFlags];
    int emode = mode;
    if (k == NSShiftKeyMask) emode = 2;
    if (k == NSControlKeyMask) emode = 0;
    if (k == NSAlternateKeyMask) emode = 4;
    if (emode == 0)
    {
        speedX = (p.x - down.x) / d;
        speedY = -(p.y - down.y) / d;
        c->rotZ = startRotZ + speedX * 50;
        c->rotX = startRotX + speedY * 50;
    }
    else if (emode == 1)
    {
        speedX = (p.x - down.x) / bounds.width;
        speedY = -(p.y - down.y) / bounds.height;
        c->userPosition[0] = startUserPosition[0] + speedX * 200 * c->zoom;
        c->userPosition[2] = startUserPosition[2] - speedY * 200 * c->zoom;
        //userPosition.X += (float)milliseconds * speedX * Math.Abs(speedX) / 10.0f;
        //userPosition.Z -= (float)milliseconds * speedY *Math.Abs(speedY)/ 10.0f;
    }
    else if (emode == 2)
    {
        speedX = (p.x - down.x) / bounds.width;
        speedY = -(p.y - down.y) / bounds.height;
        c->viewCenter[0] = startViewCenter[0]-speedX *200*c->zoom;
        c->viewCenter[2] = startViewCenter[2]+speedY *200*c->zoom;
        //viewCenter.X -= (float)milliseconds * speedX * Math.Abs(speedX) / 10.0f;
        //viewCenter.Z += (float)milliseconds * speedY * Math.Abs(speedY)/ 10.0f;
    }
    else if (emode == 3)
    {
        speedY = -MAX(-1, MIN(1, (p.y - down.y) / d));
        c->zoom *= (1 - speedY / 2);
        if (c->zoom < 0.01) c->zoom = 0.01;
        if (c->zoom > 5.9) c->zoom = 5.9;
        down.y = p.y;
        //c->userPosition[1] -= speedY * abs(speedY)/ 10.0;
    }
    else if (emode == 4)
    {
        speedX = (p.x - last.x)*200*c->zoom / bounds.width;
        speedY = (p.y - last.y)*200*c->zoom / bounds.height;
        [[NSNotificationQueue defaultQueue] enqueueNotification:[NSNotification notificationWithName:@"RHObjectMoved" object:[RHPoint withX:speedX Y:speedY]] postingStyle:NSPostASAP];
        last = p;
    }
    [self setNeedsDisplay:YES];
}
- (void)scrollWheel:(NSEvent *)theEvent {
    ThreeDContainer *c = topView->act;
    if (theEvent.deltaY != 0)
    {
        NSInteger k = [NSEvent modifierFlags];
        if(topView->act == app->codePreview) {
            if(k==NSShiftKeyMask) {
                [app->gcodeView setShowMinLayer:(app->gcodeView).showMinLayer-theEvent.deltaY];
                return;
            } else if(k==NSControlKeyMask) {
                [app->gcodeView setShowMaxLayer:(app->gcodeView).showMaxLayer-theEvent.deltaY];
                return;
            }
        }
        c->zoom *= 1 - theEvent.deltaY / 200;
        if (c->zoom < 0.01) c->zoom = 0.01;
        if (c->zoom > 5.9) c->zoom = 5.9;
        //NSLog(@"Zoom = %f",c->zoom);
        //userPosition.Y += e.Delta;
        //[self setNeedsDisplay:YES];
        [self display];
    }
}
// handle mouse up events (left mouse button)
- (void)mouseUp:(NSEvent *)theEvent
{
}
// handle mouse up events (right mouse button)
- (void)rightMouseUp:(NSEvent *)theEvent
{
    // NSLog( @"Mouse R up %d",(int)theEvent.modifierFlags);
}
// handle mouse up events (other mouse button)
- (void)otherMouseUp:(NSEvent *)theEvent
{
    //  NSLog( @"Mouse O up");
}

@end
