//
//  RectPacker.m
//  RepetierHost
//
//  Created by Roland Littwin on 12.03.12.
//  Copyright (c) 2012 Repetier. All rights reserved.
//

#import "RectPacker.h"

@implementation PackerPos

+(PackerPos*)posWithX:(int)_x y:(int)_y {
    PackerPos *pos = [PackerPos new];
    pos->x = _x;
    pos->y = _y;
    return [pos autorelease];
}
-(BOOL)isEqual:(PackerPos*)object {
    return x==object->x && y==object->y;
}
@end

@implementation PackerRect

-(void)dealloc {
    [super dealloc];
}
+(PackerRect*)rectWithX:(int)_x y:(int)_y w:(int)_w h:(int)_h object:(id)obj {
    PackerRect *p = [PackerRect new];
    p->x = _x;
    p->y = _y;
    p->w = _w;
    p->h = _h;
    p->object = obj;
    return [p autorelease];
}
-(BOOL)containsPoint:(PackerPos*)p { 
    return (p->x >= x && p->y >= y &&
            p->x < (x+w) && p->y < (y+h)); 
}
-(BOOL)containsRect:(PackerRect*)r { 
    return (r->x >= x && r->y >= y &&
        (r->x+r->w) <= (x+w) && (r->y+r->h) <= (y+h)); 
}
-(BOOL)intersects:(PackerRect*)r { 
    return w > 0 && h > 0 && r->w > 0 && r->h > 0 &&
    ((r->x+r->w) > x && r->x < (x+w) &&
     (r->y+r->h) > y && r->y < (y+h)); 
}

//  Greater rect area. Not as good as the next heuristic
//  static bool Greater(const TRect &a, const TRect &b) { return a.w*a.h > b.w*b.h; }

// Greater size in at least one dim.
+(BOOL)greater:(PackerRect*)a b:(PackerRect*)b {
    return (a->w > b->w && a->w > b->h) ||
    (a->h > b->w && a->h > b->h); 
}
@end

@implementation RectPacker
// ----------------------------------------------------------------------------------------
// Name        : RectPlacement.cpp
// Description : A class that fits subrectangles into a power-of-2 rectangle
//               (C) Copyright 2000-2002 by Javier Arevalo
//               This code is free to use and modify for all purposes
// ----------------------------------------------------------------------------------------

/*
 You have a bunch of rectangular pieces. You need to arrange them in a 
 rectangular surface so that they don't overlap, keeping the total area of the 
 rectangle as small as possible. This is fairly common when arranging characters 
 in a bitmapped font, lightmaps for a 3D engine, and I guess other situations as 
 well.
 
 The idea of this algorithm is that, as we add rectangles, we can pre-select 
 "interesting" places where we can try to add the next rectangles. For optimal 
 results, the rectangles should be added in order. I initially tried using area 
 as a sorting criteria, but it didn't work well with very tall or very flat 
 rectangles. I then tried using the longest dimension as a selector, and it 
 worked much better. So much for intuition...
 
 These "interesting" places are just to the right and just below the currently 
 added rectangle. The first rectangle, obviously, goes at the top left, the next 
 one would go either to the right or below this one, and so on. It is a weird way 
 to do it, but it seems to work very nicely.
 
 The way we search here is fairly brute-force, the fact being that for most off-
 line purposes the performance seems more than adequate. I have generated a 
 japanese font with around 8500 characters and all the time was spent generating 
 the bitmaps.
 
 Also, for all we care, we could grow the parent rectangle in a different way 
 than power of two. It just happens that power of 2 is very convenient for 
 graphics hardware textures.
 
 I'd be interested in hearing of other approaches to this problem. Make sure
 to post them on http://www.flipcode.com
 */


-(id)initWidth:(int)w height:(int)h
{
    if((self=[super init])) {
        size = [[PackerRect rectWithX:0 y:0 w:w h:h object:nil] retain];
        vRects = [[NSMutableArray arrayWithCapacity:16] retain];
        vPositions = [[NSMutableArray arrayWithCapacity:16] retain];
        [vPositions addObject:[PackerPos posWithX:0 y:0]];
        area = 0;
    }
    return self;
}
-(void)dealloc {
    [size release];
    [vRects release];
    [vPositions release];
    [super dealloc];
}
-(void)end
{
    [vPositions removeAllObjects];
    [vRects removeAllObjects];
    size->w = 0;
}

-(BOOL)isOK {
    return size->w>0;
}
-(int)w {return size->w;}
-(int)h {return size->h;}
-(long)totalArea {
    return size->w*size->h;
}

// --------------------------------------------------------------------------------
// Name        : IsFree
// Description : Check if the given rectangle is partially or totally used
// --------------------------------------------------------------------------------
-(BOOL) isFree:(PackerRect*)r
{
    if (![size containsRect:r])
        return NO;
    for (PackerRect *it in vRects)
        if ([it intersects:r])
            return NO;
    return YES;
}


// --------------------------------------------------------------------------------
// Name        : AddPosition
// Description : Add new anchor point
// --------------------------------------------------------------------------------
-(void)addPosition:(PackerPos*)p
{
    // Try to insert anchor as close as possible to the top left corner
    // So it will be tried first
    BOOL bFound = NO;
    int pos=0;
    for (PackerPos *it in vPositions)
    {
        if (p->x+p->y < it->x+it->y) {
            bFound = YES;
            break;
        }
        pos++;
    }
    if (bFound)
        [vPositions insertObject:p atIndex:pos];
    else
        [vPositions addObject:p];
}

// --------------------------------------------------------------------------------
// Name        : AddRect
// Description : Add the given rect and updates anchor points
// --------------------------------------------------------------------------------
-(void)addRect:(PackerRect*)r
{
    [vRects addObject:r];
    area += r->w*r->h;
    
    // Add two new anchor points
    [self addPosition:[PackerPos posWithX:r->x y:r->y+r->h]];
    [self addPosition:[PackerPos posWithX:r->x+r->w y:r->y]];
}

// --------------------------------------------------------------------------------
// Name        : AddAtEmptySpot
// Description : Add the given rectangle
// --------------------------------------------------------------------------------
-(BOOL)addAtEmptySpot:(PackerRect*)r
{
    // Find a valid spot among available anchors.
    
    BOOL bFound = NO;
    int pos = 0;
    for(PackerPos *it in vPositions) {
        PackerRect *rect = [PackerRect rectWithX:it->x y:it->y w:r->w h:r->h object:r->object];
        
        if ([self isFree:rect])
        {
            r = rect;
            bFound = YES;
            break; // Don't let the loop increase the iterator.
        }
        pos++;
    }
    if (bFound)
    {
        // Remove the used anchor point
        [vPositions removeObjectAtIndex:pos];
        
        // Sometimes, anchors end up displaced from the optimal position
        // due to irregular sizes of the subrects.
        // So, try to adjut it up & left as much as possible.
        int x,y;
        for (x = 1; x <= r->x; x++)
            if (![self isFree:[PackerRect rectWithX:r->x-x y:r->y w:r->w h:r->h object:r->object]])
                break;
        for (y = 1; y <= r->y; y++)
            if (![self isFree:[PackerRect rectWithX:r->x y:r->y-y w:r->w h:r->h object:r->object]])
                break;
        if (y > x)
            r->y -= y-1;
        else            
            r->x -= x-1;
        [self addRect:r];
    }
    return bFound;
}


// --------------------------------------------------------------------------------
// Name        : AddAtEmptySpotAutoGrow
// Description : Add a rectangle of the given size, growing our area if needed
//               Area grows only until the max given.
//               Returns the placement of the rect in the rect's x,y coords
// --------------------------------------------------------------------------------

-(BOOL)addAtEmptySpotAutoGrow:(PackerRect*)pRect maxWidth:(int)maxW maxHeight:(int)maxH
{
    if (pRect->w <= 0)
        return YES;
    
    int orgW = size->w;
    int orgH = size->h;
    
    // Try to add it in the existing space
    while (![self addAtEmptySpot:pRect])
    {
        int pw = size->w;
        int ph = size->h;
        
        // Sanity check - if area is complete.
        if (pw >= maxW && ph >= maxH)
        {
            size->w = orgW;
            size->h = orgH;
            return NO;
        }
        
        // Try growing the smallest dim
        if (pw < maxW && (pw < ph || ((pw == ph) && (pRect->w >= pRect->h))))
            size->w = MIN(maxW,pw+10); //*2;
        else
            size->h = MIN(maxH,ph+10); //*2;
        if ([self addAtEmptySpot:pRect])
            break;
        
        // Try growing the other dim instead
        if (pw != size->w)
        {
            size->w = pw;
            if (ph < maxW)
                size->h = MIN(maxH,ph+10); //*2;
        }
        else
        {
            size->h = ph;
            if (pw < maxW)
                size->w = MIN(maxW,pw+10); //*2;
        }
        
        if (pw != size->w || ph != size->h)
            if ([self addAtEmptySpot:pRect])
                break;
        
        // Grow both if possible, and reloop.
        size->w = pw;
        size->h = ph;
        if (pw < maxW)
            size->w = MIN(maxW,pw+10); //*2;
        if (ph < maxH)
            size->h = MIN(maxH,ph+10); //*2;
    }
    return YES;
}
@end
