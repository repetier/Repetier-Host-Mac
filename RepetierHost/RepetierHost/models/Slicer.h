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

#import <Foundation/Foundation.h>
#import "RHTask.h"
#import "Slic3rConfig.h"

@interface Slicer : NSObject {
    RHTask *skeinforgeRun;
    RHTask *skeinforgeSlice;
    RHTask *slic3rIntSlice;
    RHTask *slic3rIntRun;
    RHTask *slic3rExtRun;
    RHTask *slic3rExtSlice;
    RHTask *postprocess;
    NSString *postprocessOut;
    IBOutlet NSMenuItem *slic3rIntMenu;
    IBOutlet NSMenuItem *slic3rExtMenu;
    IBOutlet NSMenuItem *skeinforgeMenu;
    IBOutlet NSMenuItem *configSlic3rIntMenu;
    IBOutlet NSMenuItem *configSlic3rExtMenu;
    IBOutlet NSMenuItem *configSkeinforgeMenu;
    NSString *slic3rInternalPath;
    NSString *emptyPath;
    NSArray *bindingsArray;
    int activeSlicer;
    NSString *slic3rExtOut;
    NSString *slic3rIntOut;
    NSString *skeinforgeOut;
}
-(void)checkConfig;
-(void)slice:(NSString*)file;
-(void)taskFinished:(NSNotification*)event;
-(BOOL)fileExists:(NSString*)fname;
// Start Skeinforge application
-(IBAction)runSkeinforge:(id)sender;
- (IBAction)configSlic3rInternal:(id)sender;
- (IBAction)configSlic3rExternal:(id)sender;
-(BOOL)skeinforgeConfigured;
- (IBAction)activateSlic3rInternal:(id)sender;
- (IBAction)activateSlic3rExternal:(id)sender;
- (IBAction)activateSkeinforge:(id)sender;
@end
