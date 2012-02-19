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

@class ThreeDModel;

@interface ModelAnimation : NSObject {
@public
    double startTime;
    NSString *name;
}
-(id)initWithName:(NSString*)n;
-(void)dealloc;
-(double) time;
-(BOOL)animationFinished;
-(void)beforeAction:(ThreeDModel*)model;
-(void)afterAction:(ThreeDModel*)model;
@end

@interface PulseAnimation : ModelAnimation {
    double frequency;
    double scalex, scaley, scalez;
    
}
-(id)initPulseAnimation:(NSString*)n scaleX:(double)sx scaleY:(double)sy scaleZ:(double)sz frequency:(double) fq;
@end

@interface DropAnimation : ModelAnimation {
    int mode;
    double height;    
}
-(id)initDropAnimation:(NSString*)n;
@end
