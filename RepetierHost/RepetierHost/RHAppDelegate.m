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

#import "RHAppDelegate.h"
#import "RHLogger.h"
#import "PrinterConfiguration.h"
#import "PrinterConnection.h"
#import "IntegerTransformer.h"
#import "ThreeDConfig.h"
#import "Commands.h"
#import "ThreeDContainer.h"
#import "STL.h"
#import "GCodeVisual.h"
#import "RHActionTabDelegate.h"
#import "RHAnimation.h"
#import "EEPROMController.h"
#import "ThreeDView.h"
#import "GCodeEditorController.h"
#import "LogSplitViewDelegate.h"
#import "ThreeDConfig.h"
#import "GCodeView.h"
#import "Slic3rConfig.h"
#import "STLComposer.h"

@implementation RHAppDelegate

//@synthesize sendGCodeAction;
@synthesize toolbarConnect;

@synthesize window;

-(id)init {
    if((self=[super init])) {
        //[rhlog setView:logView];
        // create an autoreleased instance of our value transformer
        IntegerTransformer *intTrans;
        intTrans = [[[IntegerTransformer alloc] init]
                    autorelease];
        // register it with the name that we refer to it with
        [NSValueTransformer setValueTransformer:intTrans
                                        forName:@"IntegerTransformer"];
        commands = [Commands new];
        [commands readFirmware:@"default" language:@"en"];
    /*    IntegerTransformer *intTrans;
        
        // create an autoreleased instance of our value transformer
        intTrans = [[[IntegerTransformer alloc] init]
                           autorelease];
        
        // register it with the name that we refer to it with
        [NSValueTransformer setValueTransformer:intTrans
                                        forName:@"IntegerTransformer"];
        // Set default values
        [PrinterConfiguration initPrinter];
        conf3d = [ThreeDConfig new];*/
        eepromController = nil;
        sdcardManager = nil;
        codePreview = [ThreeDContainer new];
        stlView = [ThreeDContainer new];
        printPreview = [ThreeDContainer new];
        codeVisual = [[GCodeVisual alloc] init];
        [codePreview->models addLast:codeVisual];
        
        printVisual = [[GCodeVisual alloc] initWithAnalyzer:connection->analyzer];
        printVisual->liveView = YES;
        [printPreview->models addLast:printVisual];
    }
    app = self;
    return self;
}
- (void)dealloc {
    [codeVisual release];
    [printVisual release];
    [connectedImage release];
    [disconnectedImage release];
    [runJobIcon release];
    [pauseJobIcon release];
    [hideFilamentIcon release];
    [viewFilamentIcon release];
    [openPanel release];
    [pausePanel release];
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{    
    connectedImage = [[NSImage imageNamed:@"disconnect"] retain];
    disconnectedImage = [[NSImage imageNamed:@"connect"] retain];
    runJobIcon = [[NSImage imageNamed:@"runjob32"] retain];
    pauseJobIcon = [[NSImage imageNamed:@"pauseicon"] retain];
    viewFilamentIcon = [[NSImage imageNamed:@"preview"] retain];
    hideFilamentIcon = [[NSImage imageNamed:@"previewoff"] retain];
    [[NSNotificationCenter defaultCenter] addObserver:self                                             selector:@selector(connectionOpened:) name:@"RHConnectionOpen" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self                                             selector:@selector(connectionClosed:) name:@"RHConnectionClosed" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self                                             selector:@selector(jobChanged:) name:@"RHJobChanged" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(printerInfoReceived:) name:@"RHPrinterInfo" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(temperatureRead:) name:@"RHTemperatureRead" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(progressReceived:) name:@"RHProgress" object:nil];    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(replaceGCodeView:) name:@"RHReplaceGCodeView" object:nil];    
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(firmwareDetected:) name:@"RHFirmware" object:nil];    
    [actionTabDelegate tabView:nil didSelectTabViewItem:composerTab];
    [leftTabView selectTabViewItemAtIndex:0];
    [rightTabView selectTabViewItemAtIndex:0];
    [self updateJobButtons];
    [self updateViewFilament];
    [rhlog refillView];
    openPanel = [[NSOpenPanel openPanel] retain];
    [openPanel setCanChooseDirectories:YES];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setMessage:@"Load G-Code file"];
    pausePanel = [[NSAlert alloc] init];
    [pausePanel addButtonWithTitle:@"Continue printing"];
    [pausePanel setMessageText:@"Printing paused"];
    [pausePanel setInformativeText:@"You can also add a pause command into the G-Code. Just add a line like\n@pause Change filament\ninto your code."];
    preferences = [Preferences new];
    [emergencyButton setTag:0];
    [pausePanel setAlertStyle:NSInformationalAlertStyle];
    slic3r = [[Slic3rConfig alloc] init];
    stlHistory = [[RHFileHistory alloc] initWithName:@"stlHistory" max:20];
    [stlHistory attachMenu:openRecentSTLMenu withSelector:@selector(openRecentSTL:)];
    gcodeHistory = [[RHFileHistory alloc] initWithName:@"gcodeHistory" max:20];
    [gcodeHistory attachMenu:openRecentGCodeMenu withSelector:@selector(openRecentGCode:)];
    [creditsText readRTFDFromFile:[[NSBundle mainBundle] pathForResource:@"Credits" ofType:@"rtf"]];
    [firstStepsText readRTFDFromFile:[[NSBundle mainBundle] pathForResource:@"introduction" ofType:@"rtf"]];
    [firstStepsWindow setLevel:NSFloatingWindowLevel];
    if([[NSUserDefaults standardUserDefaults] boolForKey:@"showFirstSteps"]) {
        [firstStepsWindow orderFrontRegardless];
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"showFirstSteps"];
    }
    [PrinterConfiguration fillFormsWithCurrent];
    //[logScrollView setScrollerStyle:NSScrollerStyleLegacy];
    [logSplitterDelegate setAutosaveName:@"logSplitterHeight"];
    [editorSplitterDelegate setAutosaveName:@"editorSplitterWidth"];
}
-(void)replaceGCodeView:(NSNotification*)event {
    [codePreview->models remove:codeVisual];
    [codeVisual release];
    codeVisual = [event.object retain];
    [codePreview->models addLast:codeVisual];
    [openGLView redraw];
}
-(void)firmwareDetected:(NSNotification*)event {
    [firmwareLabel setStringValue:[event object]];
}
-(void)openRecentSTL:(NSMenuItem*)item {
    NSString *file = item.title;
    [composer loadSTLFile:file];    
}
-(void)openRecentGCode:(NSMenuItem*)item {
    NSString *file = item.title;
    [gcodeView loadGCode:file];
}
- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag {
    
    [self.window makeKeyAndOrderFront:self];
    
    return YES;
}

- (IBAction)toolConnect:(id)sender {
    if(connection->connected)
        [connection close];
    else
        [connection open];
}

- (IBAction)openPrinterSettings:(id)sender {
    if(!printerSettingsController) {
        printerSettingsController = [[PrinterSettingsController alloc] init];
//    initWithWindow:self.window];

  //  [printerSettingsController showWindow:self];
    }
  //  [printerSettingsController showWindow:self];
    [printerSettingsController.window makeKeyAndOrderFront:nil];
}
-(void)progressReceived:(NSNotification*)notification {
    NSNumber *n = notification.object;
    [printProgress setDoubleValue:n.doubleValue];
}
-(void)printerInfoReceived:(NSNotification*)notification {
    [printStatusLabel setStringValue:[notification object]];
}
-(void)temperatureRead:(NSNotification*)notification {
    NSMutableString *tr = [NSMutableString stringWithCapacity:50];
    [tr appendFormat:@"Extruder: %1.0f°C",connection->extruderTemp];
    if (connection->analyzer->extruderTemp>0)
        [tr appendFormat:@"/%d°C",connection->analyzer->extruderTemp];
    else 
        [tr appendString:@"/Off"];
    if (connection->bedTemp > 0)
    {
        [tr appendFormat:@" Bed: %1.0f",connection->bedTemp];
        if (connection->analyzer->bedTemp > 0) 
            [tr appendFormat:@"/%d°C",connection->analyzer->bedTemp];
        else 
            [tr appendString:@"°C/Off"];
    }
    [printTempLabel setStringValue:tr];
}
-(void)jobChanged:(NSNotification*)notification {
    [self updateJobButtons];
}
- (void)connectionOpened:(NSNotification *)notification {
    [connectButton setLabel:@"Disconnect"];
    [connectButton setImage:disconnectedImage];
    [printTempLabel setStringValue:@"Waiting for temperature"];  
    [eepromMenuItem setEnabled:YES];
    [emergencyButton setTag:YES];
}
-(void)updateJobButtons {
    if(connection->connected) {
        [runJobButton setTag:YES];
        [killJobButton setTag:[connection->job hasData]];
        if(![connection->job hasData]) {
            [runJobButton setLabel:@"Run"];
            [runJobButton setImage:runJobIcon];
        }
        
    } else {
        [runJobButton setTag:NO];
        [killJobButton setTag:NO];
    }
    [toolbar validateVisibleItems];
}
- (IBAction)toggleLog:(id)sender {   
    
  //  [topLogView setHidden:![topLogView isHidden]];
}

- (IBAction)showEEPROM:(NSMenuItem *)sender {
    if(!eepromController) {
        eepromController = [[EEPROMController alloc] init];
    }
    [eepromController update];
    [eepromController.window makeKeyAndOrderFront:nil];
}

- (IBAction)runJobAction:(id)sender {
    RHPrintjob *job = connection->job;
    if (job->dataComplete)
    {
        [connection pause:@"You can also add a pause command into the G-Code. Just add a line like\n@pause Change filament\ninto your code."];

      //  conn.pause("Press OK to continue.\n\nYou can add pauses in your code with\n@pause Some text like this");
    }
    else
    {
        [runJobButton setLabel:@"Pause"];
        [runJobButton setImage:pauseJobIcon];

       // toolRunJob.Image = imageList.Images[3];
        [printVisual clear];
        [job beginJob];
        [job pushData:[gcodeView getContent:1]];
        [job pushData:[gcodeView getContent:0]];
        [job pushData:[gcodeView getContent:2]];
        [job endJob ];
    }
}

- (IBAction)killJobAction:(id)sender {
    [runJobButton setLabel:@"Run"];
    [runJobButton setImage:runJobIcon];
    [connection->job killJob];
    [self updateJobButtons];
}

- (IBAction)loadGCodeAction:(id)sender {
    [openPanel beginSheetModalForWindow:mainWindow completionHandler:^(NSInteger result){
        if (result == NSFileHandlingPanelOKButton) {
            NSArray* urls = [openPanel URLs];
            if(urls.count>0) {
                [gcodeView loadGCode:[[urls objectAtIndex:0] path]];
            }
            // Use the URLs to build a list of items to import.
        }        
    }];
}

- (IBAction)sdCardAction:(id)sender {
    if(!sdcardManager) {
        sdcardManager = [[SDCardManager alloc] init];
    }
    [sdcardManager.window makeKeyAndOrderFront:nil];
}

-(void)updateViewFilament {
    if(conf3d->disableFilamentVisualization) {
        [showFilamentButton setLabel:@"Hide filament"];
        [showFilamentButton setImage:hideFilamentIcon];
    } else {
        [showFilamentButton setLabel:@"Show filament"];
        [showFilamentButton setImage:viewFilamentIcon];
    }
    [openGLView redraw];
}
- (IBAction)showFilamentAction:(NSToolbarItem *)sender {
    conf3d->disableFilamentVisualization = !conf3d->disableFilamentVisualization;
    [self updateViewFilament];
}
- (void)connectionClosed:(NSNotification *)notification {
    [connectButton setLabel:@"Connect"];
    [connectButton setImage:connectedImage];    
    [printTempLabel setStringValue:@"Disconnected"];    
    [eepromMenuItem setEnabled:NO];
    [emergencyButton setTag:NO];
}

- (IBAction)showPreferences:(NSMenuItem *)sender {
       [preferences->prefWindow makeKeyAndOrderFront:nil];
}

- (IBAction)emergencyAction:(id)sender {
    if (!connection->connected) return;
    connection->closeAfterM112 = YES;
    [connection injectManualCommandFirst:@"M112"];
    [connection->job killJob];
    [rhlog addError:@"Send emergency stop to printer. You may need to reset the printer for a restart!"];
   /* while ([connection hasInjectedMCommand:112])
    {
        [NSApplication 
        Application.DoEvents();
    }
    [connection close];*/
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
    [alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (IBAction)pausedPanelContinue:(id)sender {
    [pausedPanel orderOut:window];
    connection->paused = NO;
}

- (IBAction)ShowHomepage:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/repetier/Repetier-Host-Mac"]];
}

- (IBAction)ShowManual:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/repetier/Repetier-Host-Mac/wiki"]];
}

- (IBAction)ShowForum:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://forums.reprap.org/list.php?267"]];
}

- (IBAction)ShowSlic3rHomepage:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.slic3r.org"]];
}

- (IBAction)ShowSkeinforgeHomepage:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://fabmetheus.crsndoo.com"]];
}
- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename {
    NSString *ext = filename.pathExtension;
    if([ext compare:@"gcode" options:NSCaseInsensitiveSearch]==NSOrderedSame) {
        [gcodeView loadGCode:filename];
        return YES;
    } else if([ext compare:@"stl" options:NSCaseInsensitiveSearch]==NSOrderedSame) {
        [stlComposer loadSTLFile:filename];
        return YES;
    }
    return NO;
}
@end
