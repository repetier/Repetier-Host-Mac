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

@implementation GCodeEditorController

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if ([NSBundle loadNibNamed:@"GCodeEditor" owner:self])
    {
        [view setFrame:[self bounds]];
        [self addSubview:view];
        editor->controller = self;
        documents = [NSMutableArray new];
        gcode = [[GCodeContent alloc] initWithEditor:editor];
        prepend = [[GCodeContent alloc] initWithEditor:editor];
        append = [[GCodeContent alloc] initWithEditor:editor];
        [documents addObject:gcode];
        [documents addObject:prepend];
        [documents addObject:append];
        editor->cur = gcode;
        [editor setText:@""];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(gcodeUpdateStatus:) name:@"RHGCodeUpdateStatus" object:nil];    
        [editor registerScrollView:scrollView];
        [self setContent:1 text:currentPrinterConfiguration->startCode];
        [self setContent:2 text:currentPrinterConfiguration->endCode];
    }
    return self;
}

-(void)dealloc {
    [documents release];
    [super dealloc];
}
-(void)awakeFromNib
{
}
-(void)gcodeUpdateStatus:(NSNotification*)event {
    [updateText setStringValue:event.object];
}
-(void)loadGCode:(NSString*)file {
    editor->cur = gcode;
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
    }
    if (c == editor->cur) return editor.text;
    return c.text;
}
-(void)setContent:(int)idx text:(NSString*)text
{
    GCodeContent *c = nil;
    switch(idx) {
        case 0:c = gcode;break;
        case 1:c = prepend;break;
        case 2:c = append;break;
    }
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
    [app->codeVisual parseText:prepend->text clear:YES];
    [app->codeVisual parseText:gcode->text clear:NO];
    [app->codeVisual parseText:append->text clear:NO];
    [app->codeVisual stats];
    [app->codeVisual reduce];
    [app->codeVisual stats];
    [app->openGLView redraw];
}
@end
