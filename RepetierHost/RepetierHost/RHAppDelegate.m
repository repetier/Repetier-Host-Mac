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
#import "GCodeView.h"
#import "RHSound.h"

@implementation RHAppDelegate

@synthesize toolbarConnect;

@synthesize window;

#pragma mark Initalization related

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
        [codeVisual release];
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
    [self updateViewTravel];
    [RHSound createSounds];
}

#pragma mark -
#pragma mark Helper Functions

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename {
    NSString *ext = filename.pathExtension;
    if([ext compare:@"gcode" options:NSCaseInsensitiveSearch]==NSOrderedSame) {
        [gcodeView loadGCodeGCode:filename];
        return YES;
    } else if([ext compare:@"stl" options:NSCaseInsensitiveSearch]==NSOrderedSame) {
        [stlComposer loadSTLFile:filename];
        return YES;
    }
    return NO;
}
-(void)clearGraphicContext {
    [codePreview clearGraphicContext];
    [stlView clearGraphicContext];
    [printPreview clearGraphicContext];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {
    if(connection->job->mode==1) {
        [self showWarning:@"Stop your printing process before quitting the program!" headline:@"Termination aborted"];
        return NO; 
    }
    return YES;
}
- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag {
    
    [self.window makeKeyAndOrderFront:self];
    
    return YES;
}
- (void)windowDidBecomeKey:(NSNotification *)notification {
    [stlComposer recheckChangedFiles];
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
-(void)updateJobButtons {
    if(connection->connected) {
        [runJobButton setTag:YES];
        [killJobButton setTag:[connection->job hasData]];
        [sdcardButton setTag:YES];
    } else {
        [runJobButton setTag:NO];
        [killJobButton setTag:NO];
        [sdcardButton setTag:NO];
    }
    if(connection->job->mode!=1) {
        [runJobButton setLabel:@"Run"];
        [runJobButton setImage:runJobIcon];
    }
    [toolbar validateVisibleItems];
}


-(void)updateViewFilament {
    if(conf3d->disableFilamentVisualization) {
        [showFilamentButton setLabel:@"Hides filament"];
        [showFilamentButton setImage:hideFilamentIcon];
    } else {
        [showFilamentButton setLabel:@"Shows filament"];
        [showFilamentButton setImage:viewFilamentIcon];
    }
    [openGLView redraw];
}
-(void)updateViewTravel {
    if(!conf3d->showTravel) {
        [showTravelButton setLabel:@"Hides travel"];
        [showTravelButton setImage:hideFilamentIcon];
    } else {
        [showTravelButton setLabel:@"Shows travel"];
        [showTravelButton setImage:viewFilamentIcon];
    }
}

#pragma mark -
#pragma mark Notifications

/** Replaces the current preview model with the one
 computed in a different thread. 
 */
-(void)replaceGCodeView:(NSNotification*)event {
    [codePreview->models remove:codeVisual];
    codeVisual = event.object;
    [codePreview->models addLast:codeVisual];
    [openGLView redraw];
    @synchronized(gcodeView->editor->timer) {
        gcodeView->editor->nextView = nil;
    }
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
    [connection->tempLock lock];
    if(connection->extruderTemp.count>1) {
        for(NSNumber *key in connection->extruderTemp) {
            int e = key.intValue;
            [tr appendFormat:@"Extruder %d: %1.2f°C",e+1,[connection getExtruderTemperature:e]];
            if ([connection->analyzer getExtruderTemperature:e]>0)
                [tr appendFormat:@"/%1.0f°C ",[connection->analyzer getExtruderTemperature:e]];
            else
                [tr appendString:@"/Off "];
        }
    } else if(connection->extruderTemp.count==1){
        [tr appendFormat:@"Extruder: %1.2f°C",[connection getExtruderTemperature:-1]];
        if ([connection->analyzer getExtruderTemperature:-1]>0)
            [tr appendFormat:@"/%1.0f°C ",[connection->analyzer getExtruderTemperature:-1]];
        else
            [tr appendString:@"/Off "];
    }
    [connection->tempLock unlock];
    if (connection->bedTemp > 0)
    {
        [tr appendFormat:@"Bed: %1.2f",connection->bedTemp];
        if (connection->analyzer->bedTemp > 0)
            [tr appendFormat:@"/%1.0f°C",connection->analyzer->bedTemp];
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
    [sendScript1Menu setEnabled:YES];
    [sendScript2Menu setEnabled:YES];
    [sendScript3Menu setEnabled:YES];
    [sendScript4Menu setEnabled:YES];
    [sendScript5Menu setEnabled:YES];
}

-(void)firmwareDetected:(NSNotification*)event {
    [firmwareLabel setStringValue:[event object]];
}

- (void)connectionClosed:(NSNotification *)notification {
    [connectButton setLabel:@"  Connect  "];
    [connectButton setImage:connectedImage];    
    [printTempLabel setStringValue:@"Disconnected"];    
    [eepromMenuItem setEnabled:NO];
    [emergencyButton setTag:NO];
    [sendScript1Menu setEnabled:NO];
    [sendScript2Menu setEnabled:NO];
    [sendScript3Menu setEnabled:NO];
    [sendScript4Menu setEnabled:NO];
    [sendScript5Menu setEnabled:NO];
    [self updateJobButtons];
}

#pragma mark -
#pragma mark UI Actions

-(void)openRecentSTL:(NSMenuItem*)item {
    NSString *file = item.title;
    [composer loadSTLFile:file];
}
-(void)openRecentGCode:(NSMenuItem*)item {
    NSString *file = item.title;
    [gcodeView loadGCodeGCode:file];
}
- (IBAction)toggleLog:(id)sender {
    
    //  [topLogView setHidden:![topLogView isHidden]];
}

- (IBAction)toggleETAAction:(id)sender {
    connection->job->etaTimeLeft = !connection->job->etaTimeLeft;
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
        [job pushShortArray:gcodeView->prepend->textArray];
        [job pushShortArray:gcodeView->gcode->textArray];
        [job pushShortArray:gcodeView->append->textArray];
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
                [gcodeView loadGCodeGCode:[[urls objectAtIndex:0] path]];
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

- (IBAction)showFilamentAction:(NSToolbarItem *)sender {
    conf3d->disableFilamentVisualization = !conf3d->disableFilamentVisualization;
    [self updateViewFilament];
}

- (IBAction)showTravelAction:(id)sender {
    NSUserDefaults *d = NSUserDefaults.standardUserDefaults;
    [d setObject:[NSNumber numberWithInt:!conf3d->showTravel] forKey:@"threedShowTravel"];
}

- (IBAction)showPreferences:(NSMenuItem *)sender {
       [preferences->prefWindow makeKeyAndOrderFront:nil];
}

- (IBAction)emergencyAction:(id)sender {
    if (!connection->connected) return;
    connection->closeAfterM112 = NO; //YES;
    [connection injectManualCommandFirst:@"M112"];
    [connection->job killJob];
    [rhlog addError:@"Send emergency stop to printer. You may need to reset the printer for a restart!"];
    // Try to reset board by toggling DTR line
    [connection sendReset];
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
    [connection pauseDidEnd];
}

- (IBAction)ShowHomepage:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.repetier.com"]];
}

- (IBAction)ShowManual:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.repetier.com/documentation/repetier-host-mac/"]];
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

- (IBAction)showWorkdir:(id)sender {
    NSString *folder = @"~/Library/Repetier/";
    folder = [folder stringByExpandingTildeInPath];
    //   NSArray *fileURLs = [NSArray arrayWithObjects:folder,nil];
    //    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:fileURLs];
    [[NSWorkspace sharedWorkspace] openFile:folder];
}

- (IBAction)sendScript1Action:(id)sender {
    for (GCodeShort *code in gcodeView->script1->textArray)
    {
        [connection injectManualCommand:code->text];
    }
}

- (IBAction)sendScript2Action:(id)sender {
    for (GCodeShort *code in gcodeView->script2->textArray)
    {
        [connection injectManualCommand:code->text];
    }
}

- (IBAction)sendScript3Action:(id)sender {
    for (GCodeShort *code in gcodeView->script3->textArray)
    {
        [connection injectManualCommand:code->text];
    }
}

- (IBAction)sendScript4Action:(id)sender {
    for (GCodeShort *code in gcodeView->script4->textArray)
    {
        [connection injectManualCommand:code->text];
    }
}

- (IBAction)sendScript5Action:(id)sender {
    for (GCodeShort *code in gcodeView->script5->textArray)
    {
        [connection injectManualCommand:code->text];
    }
}

- (IBAction)donateAction:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.repetier.com/donate-or-support/"]];}
@end
