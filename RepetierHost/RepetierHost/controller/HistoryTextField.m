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

#import "HistoryTextField.h"
#import "PrinterConnection.h"

@implementation HistoryTextField


-(void)awakeFromNib
{
    commands = [RHLinkedList new];
    commandPos = 0;
    [self setDelegate:self];
}
-(void)dealloc {
    [commands release];
    [super dealloc];
}
-(void)sendCommand:(NSString*)cmd
{
    if (cmd.length<2) return;
    [connection injectManualCommand:cmd];
    [commands addLast:cmd];
    if (commands->count > 100)
        [commands removeFirst];
    commandPos = commands->count;
    [self setStringValue:@""];
}
- (BOOL)control:(NSControl *)control textView:(NSTextView *)fieldEditor
doCommandBySelector:(SEL)commandSelector {
    BOOL retval = NO;
    if (commandSelector == @selector(insertNewline:)) {
        retval = YES;
        [self sendCommand:self.stringValue];
    } else if(commandSelector == @selector(moveDown:)) {
        retval = YES;
        if(commandPos>0) {
            commandPos--;
            [self setStringValue:[commands objectAtIndex:commandPos]];
        } // else [self setStringValue:@""];       
    } else if(commandSelector == @selector(moveUp:)) {
        retval = YES;
        if(commandPos<commands->count-1) {
            commandPos++;
            [self setStringValue:[commands objectAtIndex:commandPos]];
        } else {commandPos = commands->count;[self setStringValue:@""];}       
    }
    return retval;
}
@end
