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

#import "RHLogger.h"
#import "RHAppDelegate.h"
#import "ThreadedNotification.h"
#import "PrinterConfiguration.h"

RHLogger *rhlog = nil;
NSDateFormatter *logDateFormatter = nil;

@implementation RHLogEntry

@synthesize time;
@synthesize message;

-(void)dealloc {
    [time release];
    [message release];
    [super dealloc];
}
+(id)fromMessage:(NSString*)msg level:(RHLogType)aType response:(BOOL)isResp {
    RHLogEntry *e = [[RHLogEntry alloc] init];
    NSDate *date = [NSDate date];
    e->level = aType;
    e->response = isResp;
    [e setMessage:msg];
    [e setTime:[logDateFormatter stringFromDate:date]];
    return [e autorelease];
}
-(BOOL)isACK {
    if ([message rangeOfString:@"ok"].location==0 || [message rangeOfString:@"wait"].location==0) return YES;
    if([message rangeOfString:@"T:"].location!=NSNotFound) return YES;
    if ([message rangeOfString:@"SD printing byte"].location!=NSNotFound) return YES;
    if ([message rangeOfString:@"Not SD printing"].location!=NSNotFound) return YES;
    return NO;
}
-(NSString*)asText {
    if(response)
        return [NSString stringWithFormat:@"< %@: %@\n",time,message];
    else if(level == RHLogSend)
        return [NSString stringWithFormat:@"> %@: %@\n",time,message];
    return [NSString stringWithFormat:@"  %@: %@\n",time,message];
}

@end

@implementation RHLogger
-(id)init {
    if((self=[super init])) {
        list = [RHLinkedList new];
        rhlog = self;
        logDateFormatter = [[NSDateFormatter alloc] init];
        [logDateFormatter setDateStyle:NSDateFormatterNoStyle];
        [logDateFormatter setTimeStyle:NSDateFormatterMediumStyle];
        NSString *logName = self.pathForLogFile;
        //NSLog(@"Creating log file %@",logName);
        if([[NSUserDefaults standardUserDefaults] boolForKey:@"logWriteToFile"]) {
        [[NSFileManager defaultManager] createFileAtPath:logName contents:[NSData dataWithBytes:"" length:0] attributes:nil];
        fileLog=[[NSFileHandle fileHandleForWritingAtPath:logName] retain];
        } else
            fileLog = nil;
        listLock = [NSLock new];
    }
    return self;
}
-(void)dealloc {
    [fileLog closeFile];
    [fileLog release];
    [list release];
    [listLock release];
    [super dealloc];
    rhlog = nil;
}
-(BOOL)passesFilter:(RHLogEntry*)entry {
    if(entry->response) {
        if(entry.isACK && ackButton.state==0) {
            return NO;
        }
    }
    switch(entry->level) {
        case RHLogWarning:
            if(warningsButton.state==0) return NO;
            break;
        case RHLogInfo:
            if(infoButton.state==0) return NO;
            break;
        case RHLogSend:
            if(sendButton.state==0) return NO;
            break;
        case RHLogError:
            if(sendButton.state==0) return NO;
            break;
        default:
            break;
    }
    return YES;
}
- (NSString *) pathForLogFile
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString *folder = @"~/Library/Repetier/";
    folder = [folder stringByExpandingTildeInPath];
    
    if ([fileManager fileExistsAtPath: folder] == NO)
    {
        NSError *err;
        [fileManager createDirectoryAtPath: folder withIntermediateDirectories:YES attributes:nil error:&err];
    }
    NSString *fileName = @"session.log";
    return [folder stringByAppendingPathComponent: fileName];    
}
-(void)add:(NSString*)aText level:(RHLogType)aType {
    if(currentPrinterConfiguration->dontLogM105 && [aText rangeOfString:@"M105"].location!=NSNotFound) return;
    [listLock lock];
    RHLogEntry *ent = [RHLogEntry fromMessage:aText level:aType response:NO];
    [list addLast:ent];
    if(fileLog!=nil)
        [fileLog writeData:[ent.asText dataUsingEncoding: NSUTF8StringEncoding]];
    while(list->count>MAXLOG_STORE_ENTRIES)
        [list removeFirst];
    [listLock unlock];
    if(app==nil || app->logView==nil) return;
    if([self passesFilter:(RHLogEntry*)list.peekLast])
        [app->logView addLine:list.peekLast];
    //[view updateBox];
}
-(void)addText:(NSString*)aText {
    [self add:aText level:RHLogText];
}
-(void)addInfo:(NSString*)aText {
    [self add:aText level:RHLogInfo];
}
-(void)addWarning:(NSString*)aText {
    [self add:aText level:RHLogWarning];
}
-(void)addSend:(NSString*)aText {
    [self add:aText level:RHLogSend];
}
-(void)addError:(NSString*)aText {
    [self add:aText level:RHLogError];
}
-(void)addResponse:(NSString*)aText {
    [self addResponse:aText level:RHLogResponse];
    
}
-(void)addResponse:(NSString*)aText level:(RHLogType)lev {     
    [listLock lock];
    RHLogEntry *ent = [RHLogEntry fromMessage:aText level:lev response:YES];
    [list addLast:ent];
    if(fileLog!=nil)
        [fileLog writeData:[ent.asText dataUsingEncoding: NSUTF8StringEncoding]];
    while(list->count>MAXLOG_STORE_ENTRIES)
        [list removeFirst];
    [listLock unlock];
    if(app->logView==nil) return;
    if([self passesFilter:(RHLogEntry*)list.peekLast])
        [app->logView addLine:list.peekLast];
}
-(void)refillView {
    [app->logView->linesLock lock];
    NSMutableArray *a = app->logView->lines;
    [a removeAllObjects];
    [listLock lock];
    for(RHLogEntry *ent in list) {
        if([self passesFilter:ent]==YES)
            [a addObject:ent];
    }
    [listLock unlock];
    if(a.count>MAX_LOG_ENTRIES) {
        [a removeObjectsInRange:NSMakeRange(0,a.count-MAX_LOG_ENTRIES)];
    }
    [app->logView->linesLock unlock];
    [app->logView scrollBottom];
    [app->logView updateBox];
}
- (IBAction)copyAction:(NSButton *)sender {
    [app->logView copy:nil];
}

- (IBAction)clearLogAction:(NSButton *)sender {
    [app->logView clear];
    [listLock lock];
    [list clear];
    [listLock unlock];
}

- (IBAction)autoscrollAction:(NSButton *)sender {
    app->logView->autoscroll = autoscrollButton.state;
    [app->logView updateBox];    
}

- (IBAction)filterChangedAction:(NSButton *)sender {
    [self refillView];
}

@end

