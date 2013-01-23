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

#import "GCode.h"
#import "PrinterConnection.h"
#import "StringUtil.h"

@implementation GCode
-(id)initFromString:(NSString *)cmd {
    if((self = [super init])) {
        orig = [cmd retain];
        text = nil;
        hostCommand = NO;
        forceASCII = NO;
        [self parse];
    }
    return self;
}
-(void)dealloc {
    [orig release];
    if(text!=nil)
        [text release];
    [super dealloc];
}
-(BOOL)hasM {
    return (fields & 2)!=0;
}
-(BOOL)hasN {
    return (fields & 1)!=0;
}
-(BOOL)hasG {
    return (fields & 4)!=0;
}
-(BOOL)hasT {
    return (fields & 512)!=0;
}
-(BOOL)hasX {
    return (fields & 8)!=0;
}
-(BOOL)hasY {
    return (fields & 16)!=0;
}
-(BOOL)hasZ {
    return (fields & 32)!=0;
}
-(BOOL)hasE {
    return (fields & 64)!=0;
}
-(BOOL)hasF {
    return (fields & 256)!=0;
}
-(BOOL)hasS {
    return (fields & 1024)!=0;
}
-(BOOL)hasP {
    return (fields & 2048)!=0;
}
-(BOOL)hasI {
    return (fields2 & 1)!=0;
}
-(BOOL)hasJ {
    return (fields2 & 2)!=0;
}
-(BOOL)hasR {
    return (fields2 & 4)!=0;
}
-(BOOL)hasText {
    return (fields & 32768)!=0;
}
-(BOOL)isV2 {
    return (fields & 4096)!=0;
}
-(BOOL)hasComment {return comment;}

-(NSString*)getText {
    return [[text retain] autorelease];
}
-(uint16)getG {
    return g;
}
-(uint16)getM {
    return m;
}
-(uint8)getT {
    return t;
}
-(int32_t)getN {
    return n;
}
-(void)setN:(int32_t)line {
    n = line;
    fields |= 1;
}
-(int32_t)getS {
    return s;
}
-(int32_t)getP {
    return p;
}
-(float)getX {
    return x;
}
-(float)getY {
    return y;
}
-(float)getZ {
    return z;
}
-(float)getE {
    return e;
}
-(float)getF {
    return f;
}
-(NSString*)getOriginal {
    return [[orig retain] autorelease];
}
-(void)parse {
    fields = 128;
    fields2 = 0;
    NSString *cmd = orig;
    if([connection containsVariables:orig])
        cmd = [connection replaceVariables:orig];
    int l = (int)[cmd length],i;
    int mode = 0; // 0 = search code, 1 = search value
    char code = ';';
    int p1=0;
    NSRange range;
    for (i = 0; i < l; i++)
    {
        char c = [cmd characterAtIndex:i];
        if(i==0 && c=='@') {
            hostCommand = YES;
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
                [self addCode:code value:[cmd substringWithRange:range]];
                mode = 0;
                if (self.hasM && (m == 23 || m == 28 || m == 29 || m == 32 || m == 30 || m == 117))
                {
                    int pos = i;
                    while (pos < l && isspace([cmd characterAtIndex:pos])) pos++;
                    int end = pos;
                    while (end < l && (m == 117 || !isspace([cmd characterAtIndex:end]))) end++;
                    range.location = pos;
                    range.length = end-pos;
                    text = [[cmd substringWithRange:range] retain];
                    fields |=32768;
                    break;
                }
            }
        }
        if (c == ';') break;
    }
    if (mode == 1) {
        range.location = p1;
        range.length = l-p1;
        [self addCode:code value:[cmd substringWithRange:range]];
    }
    comment = fields == 128;
}
-(NSData*) getBinary:(int) version
{
    NSMutableData *data = [NSMutableData dataWithCapacity:40];
    uint16 ns = (n & 65535);
    BOOL v2 = self.isV2;
    [data appendBytes:&fields length:2];
    if(v2) {
        [data appendBytes:&fields2 length:2];
        if(self.hasText) {
            Byte len = (Byte)text.length;
            [data appendBytes:&len length:1];
        }
    }
    if (self.hasN) [data appendBytes:&ns length:2];
    if(v2) {
        if (self.hasM) [data appendBytes:&m length:2];
        if (self.hasG) [data appendBytes:&g length:2];
    } else {
        if (self.hasM) [data appendBytes:&m length:1]; // little endian, no problem
        if (self.hasG) [data appendBytes:&g length:1];
    }
    if (self.hasX) [data appendBytes:&x length:4];
    if (self.hasY) [data appendBytes:&y length:4];
    if (self.hasZ) [data appendBytes:&z length:4];
    if (self.hasE) [data appendBytes:&e length:4];
    if (self.hasF) [data appendBytes:&f length:4];
    if (self.hasT) [data appendBytes:&t length:1];
    if (self.hasS) [data appendBytes:&s length:4];
    if (self.hasP) [data appendBytes:&p length:4];
    if(v2) {
        if (self.hasI) [data appendBytes:&ii length:4];
        if (self.hasJ) [data appendBytes:&j length:4];
        if (self.hasR) [data appendBytes:&r length:4];
    }
    if (self.hasText)
    {
        int i, len = (int)text.length;
        if (len > 16 && !v2) len = 16;
        for (i = 0; i < len; i++)
        {
            uint8 ch = [text characterAtIndex:i];
            [data appendBytes:&ch length:1];
        }
        uint8 nl = 0;
        if(!v2)
            for(;i<16;i++) [data appendBytes:&nl length:1];
    }
    // compute fletcher-16 checksum
    uint sum1 = 0, sum2 = 0;
    int blen = (int)data.length,i;
    for (i=0;i<blen;i++)
    {
        int c = ((uint8*)[data bytes])[i];
        sum1 = (sum1 + c) % 255;
        sum2 = (sum2 + sum1) % 255;
    }
    uint8 bsum1 = sum1 & 255;
    uint8 bsum2 = sum2 & 255;
    [data appendBytes:&bsum1 length:1];
    [data appendBytes:&bsum2 length:1];
    return data;
}
-(NSString*) getAsciiWithLine:(BOOL)inclLine withChecksum:(BOOL)inclChecksum
{
    NSMutableString *st = [NSMutableString stringWithCapacity:60];
    if(self.hasM && m==117) inclChecksum = NO; // For marlin :-)
    if (inclLine && self.hasN)
    {
        [st appendString:@"N"];
        [st appendFormat:@"%d",(int)n];
        [st appendString:@" "];
    }
    if(forceASCII) {
        NSRange cp = [orig rangeOfString:@";"];
        if(cp.location==NSNotFound)
            [st appendString:orig];
        else
            [st appendString:[StringUtil trim:[orig substringToIndex:cp.location]]];
    }
    else {
        if (self.hasM)
        {
            [st appendString:@"M"];
            [st appendFormat:@"%d",(int)m];
        }
        if (self.hasG)
        {
            [st appendString:@"G"];
            [st appendFormat:@"%d",(int)g];
        }
        if (self.hasT)
        {
            if (self.hasM) [st appendString:@" "];
            [st appendString:@"T"];
            [st appendFormat:@"%d",(int)t];
        }
        if (self.hasX)
        {
            [st appendString:@" X"];
            [st appendFormat:@"%.2f",x];
        }
        if (self.hasY)
        {
            [st appendString:@" Y"];
            [st appendFormat:@"%.2f",y];
        }
        if (self.hasZ)
        {
            [st appendString:@" Z"];
            [st appendFormat:@"%.2f",z];
        }
        if (self.hasE)
        {
            [st appendString:@" E"];
            [st appendFormat:@"%.4f",e];
        }
        if (self.hasF)
        {
            [st appendString:@" F"];
            [st appendFormat:@"%.2f",f];
        }
        if (self.hasI)
        {
            [st appendString:@" I"];
            [st appendFormat:@"%.2f",ii];
        }
        if (self.hasJ)
        {
            [st appendString:@" J"];
            [st appendFormat:@"%.2f",j];
        }
        if (self.hasR)
        {
            [st appendString:@" R"];
            [st appendFormat:@"%.2f",r];
        }
        if (self.hasS)
        {
            [st appendString:@" S"];
            [st appendFormat:@"%d",(int)s];
        }
        if (self.hasP)
        {
            [st appendString:@" P"];
            [st appendFormat:@"%d",(int)p];
        }
        if (self.hasText)
        {
            [st appendString:@" "];
            [st appendString:text];
        }
    }
    if (inclChecksum)
    {
        int check = 0;
        int l = (int)st.length,iii;
        for (iii=0;iii<l;iii++) {
            check ^= ([st characterAtIndex:iii] & 0xff);
        }
        check ^= 32;
        [st appendString:@" *"];
        [st appendFormat:@"%d",(int)check];
    }
    return st;
}
-(void)ActivateV2OrForceAscii
{
    if (connection->binaryVersion < 2)
    {
        forceASCII = YES;
        return;
    }
    fields |= 4096;
}
-(void) addCode:(char) c value:(NSString*)val {
    double d = [val doubleValue];
    switch (c)
    {
        case 'N':
        case 'n':
            n = (int32_t)d;
            fields|=1;
            break;
        case 'G':
        case 'g':
            g = (uint16)d;
            if(d>255) [self ActivateV2OrForceAscii];
            fields|=4;
            break;
        case 'M':
        case 'm':
            m = (uint16)d;
            if(d>255) [self ActivateV2OrForceAscii];
            fields|=2;
            break;
        case 'T':
        case 't':
            t = (uint8)d;
            fields|=512;
            break;
        case 'S':
        case 's':
            s = (int)d;
            fields|=1024;
            break;
        case 'P':
        case 'p':
            p = (int)d;
            fields|=2048;
            break;
        case 'X':
        case 'x':
            x = (float)d;
            fields|=8;
            break;
        case 'Y':
        case 'y':
            y = (float)d;
            fields|=16;
            break;
        case 'Z':
        case 'z':
            z = (float)d;
            fields|=32;
            break;
        case 'E':
        case 'e':
            e = (float)d;
            fields|=64;
            break;
        case 'A':
        case 'a':
            e = (float)d;
            fields|=64;
            forceASCII = YES;
            break;
        case 'F':
        case 'f':
            f = (float)d;
            fields|=256;
            break;
        case 'i':
        case 'I':
            ii = (float)d;
            fields2|=1;
            [self ActivateV2OrForceAscii];
            break;
        case 'j':
        case 'J':
            j = (float)d;
            fields2|=2;
            [self ActivateV2OrForceAscii];
            break;
        case 'r':
        case 'R':
            r = (float)d;
            fields2|=4;
            [self ActivateV2OrForceAscii];
            break;
        default: // Unsupported, so send line instead
            forceASCII = YES;
            break;
    }
}
-(NSString*)hostCommand
{
    NSRange pos = [orig rangeOfString:@" "];
    if (pos.location==NSNotFound) return orig;
    return [orig substringToIndex:pos.location];
}
-(NSString*)hostParameter
{
    NSRange pos = [orig rangeOfString:@" "];
    if (pos.location==NSNotFound) return @"";
    NSString *cmd = [connection replaceVariables:[orig substringFromIndex:pos.location+1]];
    return cmd;
}
@end
