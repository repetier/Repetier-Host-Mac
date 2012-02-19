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

#import "EEPROMParameter.h"
#import "StringUtil.h"
#import "PrinterConnection.h"
#import "RHAppDelegate.h"
#import "ThreadedNotification.h"

@implementation EEPROMParameter

@synthesize val;
// public delegate void OnEEPROMAdded(EEPROMParameter param);

-(id)initWithLine:(NSString*)line {
    if((self=[super init])) {
        changed = NO;
        NSArray *arr = [StringUtil explode:line sep:@" "];
        type = [[[arr objectAtIndex:0] substringFromIndex:4] intValue];
        position = [[arr objectAtIndex:1] intValue];
        val = [[arr objectAtIndex:2] retain];
        description = [[line substringFromIndex:3+[[arr objectAtIndex:0] length]+[[arr objectAtIndex:1] length]+[[arr objectAtIndex:2] length]] retain];
    }
    return self;
}
-(void)dealloc {
    [description release];
    [val release];
    [super dealloc];
}
-(void)save
{
    if (!changed) return; // nothing changed
    NSString *cmd;
    if (type == 3) cmd = [NSString stringWithFormat:@"M206 T%d P%d X%@",type,position,val];
    else cmd = [NSString stringWithFormat:@"M206 T%d P%d S%@",type,position,val];
    [connection injectManualCommand:cmd];
    changed = NO;
}
@end

@implementation EEPROMStorage
    
-(id)init {
    if((self=[super init])) {
        list = [RHLinkedList new];
    }
    return self;
}
-(void)dealloc {
    [list release];
    [super dealloc];
}
-(void)clear
{
    [list clear];
}
-(void)save
{
    for(EEPROMParameter *p in list)
        [p save];
}
-(void)add:(NSString*)line
{
    if (![line rangeOfString:@"EPR:"].location==0) return;
    EEPROMParameter *p = [[EEPROMParameter alloc] initWithLine:line];
    for(EEPROMParameter *p2 in list) {
        if(p2->position == p->position) {
            [list remove:p2];
            break;
        }
    }
    [list addLast:p];
    [ThreadedNotification notifyASAP:@"RHEepromAdded" object:p];
    [p release];
}
-(void)update
{
    [self clear];
    [connection injectManualCommand:@"M205"];
}
-(EEPROMParameter*)get:(int)pos
{
    return [list objectAtIndex:pos];
}

@end
