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

@class GCodeView;
@class GCodeContent;

@interface GCodeEditorController : NSView {
    @public
    IBOutlet NSView *view;
    IBOutlet GCodeView *editor;
    NSMutableArray *documents;
    GCodeContent *prepend;
    GCodeContent *append;
    GCodeContent *gcode;
    IBOutlet NSPopUpButton *fileSelector;
    IBOutlet NSTextField *updateText;
    IBOutlet NSScrollView *scrollView;
    IBOutlet NSTextField *layerText;
    IBOutlet NSTextField *firstLayerText;
    IBOutlet NSTextField *lastLayerText;
    IBOutlet NSSlider *firstLayerSlider;
    IBOutlet NSSlider *lastLayerSlider;
    IBOutlet NSTabView *layerCountText;
    IBOutlet NSButtonCell *showCompleteCodeRadio;
    IBOutlet NSButtonCell *showSingleLayer;
    IBOutlet NSButtonCell *showLayerRangeRadio;
    int showMinLayer,showMaxLayer,maxLayer;
    int showMode;
    BOOL triggerUpdate;
}
-(int)showMode;
-(void)setShowMode:(int)mode;
-(int)maxLayer;
-(void)setMaxLayer:(int)lay;
-(int)showMinLayer;
-(void)setShowMinLayer:(int)lay;
-(int)showMaxLayer;
-(void)setShowMaxLayer:(int)lay;
-(void)gcodeUpdateStatus:(NSNotification*)event;
-(void)loadGCode:(NSString*)file;
-(void)loadGCodeGCode:(NSString*)file;
- (IBAction)fileSelectionChanged:(id)sender;
- (IBAction)showIconClicked:(id)sender;
-(NSString*)getContent:(int)idx;
-(NSMutableArray*)getContentArray;
-(void)setContent:(int)idx text:(NSString*)text;
- (IBAction)save:(id)sender;
- (IBAction)clear:(id)sender;

@end
