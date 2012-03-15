//
//  RectPacker.h
//  RepetierHost
//
//  Created by Roland Littwin on 12.03.12.
//  Copyright (c) 2012 Repetier. All rights reserved.
//

#import <Foundation/Foundation.h>

// Helper classes
@interface PackerPos : NSObject {
@public
    int x, y;
}
+(PackerPos*)posWithX:(int)_x y:(int)_y;
-(BOOL)isEqual:(PackerPos*)object;
@end

@interface PackerRect : PackerPos
{
    @public
    int w, h;
    id object;
}    
+(PackerRect*)rectWithX:(int)_x y:(int)_y w:(int)_w h:(int)_h object:(id)obj;   
+(BOOL)greater:(PackerRect*)a b:(PackerRect*)b;
-(BOOL)containsPoint:(PackerPos*)p;
-(BOOL)containsRect:(PackerRect*)r;
-(BOOL)intersects:(PackerRect*)r;
@end

@interface RectPacker : NSObject {
    @public
    PackerRect       *size;
    NSMutableArray  *vRects;
    NSMutableArray  *vPositions;
    long        area;    
}

-(id)initWidth:(int)w height:(int)h;
-(void)end;
-(int)w;
-(int)h;
-(BOOL) isFree:(PackerRect*)r;
-(void)addPosition:(PackerPos*)p;
-(void)addRect:(PackerRect*)r;
-(BOOL)addAtEmptySpot:(PackerRect*)r;
-(BOOL)addAtEmptySpotAutoGrow:(PackerRect*)pRect maxWidth:(int)maxW maxHeight:(int)maxH;
@end
