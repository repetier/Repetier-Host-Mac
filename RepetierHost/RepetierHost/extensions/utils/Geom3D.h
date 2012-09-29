//
//  Geom3D.h
//  RepetierHost
//
//  Created by Roland Littwin on 26.09.12.
//  Copyright (c) 2012 Repetier. All rights reserved.
//

#import <Foundation/Foundation.h>
#ifndef _GEOM3D_H
#define _GEOM3D_H

@interface Geom3DVector : NSObject {
@public
    float x,y,z;
}
+(Geom3DVector*)vectorWithX:(float)_x y:(float)_y z:(float)_z;
+(Geom3DVector*)vectorFromVector:(Geom3DVector*)vec;

-(Geom3DVector*)scale:(float)fac;
-(Geom3DVector*)add:(Geom3DVector*)v;
-(Geom3DVector*)sub:(Geom3DVector*)v;
-(float)Length;
-(void) normalize;
-(NSString*) ToString;
@end

@interface Geom3DLine : NSObject {
@public
    Geom3DVector *point;
    Geom3DVector *dir;
}
@property (retain)Geom3DVector *point;
@property (retain)Geom3DVector *dir;

+(Geom3DLine*)lineFromPoint:(Geom3DVector*)pt direction:(Geom3DVector*)v isDir:(BOOL)isDir;
-(NSString*) ToString;
@end

@interface Geom3DPlane : NSObject {
@public
    Geom3DVector *origin;
    Geom3DVector *normal;
}
@property (retain)Geom3DVector *origin;
@property (retain)Geom3DVector *normal;
+(Geom3DPlane*)planeFromPoint:(Geom3DVector*) o normal:(Geom3DVector*)norm;
-(BOOL)intersectLine:(Geom3DLine*)line result:(Geom3DVector*) inter;
-(NSString*) ToString;
@end
#endif
