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
#import <OpenGL/OpenGL.h>
#import "ThreeDModel.h"
#import "RHLinkedList.h"

@interface STLTriangle : NSObject {
@public
    GLfloat normal[3];
    GLfloat p1[3];
    GLfloat p2[3];
    GLfloat p3[3];
}
+(int)compare:(STLTriangle*)x with:(STLTriangle*)y;
@end

@interface STL : ThreeDModel {
    @public
    RHLinkedList *list;
    NSString *name;
    NSString *filename;
    NSTimeInterval lastModified;
    BOOL outside;
    float trans[16];
    GLfloat *points;
    GLfloat *normals;
    GLuint *triangles;
    GLuint *edges;
    int pointsLength,normalsLength,trianglesLength;
    int edgesLength;
    GLuint *bufs;
    NSString *error;
}
@property (retain)NSString* name;
@property (retain)NSString* error;
@property (retain)NSString* filename;

-(BOOL)load:(NSString*)file;
-(void)resetModifiedDate;
-(BOOL)changedOnDisk;
-(void)land;
-(void)centerX:(float) x y:(float) y;
-(void)updateMatrix;
-(void)updateBoundingBox;
-(void)includePoint:(GLfloat*)v;
-(void)transformPoint:(GLfloat*)v to:(float*)res;
-(void)paint;
-(void)loadText:(NSData*)file;
-(void)extractVector:(GLfloat*)res from:(NSString*)s;
-(STL*)copySTL;
-(void)reload;
-(void)clearGraphicContext;
@end
