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

#import "HorizontalSpliViewDelegate.h"

@implementation HorizontalSplitViewDelegate
@synthesize leftView;
@synthesize rightView;
@synthesize splitView;

#define SPLIT_LIMIT 400

-(id)init {
    if((self=[super init])) {
        autosaveName = nil;
    }
    return self;
}
-(void)dealloc {
    if(autosaveName)
        [autosaveName release];
    [super dealloc];
}

// Lower view is fixed in size, if window changes size
- (void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize
{
    NSSize splitViewSize = [sender frame].size;
    NSSize leftSize = [leftView frame].size;
    NSSize rightSize =[rightView frame].size;
    NSPoint rightLocation = [rightView frame].origin;
    leftSize.height = rightSize.height = splitViewSize.height;
    leftSize.width = splitViewSize.width - [sender dividerThickness]-rightSize.width;    
    [leftView setFrameSize:leftSize];
    [rightView setFrameSize:rightSize];
    rightLocation.x = leftSize.width+[sender dividerThickness];
    [rightView setFrameOrigin:rightLocation];
}
- (void)splitViewDidResizeSubviews:(NSNotification *)aNotification {
    NSSize rightSize =[rightView frame].size;
    if(autosaveName && rightSize.width>SPLIT_LIMIT) {
        NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
        [d setFloat:rightSize.width forKey:autosaveName];
    }    
}
-(void)setAutosaveName:(NSString*)name {
    autosaveName = [name retain];
    float pos = SPLIT_LIMIT;
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    pos = [d floatForKey:autosaveName];
    //NSLog(@"Set H splitter %f",pos);
    NSSize splitViewSize = [splitView frame].size;
    pos = splitViewSize.width-[splitView dividerThickness]-pos;
    [splitView setPosition:pos ofDividerAtIndex:0];

}
// Minimum size of the log view
- (CGFloat)splitView:(NSSplitView *)sender
constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset
{
    NSSize splitViewSize = [sender frame].size;
    return splitViewSize.width-SPLIT_LIMIT;
}
- (CGFloat)splitView:(NSSplitView *)sender constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)dividerIndex {
    return 100;
}
- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview{
    return (subview == rightView);
}
- (BOOL)splitView:(NSSplitView *)splitView shouldCollapseSubview:(NSView *)subview forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex;
{
    return ([subview isEqual:rightView]);
}
-(IBAction)toggleRightView:(id)sender
{
	BOOL rightViewCollapsed = [[self splitView] isSubviewCollapsed:rightView];
	if (rightViewCollapsed) {
		[self uncollapseRightView];
	} else {
		[self collapseRightView];
	}
}

-(void)collapseRightView
{    
    NSRect overallFrame = [[self splitView] frame];
    double width = overallFrame.size.width-[splitView dividerThickness];
    [rightView setHidden:YES];
    [rightView setFrameOrigin:NSMakePoint(width,0)];
    [rightView setFrameSize:NSMakeSize(width,overallFrame.size.height)];
    [splitView setPosition:width ofDividerAtIndex:0];
	[[self splitView] display];
}
-(void)uncollapseRightView
{
    [rightView setHidden:NO];    
	CGFloat dividerThickness = [splitView dividerThickness];
 	NSRect leftFrame = [leftView frame];
	NSRect rightFrame = [rightView frame];
	leftFrame.size.width -= (rightFrame.size.width+dividerThickness);
	rightFrame.origin.x = leftFrame.size.width + dividerThickness;
	[leftView setFrameSize:leftFrame.size];
	[rightView setFrame:rightFrame];
	[[self splitView] display];
}
@end
