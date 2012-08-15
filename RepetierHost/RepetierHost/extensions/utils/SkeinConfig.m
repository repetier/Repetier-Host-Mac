/*
 Copyright 2011 repetier repetierdev@gmail.com
 
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


#import "SkeinConfig.h"
#import "StringUtil.h"

@implementation SkeinConfig

@synthesize lines;
@synthesize orig;
@synthesize path;

-(id)initWithPath:(NSString*) _path
{
    if((self=[super init])) {
        self.path = _path;
        exists = [[NSFileManager defaultManager] fileExistsAtPath:path];
        if (!exists) return self;
        NSString *lineString = [StringUtil normalizeLineends:[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil]];
        self.lines = [StringUtil explode:lineString sep:@"\n"];
        orig = [NSMutableArray arrayWithArray:self.lines];
    }
    return self;
}
-(void)writeModified
{
    if (!exists) return;
    [[StringUtil implode:lines sep:@"\n"] writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}
-(void)writeOriginal
{
    if (!exists) return;
    [[StringUtil implode:orig sep:@"\n"] writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}
-(int)lineForKey:(NSString*)key
{
    NSString *key2 = [NSString stringWithFormat:@"%@\t",key];
    for (int i = 0; i < lines.count; i++)
    {
        NSRange r = [[lines objectAtIndex:i] rangeOfString:key2];
        if(r.location == 0) return i;
    }
    return -1;
}
-(NSString*)getValue:(NSString*)key
{
    if (!exists) return nil;
    int idx = [self lineForKey:key];
    if (idx < 0) return nil;
    return [[lines objectAtIndex:idx] substringFromIndex:key.length + 1];
}
-(void)setValue:(NSString*)val key:(NSString*)key
{
    if (!exists) return;
    int idx = [self lineForKey:key];
    if (idx < 0) return;
    [lines replaceObjectAtIndex:idx  withObject:[NSString stringWithFormat:@"%@\t%@",key,val]];
}


@end
