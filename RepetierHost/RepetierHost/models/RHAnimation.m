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

#import "RHAnimation.h"
#import "ThreeDModel.h"
#import "PrinterConfiguration.h"
#import "OpenGL/gl.h"

@implementation ModelAnimation

/// <summary>
/// Base class for animations. Animations are used to modify the appeareance
/// of the underlying content. E.g. it could pulse an object.
/// </summary>
-(id)initWithName:(NSString *)n
{
    if((self=[super init])) {
    name = [n retain];
    startTime = CFAbsoluteTimeGetCurrent();
    }
    return self;
}
-(void)dealloc {
    [name release];
    [super dealloc];
}
-(double) time
{
    return CFAbsoluteTimeGetCurrent() - startTime; 
}
    /// <summary>
    /// Return true, if the animation is finished
    /// </summary>
    /// <returns></returns>
-(BOOL)animationFinished
{
        return false;
}
-(void)beforeAction:(ThreeDModel*)model { }
-(void)afterAction:(ThreeDModel*)model { }

@end

@implementation PulseAnimation


-(id)initPulseAnimation:(NSString*)n scaleX:(double)sx scaleY:(double)sy scaleZ:(double)sz frequency:(double) fq
{
    self = [super initWithName:n];
    frequency = fq;
    scalex = sx;
    scaley = sy;
    scalez = sz;
    return self;
}
-(void)beforeAction:(ThreeDModel*) model {
    double baseamp = sin(self.time * 2.0 * M_PI * frequency);
    float center[3];
    [model getCenter:center];
  //  center[0]+=model->position[0];
  //  center[1]+=model->position[1];
  //  center[2]+=model->position[2];
    glTranslatef(center[0],center[1],center[2]);
    glScalef(1.0 + scalex * baseamp, 1.0 + scaley * baseamp, 1.0 + scalez * baseamp);
    glTranslatef(-center[0], -center[1], -center[2]);
}
@end
@implementation DropAnimation

-(id)initDropAnimation:(NSString*)n
{
    self = [super initWithName:n];
    mode = 0;
    return self;
}
-(BOOL)animationFinished
{
    return mode==2;
}
-(void)beforeAction:(ThreeDModel*) model
{
    double t = self.time;
    float c[3];
    [model getCenter:c];
    if (mode == 0)
    {
        height = currentPrinterConfiguration->height * 1.2;
        mode = 1;
    }
    if (t < 1)
    {
        // s = 0,5*a*t^2
        // land after 1.5 sec =>a = 2*s/2.25
        
        glTranslatef(0, 0, height - 1.0 / 1.0 * height * t * t);
    }
    else if (t < 1.25)
    {
        float zamp = 0.3 * c[2] * (t - 1.25) / 0.25;
        glTranslatef(c[0],c[1],c[2]-zamp);
        glScalef(1.0 + zamp/c[2], 1.0 + zamp/c[2], 1.0 - zamp/c[2]);
        glTranslatef(-c[0], -c[1], -c[2]);
    }
    else if (t < 1.5)
    {
        double zamp = 0.3 * c[2] * (1.5-t) / 0.25;
        glTranslatef(c[0], c[1], c[2] - zamp);
        glScalef(1.0 + zamp / c[2], 1.0 + zamp / c[2], 1.0 - zamp / c[2]);
        glTranslatef(-c[0], -c[1], -c[2]);
    }
    else mode = 2;
}
@end    

