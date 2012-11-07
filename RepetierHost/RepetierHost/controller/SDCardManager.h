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

@interface SDCardFile : NSObject {
    @public
    NSString *fullname;
    NSString *filename;
    NSString *filesize;
    NSString *dirname;
    BOOL isDirectory;
}
-(id)initFile:(NSString*)fname size:(NSString*)sz;
@end
@interface SDCardManager : NSWindowController<NSWindowDelegate,NSTableViewDataSource,NSTableViewDelegate> {
    NSWindow *mainWindow;
    IBOutlet NSToolbarItem *uploadButton;
    IBOutlet NSToolbarItem *removeButton;
    IBOutlet NSToolbarItem *startPrintButton;
    IBOutlet NSToolbarItem *stopPrintButton;
    IBOutlet NSToolbarItem *mountButton;
    IBOutlet NSToolbarItem *unmountButton;
    IBOutlet NSTableView *table;
    IBOutlet NSTableColumn *filenameColumn;
    IBOutlet NSTableColumn *filesizeColumn;
    IBOutlet NSTextField *printStatus;
    IBOutlet NSToolbarItem *newFolderButton;
    IBOutlet NSProgressIndicator *progressBar;
    IBOutlet NSToolbar *toolbar;
    RHLinkedList *files;
    RHLinkedList *allFiles;
    BOOL mounted;
    BOOL printing;
    BOOL printPaused;
    BOOL uploading;
    BOOL readFilenames;
    BOOL updateFilenames;
    BOOL startPrint;
    BOOL canRemove;
    int printWait;
    int waitDelete;
    NSTimer *timer;
    IBOutlet NSTextField *uplFilenameText;
    IBOutlet NSTextField *uplExternalFilenameText;
    IBOutlet NSButton *uplIncludeStartEndCheckbox;
    IBOutlet NSButton *uplIncludeJobEndCheckbox;
    IBOutlet NSPanel *uploadPanel;
    NSOpenPanel* openPanel;
    double progress;
    NSImage *folderImage;
    NSImage *fileImage;
    NSString *folder;
    IBOutlet NSPanel *createFolderPanel;
    IBOutlet NSTextField *newFolderName;
}
@property (retain)NSString *folder;
- (IBAction)uploadAction:(id)sender;
- (IBAction)removeAction:(id)sender;
- (IBAction)startPrintAction:(id)sender;
- (IBAction)stopPrintAction:(id)sender;
- (IBAction)mountAction:(id)sender;
- (IBAction)unmountAction:(id)sender;
- (IBAction)uplBrowseExternalFile:(id)sender;
- (IBAction)uplUploadGCodeAction:(id)sender;
- (IBAction)uplUploadExternalFileAction:(id)sender;
- (IBAction)uplCancelAction:(id)sender;
- (IBAction)newFolderAction:(id)sender;
- (IBAction)cancelNewFolder:(id)sender;
- (IBAction)uplCancelAction:(id)sender;
- (IBAction)createNewFolder:(id)sender;
-(void)timerTick:(NSTimer*)timer;
-(void)refreshFilenames;
-(void)updateButtons;
-(void)showInfo:(NSString*)warn headline:(NSString*)head;
-(void)showError:(NSString*)warn headline:(NSString*)head;
-(void)analyze:(NSString*)res;
-(void)sdcardStatus:(NSNotification*)event;
@end
