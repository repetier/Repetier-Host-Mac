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

#import "GCodeVisual.h"
#import "ThreeDConfig.h"
#import "RHLogger.h"
#import "StringUtil.h"
#import "GCode.h"
#include <OpenGL/OpenGL.h>
#include <OpenGL/gl.h>
#include "../controller/GCodeEditorController.h"
#include "../RHAppDelegate.h"
#include "../controller/GCodeView.h"

BOOL correctNormals = true;

@implementation GCodePoint

-(id)init {
    if((self=[super init])) {
        fline = element = 0;
    }
    return self;
}
+(int)toFile:(int) file line:(int)line {
    if (file < 0) return 0; return (file << 29) + line;
}
@end

@implementation GCodeTravel

-(id)init {
    if((self=[super init])) {
        fline = 0;
    }
    return self;
}
+(int)toFile:(int) file line:(int)line {
    if (file < 0) return 0; return (file << 29) + line;
}
@end

@implementation GCodePath

-(id)init {
    if((self=[super init])) {
        pointsCount = 0;
        elementsLength = 0;
        positionsLength = 0;
        drawMethod = -1;
        positions = nil;
        normals = nil;
        elements = nil;
        hasBuf = NO;
        pointsLists = [RHLinkedList new];
        pointsLock = [NSLock new];
    }
    return self;
}
-(void)add:(float*)v extruder:(float)e distance:(float)d fline:(int)fl
{
    if (pointsLists->count == 0) {
        RHLinkedList *newlist = [RHLinkedList new];
        [pointsLists addLast:newlist];
        [newlist release];
    }
    GCodePoint *pt = [GCodePoint new];
    pt->p[0] = v[0];
    pt->p[1] = v[1];
    pt->p[2] = v[2];
    pt->e = e;
    pt->dist = d;
    pt->fline = fl;
    pointsCount++;
    [pointsLock lock];
    [[pointsLists peekLastFast] addLast:pt];
    [pointsLock unlock];
    [pt release];
    drawMethod = -1; // invalidate old 
}

-(float)lastDist
{
    return ((GCodePoint*)[[pointsLists peekLast] peekLast])->dist;
}

-(void)join:(GCodePath*)path
{
    [pointsLock lock];
    for (RHLinkedList *frag in path->pointsLists) {
        [pointsLists addLast:frag];
    }
    pointsCount += path->pointsCount;
    if (elements != nil) {
        if (false && path->elements != nil && drawMethod == path->drawMethod) // both parts are already up to date, so just join them
        {
            GLuint *newelements = malloc(sizeof(GLuint)*(elementsLength + path->elementsLength));
            int p, l = elementsLength, i;
            for (p = 0; p < l; p++) newelements[p] = elements[p];
            GLuint *pe = path->elements;
            l = path->elementsLength;
            for (i = 0; i < l; i++) newelements[p++] = pe[i];
            free(elements);
            elements = newelements;
            float *newnormals = nil;
            if (normals != nil) newnormals = malloc(sizeof(float)*(positionsLength + path->positionsLength));
            float *newpoints = malloc(sizeof(float)*(positionsLength + path->positionsLength));
            if (normals != nil)
            {
                l = positionsLength;
                for (p = 0; i < l; p++)
                {
                    newnormals[p] = normals[p];
                    newpoints[p] = positions[p];
                }
                float *pn = path->normals;
                float *pp = path->positions;
                l = path->positionsLength;
                for (i = 0; i < l; i++)
                {
                    newnormals[p] = pn[i];
                    newpoints[p++] = pp[i];
                }
                free(normals);
                free(positions);
                normals = newnormals;
                positions = newpoints;
            }
            else
            {
                l = positionsLength;
                for (p = 0; i < l; p++)
                {
                    newpoints[p] = positions[p];
                }
                float *pp = path->positions;
                l = path->positionsLength;
                for (i = 0; i < l; i++)
                {
                    newpoints[p++] = pp[i];
                }
                free(positions);
                positions = newpoints;
            }
            positionsLength+=path->positionsLength;
            elementsLength+=path->elementsLength;
        }
        else
        {
            if(positions!=nil)
                free(positions);
            if(elements!=nil)
                free(elements);
            if(normals!=nil)
                free(normals);
            elements = nil;
            normals = nil;
            positions = nil;
            drawMethod = -1;
        }
        if (hasBuf)
        {
            glDeleteBuffers(3, buf);
            hasBuf = NO;
        }
    } else drawMethod = -1; 
    [pointsLock unlock];
}
-(void)dealloc
{
    [self free];
    [pointsLists release];
    [pointsLock release];
    [super dealloc];
}
-(void)free
{
    if (elements != nil)
    {
        if(positions!=nil)
            free(positions);
        free(elements);
        if(normals!=nil)
            free(normals);
        elements = nil;
        normals = nil;
        positions = nil;
        pointsCount = 0;
        [pointsLists clear];
        if (hasBuf)
            glDeleteBuffers(3, buf);
        hasBuf = NO;
    }
}
-(void)normalize:(float*)n
{
    float d = (float)sqrt(n[0] * n[0] + n[1] * n[1] + n[2] * n[2]);
    n[0] /= d;
    n[1] /= d;
    n[2] /= d;
}
/// <summary>
/// Refill VBOs with current values of elements etc.
/// </summary>
-(void)refillVBO
{
    if (positions == nil) return;
    if (hasBuf)
        glDeleteBuffers(3, buf);
    glGenBuffers(3, buf);
    glBindBuffer(GL_ARRAY_BUFFER, buf[0]);
    glBufferData(GL_ARRAY_BUFFER, (positionsLength * sizeof(float)), positions,GL_STATIC_DRAW);
    if (normals != nil)
    {
        glBindBuffer(GL_ARRAY_BUFFER, buf[1]);
        glBufferData(GL_ARRAY_BUFFER, (positionsLength * sizeof(float)), normals,GL_STATIC_DRAW);
    }
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, buf[2]);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, (elementsLength * sizeof(int)), elements,GL_STATIC_DRAW);
    hasBuf = YES;
}
-(void)clearVBO {
    if (hasBuf)
        glDeleteBuffers(3, buf);
    hasBuf = NO;
    drawMethod = -1; // Force redraw
}
-(void)updateVBO:(BOOL)buffer
{
    if (pointsCount < 2) 
        return;
    if (hasBuf)
        glDeleteBuffers(3, buf);
    hasBuf = NO;
    int method = conf3d->filamentVisualization;
    float h = conf3d->layerHeight;
    float wfac = conf3d->widthOverHeight;
    float w = h * wfac;
    BOOL fixedH = conf3d->useLayerHeight;
    float dfac = (float)(M_PI * conf3d->filamentDiameter * conf3d->filamentDiameter * 0.25 / wfac);
    // nv = number vertices around circumsphere of filament
    int nv = 8 * (method - 1), i;
    if (method == 1) nv = 4;
    if (method == 0) nv = 1;
    int n = nv * (method == 0 ? 1 : 2) * (pointsCount - pointsLists->count);
    if(positions!=nil)
        free(positions);
    if(elements!=nil)
        free(elements);
    if(normals!=nil)
        free(normals);
    if (method != 0) positionsLength = pointsCount*nv*3*(correctNormals? 2 :1); else positionsLength = 3*pointsCount;
    positions = malloc(sizeof(float)*positionsLength);
    if (method != 0) normals = malloc(sizeof(float)*positionsLength); else normals = nil;
    if (method != 0) elementsLength=(pointsCount - pointsLists->count) * nv * 4+pointsLists->count*(nv-2)*4; else elementsLength = n * 2;
    elements = malloc(sizeof(GLuint)*elementsLength);
    int pos = 0;
    int npos = 0;
    int vpos = 0;
    if (method > 0)
    {
        float alpha, dalpha = (float)M_PI * 2.0 / nv;
        float dir[3];
        float dirs[3];
        float diru[3];
        float norm[3];
        float lastdir[3];
        float actdir[3],actdirs[3];
        float laste = 0;
        float dh = 0.5f * h;
        float dw = 0.5f * w;
        float deltae;
        BOOL first = YES;
        float *last;
        diru[0] = diru[1] = 0;
        diru[2] = 1;
       // w *= 0.5f;
        for (RHLinkedList * points in pointsLists)
        {
            if (points->count < 2) {
                //NSLog(@"Low point count %i",(int)points->count);
                continue;
            }
            first = YES;
            RHListNode *ptNode = points.firstNode;
            while(ptNode!=nil)
            {
                GCodePoint *pt = ptNode->value;
                pt->element = pos;
                //NSLog(@"P: %f %f %f",pt->p[0],pt->p[1],pt->p[2]);
                GCodePoint *ptn = nil;
                if (ptNode->next != nil)
                    ptn = ptNode->next->value;
                ptNode = ptNode->next;                
                float *v = pt->p;
                if (first)
                {
                    //last = v;
                    lastdir[0] = actdir[0] = ptn->p[0] - v[0];
                    lastdir[1] = actdir[1] = ptn->p[1] - v[1];
                    lastdir[2] = actdir[2] = ptn->p[2] - v[2];
                    if(ptn==nil) break;
                    deltae = ptn->e - pt->e;
                    [self normalize:lastdir];
                    // first = false;
                    // continue;
                }
                else
                {
                    if (ptn==nil) // Last value
                    {
                        actdir[0] = v[0] - last[0];
                        actdir[1] = v[1] - last[1];
                        actdir[2] = v[2] - last[2];
                        deltae = pt->e - laste;
                    }
                    else
                    {
                        actdir[0] = ptn->p[0] - v[0];
                        actdir[1] = ptn->p[1] - v[1];
                        actdir[2] = ptn->p[2] - v[2];
                        deltae = ptn->e - pt->e;
                    }
                }
                if (!fixedH)
                {
                    float dist = (float)sqrt(actdir[0] * actdir[0] + actdir[1] * actdir[1] + actdir[2] * actdir[2]);
                    if (dist > 0)
                    {
                        h = (float)sqrt(deltae * dfac / dist);
                        w = h * wfac;
                        dh = 0.5f * h;
                        dw = 0.5f * w;
                    }
                }
                [self normalize:actdir];
                dir[0] = actdir[0] + lastdir[0];
                dir[1] = actdir[1] + lastdir[1];
                dir[2] = actdir[2] + lastdir[2];
                [self normalize:dir];
                //NSLog(@"dir %f %f %f",dir[0],dir[1],dir[2]);
                //NSLog(@"lastdir %f %f %f",lastdir[0],lastdir[1],lastdir[2]);
                double vacos = dir[0] * lastdir[0] + dir[1] * lastdir[1] + dir[2] * lastdir[2];
                if(vacos<0.3) vacos = 0.3; else if(vacos>1) vacos = 1;
                float zoomw = vacos; //cos(acos(vacos));
                //NSLog(@"vacos %f,zoomz %f",vacos,zoomw);
                lastdir[0] = actdir[0];
                lastdir[1] = actdir[1];
                lastdir[2] = actdir[2];
                dirs[0] = -dir[1];
                dirs[1] = dir[0];
                dirs[2] = dir[2];
                actdirs[0] = -actdir[1];
                actdirs[1] = actdir[0];
                actdirs[2] = actdir[2];
                alpha = 0;
                float c, s;
                int b = vpos / 3-nv*(correctNormals ? 2 : 1);
                for (i = 0; i < nv; i++)
                {
                    c = (float)cos(alpha) * dh;
                    s = (float)sin(alpha) * dw/zoomw;
                    //NSLog(@"c=%f s=%f a=%f dh=%f,zoomw=%f",c,s,alpha,dh,zoomw);
                    if (correctNormals)
                    {
                        float s2 = (float)sin(alpha) * dw;
                        norm[0] = (float)(s2 * actdirs[0] + c * diru[0]);
                        norm[1] = (float)(s2 * actdirs[1] + c * diru[1]);
                        norm[2] = (float)(s2 * actdirs[2] + c * diru[2]);
                    }
                    else
                    {
                        norm[0] = (float)(s * dirs[0] + c * diru[0]);
                        norm[1] = (float)(s * dirs[1] + c * diru[1]);
                        norm[2] = (float)(s * dirs[2] + c * diru[2]);
                    }
                    [self normalize:norm];
                    if (!first)
                    {
                        if (correctNormals)
                        {
                            elements[pos++] = b + 2*((i + 1) % nv)+1;
                            elements[pos++] = b + 2*i+1;
                            elements[pos++] = b + 2*(i + nv);
                            elements[pos++] = b + 2*((i + 1) % nv + nv);
                        }
                        else
                        {
                            elements[pos++] = b + (i + 1)%nv;
                            elements[pos++] = b + i;
                            elements[pos++] = b + i + nv;
                            elements[pos++] = b + (i + 1) % nv + nv;
                        }
                                                                //NSLog(@"Pts %i %i %i %i", elements[pos-4], elements[pos-3], elements[pos-2], elements[pos-1]);
                    }
                    if (correctNormals)
                    {
                        if (first || ptNode == nil)
                        {
                            if (first)
                            {
                                normals[npos++] = -actdir[0];
                                normals[npos++] = -actdir[1];
                                normals[npos++] = -actdir[2];
                            }
                            else
                            {
                                normals[npos++] = norm[0];
                                normals[npos++] = norm[1];
                                normals[npos++] = norm[2];
                            }
                            positions[vpos++] = v[0] + s * dirs[0] + c * diru[0];
                            positions[vpos++] = v[1] + s * dirs[1] + c * diru[1];
                            positions[vpos++] = v[2] - dh + s * dirs[2] + c * diru[2];
                        }
                        else
                        {
                            normals[npos] = normals[npos - 6 * nv+3];
                            normals[npos + 1] = normals[npos - 6 * nv +4];
                            normals[npos + 2] = normals[npos - 6 * nv +5];
                            npos += 3;
                            positions[vpos++] = v[0] + s * dirs[0] + c * diru[0];
                            positions[vpos++] = v[1] + s * dirs[1] + c * diru[1];
                            positions[vpos++] = v[2] - dh + s * dirs[2] + c * diru[2];
                        }
                    }
                    if (correctNormals && ptNode == nil)
                    {
                        normals[npos++] = actdir[0];
                        normals[npos++] = actdir[1];
                        normals[npos++] = actdir[2];
                    }
                    else
                    {
                        normals[npos++] = norm[0];
                        normals[npos++] = norm[1];
                        normals[npos++] = norm[2];
                    }
                    positions[vpos++] = v[0] + s * dirs[0] + c * diru[0];
                    positions[vpos++] = v[1] + s * dirs[1] + c * diru[1];
                    positions[vpos++] = v[2] - dh + s * dirs[2] + c * diru[2];
                    //NSLog(@"pos %i %f %f %f",(vpos/3)-1,positions[vpos-3],positions[vpos-2],positions[vpos-1]);
                    alpha += dalpha;
                }
                if (first || ptNode == nil) // Draw cap
                {
                    //NSLog(@"Cap");
                    //b = vpos / 3 - nv;
                    int nn  = (nv-2)/2;
                    for (i = 0; i < nn; i++)
                    {
                        if (correctNormals)
                        {
                            if (first)
                            {
                                elements[pos++] = b + 2*i;
                                elements[pos++] = b + 2*i + 2;
                                elements[pos++] = b + 2*nv - 2*i - 4;
                                elements[pos++] = b + 2*nv - 2*i - 2;
                            }
                            else
                            {
                                elements[pos++] = b + 2*(nv -i -1)+1;
                                elements[pos++] = b + 2*(nv - i -2)+1;
                                elements[pos++] = b + 2*i + 3;
                                elements[pos++] = b + 2*i+1;
                            }
                        }
                        else
                        {
                            if (first)
                            {
                                elements[pos++] = b+i;
                                elements[pos++] = b + i + 1;
                                elements[pos++] = b + nv - i - 2;
                                elements[pos++] = b + nv - i - 1;
                            }
                            else
                            {
                                elements[pos++] = b + nv - i - 1;
                                elements[pos++] = b + nv - i - 2;
                                elements[pos++] = b + i + 1;
                                elements[pos++] = b + i;
                            }
                        }
                    }
                }
                last = v;
                laste = pt->e;
                first = NO;
            }
        }
        if(pos>elementsLength) 
            NSLog(@"Wrong elements length: %i to %i",pos,elementsLength);
        else if(pos<elementsLength) elementsLength = pos;
        if (buffer)
        {
            glGenBuffers(3, buf);
            glBindBuffer(GL_ARRAY_BUFFER, buf[0]);
            glBufferData(GL_ARRAY_BUFFER, (positionsLength * sizeof(float)), positions, GL_STATIC_DRAW);
            glBindBuffer(GL_ARRAY_BUFFER, buf[1]);
            glBufferData(GL_ARRAY_BUFFER, (positionsLength * sizeof(float)), normals, GL_STATIC_DRAW);
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, buf[2]);
            glBufferData(GL_ELEMENT_ARRAY_BUFFER, (elementsLength * sizeof(GLuint)), elements,GL_STATIC_DRAW);
            // GL.BindBuffer(BufferTarget.ArrayBuffer, 0);
            hasBuf = YES;
        }
    }
    else
    {
        // Draw edges
        BOOL first = YES;
        for (RHLinkedList *points in pointsLists)
        {
            if (points->count < 2) {
                // NSLog(@"Low point count %i",(int)points->count);
                continue;
            }
            first = YES;
            for (GCodePoint *pt in points)
            {
                pt->element = pos;
                float *v = pt->p;
                positions[vpos++] = v[0];
                positions[vpos++] = v[1];
                positions[vpos++] = v[2];
                        
                if (!first)
                {
                    elements[pos] = vpos / 3-1;
                    elements[pos + 1] = vpos / 3 -2;
                    pos += 2;
                }
                first = NO;
            }
        }
        if(pos>elementsLength) 
            NSLog(@"Wrong elements length: %i to %i",pos,elementsLength);
        else if(pos<elementsLength) elementsLength = pos;
        if (buffer)
        {
            glGenBuffers(3, buf);
            glBindBuffer(GL_ARRAY_BUFFER, buf[0]);
            glBufferData(GL_ARRAY_BUFFER, (positionsLength * sizeof(float)), positions, GL_STATIC_DRAW);
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, buf[2]);
            glBufferData(GL_ELEMENT_ARRAY_BUFFER, (elementsLength * sizeof(GLuint)), elements, GL_STATIC_DRAW);
            hasBuf = YES;
        }
    }
    drawMethod = method;
}
@end

@implementation GCodeVisual

-(id)init {
    if((self=[super init])) {
        segments = [[NSMutableArray alloc] initWithCapacity:MAX_EXTRUDER];
        travelMoves = [[NSMutableArray alloc] init];
        for(int i=0;i<MAX_EXTRUDER;i++)
            [segments addObject:[[RHLinkedList new] autorelease]];
        ana = [[GCodeAnalyzer alloc] init];
        ana->privateAnalyzer = YES;
        hasTravelBuf = NO;
        travelMovesBuffered = 0;
        //act = nil;
        lastFilHeight = 999;
        lastFilWidth = 999;
        lastFilDiameter = 999;
        lastFilUseHeight = true;
        laste = -999;
        hotFilamentLength = 1000;
        minHotDist = 0;
        totalDist = 0;
        liveView = NO; // Is live view of print. If true, color transion for end is shown
        method = 0;
        colbufSize = 0;
        lastx = 1e20f; lasty = 0; lastz = 0;
        lastLayer = -1;
        changed = NO;
        startOnClear = YES;
        changeLock = [NSLock new];
        ana->delegate = self;
        minLayer = 0;
        maxLayer = 1000000;
        fileid = actLine = 0;
        showSelection = YES;
        lastCorrectNormals = correctNormals;
    }
    return self;
}        
-(id)initWithAnalyzer:(GCodeAnalyzer*)a {
    if((self=[super init])) {
        segments = [[NSMutableArray alloc] initWithCapacity:MAX_EXTRUDER];
        travelMoves = [[NSMutableArray alloc] init];
        for(int i=0;i<MAX_EXTRUDER;i++)
            [segments addObject:[[RHLinkedList new] autorelease]];
        ana = [a retain];
        //act = nil;
        hasTravelBuf = NO;
        travelMovesBuffered = 0;
        lastFilHeight = 999;
        lastFilWidth = 999;
        lastFilDiameter = 999;
        lastFilUseHeight = true;
        laste = -999;
        hotFilamentLength = 1000;
        minHotDist = 0;
        totalDist = 0;
        liveView = NO; // Is live view of print. If true, color transion for end is shown
        method = 0;
        colbufSize = 0;
        lastx = 1e20f; lasty = 0; lastz = 0;
        lastLayer = -1;
        changed = NO;
        startOnClear = NO;
        changeLock = [NSLock new];
        ana->delegate = self;
        minLayer = 0;
        maxLayer = 1000000;
        fileid = actLine = 0;
        showSelection = NO;
        lastCorrectNormals = correctNormals;
    }
    return self;
}        
-(void)dealloc
{
    for(RHLinkedList *seg in segments) {
        for (GCodePath *p in seg)
            [p free];
        [seg clear];
    }
    [segments removeAllObjects];
    [segments release];
    [travelMoves release];
    if (colbufSize > 0)
        glDeleteBuffers(1,&colbuf);
    colbufSize = 0;
    [changeLock release];
    if(ana->privateAnalyzer)
        [ana release];
    [super dealloc];
}
-(void)reduce
{
    for(RHLinkedList *seg in segments) {
    if (seg->count < 2) continue;
    if (!liveView)
    {
        GCodePath *first = seg.peekFirst;
        while (seg->count > 1)
        {
            GCodePath *sec = [seg objectAtIndex:1];
            [first join:sec];
            [sec free];
            [seg remove:sec];
        }
    }
    else
    {
        RHListNode *actn = seg.firstNode, *next;
        while (actn->next != nil)
        {
            next = actn->next;
            if (next->next == nil) {
                break; // Don't touch last segment we are writing to
            }
            GCodePath *nextval = next->value;
            if (nextval->pointsCount < 2)
            {
                actn = next;
                if (actn->next != nil)
                    actn = actn->next;
            }
            else if (nextval.lastDist > minHotDist)
            {
                if (((GCodePath*)(actn->value))->pointsCount < 500)
                {
                    [actn->value join:nextval];
                    [nextval free];
                    [seg remove:nextval];
                }
                else
                {
                    actn = next;
                }
            }
            else if (((GCodePath*)(actn->value))->pointsCount < 5000 || (nextval->pointsCount >= 5000 && ((GCodePath*)(actn->value))->pointsCount < 27000))
            {
                    [actn->value join:nextval];
                    [nextval free ];
                    [seg remove:nextval];
            }
            else
            {
                actn = next;
            }
        }
    }
    }
}
-(void) stats
{
    int cnt = 0;
    int pts = 0;
    for(RHLinkedList *seg in segments) {
        cnt+=seg->count;
        for (GCodePath *p in seg)
        {
            pts += p->pointsCount;
            
        }
    }
    [rhlog addInfo:[NSString stringWithFormat:@"Path segments:%d",cnt]];
    [rhlog addInfo:[NSString stringWithFormat:@"Points total:%d",pts]];
}
/// <summary>
/// Add a GCode line to be visualized.
/// </summary>
/// <param name="g"></param>
-(void)addGCode:(GCode*) g
{
    //act = g;
    [ana analyze:g];
    laste = ana->activeExtruder->emax;
}
/// <summary>
/// Remove all drawn lines.
/// </summary>
-(void)clear
{
    [changeLock lock];
    for(RHLinkedList *seg in segments) {
        for(GCodePath *p in seg)
            [p free];
            [seg clear];
    }
    [travelMoves removeAllObjects];
    lastx = 1e20f; // Don't ignore first point if it was the last!
    totalDist = 0;
    if (colbufSize > 0)
        glDeleteBuffers(1, &colbuf);
    colbufSize = 0;
    if(hasTravelBuf)
        glDeleteBuffers(2,travelBuf);
    hasTravelBuf = NO;
    if (startOnClear)
        [ana start];
    else
        ana->layer = 0;
    [changeLock unlock];
}
-(void) printerStateChanged:(GCodeAnalyzer*)analyzer {}
-(void) positionChanged:(GCodeAnalyzer*)analyzer x:(float)xp y:(float)yp z:(float)zp {
    if(!analyzer->isG1Move) return;
   /* float xp = analyzer->x;
    float yp = analyzer->y;
    float zp = analyzer->z;*/
    if (!ana->drawing)
    {
        lastx = xp;
        lasty = yp;
        lastz = zp;
        laste = ana->activeExtruder->emax;
        return;
    }
    float locDist = (float)sqrt((xp - lastx) * (xp - lastx) + (yp - lasty) * (yp - lasty) + (zp - lastz) * (zp - lastz));
    BOOL isLastPos = locDist < 0.00001;
    float mypos[3] = {xp,yp,zp};
    [changeLock lock];
    if(ana->eChanged == NO) {
        GCodeTravel *travel = [GCodeTravel new];
        travel->fline = [GCodeTravel toFile:fileid line:actLine];
        travel->p1[0] = lastx;
        travel->p1[1] = lasty;
        travel->p1[2] = lastz;
        travel->p2[0] = xp;
        travel->p2[1] = yp;
        travel->p2[2] = zp;
        [travelMoves addObject:travel];
        [travel release];
    }
    int segpos = analyzer->activeExtruder->extruderId;
    if(segpos<0 || segpos>=MAX_EXTRUDER) segpos = 0;
    RHLinkedList *seg = [segments objectAtIndex:segpos];
    if (seg->count == 0 || laste >= ana->activeExtruder->e) // start new segment
    {
        if (!isLastPos) // no move, no action
        {
            GCodePath *p = [GCodePath new];
            [p add:mypos extruder:ana->activeExtruder->emax distance:totalDist fline:[GCodePoint toFile:fileid line:actLine]];
            if (seg->count > 0 && ((RHLinkedList*)((GCodePath*)(seg.peekLast))->pointsLists.peekLastFast)->count == 1)
            {
                [seg removeLast];
            }
            [seg addLast:p];
            [p release];
            changed = YES;
        }
    }
    else
    {
        if (!isLastPos)
        {
            totalDist += locDist;
            [seg.peekLastFast add:mypos extruder:ana->activeExtruder->emax distance:totalDist fline:[GCodePoint toFile:fileid line:actLine]];
            changed = YES;
        }
    }
    lastx = xp;
    lasty = yp;
    lastz = zp;
    laste = analyzer->activeExtruder->emax;
    [changeLock unlock];
}
/// Optimized version for editor preview
-(void) positionChangedFastX:(float)xp y:(float)yp z:(float)zp e:(float)e {
    if (!ana->drawing || ana->layer<minLayer || ana->layer>maxLayer)
    {
        lastx = xp;
        lasty = yp;
        lastz = zp;
        laste = ana->activeExtruder->emax;
        lastLayer = ana->layer;
        return;
    }
    float locDist = (float)sqrt((xp - lastx) * (xp - lastx) + (yp - lasty) * (yp - lasty) + (zp - lastz) * (zp - lastz));
    BOOL isLastPos = locDist < 0.00001;
    float mypos[3] = {xp,yp,zp};
    int segpos = ana->activeExtruder->extruderId;
    if(segpos<0 || segpos>=MAX_EXTRUDER) segpos = 0;
    RHLinkedList *seg = [segments objectAtIndex:segpos];
    if(lastLayer == minLayer-1 && laste<e && lastx<1e19) {
        GCodePath *p = [GCodePath new];
        float mypos2[3] = {lastx,lasty,lastz};
        [p add:mypos2 extruder:laste distance:totalDist fline:[GCodePoint toFile:fileid line:actLine]];
        if (seg->count > 0 && ((RHLinkedList*)((GCodePath*)(seg.peekLastFast))->pointsLists.peekLastFast)->count == 1)
        {
            [seg removeLast];
        }
        [seg addLast:p];
        [p release];
        
    }
    if(ana->eChanged == NO) {
        GCodeTravel *travel = [GCodeTravel new];
        travel->fline = [GCodeTravel toFile:fileid line:actLine];
        travel->p1[0] = lastx;
        travel->p1[1] = lasty;
        travel->p1[2] = lastz;
        travel->p2[0] = xp;
        travel->p2[1] = yp;
        travel->p2[2] = zp;
        [travelMoves addObject:travel];
        [travel release];
    }
    if (seg->count == 0 || laste >= e) // start new segment
    {
        if (!isLastPos) // no move, no action
        {
            GCodePath *p = [GCodePath new];
            [p add:mypos extruder:ana->activeExtruder->emax distance:totalDist fline:[GCodePoint toFile:fileid line:actLine]];
            if (seg->count > 0 && ((RHLinkedList*)((GCodePath*)(seg.peekLastFast))->pointsLists.peekLastFast)->count == 1)
            {
                [seg removeLast];
            }
            [seg addLast:p];
            [p release];
            //changed = YES;
        }
    }
    else
    {
        if (!isLastPos)
        {
            totalDist += locDist;
            [seg.peekLastFast add:mypos extruder:ana->activeExtruder->emax distance:totalDist fline:[GCodePoint toFile:fileid line:actLine]];
            //changed = YES;
        }
    }
    lastx = xp;
    lasty = yp;
    lastz = zp;
    laste = ana->activeExtruder->emax;
    lastLayer = ana->layer;
}

-(void)parseText:(NSString*)text clear:(BOOL)clear
{
    //double start = CFAbsoluteTimeGetCurrent();
    if (clear)
        [self clear];
    /* Old algortithm
    NSArray *la = [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    for (NSString *s in la)
    {
        if(s.length==0) continue;
        GCode *gc = [[GCode alloc] initFromString:s];
        [self addGCode:gc];
        [gc release];
    }
     */
    NSRange res;
    NSCharacterSet *cset = [NSCharacterSet newlineCharacterSet];
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    int lastpos = 0;
    NSUInteger len = text.length;
    int cnt=0;
    while(lastpos<len) {
        res = [text rangeOfCharacterFromSet:cset options:NSLiteralSearch range:NSMakeRange(lastpos, len-lastpos)];
        if(res.location == NSNotFound) break;
        NSString *code = [text substringWithRange:NSMakeRange(lastpos,res.location-lastpos)];
        lastpos = (int)(res.location+res.length);
        if(code.length>0) {
            GCode *gc = [[GCode alloc] initFromString:code];
            [self addGCode:gc];
            [gc release];
        }
        if(cnt++>10000) {
            cnt = 0;
            [pool release];
            pool = [[NSAutoreleasePool alloc] init];
        }            
    }
    if(lastpos<len) {
        GCode *gc = [[GCode alloc] initFromString:[text substringFromIndex:lastpos]];
        [self addGCode:gc];
        [gc release];        
    }
    [pool release];
    //double parse = 1000*(CFAbsoluteTimeGetCurrent()-start);
    //NSLog(@"Parsing %f",parse);
}
-(void)parseTextArray:(NSArray*)text clear:(BOOL)clear 
{
    //double start = CFAbsoluteTimeGetCurrent();
    if (clear)
        [self clear];
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    int cnt=0;
    for(NSString *code in text) {
        if(code.length>0) {
            GCode *gc = [[GCode alloc] initFromString:code];
            [self addGCode:gc];
            [gc release];
        }
        if(cnt++>10000) {
            cnt = 0;
            [pool release];
            pool = [[NSAutoreleasePool alloc] init];
        }            
    }
    [pool release];
    //double parse = 1000*(CFAbsoluteTimeGetCurrent()-start);
    //NSLog(@"Parsing %f",parse);
}
-(void)parseGCodeShortArray:(NSArray*)codes clear:(BOOL)clear fileid:(int)fid {
    //double start = CFAbsoluteTimeGetCurrent();
    if (clear)
        [self clear];
    fileid = fid;
    actLine = 0;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    int cnt=0;
    for(GCodeShort *code in codes) {
        [ana analyzeShort:code];
        laste = ana->activeExtruder->emax;
        actLine++;
        if(cnt++>100000) {
            cnt = 0;
            [pool release];
            pool = [[NSAutoreleasePool alloc] init];
        }            
    }
    [pool release];
    //double parse = 1000*(CFAbsoluteTimeGetCurrent()-start);
    //NSLog(@"Parsing %f",parse);
    
}

-(void)normalize:(float*)n
{
    float d = (float)sqrt(n[0] * n[0] + n[1] * n[1] + n[2] * n[2]);
    n[0] /= d;
    n[1] /= d;
    n[2] /= d;
}
-(void)setColor:(float)dist
{
    if (!liveView || dist < minHotDist)
        glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT_AND_DIFFUSE, defaultColor);
    else
    {
        float fak = (totalDist - dist) / hotFilamentLength; // 1 = default 0 = hot
        float fak2 = 1 - fak;
        curColor[0] = defaultColor[0] * fak + hotColor[0] * fak2;
        curColor[1] = defaultColor[1] * fak + hotColor[1] * fak2;
        curColor[2] = defaultColor[2] * fak + hotColor[2] * fak2;
        glMaterialfv(GL_FRONT_AND_BACK,GL_AMBIENT_AND_DIFFUSE, curColor);
    }
}
-(void)computeColor:(float) dist
{
    if (!liveView || dist < minHotDist)
    {
        curColor[0] = defaultColor[0];
        curColor[1] = defaultColor[1];
        curColor[2] = defaultColor[2];
    }
    else
    {
        float fak = (totalDist - dist) / hotFilamentLength; // 1 = default 0 = hot
        float fak2 = 1 - fak;
        curColor[0] = defaultColor[0] * fak + hotColor[0] * fak2;
        curColor[1] = defaultColor[1] * fak + hotColor[1] * fak2;
        curColor[2] = defaultColor[2] * fak + hotColor[2] * fak2;
    }
}
-(void)clearGraphicContext {
    for(int i=0;i<MAX_EXTRUDER;i++) {
        for (GCodePath *path in [segments objectAtIndex:i])
        {
            [path clearVBO];
        }
    }
    if(hasTravelBuf) {
        glDeleteBuffers(2, travelBuf);
        hasTravelBuf = NO;
    }
}
-(void)drawSegment:(GCodePath*)path
{
    [path->pointsLock lock];
    if (conf3d->drawMethod==2)
    {
        glMaterialfv(GL_FRONT_AND_BACK,GL_AMBIENT_AND_DIFFUSE, defaultColor);
        glEnableClientState(GL_VERTEX_ARRAY);        
        if (path->drawMethod != method || recompute)
        {
            [path updateVBO:true];
        }
        else if (path->hasBuf == false && path->elements != nil)
            [path refillVBO];
        if (path->elements == nil) {
            [path->pointsLock unlock];
            return;   
        }
        glBindBuffer(GL_ARRAY_BUFFER, path->buf[0]);
        glVertexPointer(3, GL_FLOAT, 0, 0);
        float *cp;
        if (liveView && path.lastDist > minHotDist)
        {
            glEnableClientState(GL_COLOR_ARRAY);
            int cplength;
            cp = malloc(cplength=sizeof(float)*path->positionsLength);
            int nv = 8 * (method - 1);
            if (method == 1) nv = 4;
            if(correctNormals) nv*=2;
            if (method == 0) nv = 1;
            int p = 0;
            for (RHLinkedList *points in path->pointsLists)
            {
                for(GCodePoint *pt in points)
                {
                    [self computeColor:pt->dist];
                    for (int j = 0; j < nv; j++)
                    {
                        cp[p++] = curColor[0];
                        cp[p++] = curColor[1];
                        cp[p++] = curColor[2];
                    }
                }
            }
            glEnable(GL_COLOR_MATERIAL);
            glColorMaterial(GL_FRONT_AND_BACK,GL_AMBIENT_AND_DIFFUSE);
            if (colbufSize <cplength)
            {
                if (colbufSize != 0)
                    glDeleteBuffers(1,&colbuf);
                glGenBuffers(1, &colbuf);
                colbufSize = cplength;
                glBindBuffer(GL_ARRAY_BUFFER, colbuf);
                glBufferData(GL_ARRAY_BUFFER, (cplength*2), 0, GL_STATIC_DRAW);
            }
            glBindBuffer(GL_ARRAY_BUFFER, colbuf);
            glBufferSubData(GL_ARRAY_BUFFER,0,(cplength), cp);
            glColorPointer(3, GL_FLOAT, 0, 0);
            free(cp);
        }
        if (method == 0)
        {
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, path->buf[2]);
            glDrawElements(GL_LINES, path->elementsLength, GL_UNSIGNED_INT, 0);
        }
        else
        {
            glEnableClientState(GL_NORMAL_ARRAY);
            glBindBuffer(GL_ARRAY_BUFFER, path->buf[1]);
            glNormalPointer(GL_FLOAT, 0, 0);
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, path->buf[2]);
            glDrawElements(GL_QUADS, path->elementsLength, GL_UNSIGNED_INT, 0);
            glDisableClientState(GL_NORMAL_ARRAY);
        }
        if (liveView && path.lastDist > minHotDist)
        {
            glDisable(GL_COLOR_MATERIAL);
            glDisableClientState(GL_COLOR_ARRAY);
        }
        glDisableClientState(GL_VERTEX_ARRAY);
        glBindBuffer(GL_ARRAY_BUFFER, 0);
    }
    else
    {
        if (path->drawMethod != method || recompute || path->hasBuf)
            [path updateVBO:NO];
        if (conf3d->drawMethod > 0) // Is also fallback for vbos with dynamic colors
        {
            glEnableClientState(GL_VERTEX_ARRAY);
            if (path->elements == nil) {    
                [path->pointsLock unlock];
                return;
            }
            glVertexPointer(3, GL_FLOAT, 0, path->positions);
            float *cp=nil;
            if (liveView && path.lastDist > minHotDist)
            {
                glEnableClientState(GL_COLOR_ARRAY);
                cp = malloc(sizeof(float)*path->positionsLength);
                int nv = 8 * (method - 1);
                if (method == 1) nv = 4;
                if(correctNormals) nv*=2;
                if (method == 0) nv = 1;
                int p = 0;
                for (RHLinkedList *points in path->pointsLists)
                {
                    for(GCodePoint *pt in points)
                    {
                        [self computeColor:pt->dist];
                        for (int j = 0; j < nv; j++)
                        {
                            cp[p++] = curColor[0];
                            cp[p++] = curColor[1];
                            cp[p++] = curColor[2];
                        }
                    }
                }
                glEnable(GL_COLOR_MATERIAL);
                glColorMaterial(GL_FRONT_AND_BACK,GL_AMBIENT_AND_DIFFUSE);
                glColorPointer(3, GL_FLOAT, 0, cp);                
            }
            if (method == 0)
                glDrawElements(GL_LINES, path->elementsLength,GL_UNSIGNED_INT, path->elements);
            else
            {
                glEnableClientState(GL_NORMAL_ARRAY);
                glNormalPointer(GL_FLOAT, 0, path->normals);
                glDrawElements(GL_QUADS, path->elementsLength, GL_UNSIGNED_INT, path->elements);
                glDisableClientState(GL_NORMAL_ARRAY);
            }
            if (liveView && path.lastDist > minHotDist)
            {
                glDisable(GL_COLOR_MATERIAL);
                glDisableClientState(GL_COLOR_ARRAY);
            }
            if(cp!=nil)
                free(cp);
            glDisableClientState(GL_VERTEX_ARRAY);
        }
        else
        {
            if (!liveView || path.lastDist < minHotDist)
            {
                int i, l = path->elementsLength;
                if (method == 0)
                {
                    glBegin(GL_LINES);
                    for (i = 0; i < l; i++)
                    {
                        int p = path->elements[i] * 3;
                        glVertex3fv(&path->positions[p]);
                    }
                    glEnd();
                }
                else
                {
                    glBegin(GL_QUADS);
                    for (i = 0; i < l; i++)
                    {
                        int p = path->elements[i]*3;
                        glNormal3fv(&path->normals[p]);
                        glVertex3fv(&path->positions[p]);
                    }
                    glEnd();
                }
            }
            else
            {
                if (method > 0)
                {
                    int nv = 8 * (method - 1), i;
                    if (method == 1) nv = 4;
                    float alpha, dalpha = (float)M_PI * 2.0 / nv;
                    float dir[3];
                    float dirs[3];
                    float diru[3];
                    float n[3];
                    float dh = 0.5f * h;
                    float dw = 0.5f * w;
                    if (path->pointsCount < 2) {       
                        [path->pointsLock unlock];
                        return;
                    }
                    glBegin(GL_QUADS);
                    BOOL first = YES;
                    float *last;
                    for (RHLinkedList *points in path->pointsLists)
                    {
                        first = YES;
                        for(GCodePoint *pt in points)
                        {
                            float *v = pt->p;
                            [self setColor:pt->dist];
                            if (first)
                            {
                                last = v;
                                first = NO;
                                continue;
                            }
                           // BOOL isLast = pt == points.peekLast;
                            dir[0] = v[0] - last[0];
                            dir[1] = v[1] - last[1];
                            dir[2] = v[2] - last[2];
                            if (!fixedH)
                            {
                                float dist = (float)sqrt(dir[0] * dir[0] + dir[1] * dir[1] + dir[2] * dir[2]);
                                if (dist > 0)
                                {
                                    h = (float)sqrt((pt->e - laste) * dfac / dist);
                                    w = h * wfac;
                                    dh = 0.5f * h;
                                    dw = 0.5f * w;
                                }
                            }
                            [self normalize:dir];
                            dirs[0] = -dir[1];
                            dirs[1] = dir[0];
                            dirs[2] = dir[2];
                            diru[0] = diru[1] = 0;
                            diru[2] = 1;
                            alpha = 0;
                            float c = (float)cos(alpha) * dh;
                            float s = (float)sin(alpha) * dw;
                            n[0] = (float)(s * dirs[0] + c * diru[0]);
                            n[1] = (float)(s * dirs[1] + c * diru[1]);
                            n[2] = (float)(s * dirs[2] + c * diru[2]);
                            [self normalize:n];
                            glNormal3fv(n);
                            for (i = 0; i < nv; i++)
                            {
                                glVertex3f(last[0] + s * dirs[0] + c * diru[0], last[1] + s * dirs[1] + c * diru[1], last[2] - dh + s * dirs[2] + c * diru[2]);
                                glVertex3f(v[0] + s * dirs[0] + c * diru[0], v[1] + s * dirs[1] + c * diru[1], v[2] - dh + s * dirs[2] + c * diru[2]);
                                alpha += dalpha;
                                c = (float)cos(alpha) * dh;
                                s = (float)sin(alpha) * dw;
                                n[0] = (float)(s * dirs[0] + c * diru[0]);
                                n[1] = (float)(s * dirs[1] + c * diru[1]);
                                n[2] = (float)(s * dirs[2] + c * diru[2]);
                                [self normalize:n];
                                glNormal3fv(n);
                                glVertex3f(v[0] + s * dirs[0] + c * diru[0], v[1] + s * dirs[1] + c * diru[1], v[2] - dh + s * dirs[2] + c * diru[2]);
                                glVertex3f(last[0] + s * dirs[0] + c * diru[0], last[1] + s * dirs[1] + c * diru[1], last[2] - dh + s * dirs[2] + c * diru[2]);
                            }
                            last = v;
                        }
                    }
                    glEnd();
                }
                else if (method == 0)
                {
                    // Draw edges
                    if (path->pointsCount < 2) {    
                        [path->pointsLock unlock];
                        return;
                    }
                    glMaterialfv(GL_FRONT,GL_EMISSION, defaultColor);
                    glBegin(GL_LINES);
                    BOOL first = YES;
                    for(RHLinkedList *points in path->pointsLists)
                    {
                        first = YES;
                        for(GCodePoint *pt in points)
                        {
                            float *v = pt->p;
                            if (liveView && pt->dist >= minHotDist)
                            {
                                float fak = (totalDist - pt->dist) / hotFilamentLength; // 1 = default 0 = hot
                                float fak2 = 1 - fak;
                                curColor[0] = defaultColor[0] * fak + hotColor[0] * fak2;
                                curColor[1] = defaultColor[1] * fak + hotColor[1] * fak2;
                                curColor[2] = defaultColor[2] * fak + hotColor[2] * fak2;
                                glMaterialfv(GL_FRONT_AND_BACK,GL_EMISSION, curColor);
                            }
                                    
                            glVertex3fv(v);
                            if (!first && pt != points.peekLast)
                                glVertex3fv(v);
                            first = NO;
                        }
                    }
                    glEnd();
                }
            }
        }
    }
    [path->pointsLock unlock];
}

-(void)drawSegment:(GCodePath*)path start:(int)mstart end:(int)mend
{
    [path->pointsLock lock];
    // Check if inside mark area
    int estart = 0;
    int eend = path->elementsLength;
    //GCodePoint *lastP = nil;
    GCodePoint *startP = nil, *endP = nil;
    for (RHLinkedList *plist in path->pointsLists)
    {
        if (plist->count > 1)
            for (GCodePoint *point in plist)
        {
            if (startP == nil)
            {
                if (point->fline >= mstart && point->fline <= mend)
                    startP = point;
            }
            else
            {
                if (point->fline > mend)
                {
                    endP = point;
                    break;
                }
            }
            //lastP = point;
        }
        if (endP != nil) break;
    }
    if (startP == nil) {
        [path->pointsLock unlock];
        return;
    }
    estart = startP->element;
    if (endP != nil) eend = endP->element;
    if (estart == eend)  {
        [path->pointsLock unlock];
        return;
    }
    if (conf3d->drawMethod==2)
    {
        glMaterialfv(GL_FRONT_AND_BACK,GL_AMBIENT_AND_DIFFUSE, defaultColor);
        glEnableClientState(GL_VERTEX_ARRAY);
        if (path->drawMethod != method || recompute)
        {
            [path updateVBO:true];
        }
        else if (path->hasBuf == false && path->elements != nil)
            [path refillVBO];
        if (path->elements == nil) {
            [path->pointsLock unlock];
            return;
        }
        glBindBuffer(GL_ARRAY_BUFFER, path->buf[0]);
        glVertexPointer(3, GL_FLOAT, 0, 0);

        if (method == 0)
        {
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, path->buf[2]);
            glDrawElements(GL_LINES, eend-estart, GL_UNSIGNED_INT, (void *)(sizeof(int)*estart));
        }
        else
        {
            glEnableClientState(GL_NORMAL_ARRAY);
            glBindBuffer(GL_ARRAY_BUFFER, path->buf[1]);
            glNormalPointer(GL_FLOAT, 0, 0);
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, path->buf[2]);
            glDrawElements(GL_QUADS, eend-estart, GL_UNSIGNED_INT, (void *)(sizeof(int)*estart));
            glDisableClientState(GL_NORMAL_ARRAY);
        }
        glDisableClientState(GL_VERTEX_ARRAY);
        glBindBuffer(GL_ARRAY_BUFFER, 0);
    }
    else
    {
        if (path->drawMethod != method || recompute || path->hasBuf)
            [path updateVBO:NO];
        if (conf3d->drawMethod > 0) // Is also fallback for vbos with dynamic colors
        {
            glEnableClientState(GL_VERTEX_ARRAY);
            if (path->elements == nil) {
                [path->pointsLock unlock];
                return;
            }
            glVertexPointer(3, GL_FLOAT, 0, path->positions);
            if (method == 0)
                glDrawElements(GL_LINES, eend-estart,GL_UNSIGNED_INT, &(path->elements[estart]));
            else
            {
                glEnableClientState(GL_NORMAL_ARRAY);
                glNormalPointer(GL_FLOAT, 0, path->normals);
                glDrawElements(GL_QUADS, eend-estart, GL_UNSIGNED_INT, &(path->elements[estart]));
                glDisableClientState(GL_NORMAL_ARRAY);
            }
            glDisableClientState(GL_VERTEX_ARRAY);
        }
        else
        {
                int i;
                if (method == 0)
                {
                    glBegin(GL_LINES);
                    for (i = estart; i < eend; i++)
                    {
                        int p = path->elements[i] * 3;
                        glVertex3fv(&path->positions[p]);
                    }
                    glEnd();
                }
                else
                {
                    glBegin(GL_QUADS);
                    for (i = estart; i < eend; i++)
                    {
                        int p = path->elements[i]*3;
                        glNormal3fv(&path->normals[p]);
                        glVertex3fv(&path->positions[p]);
                    }
                    glEnd();
                }
        }
    }
    [path->pointsLock unlock];
}
/** Draw stored travel moves */
-(void)drawMoves {
    NSUInteger l = travelMoves.count;
    if(!hasTravelBuf || travelMovesBuffered+100<l) {
        // Revill vbo
        if(hasTravelBuf)
            glDeleteBuffers(2,travelBuf);
        NSUInteger len = sizeof(float)*6*l;
        float *pts = malloc(len);
        GLint *idx = malloc(sizeof(GLint)*2*l);
        GLint *idxp = idx;
        float *p = pts;
        int n=0,ic=0;
        for(GCodeTravel *t in travelMoves) {
            *idxp++ = ic++;
            *idxp++ = ic++;
            *p++ = t->p1[0];
            *p++ = t->p1[1];
            *p++ = t->p1[2];
            *p++ = t->p2[0];
            *p++ = t->p2[1];
            *p++ = t->p2[2];
            n++;
        }
        // NSLog(@"Count %d n %d",l,n);
        glGenBuffers(2, travelBuf);
        glBindBuffer(GL_ARRAY_BUFFER, travelBuf[0]);
        glBufferData(GL_ARRAY_BUFFER, len, pts, GL_STATIC_DRAW);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, travelBuf[1]);
        glBufferData(GL_ELEMENT_ARRAY_BUFFER, (l*2 * sizeof(GLuint)), idx, GL_STATIC_DRAW);
        hasTravelBuf = YES;
        travelMovesBuffered = l;
        free(pts);
        free(idx);
    }
    // Set move color
    glMaterialfv(GL_FRONT_AND_BACK,GL_AMBIENT_AND_DIFFUSE,conf3d->blackColor);
    glMaterialfv(GL_FRONT_AND_BACK,GL_EMISSION,conf3d->blackColor);
    glMaterialfv(GL_FRONT_AND_BACK, GL_SPECULAR,conf3d->blackColor);
    glMaterialfv(GL_FRONT_AND_BACK,GL_EMISSION,conf3d->travelColor);
    // Draw buffer
    glEnableClientState(GL_VERTEX_ARRAY);
    glBindBuffer(GL_ARRAY_BUFFER,travelBuf[0]);
    glVertexPointer(3, GL_FLOAT, 0, 0);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, travelBuf[1]);
    glDrawElements(GL_LINES, (GLsizei)(travelMovesBuffered*2), GL_UNSIGNED_INT, 0);
    glDisableClientState(GL_VERTEX_ARRAY);
    glBindBuffer(GL_ARRAY_BUFFER,0);
    // Draw new lines one by one
    glBegin(GL_LINES);
    for (NSUInteger i = travelMovesBuffered; i < l; i++)
    {
        GCodeTravel *t = [travelMoves objectAtIndex:i];
        glVertex3fv(t->p1);
        glVertex3fv(t->p2);
    }
    glEnd();
    glMaterialfv(GL_FRONT_AND_BACK,GL_EMISSION,conf3d->blackColor);
}
-(void)drawMovesFrom:(int)mstart to:(int)mend {
    NSUInteger l = travelMoves.count;
    // Check if inside mark area
    NSUInteger estart = 0;
    NSUInteger eend = l;
    //GCodePoint *lastP = nil;
    int startP = -1, endP = -1,p=0;
    for (GCodeTravel *t in travelMoves)
    {
                if (startP <0)
                {
                    if (t->fline >= mstart && t->fline <= mend)
                        startP = p;
                }
                else
                {
                    if (t->fline > mend)
                    {
                        endP = p;
                        break;
                    }
                }
                //lastP = point;
        if (endP >= 0) break;
        p++;
    }
    if (startP == -1) {
        return;
    }
    estart = startP;
    if (endP >=0) eend = endP;
    if (estart == eend)  {
        return;
    }

    // Set move color
    glMaterialfv(GL_FRONT_AND_BACK,GL_AMBIENT_AND_DIFFUSE,conf3d->blackColor);
    glMaterialfv(GL_FRONT_AND_BACK,GL_EMISSION,conf3d->blackColor);
    glMaterialfv(GL_FRONT_AND_BACK, GL_SPECULAR,conf3d->blackColor);
    glMaterialfv(GL_FRONT_AND_BACK,GL_EMISSION,conf3d->selectedFilamentColor);
    // Draw buffer
    glEnableClientState(GL_VERTEX_ARRAY);
    glBindBuffer(GL_ARRAY_BUFFER,travelBuf[0]);
    glVertexPointer(3, GL_FLOAT, 0, 0);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, travelBuf[1]);
    glDrawElements(GL_LINES, (GLsizei)(2*(eend-estart)), GL_UNSIGNED_INT, (void *)(sizeof(int)*estart*2));
    //glDrawElements(GL_LINES, travelMovesBuffered*2, GL_UNSIGNED_INT, 0);
    glDisableClientState(GL_VERTEX_ARRAY);
    glBindBuffer(GL_ARRAY_BUFFER,0);
    glMaterialfv(GL_FRONT_AND_BACK,GL_EMISSION,conf3d->blackColor);
}
-(void)paint
{
    changed = NO;
    if (conf3d->drawMethod != 2 && colbufSize > 0)
    {
        glDeleteBuffers(1, &colbuf);
        colbufSize = 0;
    }
    if (conf3d->disableFilamentVisualization) return; // Disabled too much for card
    hotFilamentLength = conf3d->hotFilamentLength;
    minHotDist = totalDist - hotFilamentLength;

    NSMutableArray *sla = [NSMutableArray arrayWithCapacity:MAX_EXTRUDER];
    RHLinkedList *sl = nil;
    [changeLock lock];
    [self reduce]; // Minimize number of VBO
    for(int i=0;i<MAX_EXTRUDER;i++) {
        sl = [[RHLinkedList new] autorelease];
        for (GCodePath *path in [segments objectAtIndex:i])
        {
            //[path->pointsLock lock];
            [sl addLast:path];
        }
        [sla addObject:sl];
    }
    //[changeLock unlock];
    //long timeStart = DateTime.Now.Ticks;
    float *col;
    col = conf3d->filamentColor;
    defaultColor[0] = (float)col[0];
    defaultColor[1] = (float)col[1];
    defaultColor[2] = (float)col[2];
    defaultColor[3] = col[3];
    col = conf3d->hotFilamentColor;
    hotColor[0] = (float)col[0];
    hotColor[1] = (float)col[1];
    hotColor[2] = (float)col[2];
    hotColor[3] = curColor[3] = col[3];
    glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT_AND_DIFFUSE, defaultColor);
    glMaterialfv(GL_FRONT_AND_BACK,GL_EMISSION, conf3d->blackColor);
    glMaterialfv(GL_FRONT_AND_BACK, GL_SPECULAR, conf3d->specularColor);
    glMaterialf(GL_FRONT_AND_BACK, GL_SHININESS, 50);
    method = conf3d->filamentVisualization;
    wfac = conf3d->widthOverHeight;
    h = conf3d->layerHeight;
    w = h * wfac;
    fixedH = conf3d->useLayerHeight;
    dfac = (float)(M_PI * conf3d->filamentDiameter * conf3d->filamentDiameter * 0.25 / wfac);
    recompute = lastFilHeight != h || lastFilWidth != w || fixedH != lastFilUseHeight || dfac != lastFilDiameter || lastCorrectNormals!=correctNormals;
    lastFilHeight = h;
    lastFilWidth = w;
    lastFilDiameter = dfac;
    lastFilUseHeight = fixedH;
    lastCorrectNormals = correctNormals;
    //   int cnt=0;
    for(int i=0;i<MAX_EXTRUDER;i++) {
        if(i==0)
            col = conf3d->filamentColor;
        else if(i==1)
            col = conf3d->filament2Color;
        else if(i==2)
            col = conf3d->filament3Color;
        defaultColor[0] = (float)col[0];
        defaultColor[1] = (float)col[1];
        defaultColor[2] = (float)col[2];
        defaultColor[3] = col[3];
        glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT_AND_DIFFUSE, defaultColor);
        for (GCodePath *path in [sla objectAtIndex:i])
        {
            [self drawSegment:path];
        }
    }
    if(conf3d->showTravel) {
        //[changeLock lock];
        [self drawMoves];
        //[changeLock unlock];
    }
    GCodeEditorController *ed = app->gcodeView;
    int findex = ed.fileIndex;
    if(showSelection && findex<3) {
        GCodeView *cv = ed->editor;
        int selectionStart = 0,selectionEnd = 0;
        if (!cv.hasSelection)
        {
            selectionStart = selectionEnd = (int)([GCodePoint toFile:findex line:(int)cv->row]);
        }
        else
        {
            if (cv->row < cv->selRow)
            {
                selectionStart = (int)([GCodePoint toFile:findex line:(int)cv->row]);
                selectionEnd = (int)([GCodePoint toFile:findex line:(int)cv->selRow]);
            }
            else
            {
                selectionEnd = (int)([GCodePoint toFile:findex line:(int)cv->row]);
                selectionStart = (int)([GCodePoint toFile:findex line:(int)cv->selRow]);
            }
        }
        glDepthFunc(GL_LEQUAL);
        if(conf3d->showTravel) {
            //[changeLock lock];
            [self drawMovesFrom:selectionStart to:selectionEnd];
            //[changeLock unlock];
        }
        col = conf3d->selectedFilamentColor;
        defaultColor[0] = (float)col[0];
        defaultColor[1] = (float)col[1];
        defaultColor[2] = (float)col[2];
        defaultColor[3] = col[3];
        glMaterialfv(GL_FRONT_AND_BACK, GL_AMBIENT_AND_DIFFUSE, defaultColor);
        for(int i=0;i<MAX_EXTRUDER;i++) {
            for (GCodePath *path in [sla objectAtIndex:i])
            {
                [self drawSegment:path start:selectionStart end:selectionEnd];
            }
        }
    }
    [sla removeAllObjects];
    [changeLock unlock];

    // timeStart = DateTime.Now.Ticks - timeStart;
    //  double time = (double)timeStart * 0.1;
    // Main.conn.log("OpenGL paint time " + time.ToString("0.0", GCode.format) + " microseconds",false,4);
}
-(BOOL)changed
{
    return changed;
}

@end
