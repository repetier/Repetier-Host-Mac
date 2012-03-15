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

#import <Cocoa/Cocoa.h>
#import "RHLinkedList.h"

@class STL;

@interface STLComposer : NSView<NSTableViewDataSource,NSTableViewDelegate> {
    @public
    IBOutlet NSView *view;
    IBOutlet NSTextField *translationX;
    IBOutlet NSTextField *translationY;
    IBOutlet NSTextField *translationZ;
    IBOutlet NSTextField *scaleX;
    IBOutlet NSTextField *scaleY;
    IBOutlet NSTextField *scaleZ;
    IBOutlet NSTextField *rotateX;
    IBOutlet NSTextField *rotateY;
    IBOutlet NSTextField *rotateZ;
    IBOutlet NSButton *lockAspect;
    IBOutlet NSTableColumn *filesColumn;
    IBOutlet NSTableView *filesTable;
    IBOutlet NSButton *centerObjectButton;
    IBOutlet NSButton *dropObjectButton;
    IBOutlet NSButton *removeSTLfileButton;
    IBOutlet NSButton *autoplaceButton;
    IBOutlet NSButton *multiplyButton;
    NSOpenPanel* openPanel;
    NSSavePanel* savePanel;
    RHLinkedList *files;
    STL *actSTL;
    BOOL autosizeFailed;
    int numberOfCopies;
    BOOL autoplaceCopies;
    IBOutlet NSPanel *copyObjectsPanel;
    IBOutlet NSPanel *changedFilesPanel;
}
@property int numberOfCopies;
@property BOOL autoplaceCopies;
- (IBAction)copyMarked:(id)sender;
- (IBAction)cancelCopyMarked:(id)sender;
- (IBAction)reloadChangedFiles:(id)sender;
- (IBAction)cancelChangedFiles:(id)sender;
-(void)recheckChangedFiles;
-(void)updateSTLState:(STL*)stl;
-(void)objectMoved:(id)omove;
-(void)objectSelected:(id)obj;
- (IBAction)saveAsSTL:(NSButton *)sender;
- (IBAction)generateGCode:(NSButton *)sender;
- (IBAction)centerObject:(NSButton *)sender;
- (IBAction)dropObject:(NSButton *)sender;
- (IBAction)addSTLFile:(id)sender;
- (IBAction)removeSTLFile:(NSButton *)sender;
- (IBAction)changeLockAspect:(NSButton *)sender;
-(void)loadSTLFile:(NSString*)fname;
-(void)updateView;
-(void)saveSTLToFile:(NSString*)file;
- (IBAction)autoplaceAction:(id)sender;
- (IBAction)multiplyAction:(id)sender;
-(void)autoplace;
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification;
// NSTableViewDelegate methods
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView;
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex;
@end

extern STLComposer *stlComposer;
