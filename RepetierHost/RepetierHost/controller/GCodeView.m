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

#import "GCodeView.h"
#import "StringUtil.h"
#import "Commands.h"
#import "DefaultsExtension.h"
#import "GCodeEditorController.h"
#import "ThreadedNotification.h"
#import "RHAppDelegate.h"
#import "ThreeDConfig.h"
#import "GCodeShort.h"

@implementation GCodeView

@synthesize lastHelpCommand;
@synthesize selectionBrush;
@synthesize selectionTextBrush;
@synthesize normalBrush;
@synthesize commandBrush;
@synthesize hostCommandBrush;
@synthesize paramBrush;
@synthesize commentBrush;
@synthesize linesBgBrush;
@synthesize linesTextBrush;
@synthesize backBrush;
@synthesize evenBackBrush;

-(id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    return self;
}
-(void)awakeFromNib {
    if(drawFont==nil) {
        // Initialization code here.
        row = 0;
        selRow = 0;
        changedCounter = 4;
        hasSel = NO;
        forceSel = NO;
        mustUpdate = NO;
        rowsVisible = 10;
        colsVisible = 7;
        maxCol = 6;
        maxLines = 2000;
        focused = NO;
        blink = YES;
        nextView = nil;
        updateViewThread = nil;
        updateCode = nil;
        overwrite = NO;
        drawFont = [[NSFont userFixedPitchFontOfSize:12] retain];
        blackBrush = [[NSColor blackColor] retain];
        lines = nil; //[NSMutableArray new];
        fontAttributes = [[NSMutableDictionary alloc] init];
        [fontAttributes setObject:drawFont forKey:NSFontAttributeName];
        selectionAttributes = [NSMutableDictionary new];
        [selectionAttributes setObject:drawFont forKey:NSFontAttributeName];
        [self setupColor];
        
        NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
        //threedFacesColor
        NSArray *arr = [NSArray arrayWithObjects:@"editorCommandColor",
                        @"editorParameterIndicatorColor",@"editorParameterValueColor",@"editorCommentColor",  
                        @"editorHostCommandColor",@"editorLineBackgroundColor",
                        @"editorLineTextColor",@"editorSelectedTextColor",@"editorSelectedBackgroundColor",@"editorBackgroundOddColor",
                        @"editorBackgroundEvenColor",nil];
        bindingsArray = arr.retain;
        for(NSString *key in arr)
            [d addObserver:self forKeyPath:key options:NSKeyValueObservingOptionNew context:NULL];
        
        
        hasFocus = NO;
        ignoreMouseDown = NO;
        ignoreScrollChange = NO;
        autoscroll = YES;
        NSSize sz = [@"00000000 " sizeWithAttributes:fontAttributes];
        fontWidth = ceil(sz.width/9)+1;
        fontHeight = ceilf(sz.height);
        linesWidth = ceilf(sz.width)+1;
        [self setLastHelpCommand:@""];
        timer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(timerFired:) userInfo:nil repeats:YES];
    }
}
-(void)registerScrollView:(NSScrollView*)v {
    scrollView = v;
    [scrollView setVerticalLineScroll:fontHeight];
    [scrollView setVerticalPageScroll:10];
    [self scrollPoint:NSMakePoint(0,0)]; 
}
-(void)dealloc {
    for(NSString *key in bindingsArray)
        [NSUserDefaults.standardUserDefaults removeObserver:self
                                                 forKeyPath:key];
    [bindingsArray release];
    [timer invalidate];
    [timer release];
    //[lines release];
    [fontAttributes release];
    [selectionAttributes release];
    [drawFont release];
    [lastHelpCommand release];
    [super dealloc];
}
-(void)gcodeUpdateStatuse:(NSNotification*)event {
    
}
-(void)setupColor {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    [self setCommandBrush:[d colorForKey:@"editorCommandColor"]];
    [self setParamBrush:[d colorForKey:@"editorParameterIndicatorColor"]];
    [self setNormalBrush:[d colorForKey:@"editorParameterValueColor"]];
    [self setHostCommandBrush:[d colorForKey:@"editorHostCommandColor"]];
    [self setLinesBgBrush:[d colorForKey:@"editorLineBackgroundColor"]];
    [self setLinesTextBrush:[d colorForKey:@"editorLineTextColor"]];
    [self setSelectionTextBrush:[d colorForKey:@"editorSelectedTextColor"]];
    [self setSelectionBrush:[d colorForKey:@"editorSelectedBackgroundColor"]];
    [self setBackBrush:[d colorForKey:@"editorBackgroundOddColor"]];
    [self setEvenBackBrush:[d colorForKey:@"editorBackgroundEvenColor"]];
    [self setCommentBrush:[d colorForKey:@"editorCommentColor"]];
    [selectionAttributes setObject:selectionTextBrush forKey:NSForegroundColorAttributeName];
}
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    [self setupColor];
    [self setNeedsDisplay:YES];
}
-(void)timerFired :(NSTimer*)timer {
    blink = !blink;
    if(changedCounter>0) {
        changedCounter--;
       // if(changedCounter==0 && contentChangedEvent!=null)
       //     contentChangedEvent();
    }
    if(updateCode==nil && changedCounter==0 && mustUpdate && nextView==nil) {
        mustUpdate = NO; 
        //[cur fromActive];        
        updateCode = [[controller getContentArray] retain];
        nextView = [[GCodeVisual alloc] init];
        updateViewThread = [[NSThread alloc] initWithTarget:self
                                              selector:@selector(updateViewThread) object:nil];
        [updateViewThread start];
    }
    if(focused && col>=topCol && row>=topRow && row<=topRow+rowsVisible+1)
        [self setNeedsDisplay:YES];
}
-(void)triggerViewUpdate{
    if(nextView==nil) {
        mustUpdate = NO; 
        //[cur fromActive];        
        updateCode = [[controller getContentArray] retain];
        nextView = [[GCodeVisual alloc] init];
        updateViewThread = [[NSThread alloc] initWithTarget:self
                                                   selector:@selector(updateViewThread) object:nil];
        [updateViewThread start];        
    } else {
        changedCounter=0;
        mustUpdate = YES;
    }
}
-(void) updateViewThread
{
    [ThreadedNotification notifyASAP:@"RHGCodeUpdateStatus" object:@"Updating..."];
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    GCodeVisual *v = nextView;
    //double start = CFAbsoluteTimeGetCurrent();
    if(controller->showMode==1) {
        v->minLayer = v->maxLayer = controller->showMinLayer;
    } else if(controller->showMode==2) {
        v->minLayer = controller->showMinLayer;
        v->maxLayer = controller->showMaxLayer;
    }
    [v parseGCodeShortArray:updateCode clear:YES];
    [controller setMaxLayer:nextView->ana->layer];
    //double red = CFAbsoluteTimeGetCurrent();
    [v reduce];
    if(!conf3d->disableFilamentVisualization)
        [ThreadedNotification notifyASAP:@"RHReplaceGCodeView" object:nextView];
    [updateCode release];
    [v release];
    if(conf3d->disableFilamentVisualization)
        nextView = nil; // do it only if visualization is disabled
    updateCode = nil;
    [updateViewThread release];
    updateViewThread = nil;
    //nextView = nil; now done if displayed.
    //red = 1000*(CFAbsoluteTimeGetCurrent()-red);
    //start = 1000*(CFAbsoluteTimeGetCurrent()-start);    
    //NSLog(@"update finished red = %f total = %f",red,start);
    [ThreadedNotification notifyASAP:@"RHGCodeUpdateStatus" object:@""];
    [pool release];
}

-(BOOL)becomeFirstResponder {
    focused = YES;
    return YES;
}
-(BOOL)resignFirstResponder {
    focused = NO;
    if(blink)
        [self setNeedsDisplay:YES];
    return YES;
}
-(BOOL)isFlipped {return YES;}
-(void)clear
{
    [lines removeAllObjects];
    row = col = topRow = topCol = 0;
    maxCol=1;
    hasSel = YES;
    [self appendLine:@""];
    [self positionShowCursor:YES moved:NO];
    [self changed];
}
-(void)changed {
    changedCounter = 2;
    mustUpdate = YES;
}
-(void)appendLine:(NSString*)l
{
    [lines addObject:[GCodeShort codeWith:l]];
    maxCol = MAX(maxCol, l.length);
    //scrollRows.Maximum = lines.Count;
}
-(NSString*)text {
    NSMutableString *s = [NSMutableString new];
    for(GCodeShort *c in lines) {
        [s appendString:c->text];
        [s appendString:@"\n"];
    }
    return [s autorelease];
}
-(void)setText:(NSString*)value {
    [cur clearUndo];
    value = [StringUtil normalizeLineends:value];
    [self clear];
    [lines removeAllObjects];
     maxCol = 1;
    NSArray *la = [value componentsSeparatedByString:@"\n"];
    if (la.count == 0) [self appendLine:@""];
    else for (NSString *s in la) {
        [lines addObject:[GCodeShort codeWith:s]];
        maxCol =MAX(maxCol, s.length);
    }
    [self scrollPoint:NSMakePoint(0,0)]; 
    //    scrollRows.Maximum = lines.Count();
    row = col = topRow = topCol = selRow = selCol = 0;
    hasSel = YES;
    //editor.Focus();
    //CreateCursor();
    [self positionShowCursor:YES moved:NO];
    [self changed];
}
-(void) drawRow:(int)line y:(float)yPos
{
    NSString *text = ((GCodeShort*)([lines objectAtIndex:line]))->text;
    NSSize size = [self bounds].size;
    NSColor *fontBrush = normalBrush;
    [((line & 1)!=0 ? evenBackBrush : backBrush) set];
    float s1 = -1, s2 = -1;   
    NSString *linenumber = [NSString stringWithFormat:@"%d",line+1];
    [NSBezierPath fillRect:NSMakeRect(linesWidth-1,yPos,size.width-linesWidth, fontHeight)];
    [fontAttributes setObject:linesTextBrush forKey:NSForegroundColorAttributeName];
    NSSize lineSize = [linenumber sizeWithAttributes:fontAttributes];
    [linenumber drawAtPoint:NSMakePoint(linesWidth-fontWidth-1-lineSize.width,yPos) withAttributes:fontAttributes];
    [fontAttributes setObject:fontBrush forKey:NSForegroundColorAttributeName];
   // [lent.message drawAtPoint:NSMakePoint(linesWidth+fontWidth,yPos) withAttributes:fontAttributes];
    

    NSUInteger minc=-1,maxc=-1;
    if (line >= MIN(row, selRow) && line <= MAX(row, selRow))
    { // mark selection
        if(row<selRow || (row==selRow && col<selCol)) {
            minc = col;
            maxc=selCol;
        } else {
            minc = selCol;
            maxc=col;
        }
        if (line > MIN(row, selRow)) {minc=0;s1 = linesWidth;}
        else s1 = linesWidth-1 + minc * fontWidth;
        if(line<MAX(row,selRow)) {s2 = size.width;maxc=10000;}
        else s2 = linesWidth + maxc*fontWidth-1;
        [selectionBrush set];
         [NSBezierPath fillRect:NSMakeRect(s1,yPos,s2-s1, fontHeight)];
    }
    float ps = linesWidth;
    int i,ac=0;
    NSString *comment = @"";
    NSString *command = @"";
    NSString *parameter = @"";
    NSRange p;
    if(text.length>0 && [text characterAtIndex:0]=='@') { // Host command
        [fontAttributes setObject:hostCommandBrush forKey:NSForegroundColorAttributeName];
        for (i = 0; i < text.length; i++)
        {           
            NSString *c = [text substringWithRange:NSMakeRange(i,1)];
            [c drawAtPoint:NSMakePoint(ps,yPos) withAttributes:(ac>=minc && ac<maxc ? selectionAttributes: fontAttributes)];
            ac++;
            ps += fontWidth;
        }
        return;
    }
    p = [text rangeOfString:@";"];
    if (p.location != NSNotFound)
    {
        comment = [text substringFromIndex:p.location];
        text = [text substringToIndex:p.location];
    }
    p = [text rangeOfString:@" "];
    if (p.location == NSNotFound) {
        command = text;
    } else {
        parameter = [text substringFromIndex:p.location];
        command = [text substringToIndex:p.location];
    }
    if (command.length > 0)
    {
        [fontAttributes setObject:commandBrush forKey:NSForegroundColorAttributeName];
        for (i = 0; i < command.length; i++)
        {           
            NSString *c = [command substringWithRange:NSMakeRange(i,1)];
            [c drawAtPoint:NSMakePoint(ps,yPos) withAttributes:(ac>=minc && ac<maxc ? selectionAttributes: fontAttributes)];
            ac++;
            ps += fontWidth;
        }
    }
    if (parameter.length > 0)
    {
        for (i = 0; i < parameter.length; i++) {
            NSString *c = [parameter substringWithRange:NSMakeRange(i,1)];
            int ch=[c characterAtIndex:0];
            if((ch>='A' && ch<='Z') || (ch>='a' && ch<='z')) 
                [fontAttributes setObject:paramBrush forKey:NSForegroundColorAttributeName];
            else
                [fontAttributes setObject:normalBrush forKey:NSForegroundColorAttributeName];
            [c drawAtPoint:NSMakePoint(ps,yPos) withAttributes:(ac>=minc && ac<maxc ? selectionAttributes: fontAttributes)];
            ac++;
            ps += fontWidth;
        }
    }
    if (comment.length > 0)
    {
        [fontAttributes setObject:commentBrush forKey:NSForegroundColorAttributeName];
        for (i = 0; i < comment.length; i++)
        {
            NSString *c = [comment substringWithRange:NSMakeRange(i,1)];
            [c drawAtPoint:NSMakePoint(ps,yPos) withAttributes:(ac>=minc && ac<maxc ? selectionAttributes: fontAttributes)];
            ac++;
            ps += fontWidth;
        }
    }
}
- (void)drawRect:(NSRect)dirtyRect
{   

    // Draw background
    NSRect bounds = [scrollView documentVisibleRect];
    NSRect visibleBounds = [self.enclosingScrollView bounds];
    rowsVisible = (int)floor(visibleBounds.size.height / fontHeight);
    colsVisible = (int)floor((double)(visibleBounds.size.width - linesWidth) / fontWidth)-1;
    topRow = bounds.origin.y/fontHeight;
    [scrollView setVerticalPageScroll:MAX(1,rowsVisible-3)*fontHeight];
    bounds = dirtyRect;
    int firstLine = floor(bounds.origin.y/fontHeight);
    int lastLine =ceil((bounds.origin.y+bounds.size.height)/fontHeight);
    if(lastLine>=lines.count)
        lastLine = (int)lines.count-1;
    [linesBgBrush set];
    [NSBezierPath fillRect:NSMakeRect(0,firstLine*fontHeight,linesWidth-1,MAX(bounds.size.height,(lastLine-firstLine+1)*fontHeight))];
    //[backBrush set];
    //[NSBezierPath fillRect:NSMakeRect(linesWidth,0,bounds.size.width-linesWidth,bounds.size.height)];
    for (int r = firstLine; r <= lastLine; r++)
    {
        [self drawRow:r y:r * fontHeight];
    }
    
    if (blink && focused && col>=topCol && row>=topRow && row<=topRow+rowsVisible+1)
    {
        float x, y;
        x = (linesWidth + (col) * fontWidth);
        y = ((row) * fontHeight);
        [blackBrush set];
        [NSBezierPath fillRect:NSMakeRect(x,y,1,fontHeight)];
       /* if (_overwrite)
        {
            g.DrawLine(cursorBrush,x, y + fontHeight,x+fontWidth,y+fontHeight);
            g.DrawLine(cursorBrush, x + fontWidth, y + fontHeight,x+fontWidth, y);
            g.DrawLine(cursorBrush, x + fontWidth, y,x, y);
        }*/
    }
}
-(void)mouseDragged:(NSEvent *)event
{
    NSPoint dragLocation;
    dragLocation=[self convertPoint:[event locationInWindow]
                           fromView:nil];
    
    row = MAX(0, MIN(lines.count - 1, (int)(dragLocation.y / fontHeight)));
    col = MAX(0, MIN([[lines objectAtIndex:row] length],(int)(floor((dragLocation.x - linesWidth) / fontWidth))));
       // if (row < topRow + 3 && topRow > 0) topRow--;
       // if (row > topRow - 4 + rowsVisible && topRow + rowsVisible - 3 < lines.count) topRow++;
    hasSel = YES;
    [self setNeedsDisplay:YES];
    [self positionCursor];
    // support automatic scrolling during a drag
    // by calling NSView's autoscroll: method
    [self autoscroll:event];
    
    // act on the drag as appropriate to the application
}
- (void)mouseDown:(NSEvent *)theEvent
{
   // if (ignoreMouseDown) return;
   // Focus();
    //CreateCursor();
    NSPoint e=[self convertPoint:[theEvent locationInWindow] fromView:nil];
    if ([NSEvent modifierFlags] & NSShiftKeyMask)
    {
        row = (NSUInteger)MAX(0,MIN(lines.count-1, (e.y / fontHeight)));
        if(e.x<=linesWidth)
            col = 0;
        else
        col = MAX(0,MIN([[lines objectAtIndex:row] length], (round((e.x - linesWidth) / fontWidth))));
    }
    else
    {
        row = selRow = MAX(0, MIN(lines.count - 1,  (int)(e.y / fontHeight)));
        if(e.x<=linesWidth)
            col = selCol = 0;
        else
            col = selCol = MAX(0, MIN([[lines objectAtIndex:row] length], (int)(round((e.x - linesWidth) / fontWidth))));
    }
    [self positionCursor];    
    
}
- (BOOL)acceptsFirstResponder
{
    return YES;
}
-(BOOL)acceptsFirstMouse {
    return YES;
}
- (void)copy:(id)sender {
    if(self.hasSelection) {
        NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
        [pasteboard clearContents];
        NSArray *copiedObjects = [NSArray arrayWithObject:self.getSelection];
        [pasteboard writeObjects:copiedObjects];
    }
}
- (void)cut:(id)sender {
    if(self.hasSelection) {
        NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
        [pasteboard clearContents];
        NSArray *copiedObjects = [NSArray arrayWithObject:self.getSelection];
        [pasteboard writeObjects:copiedObjects];
        [self deleteSelectionRedraw:YES];
    }    
}
- (void)paste:(id)sender {
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    NSArray *classArray = [NSArray arrayWithObject:[NSString class]];
    NSDictionary *options = [NSDictionary dictionary];
    
    BOOL ok = [pasteboard canReadObjectForClasses:classArray options:options];
    if (ok) {
        NSArray *objectsToPaste = [pasteboard readObjectsForClasses:classArray options:options];
        NSString *text = [objectsToPaste objectAtIndex:0];
        [self insertString:text];
    }    
}
- (void)selectAll:(id)sender {
    selCol = 0;
    selRow = 0;
    row = MAX(0, lines.count - 1);
    col = [[lines objectAtIndex:row] length];
    forceSel = YES;
    [self positionShowCursor:YES moved:YES];
    forceSel = NO;
    hasSel = YES;    
}
-(void)delete:(id)sender {
    if (self.hasSelection)
    {
        [self deleteSelectionRedraw:YES];
    }
    else
    {
        [self backspace];
    }    
}
-(void)undo:(id)sender {
   [cur undo]; 
}
-(void)redo:(id)sender {
   [cur redo]; 
}
- (void)keyDown:(NSEvent *)theEvent
{
  // NSLog( @"key down %d / %@ / %@",(int)theEvent.keyCode,[theEvent characters],[theEvent charactersIgnoringModifiers] );
    NSUInteger mod = [NSEvent modifierFlags];
    BOOL handled = NO;
    NSString *c = [theEvent characters];
    
    switch (theEvent.keyCode)
    {
        case 125: // down
            [self cursorDown];
            handled = YES;
            break;
        case 126: // up
            [self cursorUp];
            handled = YES;
            break;
        case 123: // left
            [self cursorLeft];
            handled = YES;
            break;
        case 124: // right
            [self cursorRight];
            handled = YES;
            break;
        case 119: // End
            [self cursorEnd];
            handled = YES;
            break;
        case 115: // Home
            [self cursorStart];
            handled = YES;
            break;
        case 121: //PageDown
            [self cursorPageDown];
            handled = YES;
            break;
        case 116: // PageUp
            [self cursorPageUp];
            handled = YES;
            break;
        case 36: // Return
            [self insertString:@"\n\n"];
            handled = YES;
            break;
        case 117: // Delete
            if (self.hasSelection)
            {
                [self deleteSelectionRedraw:YES];
            }
            else
            {
                [self deleteChar];
            }
            handled = YES;
            break;
        case 51: // Back
            if (self.hasSelection)
            {
                [self deleteSelectionRedraw:YES];
            }
            else
            {
                [self backspace];
            }
            handled = YES;
            break;
      /*  case Keys.Insert:
            overwrite = !overwrite;
            break;*/
        case 0: //Keys.A:
            if (mod & NSCommandKeyMask)
            {
                selCol = 0;
                selRow = 0;
                row = MAX(0, lines.count - 1);
                col = [[lines objectAtIndex:row] length];
                forceSel = YES;
                [self positionShowCursor:YES moved:YES];
                forceSel = NO;
                hasSel = YES;
                handled = YES;
            }
            break;
        case 8: //Keys.C:
            if (mod & NSCommandKeyMask)
            {
                if(self.hasSelection) {
                    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
                    [pasteboard clearContents];
                    NSArray *copiedObjects = [NSArray arrayWithObject:self.getSelection];
                    [pasteboard writeObjects:copiedObjects];
                }
                 //   Clipboard.SetText(getSelection());
                handled = YES;
            }
            break;
        case 9: //Keys.V:
            if(mod & NSCommandKeyMask) {
                NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
                NSArray *classArray = [NSArray arrayWithObject:[NSString class]];
                NSDictionary *options = [NSDictionary dictionary];
                
                BOOL ok = [pasteboard canReadObjectForClasses:classArray options:options];
                if (ok) {
                    NSArray *objectsToPaste = [pasteboard readObjectsForClasses:classArray options:options];
                    NSString *text = [objectsToPaste objectAtIndex:0];
                    [self insertString:text];
                }
                handled = YES;
            }
            break;
        case 7: //Keys.X:
            if (mod & NSCommandKeyMask)
            {
                if(self.hasSelection) {
                    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
                    [pasteboard clearContents];
                    NSArray *copiedObjects = [NSArray arrayWithObject:self.getSelection];
                    [pasteboard writeObjects:copiedObjects];
                    [self deleteSelectionRedraw:YES];
                }
                handled = YES;
            }
            break;
    
    }
    if(!handled) {
        if (mod & NSCommandKeyMask && [c compare:@"z"]==NSOrderedSame)
        {
            [cur undo];
            handled = YES;
        }
        else if (mod & NSCommandKeyMask && [c compare:@"y"]==NSOrderedSame)
        {
            [cur redo];
            handled = YES;
        } else if((mod & (NSCommandKeyMask | NSControlKeyMask))==0 && c.length>0) {
            [self insertString:c];
            handled = YES;
        }
               
    }
    if(!handled)
        [super keyDown:theEvent];
}
-(BOOL)loadFile:(NSString*)path {
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL fileExists = [fm fileExistsAtPath:path] ;
    if (!fileExists) return NO;
    NSError *err = nil;
    [self setText:[NSString stringWithContentsOfFile:path encoding:NSISOLatin1StringEncoding error:&err]];
    return YES; 
}

-(void)cursorDown
{
    if (row < lines.count - 1)
    {
        row++;
        [self positionShowCursor];
    }
}
-(void)cursorPageDown
{
    if (row + rowsVisible < lines.count)
    {
        topRow += rowsVisible - 1;
        row += rowsVisible - 1;
        [self positionShowCursor ];
    }
    else
    {
        row = (int)lines.count - 1;
        col = (int)[[lines objectAtIndex:row] length];
        [self positionShowCursor];
    }
}

-(void)cursorPageUp
{
    if (topRow > 0)
    {
        topRow -= MIN(topRow,rowsVisible - 1);
        row -= MIN(row,rowsVisible - 1);
        [self positionShowCursor];
    } else {
        row = col = 0;
        [self positionShowCursor];
    }
}
-(void)updateLayer {
    GCodeShort *acode = [lines objectAtIndex:row];
    NSString *txt;
    if(acode.hasLayer)
        txt = [NSString stringWithFormat:@"Layer: %d Tool: %d",(int)acode.layer,(int)acode.tool];
    else
        txt = @"Layer: - Tool: -";
    [controller->layerText setStringValue:txt];
}
-(void)positionShowCursor
{
    [self positionShowCursor:NO moved:YES];
}
-(void)positionShowCursor:(BOOL)repaint moved:(BOOL)moved
{
    maxCol = MAX(maxCol,(int)[[lines objectAtIndex:row] length]);
    [self setFrameSize:NSMakeSize(MAX(NSWidth([self.enclosingScrollView bounds])-2,linesWidth+maxCol*fontWidth+3),lines.count*fontHeight)];
    //scrollRows.Maximum = lines.Count();
    //repaint |= hasSel;
    if (row < topRow)
    {
        topRow = row;
        //repaint = YES;
    }
    else if (row > topRow + rowsVisible - 2)
    {
        topRow = row - rowsVisible + 2;
        //repaint = YES;
    }
    if (col < topCol)
    {
        topCol = col;
        //repaint = YES;
    }
    else if (col > topCol + colsVisible - 2)
    {
        topCol = col - colsVisible + 2;
        //repaint = YES;
    }
    [self scrollPoint:NSMakePoint(topCol*fontWidth,topRow*fontHeight)]; 
    if (moved)
    {
        if ([NSEvent modifierFlags] & NSShiftKeyMask)
        {
            //repaint = YES;
            hasSel = YES;
        }
        else
        {
            if (!forceSel)
            {
                selCol = col;
                selRow = row;
                hasSel = NO;
            }
        }
    }
    else
    {
        selCol = col;
        selRow = row;
        hasSel = NO;
    }
    blink = YES;
    [self updateHelp];
    [colText setStringValue:[NSString stringWithFormat:@"C%d",col+1]];
    [rowText setStringValue:[NSString stringWithFormat:@"R%d/%d",row+1,lines.count]];
    [self setNeedsDisplay:YES];
    [self updateLayer];
}
-(void)cursorUp
{
    if (row >0)
    {
        row--;
        [self positionShowCursor];
    }
}
-(void)cursorEnd
{
    col = (int)[[lines objectAtIndex:row] length];
    [self positionShowCursor];
}
-(void)cursorStart
{
    col = 0;
    [self positionShowCursor];
}
-(BOOL)cursorLeft
{
    if (col > 0)
    {
        col--;
        [self positionShowCursor];
    }
    else
    {
        if (row == 0) return false;
        [self cursorUp];
        [self cursorEnd ];
    }
    return true;
}
-(void)cursorRight
{
    if (col <[[lines objectAtIndex:row] length])
    {
        col++;
        [self positionShowCursor];
    }
    else
    {
        [self cursorDown];
        [self cursorStart];
    }
}

-(void)insertChar:(NSString*)c {
    GCodeUndo *tmp = [[GCodeUndo alloc] initFromText:c orig:self.getSelection col:col row:row selCol:selCol selRow:selRow];
    [cur addUndo:tmp];
    [tmp release];
    if (self.hasSelection)
        [self deleteSelectionRedraw:NO];
    GCodeShort *gc = [lines objectAtIndex:row];
    NSString *l = gc->text;
    if(col>(int)l.length) col = (int)l.length;
    NSString *ns;
    if(overwrite && col < l.length)
        ns = [[NSString alloc] initWithFormat:@"%@%@%@",
              [l substringToIndex:col],c,[l substringFromIndex:col+1]];
    else
        ns = [[NSString alloc] initWithFormat:@"%@%@%@",
              [l substringToIndex:col],c,[l substringFromIndex:col]];
    [lines replaceObjectAtIndex:row withObject:[GCodeShort codeWith:ns]];
    [ns release];
    col++;
    [self positionShowCursor:YES moved:NO];
    [self changed];
}
-(void)insertString:(NSString*)s
{
    GCodeUndo *tmp = [[GCodeUndo alloc] initFromText:s orig:self.getSelection col:col row:row selCol:selCol selRow:selRow];
    [cur addUndo:tmp];
    [tmp release];
    if (self.hasSelection)
        [self deleteSelectionRedraw:NO];
    s = [StringUtil normalizeLineends:s];
    NSMutableArray *la = [StringUtil explode:s sep:@"\n"];
    GCodeShort *l = [lines objectAtIndex:row];
    if (col > l.length) col = (int)l.length;
    [la replaceObjectAtIndex:0 withObject:[[l->text substringToIndex:col] stringByAppendingString:[la objectAtIndex:0]]];
    int nc = (int)[[la objectAtIndex:la.count - 1] length];
    [la replaceObjectAtIndex:la.count-1 withObject:[[la objectAtIndex:la.count - 1] stringByAppendingString:[l->text substringFromIndex:col]]];
    col = nc;
    [lines replaceObjectAtIndex:row withObject:[GCodeShort codeWith:[la objectAtIndex:0]]];
    for (int i = 1; i < la.count; i++)
    {
        [lines insertObject:[GCodeShort codeWith:[la objectAtIndex:i]] atIndex:row+i];
    }
    row += la.count - 1;
    [self positionShowCursor:YES moved:NO];
    [self changed];
}
-(NSString*)getSelection
{
    NSUInteger rstart = row;
    NSUInteger cstart = col;
    NSUInteger rend = selRow;
    NSUInteger cend = selCol;
    if (row > selRow || (row == selRow && col > selCol))
    {
        rstart = selRow;
        cstart = selCol;
        rend = row;
        cend = col;
    }
    cstart = MIN(cstart, (int)([[lines objectAtIndex:rstart] length]));
    cend = MIN(cend, (int)([[lines objectAtIndex:rend] length]));
    NSUInteger i;
    NSMutableString *sb = [NSMutableString stringWithCapacity:1000];
    for (i = rstart; i <= rend; i++)
    {
        NSString *l = ((GCodeShort*)[lines objectAtIndex:i])->text;
        if (i == rend)
        {
            cend = MIN(cend, (int)(l.length));
            l = [l substringToIndex:cend];
        }
        if (i == rstart)
        {
            cstart = MIN((int)(l.length), cstart);
            l = [l substringFromIndex:cstart];
        }
        [sb appendString:l];
        if(i!=rend) [sb appendString:@"\n"];
    }
    return sb;
}
-(void)deleteSelectionRedraw:(BOOL)redraw
{
    NSUInteger rstart = row;
    NSUInteger cstart = col;
    NSUInteger rend = selRow;
    NSUInteger cend = selCol;
    if (row > selRow || (row == selRow && col > selCol))
    {
        rstart = selRow;
        cstart = selCol;
        rend = row;
        cend = col;
    }
    cstart = MIN(cstart, ([[lines objectAtIndex:rstart] length]));
    cend = MIN(cend, ([[lines objectAtIndex:rend] length]));
    GCodeUndo *tmp = [[GCodeUndo alloc] initFromText:@"" orig:self.getSelection col:col row:row selCol:selCol selRow:selRow];
    [cur addUndo:tmp];
    [tmp release];
    // start row = begin first + end last row
    [lines replaceObjectAtIndex:rstart withObject:[GCodeShort codeWith:[[((GCodeShort*)[lines objectAtIndex:rstart])->text substringToIndex:cstart] stringByAppendingString:[((GCodeShort*)[lines objectAtIndex:rend])->text substringFromIndex:cend]]]];
    if(rend>rstart)
        [lines removeObjectsInRange:NSMakeRange(rstart+1, rend-rstart)];
    row = selRow = rstart;
    col = selCol = cstart;
    if (lines.count == 0) [self clear];
    if (redraw)
        [self positionShowCursor:YES moved:NO];
    [self changed];
}
-(void)deleteChar
{
    GCodeShort *t = [lines objectAtIndex:row];
    if (t.length == col)
    { // Join with next line
        if (row == lines.count - 1) return;
        [lines replaceObjectAtIndex:row withObject:[GCodeShort codeWith:[((GCodeShort*)[lines objectAtIndex: row])->text stringByAppendingString:((GCodeShort*)[lines objectAtIndex:row + 1])->text]]];
        [lines removeObjectAtIndex:row+1];
        GCodeUndo *tmp = [[GCodeUndo alloc] initFromText:@"" orig:@"\n" col:col row:row selCol:0 selRow:row+1]; 
        [cur addUndo:tmp];
        [tmp release];
    } else {
        GCodeUndo *tmp = [[GCodeUndo alloc] initFromText:@"" orig:[t->text substringWithRange:NSMakeRange(col,1)] col:col row:row selCol:col+1 selRow:row];
        [cur addUndo:tmp];
        [lines replaceObjectAtIndex:row withObject:[GCodeShort codeWith:[[t->text substringToIndex:col] stringByAppendingString:[t->text substringFromIndex:col+1]]]];
        [tmp release];
    }
    [self setNeedsDisplay:YES];
    [self changed];
}
-(void)backspace
{
    GCodeShort *t = [lines objectAtIndex:row];
    if (col > t.length)
    {
        col = (int)t.length;
    } else
        if (col==0)
        { // Join with next line
            if (row == 0) return;
            GCodeUndo *tmp = [[GCodeUndo alloc] initFromText:@"" orig:@"\n" col:col row:row selCol:(int)[[lines objectAtIndex:row-1] length] selRow:row-1];
            [cur addUndo:tmp];
            [tmp release];
            col = (int)[[lines objectAtIndex:row-1] length];
            [lines replaceObjectAtIndex:row-1 withObject:[GCodeShort codeWith:[((GCodeShort*)[lines objectAtIndex: row-1])->text stringByAppendingString:((GCodeShort*)[lines objectAtIndex:row])->text]]];
            [lines removeObjectAtIndex:row];
            row--;
        } else {
            GCodeUndo *tmp = [[GCodeUndo alloc] initFromText:@"" orig:[t->text substringWithRange:NSMakeRange(col-1,1)] col:col row:row selCol:col-1 selRow:row];
            [cur addUndo:tmp];
            [lines replaceObjectAtIndex:row withObject:[GCodeShort codeWith:[[t->text substringToIndex:col-1] stringByAppendingString:[t->text substringFromIndex:col]]]];
            [tmp release];
            [self cursorLeft];
        }
    [self positionShowCursor:YES moved:NO];
    [self changed];
}
-(BOOL)hasSelection
{
    return row!=selRow || col!=selCol;
}
-(void)scrollBottom {
    [self scrollPoint:NSMakePoint(0.0,NSMaxY(self.frame)
                                  -NSHeight([self.enclosingScrollView bounds]))];
}
-(void)updateHelp
{
    if (commands == nil) return;
    NSString *l = [((GCodeShort*)[lines objectAtIndex:row])->text stringByTrimmingCharactersInSet:
                                              [NSCharacterSet whitespaceAndNewlineCharacterSet]];   
    NSRange p = [l rangeOfString:@" "];
    if (p.location == NSNotFound)
    {
        p.location = l.length;
    }
    NSString *com = [l substringToIndex:p.location];
    if ([com compare:lastHelpCommand]==NSOrderedSame) return;
    [self setLastHelpCommand:com];
    CommandDescription *desc = nil;
    desc = [commands->commands objectForKey:com];
    if (desc == nil) {
        [helpText setStringValue:@""];
        return;
    }
    [helpText setAttributedStringValue:desc.attributedDescription];
    return;
    
}
-(void)positionCursor
{
    [self updateHelp];
    [colText setStringValue:[NSString stringWithFormat:@"C%d",col+1]];
    [rowText setStringValue:[NSString stringWithFormat:@"R%d/%d",row+1,lines.count]];
    [self updateLayer];
    //if (!hasFocus) return;
    blink=YES;
    [self setNeedsDisplay:YES];
}
@end

@implementation GCodeUndo

-(id) initFromText:(NSString*)t orig:(NSString*)ot col:(NSUInteger)c row:(NSUInteger)r selCol:(NSUInteger)sc selRow:(NSUInteger)sr {
    if((self=[super init])) {
        text = [t retain];
        oldtext = [ot retain];
        col = c;
        row = r;
        selCol = sc;
        selRow = sr;
    }
    return self;
}
-(void)deleteSelection:(GCodeView*)e colStart:(NSUInteger)cstart rowStart:(NSUInteger)rstart colEnd:(NSUInteger)cend rowEnd:(NSUInteger) rend {
        // start row = begin first + end last row
    NSMutableArray *lines = e->lines;
    [lines replaceObjectAtIndex:rstart withObject:[GCodeShort codeWith:[[((GCodeShort*)[lines objectAtIndex:rstart])->text substringToIndex:cstart] stringByAppendingString:[((GCodeShort*)[lines objectAtIndex:rend])->text substringFromIndex:cend]]]];
    if (rend > rstart)
        [lines removeObjectsInRange:NSMakeRange(rstart+1,rend-rstart)];
    e->row = e->selRow = rstart;
    e->col = e->selCol = cstart;
    if (lines.count == 0) [e clear];
}
-(void)insertString:(NSString*)s editor:(GCodeView*)e
{
    NSUInteger rstart = row;
    NSUInteger cstart = col;
    NSUInteger rend = selRow;
   // NSUInteger cend = selCol;
    if (row > selRow || (row == selRow && col > selCol)){
        rstart = selRow;
        cstart = selCol;
        rend = row;
     //   cend = col;
    }
    NSMutableArray *lines = e->lines;    
    e->row = rstart;
    e->col = cstart;
    s = [StringUtil normalizeLineends:s];
    NSArray *la = [s componentsSeparatedByString:@"\n"];
    GCodeShort *l = [lines objectAtIndex:e->row];
    if (e->col > l.length) e->col = (int)l.length;
    //NSMutableArray *la2 = [[NSMutableArray alloc] initWithCapacity:la.count-1];
    //[la2 insertObject:[[l substringToIndex:e->col] stringByAppendingString:[la objectAtIndex:0]] atIndex:0];
    NSString *la20=[[l->text substringToIndex:e->col] stringByAppendingString:[la objectAtIndex:0]];
    int nc = (int)[[la objectAtIndex:la.count - 1] length];
  //  [lines replaceObjectAtIndex:rstart withObject:[la objectAtIndex:0]];
    for (int i = 1; i < la.count-1; i++) {
        [lines insertObject:[GCodeShort codeWith:[la objectAtIndex:i]] atIndex:e->row+i];
       // [la2 insertObject:[la objectAtIndex:i] atIndex:i - 1];
    }
    if(la.count==1) {
        [lines replaceObjectAtIndex:rstart withObject:[GCodeShort codeWith:[la20 stringByAppendingString:[l->text substringFromIndex:e->col]]]];
        e->col = (int)[la20 length];    
    } else {
        [lines replaceObjectAtIndex:rstart withObject:[GCodeShort codeWith:la20]];
        [lines replaceObjectAtIndex:rend withObject:[GCodeShort codeWith:[[la objectAtIndex:la.count-1] stringByAppendingString:[l->text substringFromIndex:e->col]]]];      
        e->col = nc;
    }
    //[la2 insertObject:[[la objectAtIndex:la.count - 1] stringByAppendingString:[l substringFromIndex:e->col]] atIndex:la.count - 2];
    //if(la.count>1) {
    //    for(int i=1;i<la2.count;i++)
    //        [lines insertObject:[la2 objectAtIndex:i] atIndex:e->row+1+i];
   // }
    e->row += la.count - 1;
    /*           la[0] = l.Substring(0, e.col) + la[0];
     int nc = la[la.Length - 1].Length;
     la[la.Length - 1] = la[la.Length - 1] + l.Substring(e.col);
     e.col = nc;
     e.lines[rstart] = la[0];
     string[] la2 = new string[la.Length - 1];
     for (int i = 1; i < la.Length; i++)
     {
     la2[i - 1] = la[i];
     }
     if(la.Length>1)
     e.lines.InsertRange(e.row + 1, la2);
     e.row += la.Length - 1;
 */    
    //[la2 release];
}
-(void)endPos:(NSString*)s resCol:(NSUInteger*)cpos resRow:(NSUInteger*)rpos editor:(GCodeView*)e {
    NSUInteger rstart = row;
    NSUInteger cstart = col;
   // NSUInteger rend = selRow;
   // NSUInteger cend = selCol;
    if (row > selRow || (row == selRow && col > selCol)) {
        rstart = selRow;
        cstart = selCol;
     //   rend = row;
      //  cend = col;
    }
    NSMutableArray *lines = e->lines;
    s = [StringUtil normalizeLineends:s];
    NSArray *la = [s componentsSeparatedByString:@"\n"];
    NSString *l = [lines objectAtIndex:rstart];
    if (cstart > (int)l.length) cstart = (int)l.length;
    if (la.count == 1) *cpos = cstart+(int)[[la objectAtIndex:0] length];
    else *cpos = (int)[[la objectAtIndex:la.count - 1] length];
    *rpos = rstart + la.count - 1;
}
    
-(void)undoAction:(GCodeView*)e
{
    NSUInteger rstart = row;
    NSUInteger cstart = col;
  //  NSUInteger rend = selRow;
  //  NSUInteger cend = selCol;
    NSUInteger ce, re;
    if (row > selRow || (row == selRow && col > selCol)) {
        rstart = selRow;
        cstart = selCol;
   //     rend = row;
   //     cend = col;
    }
    [self endPos:text resCol:&ce resRow:&re editor:e];
    [self deleteSelection:e colStart:cstart rowStart:rstart colEnd:ce rowEnd:re];
    [self insertString:oldtext editor:e];
    e->row = row;
    e->col = col;
    [e positionShowCursor:YES moved:NO];
    [e changed];
}
-(void)redoAction:(GCodeView*)e
{
    NSUInteger rstart = row;
    NSUInteger cstart = col;
    NSUInteger rend = selRow;
    NSUInteger cend = selCol;
    if (row > selRow || (row == selRow && col > selCol)) {
        rstart = selRow;
        cstart = selCol;
        rend = row;
        cend = col;
    }
    e->row = row;
    e->col = col;
    e->selCol = selCol;
    e->selRow = selRow;
    [self deleteSelection:e colStart:cstart rowStart:rstart colEnd:cend rowEnd:rend];
    [self insertString:text editor:e];
    if (text.length == 0)
    {
        e->row = rstart;
        e->col = cstart;
    }else{
        [self endPos:text resCol:&e->col resRow:&e->row editor:e];
    }
    [e positionShowCursor:YES moved:NO];
    [e changed];
}

@end

@implementation GCodeContent
@synthesize name;
//@synthesize text;

-(id)initWithEditor:(GCodeView*)ed {
    if((self=[super init])) {
        editor = ed;
        col = row = selCol = selRow = maxCol = 0;
        topRow = topCol=0;
        undo = [RHLinkedList new];
        redo = [RHLinkedList new];
        [self setName:@"unknown"];
        textArray = [[NSMutableArray alloc ] initWithCapacity:1000];
        [textArray addObject:[GCodeShort codeWith:@""]];
    }
    return self;
}
-(void)dealloc {
    [textArray release];
    [undo release];
    [redo release];
    [name release];
    [super dealloc];
}
-(void)resetPos
{
    col = row = selCol = selRow = topRow = topCol = 0;
    hasSel = NO;
}
-(NSString*)text {
    NSMutableString *s = [NSMutableString new];
    for(GCodeShort *c in textArray) {
        [s appendString:c->text];
        [s appendString:@"\n"];
    }
    return [s autorelease];
}
-(void)setText:(NSString*)value {
    [self clearUndo];
    value = [StringUtil normalizeLineends:value];
    [textArray removeAllObjects];
    NSArray *la = [value componentsSeparatedByString:@"\n"];
    if (la.count == 0) [textArray addObject:@""];
    else for (NSString *s in la) {
        [textArray addObject:[GCodeShort codeWith:s]];
        maxCol = MAX(maxCol,s.length);
    }
    row = col = topRow = topCol = selRow = selCol = 0;
}
-(void)fromActive
{
    col = editor->col;
    row = editor->row;
    maxCol = editor->maxCol;
    selCol = editor->selCol;
    selRow = editor->selRow;
    topCol = editor->topCol;
    topRow = editor->topRow;
    hasSel = editor->hasSel;
    //[self setTextArray:editor.textArray];
}
-(void)toActive
{
    //editor.text = self.text;
    editor->lines = textArray;
    editor->maxCol = maxCol;
    editor->col = col;
    editor->row = row;
    editor->topRow = topRow;
    editor->topCol = topCol;
    editor->selCol = selCol;
    editor->selRow = selRow;
    editor->hasSel = hasSel;
    editor->cur = self;
    [editor positionShowCursor:YES moved:NO];
    [self updateUndoButtons];
}
-(void)updateUndoButtons
{
    [editor->undoButton setEnabled:undo->count > 0];
    [editor->redoButton setEnabled:redo->count > 0];
}
-(void)clearUndo {
    [undo clear];
    [redo clear];
    [self updateUndoButtons];
}
-(void)undo
{
    if (undo->count > 0)
    {
        GCodeUndo *u = undo.removeFirst;
        [redo addFirst:u];
        [u undoAction:editor];
    }
    [self updateUndoButtons];
}
-(void)redo
{
    if (redo->count > 0)
    {
        GCodeUndo *u = redo.removeFirst;
        [undo addFirst:u];
        [u redoAction:editor];
    }
    [self updateUndoButtons];
}
-(void)addUndo:(GCodeUndo*) u
{
    [undo addFirst:u];
    if (undo->count > 100) [undo removeLast];
    [redo clear];
    [self updateUndoButtons];
}
@end
