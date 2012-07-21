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
#import "GCode.h"
#import "GCodeAnalyzer.h"

@interface RHPrintjob : NSObject {
    RHLinkedList *jobList;
    //RHLinkedList *times;
    NSDate *jobStarted, *jobFinished;
    GCodeAnalyzer *_ana;
    //NSLock *timeLock;
    NSDateFormatter *dateFormatter;
@public
    BOOL dataComplete;
    int totalLines;
    int linesSend;
    BOOL exclusive;
    double computedPrintingTime;
    int maxLayer;
    int mode; // 0 = no job defines, 1 = printing, 2 = finished, 3 = aborted
}

@property (retain) NSDate *jobStarted;
@property (retain) NSDate *jobFinished;
@property (retain) GCodeAnalyzer *ana;

-(id)init;
-(void)dealloc;
-(void) beginJob;
-(void) endJob;
-(void) killJob;
-(void) doEndKillActions;
-(void) pushData:(NSString*)code;
// Push array of GCodeShort elements
-(void)pushShortArray:(NSArray*)codes;
-(BOOL) hasData;
-(GCode*) peekData;
-(GCode*)popData;
-(float) percentDone;
-(NSString*) ETA;
-(void) updateJobButtons;
@end

@interface PrintTime : NSObject {
@public    
    int line;
    double time;
} 
-(id)initWithLine:(int)linenumber;
-(void)dealloc;

@end
