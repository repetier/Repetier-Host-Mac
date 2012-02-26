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
#import "controller/PrinterSettingsController.h"
#import "RHLogView.h"
#import "Preferences.h"
#import "RHFileHistory.h"
#import "SDCardManager.h"
#import "EnableToollbarItem.h"
#import "LogSplitViewDelegate.h"
#import "HorizontalSpliViewDelegate.h"

@class ThreeDContainer;
@class GCodeVisual;
@class ThreeDView;
@class RHActionTabDelegate;
@class EEPROMController;
@class GCodeEditorController;
@class LogSplitViewDelegate;
@class Slicer;
@class Slic3rConfig;
@class STLComposer;
@class RHTempertuareController;
@class RHManualControl;

@interface RHAppDelegate : NSObject <NSApplicationDelegate>
{
    @public
    __unsafe_unretained NSToolbarItem *toolbarConnect;
    
    IBOutlet NSTextView *logViewText;
    IBOutlet NSToolbarItem *connectButton;
    IBOutlet RHLogView *logView;
    
    IBOutlet NSSplitView *logSplitView;
    IBOutlet NSView *topLogView;
    IBOutlet NSTextField *printStatusLabel;
    IBOutlet NSTextField *printTempLabel;
    IBOutlet NSProgressIndicator *printProgress;
    IBOutlet NSTextField *printFrames;
    IBOutlet NSTextField *gcodeText;
    IBOutlet NSScrollView *manualControlScroller;
    IBOutlet NSTabViewItem *gcodeTab;
    IBOutlet NSTabViewItem *printTab;
    IBOutlet NSTabViewItem *composerTab;
    NSImage *connectedImage,*disconnectedImage;
    NSImage *runJobIcon,*pauseJobIcon;
    NSImage *viewFilamentIcon,*hideFilamentIcon;
    IBOutlet PrinterSettingsController * printerSettingsController;
    IBOutlet NSWindow *window;
    ThreeDContainer *codePreview;
    ThreeDContainer *stlView;
    ThreeDContainer *printPreview;
    GCodeVisual *codeVisual;
    GCodeVisual *printVisual;
    IBOutlet ThreeDView *openGLView;
    IBOutlet RHActionTabDelegate *actionTabDelegate;
    EEPROMController *eepromController;
    SDCardManager *sdcardManager;
    IBOutlet NSToolbarItem *runJobButton;
    IBOutlet NSTabView *rightTabView;
    IBOutlet NSTabView *leftTabView;
    IBOutlet GCodeEditorController *gcodeView;
    IBOutlet NSToolbarItem *showFilamentButton;
    IBOutlet NSToolbarItem *killJobButton;
    IBOutlet LogSplitViewDelegate *logSplitDelegate;
    IBOutlet NSToolbar *toolbar;
    NSOpenPanel* openPanel;
    NSAlert *pausePanel;
    IBOutlet NSWindow *mainWindow;
    IBOutlet NSMenuItem *eepromMenuItem;
    Preferences *preferences;
    IBOutlet Slicer *slicer;
    IBOutlet Slic3rConfig *slic3r;
    IBOutlet NSMenuItem *openRecentSTLMenuItem;
    IBOutlet NSMenuItem *openRecentGCodeMenuItem;
    IBOutlet NSMenu *openRecentSTLMenu;
    IBOutlet NSMenu *openRecentGCodeMenu;
    RHFileHistory *stlHistory;
    RHFileHistory *gcodeHistory;
    IBOutlet STLComposer *composer;
    IBOutlet NSTabViewItem *threedViewTabItem;
    IBOutlet NSTabViewItem *temperatureTabItem;
    IBOutlet NSTextView *firstStepsText;
    IBOutlet RHTempertuareController *temperatureController;
    IBOutlet NSMenu *mainMenu;
    IBOutlet NSMenuItem *slicerMenu;
    IBOutlet EnableToollbarItem *emergencyButton;
    IBOutlet NSPanel *pausedPanel;
    IBOutlet NSTextField *pausedPanelText;
    NSButton *pausedPanelContinue;
    IBOutlet NSPanel *aboutPanel;
    IBOutlet NSTextView *creditsText;
    IBOutlet NSWindow *firstStepsWindow;
    IBOutlet NSTextField *firmwareLabel;
    IBOutlet RHManualControl *manualControl;
    IBOutlet NSScrollView *logScrollView;
    IBOutlet HorizontalSplitViewDelegate *editorSplitterDelegate;
    IBOutlet LogSplitViewDelegate *logSplitterDelegate;
}
@property (assign) IBOutlet NSWindow *window;
-(void)replaceGCodeView:(NSNotification*)event;
-(void)openRecentSTL:(NSMenuItem*)item;
-(void)openRecentGCode:(NSMenuItem*)item;
- (IBAction)toolConnect:(id)sender;
- (IBAction)openPrinterSettings:(id)sender;
-(void)printerInfoReceived:(NSNotification*)notification;
- (void)connectionOpened:(NSNotification *)notification;
-(void)temperatureRead:(NSNotification*)notification;
//@property (assign) IBOutlet NSScrollView *sendGCodeAction;
- (IBAction)toggleLog:(id)sender;
-(void)updateViewFilament;
- (IBAction)showEEPROM:(NSMenuItem *)sender;
- (IBAction)runJobAction:(id)sender;
- (IBAction)killJobAction:(id)sender;
- (IBAction)loadGCodeAction:(id)sender;
- (IBAction)sdCardAction:(id)sender;
- (IBAction)showFilamentAction:(NSToolbarItem *)sender;
- (void)connectionClosed:(NSNotification *)notification;
- (IBAction)showPreferences:(id)sender;
- (IBAction)emergencyAction:(id)sender;
-(void)updateJobButtons;
-(void)progressReceived:(NSNotification*)notification;
@property (unsafe_unretained) IBOutlet NSToolbarItem *toolbarConnect;
-(void)showWarning:(NSString*)warn headline:(NSString*)head;
- (IBAction)pausedPanelContinue:(id)sender;
- (IBAction)ShowHomepage:(id)sender;
- (IBAction)ShowManual:(id)sender;
- (IBAction)ShowForum:(id)sender;
- (IBAction)ShowSlic3rHomepage:(id)sender;
- (IBAction)ShowSkeinforgeHomepage:(id)sender;

@end

RHAppDelegate *app;

