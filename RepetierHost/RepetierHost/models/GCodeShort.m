//
//  GCodeShort.m
//  RepetierHost
//
//  Created by Roland Littwin on 02.03.12.
//  Copyright (c) 2012 Repetier. All rights reserved.
//

#import "GCodeShort.h"
#import "PrinterConnection.h"

@implementation GCodeShort

-(id)initWithCommand:(NSString*)cmd {
    if((self=[super init])) {
        text = [cmd retain];
        flags = 1048575+(0<<24);
        x=y=z=e=f=-99999;
        emax=-1;
        self.variables = [connection containsVariables:cmd];
        [self parse];
    }
    return self;
}
+(GCodeShort*)codeWith:(NSString*)txt {
    GCodeShort *g = [[GCodeShort alloc] initWithCommand:txt];
    return [g autorelease];    
}

-(void)dealloc {
    [text release];
    [super dealloc];
}
-(int)layer {
    return flags & 1048575;
}
-(BOOL)hasLayer {
    return (flags & 1048575)!=1048575;
}
-(BOOL)hasVariables {
    return (flags & (1<<30))!=0;
}
-(void)setVariables:(BOOL)val {
    flags |= (1<<30);
    if(!val)
        flags-= (1<<30);
}
-(int)tool {
    return (flags >> 20) & 15;
}
-(void)setTool:(int)val {
    val = (val & 15);
    flags = (flags & ~((uint32_t)15<<20)) | (val << 20);
}
-(void)setLayer:(int)val {
    flags = (flags & ~1048575) | val;
}
-(void)setCompressedCommand:(int)val {
    flags = (flags & ~(63<<24)) | (val<<24);
}
-(NSUInteger)length {
    return text.length;
}
-(BOOL)hasX {return x!=-99999;}
-(BOOL)hasY {return y!=-99999;}
-(BOOL)hasZ {return z!=-99999;}
-(BOOL)hasE {return e!=-99999;}
-(BOOL)hasF {return f!=-99999;}

/**
Command values:
 0 = unimportant command
 1 = G0/G1
 2 = G2
 3 = G3
 4 = G28 xzy = 1 => Set this
 5 = G162
 6 = G90 relative
 7 = G91 absolute
 8 = G92 x/y/z/e != -99999 if set
 9 = M82 eRelative
 10 = M83 eAbsolute
 11 = Txx Set Tool
 12 = Host command
 63 = unparsed
*/
-(int)compressedCommand {
    return (flags>>24)& 63;
}
-(BOOL) addCode:(char) c value:(NSString*)val {
    double d = [val doubleValue];
    switch (c)
    {
        case 'G':
        case 'g':
            {
                int g = (int)d;
                if(g>0&&g<4) [self setCompressedCommand:g];
                else if(g>=90 && g<=92) [self setCompressedCommand:g-84];
                else if(g==0) [self setCompressedCommand:1];
                else if(g==28||g==161) [self setCompressedCommand:4];
                else if(g==162) [self setCompressedCommand:5];
                return YES;
            }
            break;
        case 'M':
        case 'm': {
            int m = (int)d;
            if(m==82) [self setCompressedCommand:9];
            if(m==83) [self setCompressedCommand:10];
            return YES;
            }
            break;
        case 'T':
        case 't':
            [self setTool:(int)d];
            [self setCompressedCommand:11];
            break;
        case 'X':
        case 'x':
            x = (float)d;
            break;
        case 'Y':
        case 'y':
            y = (float)d;
            break;
        case 'Z':
        case 'z':
            z = (float)d;
            break;
        case 'E':
        case 'e':
        case 'A':
        case 'a':
            e = (float)d;
            break;
        case 'F':
        case 'f':
            f = (float)d;
            break;
    }
    return NO;
}

-(void)parse {
    NSString *text2 = text;
    if([self hasVariables])
        text2 = [connection replaceVariables:text];
    int l = (int)[text2 length],i;
    int mode = 0; // 0 = search code, 1 = search value
    char code = ';';
    int p1=0;
    NSRange range;
    for (i = 0; i < l; i++)
    {
        char c = [text2 characterAtIndex:i];
        if(i==0 && c=='@') {
            [self setCompressedCommand:12]; // Host command
            return;
        }
        if (mode == 0 && c >= 'A' && c <= 'Z')
        {
            code = c;
            mode = 1;
            p1 = i + 1;
            continue;
        }
        else if (mode == 1)
        {
            if (c == ' ' || c=='\t' || c==';')
            {
                range.location = p1;
                range.length = i-p1;
                if([self addCode:code value:[text2 substringWithRange:range]]) {
                    if(self.compressedCommand==0) return; // Not interresting
                }
                mode = 0;
            }
        }
        if (c == ';') break;
    }
    if (mode == 1) {
        range.location = p1;
        range.length = l-p1;
        [self addCode:code value:[text2 substringWithRange:range]];
    }
}
@end
