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

@interface PrefTab : NSObject {
@public
    NSString *name;
    NSTabViewItem *tab;
    NSMutableArray *children;
    BOOL showAlphaColors;
}
-(void)addTab:(NSString*)tabName tab:(id)_tab;
-(void)addTabAlpha:(NSString*)tabName tab:(id)_tab;
-(int)numChildren;
@end

@interface Preferences : NSWindowController<NSOutlineViewDelegate> {
    @public
    NSMutableArray *groups;
    IBOutlet NSTabViewItem *skeinforgeTab;
    IBOutlet NSTabViewItem *slic3rTab;
    IBOutlet NSTabViewItem *editorTab;
    IBOutlet NSTabViewItem *threedSettingsTab;
    IBOutlet NSTabViewItem *threedColorsTab;
    IBOutlet NSTabViewItem *threedLights;
    IBOutlet NSTabViewItem *temperatureColorsTab;
    IBOutlet NSTabViewItem *loggingTab;
    IBOutlet NSTabViewItem *soundsTab;
    IBOutlet NSWindow *prefWindow;
    IBOutlet NSTabView *tabView;
    NSOpenPanel* openPanel;
    IBOutlet NSTextField *skeinforgeApplication;
    IBOutlet NSTextField *skeinforgeCraft;
    IBOutlet NSTextField *skeinforgePythonCraft;
    IBOutlet NSTextField *skeinforgePython;
    IBOutlet NSTextField *skeinforgeExtension;
    IBOutlet NSTextField *skeinforgePostfix;
    NSButton *browseSlic3rConfigFile;
    NSButton *browsePrintjobFinished;
    NSButton *browsePrintjobPaused;
}
- (IBAction)openSkeinforgeHomepage:(id)sender;
- (IBAction)openSlic3rHomepage:(id)sender;
- (IBAction)browseSkeinforgeApplication:(id)sender;
- (IBAction)browseSkeinforgeCraft:(id)sender;
- (IBAction)browseSkeinforgePython:(id)sender;
- (IBAction)testSkeinforge:(id)sender;
- (IBAction)browseSlic3rExecuteable:(id)sender;
- (IBAction)browseSlic3rConfigFile:(id)sender;
- (IBAction)playPrintjobFinished:(id)sender;
- (IBAction)playPrintjobPaused:(id)sender;
- (IBAction)playError:(id)sender;
- (IBAction)playCommand:(id)sender;
- (IBAction)browsePrintjobFinished:(id)sender;
- (IBAction)browsePrintjobPaused:(id)sender;
- (IBAction)browseError:(id)sender;
- (IBAction)browseCommand:(id)sender;
- (IBAction)browseSkeinforgePythonCraft:(id)sender;
- (IBAction)browseSkeinforgeProfiles:(id)sender;




@end
