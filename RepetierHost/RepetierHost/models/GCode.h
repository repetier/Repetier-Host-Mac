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

@interface GCode : NSObject {
    @public
    uint16_t fields,fields2;
    int32_t n;
    uint8 t;
    uint16 g, m;
    float x, y, z, e, f,ii,j,r;
    int32_t s;
    int32_t p;
    NSString *text;
    NSString *orig;
@public
    BOOL comment;
    BOOL hostCommand;
    BOOL forceASCII;
}
-(id)initFromString:(NSString*)cmd;
-(void)dealloc;

-(BOOL)hasM;
-(BOOL)hasN;
-(BOOL)hasG;
-(BOOL)hasT;
-(BOOL)hasX;
-(BOOL)hasY;
-(BOOL)hasZ;
-(BOOL)hasE;
-(BOOL)hasF;
-(BOOL)hasS;
-(BOOL)hasP;
-(BOOL)hasI;
-(BOOL)hasJ;
-(BOOL)hasR;
-(BOOL)hasText;
-(BOOL)hasComment;
-(BOOL)isV2;

-(NSString*)getText;
-(uint8)getG;
-(uint8)getM;
-(uint8)getT;
-(int32_t)getN;
-(int32_t)getS;
-(int32_t)getP;
-(float)getX;
-(float)getY;
-(float)getZ;
-(float)getE;
-(float)getF;
-(NSString*)getOriginal;
-(void)setN:(int32_t)line;
-(void)parse;
-(void) addCode:(char) c value:(NSString*)val;
-(NSString*) getAsciiWithLine:(BOOL)inclLine withChecksum:(BOOL)inclChecksum;
-(NSData*) getBinary:(int) version;
-(NSString*)hostCommand;
-(NSString*)hostParameter;
@end
