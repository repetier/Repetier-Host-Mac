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

#import "LogSplitViewDelegate.h"

@implementation LogSplitViewDelegate
@synthesize upperView;
@synthesize lowerView;
@synthesize splitView;

// Lower view is fixed in size, if window changes size
- (void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize
{
    NSSize splitViewSize = [sender frame].size;
    NSSize topSize = [upperView frame].size;
    NSSize bottomSize =[lowerView frame].size;
    NSPoint bottomLocation = [lowerView frame].origin;
    topSize.width = bottomSize.width = splitViewSize.width;
    topSize.height = splitViewSize.height - [sender dividerThickness]-bottomSize.height;    
    [upperView setFrameSize:topSize];
    [lowerView setFrameSize:bottomSize];
    bottomLocation.y = topSize.height+[sender dividerThickness];
    [lowerView setFrameOrigin:bottomLocation];
}

// Minimum size of the log view
- (CGFloat)splitView:(NSSplitView *)sender
constrainMaxCoordinate:(CGFloat)proposedMax ofSubviewAt:(NSInteger)offset
{
    NSSize splitViewSize = [sender frame].size;
    return splitViewSize.height-80;
}
- (CGFloat)splitView:(NSSplitView *)sender constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)dividerIndex {
    return 80;
}
- (BOOL)splitView:(NSSplitView *)sender canCollapseSubview:(NSView *)subview{
    return (subview == lowerView);
}
- (BOOL)splitView:(NSSplitView *)splitView shouldCollapseSubview:(NSView *)subview forDoubleClickOnDividerAtIndex:(NSInteger)dividerIndex;
{
    return ([subview isEqual:lowerView]);
}
-(IBAction)toggleLowerView:(id)sender
{
	BOOL rightViewCollapsed = [[self splitView] isSubviewCollapsed:lowerView];
	if (rightViewCollapsed) {
		[self uncollapseLowerView];
	} else {
		[self collapseLowerView];
	}
}

-(void)collapseLowerView
{
    
    NSRect overallFrame = [[self splitView] frame];
    double height = overallFrame.size.height-[splitView dividerThickness];
    [lowerView setHidden:YES];
    [lowerView setFrameOrigin:NSMakePoint(0,height)];
    [upperView setFrameSize:NSMakeSize(overallFrame.size.width,height)];
    [splitView setPosition:height ofDividerAtIndex:0];
	[[self splitView] display];
}
-(void)uncollapseLowerView
{
    [lowerView setHidden:NO];    
	CGFloat dividerThickness = [splitView dividerThickness];
 	NSRect upperFrame = [upperView frame];
	NSRect lowerFrame = [lowerView frame];
	upperFrame.size.height -= (lowerFrame.size.height+dividerThickness);
	lowerFrame.origin.y = upperFrame.size.height + dividerThickness;
	[upperView setFrameSize:upperFrame.size];
	[lowerView setFrame:lowerFrame];
	[[self splitView] display];
}
@end
