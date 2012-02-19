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

@interface Slic3rSettings : NSObject {
@public
    NSString *name;
}
+(NSArray*)configNames;
-(id)initFromCurrent:(NSString*)_name;
-(id)initFromStored:(NSString*)_name;
-(void)toCurrent;
-(void)fromCurrent;
-(void)unregister;
-(id)getObject:(NSString*)name;
-(int)getInt:(NSString*)objname;
-(double)getDouble:(NSString*)objname;
-(BOOL)getBool:(NSString*)objname;
-(NSString*)getString:(NSString*)objname;
@end

@interface Slic3rConfig : NSWindowController<NSTabViewDelegate> {
    RHLinkedList *configs;
    IBOutlet NSButton *addConfigButton;
    IBOutlet NSButton *delConfigButton;
    IBOutlet NSTableView *configTable;
    IBOutlet NSTextField *newConfigName;
@public
    BOOL ignoreChange;
    IBOutlet NSWindow *configWindow;
    Slic3rSettings *current;
    IBOutlet NSPanel *newConfigPanel;
}
-(id)init;
-(Slic3rSettings*)findByName:(NSString*)name;
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context;
- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
-(void)updateConfig;
- (IBAction)addConfig:(id)sender;
- (IBAction)delConfig:(id)sender;
- (IBAction)visitSlic3rHomepage:(id)sender;
- (IBAction)configSelected:(id)sender;
- (IBAction)newConfigCreate:(id)sender;
- (IBAction)newConfigCancel:(id)sender;

@end
