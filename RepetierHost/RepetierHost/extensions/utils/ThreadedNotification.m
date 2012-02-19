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

#import "ThreadedNotification.h"

@implementation ThreadedNotification 

+(void)_notifyASPAP:(NSNotification*)n {
    [[NSNotificationQueue defaultQueue] enqueueNotification:n postingStyle:NSPostASAP];    
}
+(void)notifyASAP:(NSString*)msg object:(id)obj {
    NSNotification *n = [NSNotification notificationWithName:msg object:obj];
    if( [NSThread isMainThread] ) {
        [[NSNotificationQueue defaultQueue] enqueueNotification:n postingStyle:NSPostASAP];
        return;
    }
    // We are not in main thread
    [[self class] performSelectorOnMainThread:@selector(_notifyASPAP:) withObject:n waitUntilDone:NO];
}
+(void)_notifyNow:(NSNotification*)n {
    [[NSNotificationQueue defaultQueue] enqueueNotification:n postingStyle:NSPostNow];    
}
+(void)notifyNow:(NSString*)msg object:(id)obj {
    NSNotification *n = [NSNotification notificationWithName:msg object:obj];
    if( [NSThread isMainThread] ) {
        [[NSNotificationQueue defaultQueue] enqueueNotification:n postingStyle:NSPostNow];
        return;
    }
    // We are not in main thread
    [[self class] performSelectorOnMainThread:@selector(_notifyNow:) withObject:n waitUntilDone:YES];
}

@end
