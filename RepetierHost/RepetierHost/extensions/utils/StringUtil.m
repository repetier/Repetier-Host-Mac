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

#import "StringUtil.h"

@implementation StringUtil
+(NSMutableArray*)explode:(NSString*)text sep:(NSString*)c {
    NSMutableArray *arr = [NSMutableArray array];
    while([text length]>0) {
        NSRange r = [text rangeOfString:c];
        if(r.location==NSNotFound) {
            [arr addObject:text];
            text = @"";
        } else {
            [arr addObject:[text substringToIndex:r.location]];
            text = [text substringFromIndex:r.location+r.length];
        }
    }
    return arr; //[arr autorelease];
}
+(NSString*)implode:(NSArray*)list sep:(NSString*)c {
    return [list componentsJoinedByString:c];
}
+(BOOL)string:(NSString*)text startsWith:(NSString*)comp {
    NSRange r = [text rangeOfString:comp];
    return r.location==0;
}
+(NSString*)normalizeLineends:(NSString*)line {
    NSString *s=[line stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
    s=[s stringByReplacingOccurrencesOfString:@"\r" withString:@"\n"];
    return s;
}
+(NSString*)replaceIn:(NSString*)orig all:(NSString*)all with:(NSString*)with {
    return [StringUtil implode:[StringUtil explode:orig sep:all] sep:with];
}
+(NSString*)trim:(NSString*)orig {
    return [orig stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}
@end
