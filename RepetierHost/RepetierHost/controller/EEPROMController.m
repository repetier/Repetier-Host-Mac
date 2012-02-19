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

#import "EEPROMController.h"
#import "EEPROMParameter.h"
#import "PrinterConnection.h"

@implementation EEPROMController

- (id) init {
    if(self = [super initWithWindowNibName:@"EEPROM" owner:self]) {
        initDone = NO;
        list = [RHLinkedList new];
      //  NSLog(@"Window is %l",self.window);
        //[self.window setReleasedWhenClosed:NO];
    }
    return self;
}
- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}
-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [list release];
    [super dealloc];
}
- (void)windowDidLoad
{
    [super windowDidLoad];
    mainwindow = self.window;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(newParam:) name:@"RHEepromAdded" object:nil];
}
- (BOOL)windowShouldClose:(id)sender {
    [mainwindow orderOut:self];
    return NO;
}
-(void)update {
    [list clear];
    [table reloadData];
    [connection->eeprom update];
}
- (void)newParam:(NSNotification *)notification {
    EEPROMParameter *p = notification.object;
    [list addLast:p];
    [table reloadData];
}
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
    return list->count;
}
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)col row:(NSInteger)rowIndex {
    if(col==descriptionColumn)
        return ((EEPROMParameter*)[list objectAtIndex:(int)rowIndex])->description;
    return ((EEPROMParameter*)[list objectAtIndex:(int)rowIndex])->val;
}
- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)col row:(NSInteger)rowIndex {
    if(col==valueColumn) {
        EEPROMParameter *p = [list objectAtIndex:(int)rowIndex];
        [p setVal:anObject];
        p->changed = YES;
        [connection->eeprom save];
    }
}
@end
