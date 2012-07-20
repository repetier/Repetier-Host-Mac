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

@interface PrinterSettingsController : NSWindowController {
    BOOL initDone;
    IBOutlet NSPopUpButton *portPopup;
    IBOutlet NSPopUpButton *baudRatePopup;
    IBOutlet NSPopUpButton *configPopup;
    IBOutlet NSPopUpButton *stopbitsPopup;
    IBOutlet NSPopUpButton *parityPopup;
    IBOutlet NSPopUpButton *protocolPopup;
    IBOutlet NSTextField *receiveCacheSizeText;
    IBOutlet NSButton *pingPongCheck;
    IBOutlet NSButton *okAfterResendCheck;
    NSArray *baudRates;
    NSArray *protocolNames;
    IBOutlet NSPanel *newConfigPanel;
    IBOutlet NSTextField *newConfigName;
    IBOutlet NSWindow *mainWindow;
    IBOutlet NSButton *addButton;
    IBOutlet NSButton *deleteButton;
    IBOutlet NSTextField *filterPathText;
    IBOutlet NSButton *runFilterCheckbox;
    IBOutlet NSTextField *printWidthText;
    IBOutlet NSTextField *printDepthText;
    IBOutlet NSTextField *printHeightText;
    IBOutlet NSButton *hasDumpCheckbox;
    IBOutlet NSTextField *dumpLeftText;
    IBOutlet NSTextField *dumpFrontText;
    IBOutlet NSTextField *dumpWidthText;
    IBOutlet NSTextField *dumpHeightText;
    IBOutlet NSTextField *travelFeedrateText;
    IBOutlet NSTextField *zAxisFeedrateText;
    IBOutlet NSTextField *defaultExtruderTempText;
    IBOutlet NSTextField *defaultBedTempText;
    IBOutlet NSButton *checkExtruderCheckbox;
    IBOutlet NSTextField *checkIntervalText;
    IBOutlet NSTextField *dumpPosX;
    IBOutlet NSTextField *dumpPosY;
    IBOutlet NSTextField *dumpPosZ;
    IBOutlet NSButton *goDisposeCheckbox;
    IBOutlet NSButton *disableExtruderCheckbox;
    IBOutlet NSButton *disableBedCheckbox;
    IBOutlet NSButton *disableMotorAfterJob;
    IBOutlet NSTextField *addPrintingTime;
    IBOutlet NSButton *dontLogM105Checkbox;
}
@property (retain)NSArray* baudRates;
@property (retain)NSArray* protocolNames;

-(void)configRemoved:(NSNotification*)event;
-(void)configCreated:(NSNotification*)event;
- (IBAction)selectorChanged:(id)sender;

- (IBAction)abortButtonHit:(id)sender;
- (IBAction)okButtonHit:(id)sender;
- (IBAction)applyButtonHit:(id)sender;
- (IBAction)addButtonHit:(id)sender;
- (IBAction)deleteButtonHit:(id)sender;
- (void)loadFromConfig;
- (void)saveToConfig;
- (IBAction)createNewConfig:(id)sender;
- (IBAction)cancelNewConfig:(id)sender;
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context;
@end
