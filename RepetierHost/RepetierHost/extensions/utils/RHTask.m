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

#import "RHTask.h"
#import "RHLogger.h"
#import "ThreadedNotification.h"
#import "StringUtil.h"

static RHLinkedList *executeList = nil;

@implementation RHTask

-(id)initProgram:(NSString*)prg args:(NSArray*)args logPrefix:(NSString*)prefix {
    if((self=[super init])) {
        [executeList addLast:self];
        task = [[NSTask alloc] init];
        pipe = [[NSPipe pipe] retain];
        logPrefix = [prefix retain];
        readHandle = [[pipe fileHandleForReading] retain];
        
        // write handle is closed to this process
        [task setStandardOutput:pipe];
        [task setStandardError:pipe];
        [task setLaunchPath:prg];
        [task setArguments:args];
        [task launch];
        thread = [[NSThread alloc] initWithTarget:self
                                selector:@selector(taskThread:) object:nil];
        [thread start];
    }
    return self;
}
-(void)dealloc {
    [readHandle release];
    [pipe release];
    if(task)
        [task release];
    [thread release];
    [logPrefix release];
    [super dealloc];
}
+(void)execute:(NSString*)cmd {
    if(executeList==nil) {
        executeList = [RHLinkedList new];
    }
    NSMutableArray *arr = [NSMutableArray new];
    NSString *exe = nil;
    cmd = [StringUtil trim:cmd];
    NSUInteger exeEnd = 0;
    NSUInteger cmdLength = cmd.length;
    if ([StringUtil string:cmd startsWith:@"\""])
    {
        while (exeEnd < cmdLength && [cmd characterAtIndex:exeEnd] != '"') exeEnd++;
        exe = [[cmd substringToIndex:exeEnd] substringFromIndex:1];
    }
    else
    {
        while (exeEnd < cmdLength && [cmd characterAtIndex:exeEnd] != ' ') exeEnd++;
        exe = [cmd substringToIndex:exeEnd];
    }
    do {
        cmd = [StringUtil trim:[cmd substringFromIndex:exeEnd]];
        if(cmd.length==0) break;
        if ([StringUtil string:cmd startsWith:@"\""])
        {
            while (exeEnd < cmdLength && [cmd characterAtIndex:exeEnd] != '"') exeEnd++;
            [arr  addObject:[[cmd substringToIndex:exeEnd] substringFromIndex:1]];
        }
        else
        {
            while (exeEnd < cmdLength && [cmd characterAtIndex:exeEnd] != ' ') exeEnd++;
            [arr addObject:[cmd substringToIndex:exeEnd]];
        }
    } while(YES);
    RHTask *task = [[RHTask alloc] initProgram:exe args:arr logPrefix:[exe lastPathComponent]];
    [task release];
}
-(void)bringToFront {
    int pid  = [task processIdentifier];
    ProcessSerialNumber psn;
    GetProcessForPID(pid, &psn);
    SetFrontProcess(&psn);
}
-(void)taskThread:(id)obj {
    running = YES;
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSData *inData;
    NSMutableString *s = [[NSMutableString alloc] initWithCapacity:200];
    while ((inData = [readHandle availableData]) && [inData length]) {
        [s appendString:[[[NSString alloc] initWithData: inData encoding: NSUTF8StringEncoding] autorelease]];
        NSRange range;
        do {
            range = [s rangeOfCharacterFromSet:[NSCharacterSet newlineCharacterSet]];
            if(range.location!=NSNotFound) {
                NSString *p = [s substringWithRange:NSMakeRange(0,range.location)];
                p = [p stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if(p.length>0)
                    [rhlog addPrg:[logPrefix stringByAppendingString:p]];
                [s deleteCharactersInRange:NSMakeRange(0,range.location+1)];
            }
        } while(range.location!=NSNotFound);
    }
    while(task.isRunning)
        [NSThread sleepForTimeInterval:0.02];
    status = [task terminationStatus];
    [s release];
    [pool release];
    [task release];
    task = nil;
    running = NO;
    [ThreadedNotification notifyASAP:@"RHTaskFinished" object:self];
}
-(void)kill {
    [task terminate];
}
-(BOOL)finishedSuccessfull {
    [executeList remove:self];
    if (task==nil) {
        if (status == 0)
            return YES;
        else
            return NO;
    }
    return NO;
}
@end
