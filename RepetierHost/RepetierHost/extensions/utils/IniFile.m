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


#import "IniFile.h"
#import "StringUtil.h"

@implementation IniSection

@synthesize name;
@synthesize entries;

-(id)initWithName:(NSString*)_name {
    if((self=[super init])) {
        self.entries = [[[NSMutableDictionary alloc] initWithCapacity:10] autorelease];
        self.name = _name;
    }
    return self;
}
-(void)addLine:(NSString*)line {
    NSRange p = [line rangeOfString:@"="];
    NSString *key = [[line substringToIndex:p.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *v = [self.entries objectForKey:key];
    if (v==nil) {
        [self.entries setValue:line forKey:key];
    }
}
-(void)merge:(IniSection*)s
{
    for(NSString *key in s.entries.allKeys)
    {
        if ([key isEqualToString:@"extrusion_multiplier"] || [key isEqualToString:@"filament_diameter"] || [key isEqualToString:@"first_layer_temperature"]
            || [key isEqualToString:@"temperature"])
        {
            NSString *value = [entries objectForKey:key];
            if (value)
            {
                NSString *full = [s.entries objectForKey:key];
                NSRange p = [full rangeOfString:@"="];
                if (p.location!=NSNotFound)
                    full = [[full substringFromIndex:1+p.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                [self.entries setValue:[NSString stringWithFormat:@"%@,%@",value,full] forKey:key];
                //NSLog(@"Merge %@ and %@ to %@",value,full, [self.entries objectForKey:key]);
            }
            else
            {
                [self.entries setValue:[s.entries objectForKey:key] forKey:key];
            }
        }
    }
}
@end

@implementation IniFile

@synthesize path;
@synthesize sections;

-(id)init {
    if((self=[super init])) {
        self.path = @"";
        self.sections = [[[NSMutableDictionary alloc] init] autorelease];
    }
    return self;
}
-(void)read:(NSString*)_path {
    self.path = _path;
    IniSection *actSect = nil;
    actSect = [[[IniSection alloc] initWithName:@""] autorelease];
    [sections setValue:actSect forKey:@""];
    if(![[NSFileManager defaultManager] fileExistsAtPath:path]) return; // file does not exist
    NSString *lineString = [StringUtil normalizeLineends:[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil]];
    for(NSString *line in [StringUtil explode:lineString sep:@"\n"]) {
        NSString *tl = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([tl rangeOfString:@"#"].location == 0) continue; // comment
        NSRange ko = [tl rangeOfString:@"["];
        NSRange kc = [tl rangeOfString:@"]"];
        if(ko.location==0 && kc.location==tl.length-1)
        {
            NSString *secname = [tl substringWithRange:NSMakeRange(1,tl.length-2)];
            actSect = [sections objectForKey:secname];
            if (actSect == nil)
            {
                actSect = [[[IniSection alloc] initWithName:secname] autorelease];
                [sections setValue:actSect forKey:secname];
            }
            continue;
        }
        NSRange p = [tl rangeOfString:@"="];
        if (p.location == NSNotFound) continue;
        [actSect addLine:line];
    }
}
-(void)add:(IniFile*)f
{
    for (IniSection *s in f.sections.allValues)
    {
        if (![sections objectForKey:s.name])
        {
            [sections setValue:[[[IniSection alloc] initWithName:s.name] autorelease] forKey:s.name];
        }
        IniSection *ms = [sections objectForKey:s.name];
        for (NSString *ent in s.entries.allValues)
            [ms addLine:ent];
    }
}
-(void)merge:(IniFile*)f
{
    for (IniSection *s in f.sections.allValues)
    {
        if (![sections objectForKey:s.name])
        {
            [sections setValue:[[[IniSection alloc] initWithName:s.name] autorelease] forKey:s.name];
        } else {
            [((IniSection*)[sections objectForKey:s.name]) merge:s];
        }
    }
}
-(void)flatten
{
    IniSection *flat = [sections objectForKey:@""];
    NSMutableArray *dellist = [[[NSMutableArray alloc] initWithCapacity:sections.count] autorelease];
    for (IniSection *s in sections.allValues)
    {
        for (NSString *line in s.entries.allValues)
            [flat addLine:line];
        if (s.name.length > 0)
            [dellist addObject:s.name];
    }
    [sections removeObjectsForKeys:dellist];
}

-(void)write:(NSString*)_path
{
    NSMutableArray *lines = [NSMutableArray array];
    for (IniSection *s in sections.allValues)
    {
        if (s.name.length>0)
            [lines addObject:[NSString stringWithFormat:@"[%@]",s.name]];
        for(NSString *line in s.entries.allValues) {
            [lines addObject:line];
        }
    }
    NSString *file = [StringUtil implode:lines sep:@"\n"];
    [file writeToFile:_path atomically:YES encoding:NSUTF8StringEncoding error:nil];
}
@end
