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

#import "RHFileHistory.h"
#import "RHAppDelegate.h"

@implementation RHFileHistory

-(id)initWithName:(NSString*)nm max:(int)m {
    if((self=[super init])) {
        name = [nm retain];
        max = m;
        menu = nil;
        selector = nil;
        files = [RHLinkedList new];
        NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
        NSArray *names = [d arrayForKey:name];
        if(names!=nil) {
            for(NSString *s in names)
                [files addLast:s];
        }
    }
    return self;
}
-(void)dealloc {
    [name release];
    [files release];
    [super dealloc];
}
-(void)rebuildMenu {
    if(menu == nil) return;
    while(menu.numberOfItems)
        [menu removeItemAtIndex:0];
    //[menu removeAllItems]; doesn't work on 10.5
    int i=0;
    for(NSString *s in files) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:s action:selector keyEquivalent:@""];
        [item setTarget:app];
        [item setTag:i];
        [menu addItem:item];
        i++;
        [item release];
    }
    [menu update];
}

-(void)attachMenu:(NSMenu*)m withSelector:(SEL)sel {
    menu = m;
    selector = sel;
    [self rebuildMenu];
}
-(void)add:(NSString*)filename {
    for(NSString *s in files) {
        if([s isEqualToString:filename]) {
            [files remove:s];
            break;
        }
    }
    [files addFirst:filename];
    while(files->count>max)
        [files removeLast];
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSMutableArray *a = [[NSMutableArray alloc] initWithCapacity:files->count];
    for(NSString *s in files) {
        [a addObject:s];
    }    
    [d setObject:a forKey:name];
    [a release];
    [self rebuildMenu];
}
@end
