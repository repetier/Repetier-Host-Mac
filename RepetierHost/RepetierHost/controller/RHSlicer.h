/*
 Copyright 2011 repetier repetierdev@gmail.com
 
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

@interface RHSlicer : NSView {
    NSView *view;
    NSButton *slic3rActive;
    NSButton *skeinforgeActive;
    NSPopUpButton *slic3rPrintSettings;
    NSPopUpButton *slic3rFilamentSettings;
    NSPopUpButton *slic3rPrinterSettings;
    NSPopUpButton *skeinforgeProfile;
    NSMutableArray *slic3rFilamentList;
    IBOutlet NSPopUpButton *slic3rFilamentSettings2;
    NSMutableArray *slic3rPrintList;
    NSMutableArray *slic3rPrinterList;
    NSMutableArray *skeinforgeProfileList;
    NSButton *runSlice;
    NSButtonCell *killButton;
    NSPopUpButton *slic3rFilamentSettings3;
}
@property (assign) IBOutlet NSPopUpButton *slic3rFilamentSettings3;

@property (assign) IBOutlet NSView *view;
@property (assign) IBOutlet NSButton *slic3rActive;
@property (assign) IBOutlet NSButton *skeinforgeActive;
@property (assign) IBOutlet NSPopUpButton *slic3rPrintSettings;
@property (assign) IBOutlet NSPopUpButton *slic3rFilamentSettings;
@property (assign) IBOutlet NSPopUpButton *slic3rPrinterSettings;
@property (assign) IBOutlet NSPopUpButton *skeinforgeProfile;
@property (retain) NSMutableArray *slic3rFilamentList;
@property (retain) NSMutableArray *slic3rPrintList;
@property (retain) NSMutableArray *slic3rPrinterList;
@property (retain) NSMutableArray *skeinforgeProfileList;
@property (assign) IBOutlet NSButton *runSlice;

- (IBAction)configureSlic3rAction:(id)sender;
- (IBAction)configureSkeinforgeAction:(id)sender;
- (IBAction)selectSlic3rAction:(id)sender;
- (IBAction)selectSkeinforgeAction:(id)sender;
- (IBAction)killAction:(id)sender;
-(void)updateSelections;
- (IBAction)sliceAction:(id)sender;
@property (assign) IBOutlet NSButtonCell *killButton;
-(void)slicerConfigToVariables;
+(NSString*)slic3rConfigDir;
@end
