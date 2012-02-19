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

typedef struct RHListNode RHListNode;
struct RHListNode {
	id value;
	RHListNode *next;
	RHListNode *prev;
};

@interface RHLinkedList : NSObject<NSFastEnumeration> {
    RHListNode *first;
    RHListNode *last;
@public
    int count;
}
-(id)init;
-(void)addFirst:(id)obj;
-(void)addLast:(id)obj;
-(id)removeFirst;
-(id)peekFirst;
-(id)peekLast;
-(id)peekFirstFast;
-(id)peekLastFast;
-(id)removeLast;
-(void)remove:(id)obj;
-(id)objectAtIndex:(int)idx;
-(void)clear;
-(RHListNode*)lastNode;
-(RHListNode*)firstNode;
@end
