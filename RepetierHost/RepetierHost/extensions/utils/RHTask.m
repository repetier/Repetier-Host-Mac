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

@implementation RHTask

-(id)initProgram:(NSString*)prg args:(NSArray*)args {
    if((self=[super init])) {
        task = [[NSTask alloc] init];
        pipe = [[NSPipe pipe] retain];
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
    [task release];
    [thread release];
    [super dealloc];
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
                    [rhlog addInfo:p];
                [s deleteCharactersInRange:NSMakeRange(0,range.location+1)];
            }
        } while(range.location!=NSNotFound);
    }
    [s release];
    [pool release];
    running = NO;
    [ThreadedNotification notifyASAP:@"RHTaskFinished" object:self];
}
-(BOOL)finishedSuccessfull {
    if (![task isRunning]) {
        int status = [task terminationStatus];
        if (status == 0)
            return YES;
        else
            return NO;
    }
    return NO;
}
@end
