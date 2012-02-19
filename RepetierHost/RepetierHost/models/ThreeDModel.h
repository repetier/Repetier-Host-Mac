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

@class ModelAnimation;

@interface ThreeDModel : NSObject {
@public
    float position[3];
    float rotation[3];
    float scale[3];
    BOOL selected;
    RHLinkedList *animations;
}

-(BOOL)changed;
-(void)clear;
-(void)paint;
-(void)addAnimation:(ModelAnimation*) anim;
-(void) removeAnimationWithName:(NSString*)aname;
-(BOOL)hasAnimationWithName:(NSString*) aname;
-(void) clearAnimations;
-(BOOL)hasAnimations;
-(void)animationBefore;
-(void)animationAfter;
-(void)getCenter:(float*)center;
@end
