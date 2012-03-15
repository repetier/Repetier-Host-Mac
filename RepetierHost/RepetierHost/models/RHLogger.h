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
#import "RHLinkedList.h"
#import "RHLogView.h"

typedef enum {
    RHLogText=0,
    RHLogWarning=1,
    RHLogError=2,
    RHLogInfo=3,
    RHLogResponse=4,
    RHLogSend=5,
    RHLogPrg=6
} RHLogType;
@interface RHLogEntry : NSObject {
@public
    NSString *time;
    NSString *message;
    RHLogType level;
    BOOL response;
}
#define MAX_LOG_ENTRIES 2000
#define MAXLOG_STORE_ENTRIES 5000
@property (retain)NSString *time;
@property (retain)NSString *message;
+(id)fromMessage:(NSString*)msg level:(RHLogType)aType response:(BOOL)isResp;
-(BOOL)isACK;
-(NSString*)asText;
@end
@interface RHLogger : NSObject {
    RHLinkedList *list;
    NSFileHandle *fileLog;
    NSLock *listLock;
    IBOutlet NSButton *sendButton;
    IBOutlet NSButton *infoButton;
    IBOutlet NSButton *warningsButton;
    IBOutlet NSButton *errorsButton;
    IBOutlet NSButton *ackButton;
    IBOutlet NSButton *autoscrollButton;
    IBOutlet NSButton *copyButton;
    IBOutlet NSButton *clearLogButton;
}
-(BOOL)passesFilter:(RHLogEntry*)entry;
- (NSString *) pathForLogFile;
-(void)add:(NSString*)aText level:(RHLogType)aType;
-(void)addText:(NSString*)aText;
-(void)addInfo:(NSString*)aText;
-(void)addPrg:(NSString*)aText;
-(void)addWarning:(NSString*)aText;
-(void)addError:(NSString*)aText;
-(void)addSend:(NSString*)aText;
-(void)addResponse:(NSString*)aText;
-(void)addResponse:(NSString*)aText level:(RHLogType)lev;
-(void)refillView;
- (IBAction)copyAction:(NSButton *)sender;
- (IBAction)clearLogAction:(NSButton *)sender;
- (IBAction)autoscrollAction:(NSButton *)sender;
- (IBAction)filterChangedAction:(NSButton *)sender;
@end

extern RHLogger *rhlog;