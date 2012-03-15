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


#import "RHLogView.h"
#import "RHLogger.h"
#import "DefaultsExtension.h"

@implementation RHLogView

@synthesize normalBrush;
@synthesize infoBrush;
@synthesize warningBrush;
@synthesize errorBrush;
@synthesize linesBgColor;
@synthesize linesTextColor;
@synthesize backBrush;
@synthesize evenBackBrush;
@synthesize selectionBrush;
@synthesize selectionTextBrush;

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
        row = 0;
        selRow = 0;
        hasSel = NO;
        forceSel = NO;
        inDrawRect = NO;
        rowsVisible = 10;
        colsVisible = 7;
        maxLines = 2000;
        drawFont = [[NSFont userFixedPitchFontOfSize:12] retain];
      /*  normalBrush = [[NSColor colorWithDeviceRed:0 green:0 blue:0.5 alpha:1] retain];
        infoBrush = [[NSColor colorWithDeviceRed:0 green:0 blue:0.5 alpha:1] retain];
        warningBrush = [[NSColor colorWithDeviceRed:1 green:0.27 blue:0.5 alpha:1] retain];
        errorBrush = [[NSColor colorWithDeviceRed:0.5 green:0 blue:0 alpha:1] retain];
        linesBgColor = [[NSColor colorWithDeviceRed:0.372 green:0.62 blue:0.627 alpha:1] retain];
        linesTextColor = [[NSColor whiteColor] retain];
        backBrush = [[NSColor whiteColor] retain];
        evenBackBrush = [[NSColor colorWithDeviceRed:0.98 green:0.94 blue:0.9 alpha:1] retain];
        selectionBrush = [[NSColor colorWithDeviceRed:0.125 green:0.698 blue:0.667 alpha:1] retain];
        selectionTextBrush = [[NSColor whiteColor] retain];   */
        [self setupColor];
        NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
        //threedFacesColor
        NSArray *arr = [NSArray arrayWithObjects:@"logDefaultColor",
                        @"logInformationColor",@"logWarningColor",  
                        @"logErrorColor",@"logLineBackgroundColor",
                        @"logLineTextColor",@"logSelectedTextColor",@"logSelectedBackgroundColor",@"logBackgroundOddColor",
                        @"logBackgroundEvenColor",nil];
        bindingsArray = arr.retain;
        for(NSString *key in arr)
            [d addObserver:self forKeyPath:key options:NSKeyValueObservingOptionNew context:NULL];

        hasFocus = NO;
        ignoreMouseDown = NO;
        ignoreScrollChange = NO;
        autoscroll = YES;
        lines = [NSMutableArray new];
        fontAttributes = [[NSMutableDictionary alloc] init];
        [fontAttributes setObject:drawFont forKey:NSFontAttributeName];
        NSSize sz = [@" 00:00:00 " sizeWithAttributes:fontAttributes];
        fontWidth = sz.width/10;
        fontHeight = ceilf(sz.height);
        linesWidth = sz.width;
        changed = NO;
        linesLock = [NSLock new];
        timer = [NSTimer scheduledTimerWithTimeInterval:0.1
                                                 target:self selector:@selector(timerTick:)
                                               userInfo:nil repeats:YES];
    }
    
    return self;
}
-(void)dealloc {
    [timer invalidate];
    for(NSString *key in bindingsArray)
        [NSUserDefaults.standardUserDefaults removeObserver:self
                                                 forKeyPath:key];
    [bindingsArray release];
    [lines release];
    [fontAttributes release];
    [drawFont release];
    [super dealloc];
}
-(void)awakeFromNib {
    scrollView = (NSScrollView*)[self superview];    
}
- (void)timerTick:(NSTimer*)theTimer {
    if(changed) {
        [self setFrameSize:NSMakeSize(NSWidth([self.enclosingScrollView bounds])-2,lines.count*fontHeight)];
        if(autoscroll && !hasFocus)
            [self scrollBottom];
        [self setNeedsDisplay:YES]; // Repaint
    }
}
-(void)setupColor {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    [self setInfoBrush:[d colorForKey:@"logInformationColor"]];
    [self setWarningBrush:[d colorForKey:@"logWarningColor"]];
    [self setNormalBrush:[d colorForKey:@"logDefaultColor"]];
    [self setErrorBrush:[d colorForKey:@"logErrorColor"]];
    [self setLinesBgColor:[d colorForKey:@"logLineBackgroundColor"]];
    [self setLinesTextColor:[d colorForKey:@"logLineTextColor"]];
    [self setSelectionTextBrush:[d colorForKey:@"logSelectedTextColor"]];
    [self setSelectionBrush:[d colorForKey:@"logSelectedBackgroundColor"]];
    [self setBackBrush:[d colorForKey:@"logBackgroundOddColor"]];
    [self setEvenBackBrush:[d colorForKey:@"logBackgroundEvenColor"]];
    [fontAttributes setObject:selectionTextBrush forKey:NSForegroundColorAttributeName];
}
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    [self setupColor];
    [self setNeedsDisplay:YES];
}
-(BOOL)isFlipped {return YES;}
-(void) drawRow:(int)line y:(float)yPos
{
    RHLogEntry *lent = [lines objectAtIndex:line];
    NSColor *fontBrush;
    if (hasFocus && line >= MIN(row, selRow) && line <= MAX(row, selRow))
    { // mark selection
        [selectionBrush set];
        fontBrush = selectionTextBrush;
    }
    else
    {
        [((line & 1)!=0 ? evenBackBrush : backBrush) set];
        switch (lent->level)
        {
            case RHLogText:
            case RHLogSend:
            case RHLogResponse:
                fontBrush = normalBrush;
                break;
            case RHLogWarning:
                fontBrush = warningBrush;
                break;
            case RHLogError:
                fontBrush = errorBrush;
                break;
            case RHLogInfo:
            case RHLogPrg:
                fontBrush = infoBrush;
                break;
            default:
                fontBrush = normalBrush;
                break;
        }
    }
    
    [NSBezierPath fillRect:NSMakeRect(linesWidth,yPos,[self bounds].size.width, fontHeight)];
    [fontAttributes setObject:linesTextColor forKey:NSForegroundColorAttributeName];
    [lent.time drawAtPoint:NSMakePoint(fontWidth,yPos) withAttributes:fontAttributes];
    [fontAttributes setObject:fontBrush forKey:NSForegroundColorAttributeName];
    [lent.message drawAtPoint:NSMakePoint(linesWidth+fontWidth,yPos) withAttributes:fontAttributes];
}
- (void)drawRect:(NSRect)dirtyRect
{    
    if(inDrawRect) return; // Avoid deadlock if scrolling changes something
    inDrawRect = YES;
    // Draw background
    if(scrollView!=nil)
        topRow = (int)ceil([scrollView documentVisibleRect].origin.y/fontHeight);
    NSRect bounds = dirtyRect; //[self bounds];[scrollView documentVisibleRect]
    [linesLock lock];
    rowsVisible = (int)ceil(bounds.size.height / fontHeight);
    colsVisible = (int)ceil((double)(bounds.size.width - linesWidth) / fontWidth);
    int firstLine = floor(bounds.origin.y/fontHeight);
    int lastLine =ceil((bounds.origin.y+bounds.size.height)/fontHeight);
    if(lastLine>=lines.count)
        lastLine = (int)lines.count-1;
    [linesBgColor set];
    [NSBezierPath fillRect:NSMakeRect(0,firstLine*fontHeight,linesWidth,MAX(bounds.size.height,(lastLine-firstLine+1)*fontHeight))];
    [backBrush set];
    [NSBezierPath fillRect:NSMakeRect(linesWidth,0,bounds.size.width-linesWidth,bounds.size.height)];
    for (int r = firstLine; r <= lastLine; r++)
    {
        [self drawRow:r y:r * fontHeight];
    }
    changed = NO;
    [linesLock unlock];  
    inDrawRect = NO;
}
-(BOOL)becomeFirstResponder {
    hasFocus = YES;
    return YES;
}
-(BOOL)resignFirstResponder {
    hasFocus = NO;
    changed = YES;
    return YES;
}
- (void)viewDidEndLiveResize {
    [self setFrameSize:NSMakeSize(NSWidth([self.enclosingScrollView bounds])-2,lines.count*fontHeight)];
    changed = YES;
}
-(void)updateBox
{
    changed = YES;
    /*ignoreScrollChange = YES;
    [self setFrameSize:NSMakeSize(NSWidth([self.enclosingScrollView bounds]),lines.count*fontHeight)];
   // scroll.Maximum = Math.Max(0,lines.Count-rowsVisible-1);
   // scroll.Value = topRow;
   // scroll.LargeChange = Math.Max(1, rowsVisible - 1);
    if (autoscroll && !hasFocus)
        [self scrollBottom];
    ignoreScrollChange = YES;
    [self setNeedsDisplay:YES]; // Repaint*/
}
-(void)clear
{
    row = 0;
    [linesLock lock];
    [lines removeAllObjects];
    changed = YES;
    [linesLock unlock];
}
-(void)addLine:(RHLogEntry*)l;
{
    [linesLock lock];
    if(!hasFocus)
        while (lines.count >= maxLines)
        {
            row--;
            selRow--;
            [lines removeObjectAtIndex:0];
        }
    [lines addObject:l];
    changed = YES;
    [linesLock unlock];
}
-(void)scrollBottom {
    [self setFrameSize:NSMakeSize(NSWidth([self.enclosingScrollView bounds])-2,lines.count*fontHeight)];
    [self scrollPoint:NSMakePoint(0.0,NSMaxY(self.frame)
                                  -NSHeight([self.enclosingScrollView bounds]))];
}
-(void)cursorDown
{
    if (row < lines.count - 1)
    {
        row++;
        [self positionShowCursor];
    }
}
-(void)cursorHome
{
    row = topRow = 0;
    [self positionShowCursor];
}
-(void)cursorEnd
{
    row = lines.count - 1;
    topRow = MAX(0, lines.count - rowsVisible - 1);
    [self positionShowCursor];
}
-(void)cursorPageDown
{
    if (row + rowsVisible < lines.count)
    {
        //topRow += rowsVisible - 1;
        row += rowsVisible - 1;
        [self positionShowCursor];
    }
    else
    {
        row = lines.count - 1;
        [self positionShowCursor ];
    }
}
-(void)cursorPageUp
{
    if (topRow > 0)
    {
        //topRow -= rowsVisible - 1;
        row -= rowsVisible - 1;
        //if (topRow < 0) topRow = 0;
        if (row < 0) { row = 0; }
        [self positionShowCursor];
    }
    else
    {
        row = 0;
        [self positionShowCursor];
    }
}
-(void)positionShowCursor
{
    [self positionShowCursor:NO moved:YES];
}
-(void)positionShowCursor:(BOOL)repaint moved:(BOOL)moved
{
    //scroll.Maximum = lines.count();
    if (row < topRow)
    {
        topRow = row;
        [self scrollPoint:NSMakePoint(0,topRow*fontHeight)];
    }
    else if (row > topRow + rowsVisible - 2)
    {
        topRow = row - rowsVisible + 2;
        [self scrollPoint:NSMakePoint(0,topRow*fontHeight)];
    }
    if (moved)
    {
        if ([NSEvent modifierFlags] & NSShiftKeyMask)
        {
            hasSel = YES;
        }
        else
        {
            if (!forceSel)
            {
                selRow = row;
                hasSel = NO;
            }
        }
    }
    else
    {
        selRow = row;
        hasSel = false;
    }
    [self setNeedsDisplay:YES];
}
-(void)cursorUp
{
    if (row > 0)
    {
        row--;
        [self positionShowCursor];
    }
}

-(NSString*)getSelection
{
    int rstart = row;
    int rend = selRow;
    if (row > selRow)
    {
        rstart = selRow;
        rend = row;
    }
    int i;
    NSMutableString *sb = [NSMutableString stringWithCapacity:1000];
    for (i = rstart; i <= rend; i++)
    {
        [sb appendString:[[lines objectAtIndex:i] asText]];
    }
    return sb;
}
-(BOOL)hasSelection
{
    return hasSel || hasFocus;
}

- (void)keyDown:(NSEvent *)theEvent
{
    // NSLog( @"key down %d / %@ / %@",(int)theEvent.keyCode,[theEvent characters],[theEvent charactersIgnoringModifiers] );
    NSUInteger mod = [NSEvent modifierFlags];
    BOOL handled = NO;
    switch (theEvent.keyCode)
    {
        case 125: //Keys.Down:
            [self cursorDown];
            handled = YES;
            break;
        case 126: //Keys.Up:
            [self cursorUp];
            handled = YES;
            break;
        case 119: //Keys.End:
            [self cursorEnd];
            handled = YES;
            break;
        case 115: //Keys.Home:
            [self cursorHome];
            handled = YES;
            break;
        case 121: //Keys.PageDown:
            [self cursorPageDown];
            handled = YES;
            break;
        case 116: //Keys.PageUp:
            [self cursorPageUp];
            handled = YES;
            break;
        case 0: //Keys.A:
            if (mod==NSCommandKeyMask)
            {
                selRow = 0;
                row = MAX(0, lines.count - 1);
                forceSel = true;
                [self positionShowCursor:YES moved:YES];
                forceSel = NO;
                hasSel = YES;
                handled = YES;
            }
            break;
        case 8: //Keys.C:
        case 9: //Keys.X:
            if (mod==NSCommandKeyMask)
            {
                if (self.hasSelection) {
                    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
                    [pasteboard clearContents];
                    NSArray *copiedObjects = [NSArray arrayWithObject:self.getSelection];
                    [pasteboard writeObjects:copiedObjects];
                }
                handled = YES;
            }
            break;
    }
    if(!handled)
        [super keyDown:theEvent];
}
- (void)copy:(id)sender {
    if(self.hasSelection) {
        NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
        [pasteboard clearContents];
        NSArray *copiedObjects = [NSArray arrayWithObject:self.getSelection];
        [pasteboard writeObjects:copiedObjects];
    }
}
-(void)mouseDragged:(NSEvent *)event
{
    NSPoint dragLocation;
    dragLocation=[self convertPoint:[event locationInWindow]
                           fromView:nil];
    if(dragLocation.y<0)
        row = 0;
    else
        row = MAX(0, MIN(lines.count - 1, (int)(dragLocation.y / fontHeight)));
    hasSel = YES;
    [self setNeedsDisplay:YES];
    forceSel = YES;
    [self positionShowCursor:YES moved:YES];
    forceSel = NO;
    [self autoscroll:event];
}
- (void)mouseDown:(NSEvent *)theEvent
{
    // if (ignoreMouseDown) return;
    // Focus();
    //CreateCursor();
    hasFocus = YES;
    NSPoint e=[self convertPoint:[theEvent locationInWindow] fromView:nil];
    if ([NSEvent modifierFlags] & NSShiftKeyMask)
    {
        row = (NSUInteger)MAX(0,MIN(lines.count-1, (e.y / fontHeight)));
    }
    else
    {
        row = selRow = MAX(0, MIN(lines.count - 1,  (int)(e.y / fontHeight)));
    }
    [self positionShowCursor];    
    
}
- (BOOL)acceptsFirstResponder
{
    return YES;
}
-(BOOL)acceptsFirstMouse {
    return YES;
}
- (void)selectAll:(id)sender {
    selRow = 0;
    row = MAX(0, lines.count - 1);
    forceSel = YES;
    [self positionShowCursor:YES moved:YES];
    forceSel = NO;
    hasSel = YES;    
}

@end
