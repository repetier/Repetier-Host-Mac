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
#import "GCodeVisual.h"

@class GCodeUndo;
@class GCodeContent;
@class GCodeEditorController;

@interface GCodeView : NSView {
@public
    GCodeEditorController *controller;
    GCodeContent *cur;
    NSTimer *timer;
    NSScrollView *scrollView;
    NSUInteger row,col;
    NSUInteger selRow,selCol;
    NSUInteger topRow,topCol;
    NSUInteger maxCol;
    int changedCounter;
    BOOL mustUpdate;
    BOOL hasSel, forceSel;
    BOOL focused;
    BOOL blink;
    BOOL overwrite;
    int rowsVisible,colsVisible;
    NSFont *drawFont;
    NSColor *blackBrush;
    NSColor *normalBrush;
    NSColor *commandBrush;
    NSColor *hostCommandBrush;
    NSColor *paramBrush;
    NSColor *commentBrush;
    NSColor *linesBgBrush;
    NSColor *linesTextBrush;
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
    NSString *lastHelpCommand;
    NSMutableArray *lines;
    NSMutableDictionary *fontAttributes;
    NSMutableDictionary *selectionAttributes;
    IBOutlet NSScrollView *scollView;
    IBOutlet NSTextField *helpText;
    IBOutlet NSButton *undoButton;
    IBOutlet NSButton *redoButton;
    IBOutlet NSTextField *rowText;
    IBOutlet NSTextField *colText;
    IBOutlet NSTextField *updateText;
    NSArray *bindingsArray;
    GCodeVisual *nextView;
    NSMutableArray *updateCode;
    NSThread *updateViewThread;
}
@property (retain)NSString* lastHelpCommand;
@property (retain)NSColor *selectionBrush;
@property (retain)NSColor *selectionTextBrush;
@property (retain)NSColor *normalBrush;
@property (retain)NSColor *commandBrush;
@property (retain)NSColor *hostCommandBrush;
@property (retain)NSColor *paramBrush;
@property (retain)NSColor *commentBrush;
@property (retain)NSColor *linesBgBrush;
@property (retain)NSColor *backBrush;
@property (retain)NSColor *evenBackBrush;
@property (retain)NSColor *linesTextBrush;

-(void)setupColor;
-(id)initWithFrame:(NSRect)frameRect;
-(BOOL)loadFile:(NSString*)path;
-(void)scrollBottom;
-(void)changed;
-(void)appendLine:(NSString*)l;
-(void)positionShowCursor:(BOOL)repaint moved:(BOOL)moved;
-(void)positionShowCursor;
-(NSString*)text;
-(void)setText:(NSString*)value;
-(void)positionCursor;
-(void)cursorDown;
-(void)cursorPageDown;
-(void)cursorPageUp;
-(void)cursorUp;
-(void)cursorEnd;
-(void)cursorStart;
-(BOOL)cursorLeft;
-(void)cursorRight;
-(void)insertChar:(NSString*) c;
-(void)deleteSelectionRedraw:(BOOL)redraw;
-(NSString*)getSelection;
-(void)insertString:(NSString*)s;
-(void)insertChar:(NSString*)c;
-(BOOL)hasSelection;
-(void)positionCursor;
-(void)backspace;
-(void)deleteChar;
-(void)updateHelp;
-(void)registerScrollView:(NSScrollView*)v;

@end

@interface GCodeUndo : NSObject {
@public
    NSUInteger col, row, selCol, selRow;
    NSString *text,*oldtext;
}
-(id) initFromText:(NSString*)t orig:(NSString*)ot col:(NSUInteger)c row:(NSUInteger)r selCol:(NSUInteger)sc selRow:(NSUInteger)sr;
-(void)deleteSelection:(GCodeView*)e colStart:(NSUInteger)cstart rowStart:(NSUInteger)rstart colEnd:(NSUInteger)cend rowEnd:(NSUInteger)rend;
-(void)insertString:(NSString*)s editor:(GCodeView*)e;
-(void)endPos:(NSString*)s resCol:(NSUInteger*)cpos resRow:(NSUInteger*)rpos editor:(GCodeView*)e;
-(void)undoAction:(GCodeView*)e;
-(void)redoAction:(GCodeView*)e;
@end

@interface GCodeContent : NSObject {
@public
    //NSString *text;
    NSUInteger col, row, selCol, selRow;
    NSUInteger topRow, topCol,maxCol;
    BOOL hasSel;
    RHLinkedList *undo;
    RHLinkedList *redo;
    GCodeView *editor;
    NSMutableArray *textArray;
    NSString *name;
    int etype; // 0 = G-Code, 1 = prepend, 2 = append
}
@property (retain)NSString *name;
//@property (retain)NSString *text;

-(id)initWithEditor:(GCodeView*)ed;
-(void)toActive;
-(void)fromActive;
-(void)setText:(NSString*)value;
-(void)resetPos;
-(void)clearUndo;
-(void)addUndo:(GCodeUndo*) u;
-(void)redo;
-(void)undo;
-(void)updateUndoButtons;
@end
