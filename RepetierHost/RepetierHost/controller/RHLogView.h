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
@class RHLogEntry;
@interface RHLogView : NSView {
    @public
    int topRow;
    int row;
    int selRow;
    BOOL hasSel, forceSel;
    int rowsVisible,colsVisible;
    NSScrollView *scrollView;
    NSFont *drawFont;
    NSColor *normalBrush;
    NSColor *infoBrush;
    NSColor *warningBrush;
    NSColor *errorBrush;
    NSColor *linesBgColor;
    NSColor *linesTextColor;
    NSColor *backBrush;
    NSColor *evenBackBrush;
    NSColor *selectionBrush;
    NSColor *selectionTextBrush;
    float fontHeight;
    float fontWidth;
    BOOL hasFocus;
    int linesWidth;
    int maxLines;
    BOOL ignoreMouseDown;
    BOOL ignoreScrollChange;
    BOOL autoscroll;
    NSMutableArray *lines;
    NSMutableDictionary *fontAttributes;
    NSArray *bindingsArray;
    NSTimer *timer;
    BOOL changed;
    NSLock *linesLock;
    BOOL inDrawRect;
}
@property (retain)NSColor *normalBrush;
@property (retain)NSColor *infoBrush;
@property (retain)NSColor *warningBrush;
@property (retain)NSColor *errorBrush;
@property (retain)NSColor *linesBgColor;
@property (retain)NSColor *linesTextColor;
@property (retain)NSColor *backBrush;
@property (retain)NSColor *evenBackBrush;
@property (retain)NSColor *selectionBrush;
@property (retain)NSColor *selectionTextBrush;
-(void)addLine:(RHLogEntry*)l;
-(void)clear;
-(void)setupColor;
-(void)updateBox;
-(void)scrollBottom;
-(void)positionShowCursor:(BOOL)repaint moved:(BOOL)moved;
-(void)positionShowCursor;
-(BOOL)hasSelection;
-(NSString*)getSelection;
- (void)copy:(id)sender;
@end
