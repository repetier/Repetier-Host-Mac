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


#import "GCodeEditorController.h"
#import "GCodeView.h"
#import "RHAppDelegate.h"
#import "GCodeVisual.h"
#import "RHOpenGLView.h"
#import "PrinterConfiguration.h"
#import "StringUtil.h"
#import "../models/PrinterConnection.h"

@implementation GCodeEditorController

@synthesize variableKeys;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if ([NSBundle loadNibNamed:@"GCodeEditor" owner:self])
    {
        [view setFrame:[self bounds]];
        [self addSubview:view];
        editor->controller = self;
        showMode = 0;
        printingTime = 0;
        triggerUpdate = YES;
        showMinLayer = showMaxLayer = maxLayer = 0;
        documents = [NSMutableArray new];
        gcode = [[GCodeContent alloc] initWithEditor:editor];
        prepend = [[GCodeContent alloc] initWithEditor:editor];
        append = [[GCodeContent alloc] initWithEditor:editor];
        killjob = [[GCodeContent alloc] initWithEditor:editor];
        pausejob = [[GCodeContent alloc] initWithEditor:editor];
        script1 = [[GCodeContent alloc] initWithEditor:editor];
        script2 = [[GCodeContent alloc] initWithEditor:editor];
        script3 = [[GCodeContent alloc] initWithEditor:editor];
        script4 = [[GCodeContent alloc] initWithEditor:editor];
        script5 = [[GCodeContent alloc] initWithEditor:editor];
        [documents addObject:gcode];
        [documents addObject:prepend];
        [documents addObject:append];
        [documents addObject:killjob];
        [documents addObject:pausejob];
        [documents addObject:script1];
        [documents addObject:script2];
        [documents addObject:script3];
        [documents addObject:script4];
        [documents addObject:script5];
        [gcode toActive];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(gcodeUpdateStatus:) name:@"RHGCodeUpdateStatus" object:nil];    
        [editor registerScrollView:scrollView];
        [self setContent:1 text:currentPrinterConfiguration->startCode];
        [self setContent:2 text:currentPrinterConfiguration->endCode];
        [self setContent:3 text:currentPrinterConfiguration->jobkillCode];
        [firstLayerSlider setAltIncrementValue:1];
        [lastLayerSlider setAltIncrementValue:1];
    }
    return self;
}

-(void)dealloc {
    [gcode release];
    [prepend release];
    [append release];
    [killjob release];
    [pausejob release];
    [script1 release];
    [script2 release];
    [script3 release];
    [script4 release];
    [script5 release];
    [documents release];
    [super dealloc];
}
-(void)awakeFromNib
{
}
-(int)showMinLayer {
    return showMinLayer;
}
-(void)setShowMinLayer:(int)lay {
    int old = showMinLayer;
    showMinLayer = MAX(0,MIN(maxLayer,lay));
    if(showMinLayer>showMaxLayer || (showMode==1 && showMinLayer!=showMaxLayer)) {
        triggerUpdate = NO;
        [self setShowMaxLayer:showMinLayer];
        triggerUpdate = YES;
    }
    if(showMode>0 && triggerUpdate && old!=showMinLayer)
        [editor triggerViewUpdate];
}
-(int)showMaxLayer {
    return showMaxLayer;
}
-(void)setShowMaxLayer:(int)lay {
    int old = showMaxLayer;
    showMaxLayer = MAX(0,MIN(maxLayer,lay));
    if(showMaxLayer<showMinLayer || (showMode==1 && showMinLayer!=showMaxLayer)) {
        triggerUpdate = NO;
        [self setShowMinLayer:showMaxLayer];
        triggerUpdate = YES;
    }
    if(showMode>0 && triggerUpdate && old!=showMaxLayer)
        [editor triggerViewUpdate];
}
-(int)showMode {
    return showMode;
}
-(void)setShowMode:(int)mode {
    showMode = mode;
    [editor triggerViewUpdate];
}
-(int)maxLayer {
    return maxLayer;
}
-(void)setMaxLayer:(int)lay {
    maxLayer = lay;
    if(showMinLayer>maxLayer)
        [self setShowMinLayer:maxLayer];
    if(showMaxLayer>maxLayer)
        [self setShowMaxLayer:maxLayer];
    
}
-(int)fileIndex {
    id obj = editor->cur;
    int idx = 0;
    for(GCodeContent *gc in documents) {
        if(gc == obj) break;
        idx++;
    }
    if(idx==0) return 1;
    if(idx==1) return 0;
    return idx;
}
-(void)gcodeUpdateStatus:(NSNotification*)event {
    [updateText setStringValue:event.object];
    if([event.object length]==0) {
        [editor updateLayer];
    }
}
-(void)loadGCode:(NSString*)file {
    [editor loadFile:file];
    [app->gcodeHistory add:file];
    [app->rightTabView selectTabViewItem:app->gcodeTab];
}
-(void)loadGCodeGCode:(NSString*)file {
    if(editor->cur!=gcode) {
        [fileSelector selectItemAtIndex:0];
        [editor->cur fromActive];
        editor->cur = gcode;
        [editor->cur toActive];
    }
    [editor loadFile:file];
    [app->gcodeHistory add:file];
    [app->rightTabView selectTabViewItem:app->gcodeTab];
}
- (void)drawRect:(NSRect)dirtyRect
{
    // Drawing code here.
}
-(NSString*)getContent:(int)idx
{
    GCodeContent *c = nil;
    switch(idx) {
        case 0:c = gcode;break;
        case 1:c = prepend;break;
        case 2:c = append;break;
        case 3:c = killjob;break;
        case 4:c = pausejob;break;
        case 5:c = script1;break;
        case 6:c = script2;break;
        case 7:c = script3;break;
        case 8:c = script4;break;
        case 9:c = script5;break;
        default:c = gcode;break;
    }
    return [c text];
}
-(NSMutableArray*)getContentArray
{
    NSInteger len = prepend->textArray.count+gcode->textArray.count
    +append->textArray.count;    
    NSMutableArray *updateCode = [[NSMutableArray alloc] initWithCapacity:len];
    [updateCode addObjectsFromArray:prepend->textArray];
    [updateCode addObjectsFromArray:gcode->textArray];
    [updateCode addObjectsFromArray:append->textArray];
    return [updateCode autorelease];
}
-(NSMutableArray*)getClonedContentArrayAtIndex:(int)idx {
    NSMutableArray *orig = [self getContentArrayAtIndex:idx];
    NSMutableArray *updateCode = [[NSMutableArray alloc] initWithCapacity:orig.count];
    [updateCode addObjectsFromArray:orig];
    return [updateCode autorelease];
}

- (IBAction)goFirstLayer:(id)sender {
    [editor goLayer:showMinLayer];
}

- (IBAction)goLastLayer:(id)sender {
    [editor goLayer:showMaxLayer+1];
}
-(NSMutableArray*)getContentArrayAtIndex:(int)idx
{
    return ((GCodeContent*)[documents objectAtIndex:idx])->textArray;
}
-(void)setContent:(int)idx text:(NSString*)text
{
    GCodeContent *c = nil;
    switch(idx) {
        case 0:c = gcode;break;
        case 1:c = prepend;break;
        case 2:c = append;break;
        case 3:c = killjob;break;
        case 4:c = pausejob;break;
        case 5:c = script1;break;
        case 6:c = script2;break;
        case 7:c = script3;break;
        case 8:c = script4;break;
        case 9:c = script5;break;
    }
    if(c==nil) return;
    if (c == editor->cur)
    {
        [editor setText:text];
    }
    else
    {
        [c setText:text];
    }
}

- (IBAction)save:(id)sender {
    if(editor->cur==gcode) {
        NSSavePanel *save = [NSSavePanel savePanel];
        [save setMessage:@"Save G-Code file"];
        [save setAllowedFileTypes:[NSArray arrayWithObject:@"gcode"]];
        [save beginSheetModalForWindow:app->mainWindow completionHandler:^(NSInteger result){
            if (result == NSFileHandlingPanelOKButton) {
                NSURL *url = [save URL];
                NSError *err = nil;
                [editor.text writeToURL:url atomically:YES encoding:NSUTF8StringEncoding error:&err];
            }        
        }];
    } else if(editor->cur==prepend) {
        [currentPrinterConfiguration setStartCode:editor.text];
        [currentPrinterConfiguration saveToRepository];
    } else if(editor->cur==append) {
        [currentPrinterConfiguration setEndCode:editor.text];
        [currentPrinterConfiguration saveToRepository];        
    } else if(editor->cur==killjob) {
        [currentPrinterConfiguration setJobkillCode:editor.text];
        [currentPrinterConfiguration saveToRepository];        
    } else if(editor->cur==pausejob) {
        [currentPrinterConfiguration setJobpauseCode:editor.text];
        [currentPrinterConfiguration saveToRepository];
    } else if(editor->cur==script1) {
        [currentPrinterConfiguration setScript1Code:editor.text];
        [currentPrinterConfiguration saveToRepository];
    } else if(editor->cur==script2) {
        [currentPrinterConfiguration setScript2Code:editor.text];
        [currentPrinterConfiguration saveToRepository];
    } else if(editor->cur==script3) {
        [currentPrinterConfiguration setScript3Code:editor.text];
        [currentPrinterConfiguration saveToRepository];
    } else if(editor->cur==script4) {
        [currentPrinterConfiguration setScript4Code:editor.text];
        [currentPrinterConfiguration saveToRepository];
    } else if(editor->cur==script5) {
        [currentPrinterConfiguration setScript5Code:editor.text];
        [currentPrinterConfiguration saveToRepository];
    }
}

- (IBAction)clear:(id)sender {
    [editor setText:@""];
}

- (IBAction)fileSelectionChanged:(id)sender {
    [editor->cur fromActive];
    editor->cur = [documents objectAtIndex:fileSelector.indexOfSelectedItem];
    [editor->cur toActive];
}

- (IBAction)showIconClicked:(id)sender {
    [editor->cur fromActive];
    [app->codeVisual parseTextArray:prepend->textArray clear:YES];
    [app->codeVisual parseTextArray:gcode->textArray clear:NO];
    [app->codeVisual parseTextArray:append->textArray clear:NO];
    [app->codeVisual stats];
    [app->codeVisual reduce];
    [app->codeVisual stats];
    [app->openGLView redraw];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
    self.variableKeys = [[connection.variables allKeys] sortedArrayUsingSelector: @selector(compare:)];
    return connection.variables.count;
}
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)col row:(NSInteger)rowIndex {
    if(col==app->gcodeView->variablesVarCol) {
        return [self.variableKeys objectAtIndex:rowIndex];
    }
    NSObject *obj = [connection.variables objectForKey:[self.variableKeys objectAtIndex:rowIndex]];
    if(obj) return obj;
    return @"";
}
- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
    NSInteger row = [variablesTable.tableView selectedRow];
    if(row<variableKeys.count) {
        NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
        [pasteboard clearContents];
        NSArray *copiedObjects = [NSArray arrayWithObject:[variableKeys objectAtIndex:row]];
        [pasteboard writeObjects:copiedObjects];
    }
}
@end
