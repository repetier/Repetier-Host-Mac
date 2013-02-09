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


#import "PrinterSettingsController.h"
#import "PrinterConfiguration.h"
#import "AMSerialPortList.h"
#import "AMSerialPortAdditions.h"
#import "StringUtil.h"
#import "RHAppDelegate.h"
#import "GCodeEditorController.h"
#import "RHOpenGLView.h"
#import "RHManualControl.h"
#import "PrinterConnection.h"
#import "RHSlicer.h"

@implementation PrinterSettingsController

@synthesize baudRates;
@synthesize protocolNames;
@synthesize numberOfExtruder;

- (id) init {
    if((self = [super initWithWindowNibName:@"PrinterSettings"])) {
        initDone = NO;
        [self setNumberOfExtruder:1];
        //[self.window setReleasedWhenClosed:NO];
    }
    return self;
}
- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    
    return self;
}
/*- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindowNibName:@"PrinterSettings" owner:self];
    if (self) {
        // Initialization code here.
        initDone = NO;
    }
    
    return self;
}*/

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
 }
-(void)awakeFromNib
{
    if(initDone) return;
    initDone = YES;
    for(int i=0;i<[printerConfigurations count];i++) {
        [configPopup addItemWithTitle:[[printerConfigurations objectAtIndex:i] name]];
    }

    [configPopup setTitle:[currentPrinterConfiguration name]];
    [portPopup removeAllItems];
    [portPopup addItemWithTitle:@"Virtual printer"];
    for (AMSerialPort* aPort in [[AMSerialPortList sharedPortList] serialPorts]) {
		// print port name
		[portPopup addItemWithTitle:[aPort name]];
	}    
	// register for port add/remove notification
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didAddPorts:) name:AMSerialPortListDidAddPortsNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didRemovePorts:) name:AMSerialPortListDidRemovePortsNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(configCreated:) name:@"RHPrinterConfigCreated" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(configRemoved:) name:@"RHPrinterConfigRemoved" object:nil];
	[AMSerialPortList sharedPortList]; // initialize port list to arm notifications
    [baudRatePopup removeAllItems];
    [self setBaudRates:[NSArray arrayWithObjects:@"9600",@"14400",@"19200",@"28800",@"38400",@"56000",@"57600",
                        @"76800",@"111112",@"115200",@"128000",@"230400",@"250000",@"256000",
                        @"460800",@"500000",@"921600",@"1000000",@"1382400",@"1500000",@"2000000",nil]];
    [baudRatePopup  addItemsWithTitles:baudRates];
    [protocolPopup removeAllItems];
    [self setProtocolNames:[NSArray arrayWithObjects:@"Autodetect",@"Force ASCII protocol",@"Force Repetier protocol", nil]];
    [protocolPopup addItemsWithTitles:protocolNames];
    [self loadFromConfig];
    [NSUserDefaults.standardUserDefaults addObserver:self forKeyPath:@"currentPrinter" options:NSKeyValueObservingOptionNew context:NULL];
    
}
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if([keyPath compare:@"currentPrinter"]==NSOrderedSame) {
        currentPrinterConfiguration = [PrinterConfiguration findPrinter:[change objectForKey:NSKeyValueChangeNewKey]];
        [self loadFromConfig];
        [PrinterConfiguration fillFormsWithCurrent];
        //    [configPopup setTitle:[currentPrinterConfiguration name]];
    } 
}
-(void)configCreated:(NSNotification*)event {
    [configPopup addItemWithTitle:event.object];             
}
-(void)configRemoved:(NSNotification*)event {
    [configPopup removeItemWithTitle:event.object];             
}

-(void)showWarning:(NSString*)warn headline:(NSString*)head {
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert addButtonWithTitle:@"OK"];
    [alert setMessageText:head];
    [alert setInformativeText:warn];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert beginSheetModalForWindow:mainWindow modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
}
- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode
        contextInfo:(void *)contextInfo {
    
}

-(void)loadFromConfig {
    PrinterConfiguration *c = currentPrinterConfiguration;
    [portPopup setTitle:c.port];
    [baudRatePopup setTitle:[NSString stringWithFormat:@"%d",c->baud]];
    [stopbitsPopup selectItemAtIndex:c->stopBits-1];
    [parityPopup selectItemAtIndex:c->parity];
    [protocolPopup setTitle:[protocolPopup itemTitleAtIndex:c->protocol]];
    [receiveCacheSizeText setIntValue:c->receiveCacheSize];
    [pingPongCheck setState:c->pingPongMode];
    [okAfterResendCheck setState:c->okAfterResend];
    [printWidthText setDoubleValue:c->width];
    [printDepthText setDoubleValue:c->depth];
    [printHeightText setDoubleValue:c->height];
    [dumpLeftText setDoubleValue:c->dumpAreaLeft];
    [dumpFrontText setDoubleValue:c->dumpAreaFront];
    [dumpWidthText setDoubleValue:c->dumpAreaWidth];
    [dumpHeightText setDoubleValue:c->dumpAreaDepth];
    [hasDumpCheckbox setState:c->hasDumpArea];
    [travelFeedrateText setDoubleValue:c->travelFeedrate];
    [zAxisFeedrateText setDoubleValue:c->travelZFeedrate];
    [filterPathText setStringValue:c->filterPrg];
    [dumpPosX setDoubleValue:c->disposeX];
    [dumpPosY setDoubleValue:c->disposeY];
    [dumpPosZ setDoubleValue:c->disposeZ];
    [goDisposeCheckbox setState:c->afterJobGoDispose];
    [disableExtruderCheckbox setState:c->afterJobDisableExtruder];
    [disableBedCheckbox setState:c->afterJobDisableHeatedBed];
    [checkIntervalText setIntValue:c->autocheckInterval];
    [checkExtruderCheckbox setState:c->autocheckTemp];
    [runFilterCheckbox setState:c->enableFilterPrg];
    [defaultExtruderTempText setIntValue:c->defaultExtruderTemp];
    [defaultBedTempText setIntValue:c->defaultHeatedBedTemp];
    [dontLogM105Checkbox setState:c->dontLogM105];
    [addPrintingTime setDoubleValue:c->addPrintingTime];
    [disableMotorAfterJob setState:c->afterJobDisableMotors];
    [homeXMax setState:c->homeXMax];
    [homeYMax setState:c->homeYMax];
    [homeZMax setState:c->homeZMax];
    [xMax setDoubleValue:c->xMax];
    [xMin setDoubleValue:c->xMin];
    [yMax setDoubleValue:c->yMax];
    [yMin setDoubleValue:c->yMin];
    [bedFront setDoubleValue:c->bedFront];
    [bedLeft setDoubleValue:c->bedLeft];
    [self setNumberOfExtruder:c->numberOfExtruder];
}
-(void)saveToConfig {
    PrinterConfiguration *c = currentPrinterConfiguration;
    [c setPort:[portPopup title]];
    c->baud = [[baudRatePopup title] intValue];
    c->stopBits = 1+(int)[stopbitsPopup indexOfSelectedItem];
    c->parity = (int)[parityPopup indexOfSelectedItem];
    c->protocol = (int)[protocolPopup indexOfSelectedItem];
    c->receiveCacheSize = (int)[receiveCacheSizeText intValue];
    c->pingPongMode = [pingPongCheck state];
    c->okAfterResend = [okAfterResendCheck state];
    c->width = [printWidthText doubleValue];
    c->depth = [printDepthText doubleValue];
    c->height = [printHeightText doubleValue];
    c->dumpAreaLeft = [dumpLeftText doubleValue];
    c->dumpAreaFront = [dumpFrontText doubleValue];
    c->dumpAreaWidth = [dumpWidthText doubleValue];
    c->dumpAreaDepth = [dumpHeightText doubleValue];
    c->hasDumpArea = [hasDumpCheckbox state];
    c->travelFeedrate = [travelFeedrateText doubleValue];
    c->travelZFeedrate = [zAxisFeedrateText doubleValue];
    c->filterPrg = [filterPathText stringValue];
    c->disposeX = [dumpPosX doubleValue];
    c->disposeY = [dumpPosY doubleValue];
    c->disposeZ = [dumpPosZ doubleValue];
    c->afterJobGoDispose = [goDisposeCheckbox state];
    c->afterJobDisableExtruder = [disableExtruderCheckbox state];
    c->afterJobDisableHeatedBed = [disableBedCheckbox state];
    c->autocheckInterval = [checkIntervalText intValue];
    c->autocheckTemp = [checkExtruderCheckbox state];
    c->enableFilterPrg = [runFilterCheckbox state];
    c->defaultExtruderTemp = [defaultExtruderTempText intValue];
    c->defaultHeatedBedTemp = [defaultBedTempText intValue];
    c->dontLogM105 = [dontLogM105Checkbox state];
    c->addPrintingTime = [addPrintingTime doubleValue];
    c->afterJobDisableMotors = [disableMotorAfterJob state];
    c->homeXMax = [homeXMax state];
    c->homeYMax = [homeYMax state];
    c->homeZMax = [homeZMax state];
    c->xMax = [xMax doubleValue];
    c->xMin = [xMin doubleValue];
    c->yMax = [yMax doubleValue];
    c->yMin = [yMin doubleValue];
    c->bedFront = [bedFront doubleValue];
    c->bedLeft = [bedLeft doubleValue];
    c->numberOfExtruder = numberOfExtruder;
    [c saveToRepository];
    [app->rhslicer updateSelections];
}

- (IBAction)createNewConfig:(id)sender {
    NSString *cname = [newConfigName stringValue];
    cname = [StringUtil replaceIn:cname all:@";" with:@"_"];
    cname = [StringUtil replaceIn:cname all:@"." with:@"_"];
    [NSApp endSheet:newConfigPanel];
    [newConfigPanel orderOut:self];
    if(cname.length==0)
        [self showWarning:@"No configuration name entered." headline:@"New configuration failed"];
    else if(![PrinterConfiguration createPrinter:cname])
        [self showWarning:@"Configuration name already exists." headline:@"New configuration failed"];
}

- (IBAction)cancelNewConfig:(id)sender {
    [NSApp endSheet:newConfigPanel];
    [newConfigPanel orderOut:self];
}
- (void)didAddPorts:(NSNotification *)theNotification
{
    NSString *act = [portPopup title];
    [portPopup removeAllItems];
    [portPopup addItemWithTitle:@"Virtual printer"];
    for (AMSerialPort* aPort in [[AMSerialPortList sharedPortList] serialPorts]) {
		// print port name
		[portPopup addItemWithTitle:[aPort name]];
	}    
    [portPopup setTitle:act];
}

- (void)didRemovePorts:(NSNotification *)theNotification
{
    NSString *act = [portPopup title];
    BOOL hasAct = NO;
    [portPopup removeAllItems];
    [portPopup addItemWithTitle:@"Virtual printer"];
    for (AMSerialPort* aPort in [[AMSerialPortList sharedPortList] serialPorts]) {
		// print port name
		[portPopup addItemWithTitle:[aPort name]];
        if(act!=nil && [act compare:[aPort name]]==NSOrderedSame)
            hasAct = YES;
	}    
    [portPopup setTitle:act];
    if(connection->connected && !hasAct) 
        [connection close];
}

- (IBAction)selectorChanged:(id)sender {
    [sender setTitle:[[sender selectedItem] title]];
}
-(void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [baudRates release];
    [super dealloc];
}
- (IBAction)abortButtonHit:(id)sender {
    [mainWindow orderOut:mainWindow];
}

- (IBAction)okButtonHit:(id)sender {
    [self saveToConfig];
    [mainWindow orderOut:mainWindow];
    [app->openGLView redraw];
}

- (IBAction)applyButtonHit:(id)sender {
    [self saveToConfig];
    [app->openGLView redraw];
}

- (IBAction)addButtonHit:(id)sender {
    [NSApp beginSheet: newConfigPanel
       modalForWindow: mainWindow
        modalDelegate: self
       didEndSelector: @selector(alertDidEnd:returnCode:contextInfo:)
          contextInfo: nil];

}

- (IBAction)deleteButtonHit:(id)sender {
}
@end
