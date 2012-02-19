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

#import "Preferences.h"
#import "RHAppDelegate.h"
#import "Slicer.h"

@implementation PrefTab

-(id)initGroup:(NSString*)groupName {
    if((self=[super init])) {
        name = [groupName retain];
        tab = nil;
        showAlphaColors = NO;
        children = [[NSMutableArray alloc] initWithCapacity:5];        
    }
    return self;
}
-(id)initTab:(NSString*)tabName tab:(id)_tab alpha:(BOOL)al {
    if((self=[super init])) {
        name = [tabName retain];
        children = nil;
        tab = _tab;
        showAlphaColors = al;
    }
    return self;
}
-(void)dealloc {
    [name release];
    if(children)
        [children release];
    [super dealloc];
}
-(void)addTab:(NSString*)tabName tab:(id)_tab {
    [children addObject:[[[PrefTab alloc] initTab:tabName tab:_tab alpha:NO] autorelease]];
}
-(void)addTabAlpha:(NSString*)tabName tab:(id)_tab {
    [children addObject:[[[PrefTab alloc] initTab:tabName tab:_tab alpha:YES] autorelease]];
}
-(int)numChildren {
    if(children==nil) return 0;
    return (int)children.count;
}
@end

@implementation Preferences

- (id) init {
    if(self = [super initWithWindowNibName:@"Preferences" owner:self]) {
        groups = [[NSMutableArray alloc] initWithCapacity:10];
        [self.window setReleasedWhenClosed:NO];
    }
    return self;
}

- (id)initWithWindow:(NSWindow *)_window
{
    self = [super initWithWindow:_window];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}
-(void)dealloc {
    [groups release];
    [openPanel release];
    [super dealloc];
}
- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    PrefTab *g = [[PrefTab alloc] initGroup:@"Slicer"];
    [groups addObject:g];
    [g addTab:@"Skeinforge" tab:skeinforgeTab];
    [g addTab:@"Slic3r" tab:slic3rTab];
    [g release];
    g = [[PrefTab alloc] initGroup:@"3D visualization"];
    [groups addObject:g];
    [g addTab:@"General settings" tab:threedSettingsTab];
    [g addTab:@"Colors" tab:threedColorsTab];
    [g addTab:@"Lightning" tab:threedLights];
    [g release];
    g = [[PrefTab alloc] initGroup:@"Colors"];
    [groups addObject:g];
    [g addTab:@"Editor Colors" tab:editorTab];
    [g addTabAlpha:@"Temperature Colors" tab:temperatureColorsTab];
    [g addTab:@"Logging" tab:loggingTab];
    [g release];
    openPanel = [[NSOpenPanel openPanel] retain];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setAllowsMultipleSelection:NO];
    [[NSColorPanel sharedColorPanel] setShowsAlpha:YES];
    [NSColor setIgnoresAlpha:NO];
}
- (BOOL)windowShouldClose:(id)sender {
    return YES;
}
- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    
    return (item == nil) ? groups.count : [item numChildren];
}
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
    PrefTab *tab = item;
    if(tab->tab) {
        [tabView selectTabViewItem:tab->tab];
        [[NSColorPanel sharedColorPanel] setShowsAlpha:tab->showAlphaColors];
        return YES;
    }
    return NO;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    return (item == nil) ? YES : ([item numChildren] > 0);
}


- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    
    return (item == nil) ? [groups objectAtIndex:index] : [((PrefTab *)item)->children objectAtIndex:index];
}


- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
    return (item == nil) ? @"Repetier-Host" : ((PrefTab*)item)->name;
}
- (IBAction)openSkeinforgeHomepage:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://fabmetheus.crsndoo.com"]];
}

- (IBAction)openSlic3rHomepage:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.slic3r.org"]];
}

- (IBAction)browseSkeinforgeApplication:(id)sender {
    [openPanel setMessage:@"Select Skeinforge application"];
    [openPanel beginSheetModalForWindow:prefWindow completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            NSArray* urls = [openPanel URLs];
            if(urls.count>0) {
                NSURL *url = [urls objectAtIndex:0];
                [NSUserDefaults.standardUserDefaults setObject:url.path forKey:@"skeinforgeApplication"];
                if([NSUserDefaults.standardUserDefaults stringForKey:@"skeinforgeCraft"].length==0) {
                    NSString *craft = [NSString stringWithFormat:@"%@/skeinforge_utilities/skeinforge_craft.py",[url.path stringByDeletingLastPathComponent]];
                    if([app->slicer fileExists:craft]) {
                        [NSUserDefaults.standardUserDefaults setObject:craft forKey:@"skeinforgeCraft"];
                    }
                }
            }
        }        
    }];
}

- (IBAction)browseSkeinforgeCraft:(id)sender {
    [openPanel setMessage:@"Select Skeinforge craft utility"];
    [openPanel beginSheetModalForWindow:prefWindow completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            NSArray* urls = [openPanel URLs];
            if(urls.count>0) {
                NSURL *url = [urls objectAtIndex:0];
                [NSUserDefaults.standardUserDefaults setObject:url.path forKey:@"skeinforgeCraft"];
            }
        }        
    }];
}

- (IBAction)browseSkeinforgePython:(id)sender {
    [openPanel setMessage:@"Select python interpreter"];
    [openPanel beginSheetModalForWindow:prefWindow completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            NSArray* urls = [openPanel URLs];
            if(urls.count>0) {
                NSURL *url = [urls objectAtIndex:0];
                [NSUserDefaults.standardUserDefaults setObject:url.path forKey:@"skeinforgePython"];
            }
        }        
    }];
}

- (IBAction)testSkeinforge:(id)sender {
}

- (IBAction)browseSlic3rExecuteable:(id)sender {
    [openPanel setMessage:@"Select Slic3r executable (slic3r.app)"];
    [openPanel beginSheetModalForWindow:prefWindow completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            NSArray* urls = [openPanel URLs];
            if(urls.count>0) {
                NSURL *url = [urls objectAtIndex:0];
                [NSUserDefaults.standardUserDefaults setObject:[url.path stringByAppendingString:@"/Contents/MacOS/slic3r"] forKey:@"slic3rExternalPath"];
            }
        }        
    }];
}

- (IBAction)browseSlic3rConfigFile:(id)sender {
    [openPanel setMessage:@"Select Slic3r configuration file (*.ini)"];
    [openPanel beginSheetModalForWindow:prefWindow completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            NSArray* urls = [openPanel URLs];
            if(urls.count>0) {
                NSURL *url = [urls objectAtIndex:0];
                [NSUserDefaults.standardUserDefaults setObject:url.path forKey:@"slic3rExternalConfig"];
            }
        }        
    }];
}
@end
