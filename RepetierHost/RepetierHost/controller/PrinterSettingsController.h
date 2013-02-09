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
    IBOutlet NSTextField *numberExtruder;
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
    double dumpLeft;
    double dumpFront;
    double dumpWidth;
    double dumpHeight;
    IBOutlet NSTextField *travelFeedrateText;
    IBOutlet NSTextField *zAxisFeedrateText;
    IBOutlet NSTextField *defaultExtruderTempText;
    IBOutlet NSTextField *defaultBedTempText;
    IBOutlet NSButton *checkExtruderCheckbox;
    IBOutlet NSTextField *checkIntervalText;
    double dumpPosX;
    double dumpPosY;
    double dumpPosZ;
    IBOutlet NSButton *goDisposeCheckbox;
    IBOutlet NSButton *disableExtruderCheckbox;
    IBOutlet NSButton *disableBedCheckbox;
    IBOutlet NSButton *disableMotorAfterJob;
    IBOutlet NSTextField *addPrintingTime;
    IBOutlet NSButton *dontLogM105Checkbox;
    IBOutlet NSButton *homeXMax;
    IBOutlet NSButton *homeYMax;
    IBOutlet NSButton *homeZMax;
    int numberOfExtruder;
    double printAreaWidth;
    double printAreaHeight;
    double printAreaDepth;
    int printerType;
    double xMin,xMax;
    double yMin,yMax;
    double bedLeft,bedFront;
    double deltaDiameter;
    double deltaHeight;
    int homeX,homeY,homeZ;
}
@property (retain)NSArray* baudRates;
@property (retain)NSArray* protocolNames;
@property (nonatomic,readwrite)double dumpLeft;
@property (nonatomic,readwrite)double dumpFront;
@property (nonatomic,readwrite)double dumpWidth;
@property (nonatomic,readwrite)double dumpHeight;
@property (nonatomic,readwrite)double dumpPosX;
@property (nonatomic,readwrite)double dumpPosY;
@property (nonatomic,readwrite)double dumpPosZ;
@property (nonatomic, readwrite) int numberOfExtruder;
@property (nonatomic,readwrite)int printerType;
@property (nonatomic,readwrite)double printAreaWidth;
@property (nonatomic,readwrite)double printAreaHeight;
@property (nonatomic,readwrite)double printAreaDepth;
@property (nonatomic,readwrite)double xMin;
@property (nonatomic,readwrite)double yMin;
@property (nonatomic,readwrite)double xMax;
@property (nonatomic,readwrite)double yMax;
@property (nonatomic,readwrite)double bedLeft;
@property (nonatomic,readwrite)double bedFront;
@property (nonatomic,readwrite)double deltaDiameter;
@property (nonatomic,readwrite)double deltaHeight;
@property (nonatomic,readwrite)int homeX;
@property (nonatomic,readwrite)int homeY;
@property (nonatomic,readwrite)int homeZ;

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
