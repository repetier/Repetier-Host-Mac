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


#import "ThreeDModel.h"
#import "RHAnimation.h"

@implementation ThreeDModel
-(id)init {
    if((self = [super init])) {
        selected = NO;
        scale[0] = scale[1] = scale[2] = 1;
        rotation[0] = rotation[1] = rotation[2] = 0;
        position[0] = position[1] = position[2] = 0;
        animations = [RHLinkedList new];
    }
    return self;
}
-(void)dealloc {
    [animations release];
    [super dealloc];
}
-(void)addAnimation:(ModelAnimation*) anim
{
    [animations addLast:anim];
}
-(void) removeAnimationWithName:(NSString*)aname
{
    BOOL found = YES;
    while (found)
    {
        found = NO;
        for (ModelAnimation *a in animations)
        {
            if ([a->name compare:aname]==NSOrderedSame)
            {
                found = YES;
                [animations remove:a];
                break;
            }
        }
    }
}
-(BOOL)hasAnimationWithName:(NSString*) aname
{
    for(ModelAnimation *a in animations)
    {
        if ([a->name compare:aname]==NSOrderedSame)
        {
            return YES;
        }
    }
    return NO;
}
-(void) clearAnimations
{
    [animations clear];
}
-(BOOL)hasAnimations
{
    return animations->count > 0; 
}
-(void)animationBefore
{
    for (ModelAnimation *a in animations)
        [a beforeAction:self];
}
/// <summary>
/// Plays the after action and removes finished animations.
/// </summary>
-(void)animationAfter
{
    BOOL remove = NO;
    for (ModelAnimation *a in animations)
    {
        [a afterAction:self];
        remove |= a.animationFinished;
    }
    if (remove)
    {
        bool found = YES;
        while (found)
        {
            found = NO;
            for (ModelAnimation *a in animations)
            {
                if (a.animationFinished)
                {
                    found = YES;
                    [animations remove:a];
                    break;
                }
            }
        }
    }
}
-(void)getCenter:(float*)center {
    center[0] = center[1] = center[2] = 0;
}

/// <summary>
/// Has the model changed since last paint?
/// </summary>
-(BOOL)changed
{
    return NO; 
}
-(void)clear {}
-(void)paint {}
@end
