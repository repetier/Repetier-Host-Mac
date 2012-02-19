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


#import "RHLinkedList.h"

@implementation RHLinkedList
-(id)init {
    if((self=[super init])) {
        first = last = nil;
        count = 0;
    }
    return self;
}
-(void)dealloc {
    [self clear];
    [super dealloc];
}
-(void)clear {
    while(last!=nil) {
        [last->value release];
        RHListNode *n = last;
        last = last->prev;
        free(n);
    };
    first = last = nil;
    count = 0;
}
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(id *)stackbuf count:(NSUInteger)len
{
    RHListNode *currentNode;
    if (state->state == 0)
    {
        // Set the starting point. _startOfListNode is assumed to be our
        // object's instance variable that points to the start of the list.
        currentNode = first;
    } else if(state->state == 1) { // End of list
        return 0;
    }
    else
    {
        // Subsequent iterations, get the current progress out of state->state
        currentNode = (struct RHListNode *)state->state;
    }
    
    // Accumulate nodes from the list until we reach the object's
    // _endOfListPlusOneNode
    NSUInteger batchCount = 0;
    while (currentNode != nil && batchCount < len)
    {
        stackbuf[batchCount] = currentNode->value;
        currentNode = currentNode->next;
        batchCount++;
    }
    if(currentNode == nil)
        state->state = 1;
    else
        state->state = (unsigned long)currentNode;
    state->itemsPtr = stackbuf;
    state->mutationsPtr = (unsigned long *)self;
    
    return batchCount;
}
-(void)addFirst:(id)obj {
    RHListNode *n = malloc(sizeof(RHListNode));
    n->prev = nil;
    n->next = first;
    n->value = [obj retain];
    if(first!=nil)
        first->prev = n;
    first = n;
    if(last==nil) last = n;
    count++;
}
-(void)addLast:(id)obj {
    RHListNode *n = malloc(sizeof(RHListNode));
    n->prev = last;
    n->next = nil;
    n->value = [obj retain];
    if(last!=nil)
        last->next = n;
    last = n;
    if(first==nil) first = n;
    count++;
}
-(id)removeFirst {
    if(first == nil) return nil; // for safety
    RHListNode *n = first;
    first = n->next;
    if(first!=nil)
        first->prev = nil;
    else
        last = nil;
    id v = n->value;
    free(n);
    [v autorelease];
    count--;
    return v;
}
-(id)removeLast {
    if(last == nil) return nil; // for safety
    RHListNode *n = last;
    last = n->prev;
    if(last!=nil)
        last->next = nil;
    else
        first = nil;
    id v = n->value;
    free(n);
    [v autorelease];
    count--;
    return v;    
}
-(void)remove:(id)obj {
    RHListNode *act = first;
    while(act!=nil) {
        if(act->value==obj) {
            if(act->prev==nil)
                first = act->next;
            else
                act->prev->next = act->next;
            if(act->next==nil)
                last = act->prev;
            else
                act->next->prev = act->prev;
            [act->value release];
            free(act);
            count--;
            return;
        }
        act = act->next;
    }
}
-(id)objectAtIndex:(int)idx {
    if(idx<0 || idx>=count) return nil;
    RHListNode *act = first;
    while(idx>0) {
        idx--;
        act = act->next;
    }
    return [[act->value retain] autorelease];
}
-(id)peekFirst {
    if(first==nil) return nil;
    return [[first->value retain] autorelease];
}
-(id)peekFirstFast {
    if(first==nil) return nil;
    return first->value;
}
-(id)peekLast {
    if(last==nil) return nil;
    return [[last->value retain] autorelease];
}
-(id)peekLastFast {
    if(last==nil) return nil;
    return last->value;
}
-(RHListNode*)lastNode {
    return last;
}
-(RHListNode*)firstNode {
    return first;
}

@end
