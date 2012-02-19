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

#import "STL.h"
#import "RHMatrix.h"
#import "ThreeDConfig.h"

@implementation STLTriangle

+(int)compare:(STLTriangle*)x with:(STLTriangle*)y
{
    if (x == nil) {
        if (y == nil) {
            // If x is null and y is null, they're
            // equal. 
            return 0;
        } else {
            // If x is null and y is not null, y
            // is greater. 
            return -1;
        }
    } else {
        // If x is not null...
        //
        if (y == nil)
        {
            return 1;
        } else {
            GLfloat xmin = MIN(x->p1[2], MIN(x->p2[2], x->p3[2]));
            GLfloat ymin = MIN(y->p1[2], MIN(y->p2[2], y->p3[2]));
            return xmin < ymin ? -1 : (xmin > ymin ? 1 : 0);
        }
    }
}
-(NSComparisonResult)compare:(STLTriangle*)y
{
    GLfloat xmin = MIN(p1[2], MIN(p2[2], p3[2]));
    GLfloat ymin = MIN(y->p1[2], MIN(y->p2[2], y->p3[2]));
    return xmin < ymin ? -1 : (xmin > ymin ? NSOrderedSame : 0);
}

@end
                               
@implementation STL

@synthesize name;
@synthesize error;

-(id)init {
    if((self = [super init])) {
        xMin = yMin = zMin = xMax = yMax = zMax = 0;
        [self setName:@"Unknown"];
        error = nil;
        points = normals = nil;
        triangles = edges = nil;
        list = nil;
        bufs = nil;
    }
    return self;
}

-(void)dealloc {
    if(error!=nil)
        [error release];
    if(points!=nil) free(points);
    if(normals!=nil) free(normals);
    if(triangles!=nil) free(triangles);
    if(edges!=nil) free(edges);
    if(list!=nil) [list release];
    if(bufs!=nil) {
        glDeleteBuffers(4, bufs);
        free(bufs);
    }
    [super dealloc];
}
-(BOOL)load:(NSString*)file {
    double starttime = CFAbsoluteTimeGetCurrent();
    list = [RHLinkedList new];
    NSData *data = [NSData dataWithContentsOfFile:file];
    if(data.length<84) return NO;
    const void *f = data.bytes;
    int32_t nTri = *(int32_t*)(f+80);
    if (data.length != 84 + nTri * 50) {
        [self loadText:data];
        starttime = CFAbsoluteTimeGetCurrent()-starttime;
        //NSLog(@"Imported ASCII STL in %1.2f seconds",starttime);
    }  else {
        for (int i = 0; i < nTri; i++) {
            float *arr = (float*)(f+84+50*i);
            STLTriangle *tri = [STLTriangle new];
            tri->normal[0] = arr[0];
            tri->normal[1] = arr[1];
            tri->normal[2] = arr[2];
            tri->p1[0] = arr[3];
            tri->p1[1] = arr[4];
            tri->p1[2] = arr[5];
            tri->p2[0] = arr[6];
            tri->p2[1] = arr[7];
            tri->p2[2] = arr[8];
            tri->p3[0] = arr[9];
            tri->p3[1] = arr[10];
            tri->p3[2] = arr[11];
            [list addLast:tri];
            [tri release];
        }
        starttime = CFAbsoluteTimeGetCurrent()-starttime;
        //NSLog(@"Imported binary STL in %1.2f seconds",starttime);
    }
//                FileInfo info = new FileInfo(file);
    [self setName:[file lastPathComponent]];
    return error==nil;
}
/// <summary>
/// Translate Object, so that the lowest point is 0.
/// </summary>
-(void)land {
    [self updateBoundingBox];
    position[2] -= zMin;
    zMax-=zMin;
    zMin =0;
}
-(void)centerX:(float) x y:(float) y {
    [self land];
    float dx,dy;
    position[0] += (dx=x - 0.5f * (xMax + xMin));
    position[1] += (dy=y - 0.5f * (yMax + yMin));
    xMax+=dx;
    xMin+=dx;
    yMax+=dy;
    yMin+=dy;
}
-(void)getCenter:(float*)center {
    center[0] = 0.5*(xMin+xMax);
    center[1] = 0.5*(yMin+yMax);
    center[2] = 0.5*(zMin+zMax);
}

-(void)updateMatrix {
    float transl[16],scalem[16],rotx[16],roty[16],rotz[16];
    matrix4Translatef(transl, position[0], position[1],position[2]);
    matrix4Scalef(scalem,scale[0],scale[1],scale[2]);
    matrix4RotateXf(rotx, rotation[0]*(float)M_PI/180.0);
    matrix4RotateYf(roty, rotation[1]*(float)M_PI/180.0);
    matrix4RotateZf(rotz, rotation[2]*(float)M_PI/180.0);
    matrix4MulMatf(trans,scalem,rotx);
    matrix4MulMatf(scalem,trans,roty);
    matrix4MulMatf(rotx,scalem,rotz);
    matrix4MulMatf(trans,rotx,transl);
}
-(void)updateBoundingBox {
    [self updateMatrix ];
    xMin = yMin = zMin =FLT_MAX;
    xMax = yMax = zMax = FLT_MIN;
            
    for(STLTriangle *tri in list) {
        [self includePoint:tri->p1];
        [self includePoint:tri->p2];
        [self includePoint:tri->p3];
    }
}

-(void)includePoint:(GLfloat*)v {
    //float x, y, z;
    float v4[] = {v[0],v[1],v[2],1};
    float p[4];
    matrix4MulVecf(trans,v4,p);
    //x = vector4Dotf(trans, v4);
    //y = vector4Dotf(&trans[4], v4);
    //z = vector4Dotf(&trans[8], v4);
    xMin = MIN(xMin, p[0]);
    xMax = MAX(xMax, p[0]);
    yMin = MIN(yMin, p[1]);
    yMax = MAX(yMax, p[1]);
    zMin = MIN(zMin, p[2]);
    zMax = MAX(zMax, p[2]);
}
-(void)transformPoint:(GLfloat*)v to:(float*)res {
    float v4[] = {v[0],v[1],v[2],1};
    matrix4MulVecRes3f(trans,v4,res);
    //res[0] = vector4Dotf(trans, v4);
    //res[1] = vector4Dotf(&trans[4], v4);
    //res[2] = vector4Dotf(&trans[8], v4);
}
-(void)paint {
    /*if(points!=nil) free(points);
    if(normals!=nil) free(normals);
    if(triangles!=nil) free(triangles);
    if(edges!=nil) free(edges);
    if(bufs!=nil) {
        glDeleteBuffers(4, bufs);
        free(bufs);
        bufs = nil;
    }*/
    if (conf3d->useVBOs && bufs == nil) {
        bufs = malloc(4*sizeof(GLuint));
        glGenBuffers(4, bufs);
        int nv = list->count * 3;
        points    = malloc(pointsLength=nv*3*sizeof(GLfloat));
        normals   = malloc(normalsLength=nv*3*sizeof(GLfloat));
        triangles = malloc(trianglesLength=sizeof(GLuint)*nv);
        edges     = malloc(edgesLength=sizeof(GLuint)*2 * nv);
        int pos  = 0;
        int epos = 0;
        int tpos = 0;
        int ppos = 0;
        for(STLTriangle *tri in list) {
            edges[epos++] = pos;
            edges[epos++] = pos+1;
            edges[epos++] = pos+1;
            edges[epos++] = pos+2;
            edges[epos++] = pos+2;
            edges[epos++] = pos;
            triangles[tpos++] = pos++;
            triangles[tpos++] = pos++;
            triangles[tpos++] = pos++;
            normals[ppos]  = tri->normal[0];
            points[ppos++] = tri->p1[0];
            normals[ppos]  = tri->normal[1];
            points[ppos++] = tri->p1[1];
            normals[ppos]  = tri->normal[2];
            points[ppos++] = tri->p1[2];
            normals[ppos]  = tri->normal[0];
            points[ppos++] = tri->p2[0];
            normals[ppos]  = tri->normal[1];
            points[ppos++] = tri->p2[1];
            normals[ppos]  = tri->normal[2];
            points[ppos++] = tri->p2[2];
            normals[ppos]  = tri->normal[0];
            points[ppos++] = tri->p3[0];
            normals[ppos]  = tri->normal[1];
            points[ppos++] = tri->p3[1];
            normals[ppos]  = tri->normal[2];
            points[ppos++] = tri->p3[2];
        }
        glBindBuffer(GL_ARRAY_BUFFER, bufs[0]);
        glBufferData(GL_ARRAY_BUFFER, pointsLength, points,GL_STATIC_DRAW);
        glBindBuffer(GL_ARRAY_BUFFER, bufs[1]);
        glBufferData(GL_ARRAY_BUFFER, normalsLength, normals,GL_STATIC_DRAW);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, bufs[2]);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, trianglesLength, triangles, GL_STATIC_DRAW);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, bufs[3]);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, edgesLength, edges, GL_STATIC_DRAW);
    }
    float *col;
    if (selected)
        col = conf3d->selectedObjectColor;
    else
        col = conf3d->objectColor;
    glMaterialfv(GL_FRONT_AND_BACK,GL_AMBIENT,col);
    glMaterialfv(GL_FRONT_AND_BACK,GL_DIFFUSE,col);
    glMaterialfv(GL_FRONT_AND_BACK,GL_EMISSION,conf3d->blackColor);
    glMaterialfv(GL_FRONT_AND_BACK,GL_SPECULAR,conf3d->specularColor);
    glMaterialf(GL_FRONT_AND_BACK,GL_SHININESS, 50);
    
    if (conf3d->useVBOs)
    {
        glEnableClientState(GL_VERTEX_ARRAY);
        glEnableClientState(GL_NORMAL_ARRAY);
        if(NO) {
            glVertexPointer(3, GL_FLOAT, 0, points);
            glNormalPointer(GL_FLOAT, 0, normals);            
            glDrawElements(GL_TRIANGLES, list->count*3,GL_UNSIGNED_INT, triangles);
            
        } else {
        glBindBuffer(GL_ARRAY_BUFFER, bufs[0]);
    //    glBufferData(GL_ARRAY_BUFFER, pointsLength, points,GL_STATIC_DRAW);
        glVertexPointer(3, GL_FLOAT, 0, 0);
        glBindBuffer(GL_ARRAY_BUFFER, bufs[1]);
      //  glBufferData(GL_ARRAY_BUFFER, normalsLength, normals,GL_STATIC_DRAW);
        glNormalPointer(GL_FLOAT, 0, 0);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, bufs[2]);    
  //          glBufferData(GL_ELEMENT_ARRAY_BUFFER, trianglesLength, triangles, GL_STATIC_DRAW);
        glDrawElements(GL_TRIANGLES, list->count*3,GL_UNSIGNED_INT, 0);
        }
        if (conf3d->showEdges)
        {
            col = conf3d->edgeColor;
            glMaterialfv(GL_FRONT_AND_BACK,GL_EMISSION,col);
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, bufs[3]);
            glDrawElements(GL_LINES, edgesLength/sizeof(GLuint), GL_UNSIGNED_INT, 0);
        }
        glDisableClientState(GL_VERTEX_ARRAY);
        glDisableClientState(GL_NORMAL_ARRAY);
    }
    else
    {
        glBegin(GL_TRIANGLES);
        for (STLTriangle *tri in list)
        {
            glNormal3fv(tri->normal);
            glVertex3fv(tri->p1);
            glVertex3fv(tri->p2);
            glVertex3fv(tri->p3);
        }
        glEnd();
    }
    // Draw edges
    if (conf3d->showEdges && !conf3d->useVBOs)
    {
        col = conf3d->edgeColor;
        glMaterialfv(GL_FRONT_AND_BACK,GL_EMISSION,col);
        glBegin(GL_LINE);
        for(STLTriangle *tri in list)
        {
            glVertex3fv(tri->p1);
            glVertex3fv(tri->p2);
            glVertex3fv(tri->p2);
            glVertex3fv(tri->p3);
            glVertex3fv(tri->p3);
            glVertex3fv(tri->p1);
        }
        glEnd();
    }
}
/// solid
///  facet normal -1.000000 -0.000000 -0.000000
/// outer loop
/// vertex -12.000000 -12.000000 0.000000
/// vertex -12.000000 -12.000000 24.000000
/// vertex -12.000000 12.000000 0.000000
/// endloop
/// endfacet
-(void)loadText:(NSData*)data {
    NSString *text = [[NSString alloc]
                        initWithData:data encoding: NSISOLatin1StringEncoding];
    NSRange p,pend,normal,outer,vertex,vertex2;
    NSRange sr = NSMakeRange(0, text.length);
    while((p = [text rangeOfString:@"facet" options:NSLiteralSearch range:sr]).location!=NSNotFound) {
        pend = [text rangeOfString:@"endfacet" options:NSLiteralSearch range:sr];
        if(pend.location == NSNotFound) {
            error = @"Format error";
            [text release];
            return;
        }
        sr = NSMakeRange(p.location+5,pend.location-p.location);
        normal = [text rangeOfString:@"normal" options:NSLiteralSearch range:sr];
        if(normal.location == NSNotFound) {
            error = @"Format error";
            [text release];
            return;
        }
        outer = [text rangeOfString:@"outer loop" options:NSLiteralSearch range:sr];
        if(outer.location == NSNotFound) {
            error = @"Format error";
            [text release];
            return;
        }
        STLTriangle *tri = [STLTriangle new];
        [self extractVector:tri->normal from:[text substringWithRange:NSMakeRange(normal.location+6,outer.location-normal.location-6)]];
        if(error!=nil) {
            [text release];
            return;
        }
        outer.location+=10;
        outer.length = pend.location-outer.location;
        vertex = [text rangeOfString:@"vertex" options:NSLiteralSearch range:outer];
        if(vertex.location == NSNotFound) {
            error = @"Format error";
            [text release];
            return;
        }
       vertex.location+=6;
        vertex.length = pend.location-vertex.location;
        vertex2 = [text rangeOfString:@"vertex" options:NSLiteralSearch range:vertex];
        if(vertex2.location == NSNotFound) {
            error = @"Format error";
            [text release];
            return;
        }
        [self extractVector:tri->p1 from:[text substringWithRange:NSMakeRange(vertex.location,vertex2.location-vertex.location)]];
        if(error!=nil) {
            [text release];
            return;
        }
        vertex2.location += 7;
        vertex2.length = pend.location-vertex2.location;
        vertex = [text rangeOfString:@"vertex" options:NSLiteralSearch range:vertex2];
        if(vertex.location == NSNotFound) {
            error = @"Format error";
            [text release];
            return;
        }
        [self extractVector:tri->p2 from:[text substringWithRange:NSMakeRange(vertex2.location,vertex.location-vertex2.location)]];
        if(error!=nil) {
            [text release];
            return;}
        vertex.location += 7;
        vertex.length = pend.location-vertex.location;
        vertex2 = [text rangeOfString:@"endloop" options:NSLiteralSearch range:vertex];
        if(vertex2.location == NSNotFound) {
            error = @"Format error";
            [text release];
            return;
        }
        [self extractVector:tri->p3 from:[text substringWithRange:NSMakeRange(vertex.location,vertex2.location-vertex.location)]];
        if(error!=nil) {
            [text release];
            return;
        }
        sr = NSMakeRange(pend.location+8,text.length-pend.location-8);
        [list addLast:tri];
    }
    [text release];
}
-(void)extractVector:(GLfloat*)res from:(NSString*) s {
    s = [s stringByTrimmingCharactersInSet:
                [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSRange p = [s rangeOfString:@" "];
    if (p.location == NSNotFound) {
        [self setError:@"Format error"];
         return;
    };
    res[0] = ((NSString*)[s substringWithRange:NSMakeRange(0,p.location)]).floatValue;     
    s = [[s substringFromIndex:p.location+1] stringByTrimmingCharactersInSet:
         [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    p = [s rangeOfString:@" "];
    if (p.location == NSNotFound) {
        [self setError:@"Format error"];
        return;
    };
    res[1] = ((NSString*)[s substringWithRange:NSMakeRange(0,p.location)]).floatValue;     
    s = [[s substringFromIndex:p.location+1] stringByTrimmingCharactersInSet:
         [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    res[2] = s.floatValue;     
}

@end
