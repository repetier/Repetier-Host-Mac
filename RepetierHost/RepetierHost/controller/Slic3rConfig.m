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

#import "Slic3rConfig.h"
#import "StringUtil.h"

@implementation Slic3rSettings

-(id)initFromCurrent:(NSString*)_name {
    if((self=[super init])) {
        name = [_name retain];
        NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
        for(NSString *s in [Slic3rSettings configNames]) {
            NSObject *obj = [d objectForKey:[NSString stringWithFormat:@"slic3r#current#%@",s]];
            obj = [obj copy];
            [d setObject:obj forKey:[NSString stringWithFormat:@"slic3r#%@#%@",name,s]]; // Needs copy
            [obj release];
        }    
    }
    return self;
}
-(id)initFromStored:(NSString*)_name {
    if((self=[super init])) {
        name = [_name retain];
    }
    return self;
}
-(void)dealloc {
    [name release];
    [super dealloc];
}
+(NSArray*)configNames {
    return [NSArray arrayWithObjects:@"nozzleDiameter",@"useRealtiveE",@"zOffset",
            @"filamentDiameter",@"extrusionMultiplier",@"temperature",@"perimeterSpeed",@"smallPerimeterSpeed",
            @"infillSpeed",@"solidInfillSpeed",@"bridgesSpeed",@"travelSpeed",@"bottomLayerSpeedRatio",
            @"layerHeight",@"firstLayerHeightRatio",@"infillEveryNLayers",@"skirtLoops",@"skirtDistance",
            @"skirtHeight",@"perimeters",@"solidLayers",@"fillDensity",@"fillAngle",
            @"retractLength",@"retractZLift",@"retractSpeed",@"retractExtraLength",@"retractMinTravel",
            @"extrusionWidth",@"bridgeFlowRatio",@"fillPattern",@"solidFillPattern",@"comments",
            @"coolBridgeFanSpeed",@"coolDisplayLayer",@"coolEnableBelow",@"coolMaxFanSpeed",@"coolMinFanSpeed",
            @"coolMinPrintSpeed",@"coolSlowDownBelow",@"coolEnable",@"generateSupportMaterial",
            @"GCodeFlavor",@"supportMaterialTool",@"firstLayerTemperature",
            @"keepFanAlwaysOn",@"bedtemperature",@"firstLayerBedTemperature",nil];
    
}
-(void)toCurrent {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    for(NSString *s in [Slic3rSettings configNames]) {
        NSObject *obj = [d objectForKey:[NSString stringWithFormat:@"slic3r#%@#%@",name,s]];
        if(obj==nil) 
            obj = [[d objectForKey:[NSString stringWithFormat:@"slic3r#Default#%@",s]] copy];
        else 
            [obj retain];
        [d setObject:obj forKey:[NSString stringWithFormat:@"slic3r#current#%@",s]];
        [obj release];
    }
}
-(void)fromCurrent {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    for(NSString *s in [Slic3rSettings configNames]) {
        NSObject *obj = [d objectForKey:[NSString stringWithFormat:@"slic3r#current#%@",s]];
        [d setObject:obj forKey:[NSString stringWithFormat:@"slic3r#%@#%@",name,s]];
    }    
}
-(void)unregister {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    for(NSString *s in [Slic3rSettings configNames]) {
        [d removeObjectForKey:[NSString stringWithFormat:@"slic3r#%@#%@",name,s]];
    }    
    
}
-(id)getObject:(NSString*)objname {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    NSObject *obj = [d objectForKey:[NSString stringWithFormat:@"slic3r#%@#%@",name,objname]];
    if(obj==nil) 
        obj = [d objectForKey:[NSString stringWithFormat:@"slic3r#Default#%@",objname]];
    return obj;
}
-(BOOL)getBool:(NSString*)objname {
    return [[self getObject:objname] boolValue];
}
-(int)getInt:(NSString*)objname {
    return [[self getObject:objname] intValue];
}
-(double)getDouble:(NSString*)objname {
    return [[self getObject:objname] doubleValue];
}
-(NSString*)getString:(NSString*)objname {
    id o = [self getObject:objname];
    if([o isKindOfClass:[NSString class]]) return o;
    return [o stringValue];
}
@end

@implementation Slic3rConfig

- (id)init
{
    self = [super initWithWindowNibName:@"Slic3rSettings" owner:self];
    if (self) {
        configs = [RHLinkedList new];
        [self.window setReleasedWhenClosed:NO];
        NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
        NSArray *cl = [StringUtil explode:[d stringForKey:@"slic3rConfigs"] sep:@"\t"];
        for(NSString *s in cl) {
            Slic3rSettings *set = [[Slic3rSettings alloc] initFromStored:s];
            [configs addLast:set];
            [set release];
        }
        current = [self findByName:[d stringForKey:@"slic3rCurrent"]];
        if(current)
            [current toCurrent]; // Fill in paremeter values
        [configTable reloadData];
        for(NSString *key in [Slic3rSettings configNames]) {
            NSString *kname = [NSString stringWithFormat:@"slic3r#current#%@",key];
            [d addObserver:self forKeyPath:kname options:NSKeyValueObservingOptionNew context:NULL];
        }
        ignoreChange = NO;
    }
    
    return self;
}
- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    
    return self;
}
-(void)dealloc {
    for(NSString *key in [Slic3rSettings configNames])
        [NSUserDefaults.standardUserDefaults removeObserver:self
                                                 forKeyPath:[NSString stringWithFormat:@"slic3r.current.%@",key]];
    [configs release];
    [super dealloc];
}
- (void)windowDidLoad
{
    [super windowDidLoad];
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.

}
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    
    if(current==nil || ignoreChange) return;
    [current fromCurrent];
}
-(Slic3rSettings*)findByName:(NSString*)name {
    for(Slic3rSettings *set in configs) {
        if([set->name compare:name]==NSOrderedSame) {
            return set;
        }
    }
    return nil;
}
- (IBAction)addConfig:(id)sender {
    [NSApp beginSheet: newConfigPanel
       modalForWindow: configWindow
        modalDelegate: self
       didEndSelector: @selector(alertDidEnd:returnCode:contextInfo:)
          contextInfo: nil];
}

- (IBAction)delConfig:(id)sender {
    int row = (int)[configTable selectedRow];
    if(row<0 || configs->count<2) return;
    Slic3rSettings *s = [configs objectAtIndex:row];
    [s unregister];
    [configs remove:s];
    if(current == s) {
        current = [configs peekFirst];
        [current toCurrent];
        [self updateConfig];
    }
    [delConfigButton setEnabled:NO];
}

- (IBAction)visitSlic3rHomepage:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.slic3r.org"]];
}
- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode
        contextInfo:(void *)contextInfo {
    
}
-(void)showWarning:(NSString*)warn headline:(NSString*)head {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:head];
    [alert setInformativeText:warn];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert beginSheetModalForWindow:configWindow modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
}
-(void)updateConfig {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    [d setObject:current->name forKey:@"slic3rCurrent"];
    NSMutableArray *a = [[NSMutableArray alloc] initWithCapacity:configs->count];
    for(Slic3rSettings *s in configs)
        [a addObject:s->name];
    [d setObject:[StringUtil implode:a sep:@"\t"] forKey:@"slic3rConfigs"];
    [configTable reloadData];
    [a release];
}
-(BOOL)newConfig:(NSString*)cname {
    if([cname compare:@"current"]==NSOrderedSame) return NO;
    for(Slic3rSettings *s in configs) {
        if([s->name compare:cname]==NSOrderedSame) return NO;
    }
    Slic3rSettings *ns = [[Slic3rSettings alloc] initFromCurrent:cname];
    [configs addLast:ns];
    current = ns;
    [self updateConfig];
    [ns release];
    return YES;
}
- (IBAction)configSelected:(id)sender {
    int row = (int)[configTable selectedRow];
    if(row<0) {
        [delConfigButton setEnabled:NO];
        return;
    }
    [delConfigButton setEnabled:(configs->count>1)];
    Slic3rSettings *s = [configs objectAtIndex:row];
    current = s;
    ignoreChange = YES;
    [current toCurrent];
    [self updateConfig];
    ignoreChange = NO;
}

- (IBAction)newConfigCreate:(id)sender {
    NSString *cname = [newConfigName stringValue];
    cname = [StringUtil replaceIn:cname all:@"#" with:@"_"];
    [NSApp endSheet:newConfigPanel];
    [newConfigPanel orderOut:self];
    if(cname.length==0)
        [self showWarning:@"No configuration name entered." headline:@"New configuration failed"];
    else if(![self newConfig:cname])
        [self showWarning:@"Configuration name already exists." headline:@"New configuration failed"];
}

- (IBAction)newConfigCancel:(id)sender {
    [NSApp endSheet:newConfigPanel];
    [newConfigPanel orderOut:self];
}
// NSTableViewDelegates
- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView {
    return configs->count;
}
- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
    return ((Slic3rSettings*)[configs objectAtIndex:(int)rowIndex])->name;
}
- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
    return NO;
}
- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)col row:(NSInteger)rowIndex {
    Slic3rSettings *set = [configs objectAtIndex:rowIndex];
    [set->name release];
    set->name = [anObject retain];
    [self updateConfig];
}
@end
