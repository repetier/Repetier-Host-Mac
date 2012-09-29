//
//  Geom3D.m
//  RepetierHost
//
//  Created by Roland Littwin on 26.09.12.
//  Copyright (c) 2012 Repetier. All rights reserved.
//

#import "Geom3D.h"

@implementation Geom3DVector

+(Geom3DVector*)vectorWithX:(float)_x y:(float)_y z:(float)_z  {
    Geom3DVector *vec = [Geom3DVector new];
    vec->x = _x;
    vec->y = _y;
    vec->z = _z;
    return [vec autorelease];
}
+(Geom3DVector*)vectorFromVector:(Geom3DVector*)v {
    Geom3DVector *vec = [Geom3DVector new];
    vec->x = v->x;
    vec->y = v->y;
    vec->z = v->z;
    return [vec autorelease];
}
-(Geom3DVector*)scale:(float)fac {
    return [Geom3DVector vectorWithX:x * fac y:y * fac z:z * fac];
}
-(Geom3DVector*)add:(Geom3DVector*)v {
    return [Geom3DVector vectorWithX:x + v->x y:y + v->y z:z + v->z];
}
-(Geom3DVector*)sub:(Geom3DVector*)v {
    return [Geom3DVector vectorWithX:x - v->x y:y - v->y z:z - v->z];
}
-(float)Length {
    return sqrt(x * x + y * y + z * z);
}
-(void) normalize {
    float f = 1.0f / self.Length;
    x *= f;
    y *= f;
    z *= f;
}
-(NSString*) ToString {
    return [NSString stringWithFormat:@"(%f;%f;%f)",x,y,z];
}
@end

@implementation Geom3DLine

@synthesize point;
@synthesize dir;

+(Geom3DLine*)lineFromPoint:(Geom3DVector*)pt direction:(Geom3DVector*)v isDir:(BOOL)isDir {
    Geom3DLine *vec = [Geom3DLine new];
    vec.point = [Geom3DVector vectorFromVector:pt];
    if (isDir)
        vec.dir = [Geom3DVector vectorFromVector:v];
    else
        vec.dir = [v sub:pt];
    return [vec autorelease];
}
-(NSString*) ToString {
  return [NSString stringWithFormat:@"Line %@->%@",point.ToString,dir.ToString];
}
@end

@implementation Geom3DPlane

@synthesize origin;
@synthesize normal;

+(Geom3DPlane*)planeFromPoint:(Geom3DVector*) o normal:(Geom3DVector*)norm {
    Geom3DPlane *plane = [Geom3DPlane new];
    plane.origin = [Geom3DVector vectorFromVector:o];
    plane.normal = [Geom3DVector vectorFromVector:norm];
    return [plane autorelease];
}
/// <summary>
/// Inersection of plane with line
/// </summary>
/// <param name="line"></param>
/// <param name="inter"></param>
/// <returns>true if intersection exists</returns>
-(BOOL)intersectLine:(Geom3DLine*)line result:(Geom3DVector*) inter {
    float q = normal->x * (origin->x - line.point->x) + normal->y * (origin->y - line.point->y) + normal->z * (origin->z - line.point->z);
    float d = normal->x * line.dir->x + normal->y * line.dir->y + normal->z * line.dir->z;
    if (d == 0)
    {
        inter->x = inter->y = inter->z = 0;
        return NO;
    }
    float r = q / d;
    inter->x = line.point->x + r * line.dir->x;
    inter->y = line.point->y + r * line.dir->y;
    inter->z = line.point->z + r * line.dir->z;
    return YES;
}
-(NSString*) ToString {
    return [NSString stringWithFormat:@"Plane %@*%@",origin,normal];
}
@end