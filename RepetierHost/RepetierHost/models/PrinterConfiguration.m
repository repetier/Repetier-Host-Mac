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


#import "PrinterConfiguration.h"
#import "StringUtil.h"
#import "ThreadedNotification.h"
#import "RHAppDelegate.h"
#import "RHManualControl.h"
#import "GCodeEditorController.h"
#import "RHOpenGLView.h"
#import "PrinterConnection.h"

@implementation PrinterConfiguration

@synthesize name;
@synthesize port;
@synthesize startCode;
@synthesize endCode;
@synthesize jobkillCode;
@synthesize jobpauseCode;
@synthesize script1Code;
@synthesize script2Code;
@synthesize script3Code;
@synthesize script4Code;
@synthesize script5Code;
@synthesize filterPrg;

-(id)init {
    if((self = [super init])) {
        [self setName:@"Default"];
        [self setPort:@"None"];
        baud = 57600;
        databits = 8;
        parity = kAMSerialParityNone;
        stopBits = kAMSerialStopBitsOne;
        width = 200;
        height = 100;
        depth = 200;
        bedLeft = bedFront = xMin = yMin = 0;
        xMax = width;
        yMax = depth;
        afterJobGoDispose = YES;
        afterJobDisableExtruder = YES;
        afterJobDisableHeatedBed = YES;
        afterJobDisableMotors = NO;
        pingPongMode = NO;
        receiveCacheSize = 63;
        autocheckTemp = YES;
        dontLogM105 = YES;
        autocheckInterval = 1;
        disposeZ = 0;
        disposeX = 135;
        disposeY = 0;
        travelFeedrate = 4800;
        travelZFeedrate = 100;
        defaultExtruderTemp = 200;
        defaultHeatedBedTemp = 55;
        protocol = 0;
        numberOfExtruder = 1;
        pingPongMode = NO;
        okAfterResend = YES;
        hasDumpArea = YES;
        dumpAreaLeft = 125;
        dumpAreaFront = 0;
        dumpAreaWidth = 40;
        dumpAreaDepth = 22;
        enableFilterPrg = NO;
        homeXMax = homeYMax = homeZMax = NO;
        [self setStartCode:@""];
        [self setEndCode:@""];
        [self setJobkillCode:@""];
        [self setJobpauseCode:@""];
        [self setScript1Code:@""];
        [self setScript2Code:@""];
        [self setScript3Code:@""];
        [self setScript4Code:@""];
        [self setScript5Code:@""];
        [self setFilterPrg:@""];
    }
    return self;
}
-(void)dealloc {
    [name release];
    [port release];
    [super dealloc];
}
-(void)sanityCheck {
    if(xMax<xMin+width)
        xMax = xMin+width;
    if(yMax<yMin+depth)
        yMax = yMin+depth;
    if(bedLeft>xMax-width)
        bedLeft = xMax-width;
    if(bedLeft<xMin) bedLeft = xMin;
    if(bedFront>yMax-depth)
        bedFront = yMax-depth;
    if(bedFront<yMin) bedFront = yMin;
}
-(PrinterConfiguration*)initLoadFromRepository:(NSString*)confname {
    NSString *b = [@"printer." stringByAppendingString:confname];
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    self=[self init];
    [self initDefaultsRepository:confname]; // Make sure we have data to read
    [self setName:confname];
    [self setPort:[d objectForKey:[b stringByAppendingString:@".port"]]];
    baud = (int)[d integerForKey:[b stringByAppendingString:@".baud"]];
    parity = (int)[d integerForKey:[b stringByAppendingString:@".parity"]];
    stopBits = (int)[d integerForKey:[b stringByAppendingString:@".stopBits"]];
    databits = (int)[d integerForKey:[b stringByAppendingString:@".databits"]];
    protocol = (int)[d integerForKey:[b stringByAppendingString:@".protocol"]];
    autocheckInterval = (int)[d integerForKey:[b stringByAppendingString:@".autocheckInterval"]];
    defaultExtruderTemp = (int)[d integerForKey:[b stringByAppendingString:@".defaultExtruderTemp"]];
    defaultHeatedBedTemp = (int)[d integerForKey:[b stringByAppendingString:@".defaultHeatedBedTemp"]];
    receiveCacheSize = (int)[d integerForKey:[b stringByAppendingString:@".receiveCacheSize"]];
    afterJobGoDispose = [d boolForKey:[b stringByAppendingString:@".afterJobGoDispose"]];
    afterJobDisableExtruder = [d boolForKey:[b stringByAppendingString:@".afterJobDisableExtruder"]];
    afterJobDisableHeatedBed = [d boolForKey:[b stringByAppendingString:@".afterJobDisableHeatedBed"]];
    afterJobDisableMotors = [d boolForKey:[b stringByAppendingString:@".afterJobDisableMotors"]];
    dontLogM105 = [d boolForKey:[b stringByAppendingString:@".dontLogM105"]];
    autocheckTemp = [d boolForKey:[b stringByAppendingString:@".autocheckTemp"]];
    okAfterResend = [d boolForKey:[b stringByAppendingString:@".okAfterResend"]];
    pingPongMode = [d boolForKey:[b stringByAppendingString:@".pingPongMode"]];
    width = [d doubleForKey:[b stringByAppendingString:@".width"]];
    height = [d doubleForKey:[b stringByAppendingString:@".height"]];
    depth = [d doubleForKey:[b stringByAppendingString:@".depth"]];
    xMin = [d doubleForKey:[b stringByAppendingString:@".xMin"]];
    xMax = [d doubleForKey:[b stringByAppendingString:@".xMax"]];
    yMin = [d doubleForKey:[b stringByAppendingString:@".yMin"]];
    yMax = [d doubleForKey:[b stringByAppendingString:@".yMax"]];
    bedLeft = [d doubleForKey:[b stringByAppendingString:@".bedLeft"]];
    bedFront = [d doubleForKey:[b stringByAppendingString:@".bedFront"]];
    homeXMax = [d boolForKey:[b stringByAppendingString:@".homeXMax"]];
    homeYMax = [d boolForKey:[b stringByAppendingString:@".homeYMax"]];
    homeZMax = [d boolForKey:[b stringByAppendingString:@".homeZMax"]];
    travelFeedrate = [d doubleForKey:[b stringByAppendingString:@".travelFeedrate"]];
    travelZFeedrate = [d doubleForKey:[b stringByAppendingString:@".travelZFeedrate"]];
    disposeX = [d doubleForKey:[b stringByAppendingString:@".disposeX"]];
    disposeY = [d doubleForKey:[b stringByAppendingString:@".disposeY"]];
    disposeZ = [d doubleForKey:[b stringByAppendingString:@".disposeZ"]];
    [self setStartCode:[d stringForKey:[b stringByAppendingString:@".startCode"]]];
    [self setEndCode:[d stringForKey:[b stringByAppendingString:@".endCode"]]];
    [self setJobkillCode:[d stringForKey:[b stringByAppendingString:@".jobkillCode"]]];
    [self setJobpauseCode:[d stringForKey:[b stringByAppendingString:@".jobpauseCode"]]];
    [self setScript1Code:[d stringForKey:[b stringByAppendingString:@".script1Code"]]];
    [self setScript2Code:[d stringForKey:[b stringByAppendingString:@".script2Code"]]];
    [self setScript3Code:[d stringForKey:[b stringByAppendingString:@".script3Code"]]];
    [self setScript4Code:[d stringForKey:[b stringByAppendingString:@".script4Code"]]];
    [self setScript5Code:[d stringForKey:[b stringByAppendingString:@".script5Code"]]];
    [self setFilterPrg:[d stringForKey:[b stringByAppendingString:@".filterPrg"]]];
    enableFilterPrg = [d boolForKey:[b stringByAppendingString:@".enableFilterPrg"]];
    hasDumpArea = [d boolForKey:[b stringByAppendingString:@".hasDumpArea"]];
    dumpAreaLeft = [d doubleForKey:[b stringByAppendingString:@".dumpAreaLeft"]];
    dumpAreaFront = [d doubleForKey:[b stringByAppendingString:@".dumpAreaFront"]];
    dumpAreaWidth = [d doubleForKey:[b stringByAppendingString:@".dumpAreaWidth"]];
    dumpAreaDepth = [d doubleForKey:[b stringByAppendingString:@".dumpAreaDepth"]];
    addPrintingTime = [d doubleForKey:[b stringByAppendingString:@".addPrintingTime"]];
    numberOfExtruder = (int)[d integerForKey:[b stringByAppendingString:@".numberOfExtruder"]];
    [self sanityCheck];
    return self;
}
-(void)initDefaultsRepository:(NSString*)confname {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    NSString *b = [@"printer." stringByAppendingString:confname];
    [d setObject:port forKey:[b stringByAppendingString:@".port"]];
    [d setObject:[NSNumber numberWithInt:baud] forKey:[b stringByAppendingString:@".baud"]];
    [d setObject:[NSNumber numberWithInt:parity] forKey:[b stringByAppendingString:@".parity"]];
    [d setObject:[NSNumber numberWithInt:stopBits] forKey:[b stringByAppendingString:@".stopBits"]];
    [d setObject:[NSNumber numberWithInt:databits] forKey:[b stringByAppendingString:@".databits"]];
    [d setObject:[NSNumber numberWithInt:protocol] forKey:[b stringByAppendingString:@".protocol"]];
    [d setObject:[NSNumber numberWithInt:autocheckInterval] forKey:[b stringByAppendingString:@".autocheckInterval"]];
    [d setObject:[NSNumber numberWithInt:defaultExtruderTemp] forKey:[b stringByAppendingString:@".defaultExtruderTemp"]];
    [d setObject:[NSNumber numberWithInt:defaultHeatedBedTemp] forKey:[b stringByAppendingString:@".defaultHeatedBedTemp"]];
    [d setObject:[NSNumber numberWithInt:receiveCacheSize] forKey:[b stringByAppendingString:@".receiveCacheSize"]];
    [d setObject:[NSNumber numberWithBool:afterJobGoDispose] forKey:[b stringByAppendingString:@".afterJobGoDispose"]];
    [d setObject:[NSNumber numberWithBool:afterJobDisableExtruder] forKey:[b stringByAppendingString:@".afterJobDisableExtruder"]];
    [d setObject:[NSNumber numberWithBool:afterJobDisableHeatedBed] forKey:[b stringByAppendingString:@".afterJobDisableHeatedBed"]];
    [d setObject:[NSNumber numberWithBool:afterJobDisableMotors] forKey:[b stringByAppendingString:@".afterJobDisableMotors"]];
    [d setObject:[NSNumber numberWithBool:dontLogM105] forKey:[b stringByAppendingString:@".dontLogM105"]];
    [d setObject:[NSNumber numberWithBool:autocheckTemp] forKey:[b stringByAppendingString:@".autocheckTemp"]];
    [d setObject:[NSNumber numberWithBool:okAfterResend] forKey:[b stringByAppendingString:@".okAfterResend"]];
    [d setObject:[NSNumber numberWithBool:pingPongMode] forKey:[b stringByAppendingString:@".pingPongMode"]];
    [d setObject:[NSNumber numberWithDouble:width] forKey:[b stringByAppendingString:@".width"]];
    [d setObject:[NSNumber numberWithDouble:height] forKey:[b stringByAppendingString:@".height"]];
    [d setObject:[NSNumber numberWithDouble:depth] forKey:[b stringByAppendingString:@".depth"]];
    [d setObject:[NSNumber numberWithDouble:xMin] forKey:[b stringByAppendingString:@".xMin"]];
    [d setObject:[NSNumber numberWithDouble:xMax] forKey:[b stringByAppendingString:@".xMax"]];
    [d setObject:[NSNumber numberWithDouble:yMin] forKey:[b stringByAppendingString:@".yMin"]];
    [d setObject:[NSNumber numberWithDouble:yMax] forKey:[b stringByAppendingString:@".yMax"]];
    [d setObject:[NSNumber numberWithDouble:bedLeft] forKey:[b stringByAppendingString:@".bedLeft"]];
    [d setObject:[NSNumber numberWithDouble:bedFront] forKey:[b stringByAppendingString:@".bedFront"]];
    [d setObject:[NSNumber numberWithBool:homeXMax] forKey:[b stringByAppendingString:@".homeXMax"]];
    [d setObject:[NSNumber numberWithBool:homeYMax] forKey:[b stringByAppendingString:@".homeYMax"]];
    [d setObject:[NSNumber numberWithBool:homeZMax] forKey:[b stringByAppendingString:@".homeZMax"]];
    [d setObject:[NSNumber numberWithDouble:travelFeedrate] forKey:[b stringByAppendingString:@".travelFeedrate"]];
    [d setObject:[NSNumber numberWithDouble:travelZFeedrate] forKey:[b stringByAppendingString:@".travelZFeedrate"]];
    [d setObject:[NSNumber numberWithDouble:disposeX] forKey:[b stringByAppendingString:@".disposeX"]];
    [d setObject:[NSNumber numberWithDouble:disposeY] forKey:[b stringByAppendingString:@".disposeY"]];
    [d setObject:[NSNumber numberWithDouble:disposeZ] forKey:[b stringByAppendingString:@".disposeZ"]];
    [d setObject:@"" forKey:[b stringByAppendingString:@".startCode"]];
    [d setObject:@"" forKey:[b stringByAppendingString:@".endCode"]];
    [d setObject:@"" forKey:[b stringByAppendingString:@".jobkillCode"]];
    [d setObject:@"" forKey:[b stringByAppendingString:@".jobpauseCode"]];
    [d setObject:@"" forKey:[b stringByAppendingString:@".script1Code"]];
    [d setObject:@"" forKey:[b stringByAppendingString:@".script2Code"]];
    [d setObject:@"" forKey:[b stringByAppendingString:@".script3Code"]];
    [d setObject:@"" forKey:[b stringByAppendingString:@".script4Code"]];
    [d setObject:@"" forKey:[b stringByAppendingString:@".script5Code"]];

    [d setObject:@"" forKey:[b stringByAppendingString:@".filterPrg"]];
    [d setObject:[NSNumber numberWithBool:enableFilterPrg] forKey:[b stringByAppendingString:@".enableFilterPrg"]];
    
    // Some defaults for the gui
    [d setObject:[NSNumber numberWithDouble:100] forKey:@"fanSpeed"];
    [d setObject:[NSNumber numberWithBool:NO] forKey:@"debugEcho"];
    [d setObject:[NSNumber numberWithBool:YES] forKey:@"debugInfo"];
    [d setObject:[NSNumber numberWithBool:YES] forKey:@"debugErrors"];
    [d setObject:[NSNumber numberWithBool:NO] forKey:@"debugDryRun"];
    [d setObject:[NSNumber numberWithDouble:10] forKey:@"extruder.extrudeLength"];
    [d setObject:[NSNumber numberWithDouble:50] forKey:@"extruder.extrudeSpeed"];
    [d setObject:[NSNumber numberWithBool:YES] forKey:[b stringByAppendingString:@".hasDumpArea"]];
    [d setObject:[NSNumber numberWithDouble:125] forKey:[b stringByAppendingString:@".dumpAreaLeft"]];
    [d setObject:[NSNumber numberWithDouble:0] forKey:[b stringByAppendingString:@".dumpAreaFront"]];
    [d setObject:[NSNumber numberWithDouble:40] forKey:[b stringByAppendingString:@".dumpAreaWidth"]];
    [d setObject:[NSNumber numberWithDouble:22] forKey:[b stringByAppendingString:@".dumpAreaDepth"]];
    [d setObject:[NSNumber numberWithDouble:8] forKey:[b stringByAppendingString:@".addPrintingTime"]];
    [d setObject:[NSNumber numberWithInt:1] forKey:[b stringByAppendingString:@".numberOfExtruder"]];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:d];
    //[d release];
}
-(void)saveToRepository{
    [self sanityCheck];
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    NSString *b = [@"printer." stringByAppendingString:name];
    [d setObject:port forKey:[b stringByAppendingString:@".port"]];
    [d setInteger:baud forKey:[b stringByAppendingString:@".baud"]];
    [d setInteger:parity forKey:[b stringByAppendingString:@".parity"]];
    [d setInteger:stopBits forKey:[b stringByAppendingString:@".stopBits"]];
    [d setInteger:databits forKey:[b stringByAppendingString:@".databits"]];
    [d setInteger:protocol forKey:[b stringByAppendingString:@".protocol"]];
    [d setInteger:autocheckInterval forKey:[b stringByAppendingString:@".autocheckInterval"]];
    [d setInteger:defaultExtruderTemp forKey:[b stringByAppendingString:@".defaultExtruderTemp"]];
    [d setInteger:defaultHeatedBedTemp forKey:[b stringByAppendingString:@".defaultHeatedBedTemp"]];
    [d setInteger:receiveCacheSize forKey:[b stringByAppendingString:@".receiveCacheSize"]];
    [d setBool:afterJobGoDispose forKey:[b stringByAppendingString:@".afterJobGoDispose"]];
    [d setBool:afterJobDisableExtruder forKey:[b stringByAppendingString:@".afterJobDisableExtruder"]];
    [d setBool:afterJobDisableHeatedBed forKey:[b stringByAppendingString:@".afterJobDisableHeatedBed"]];
    [d setBool:afterJobDisableMotors forKey:[b stringByAppendingString:@".afterJobDisableMotors"]];
    [d setBool:autocheckTemp forKey:[b stringByAppendingString:@".autocheckTemp"]];
    [d setBool:okAfterResend forKey:[b stringByAppendingString:@".okAfterResend"]];
    [d setBool:pingPongMode forKey:[b stringByAppendingString:@".pingPongMode"]];
    [d setBool:dontLogM105 forKey:[b stringByAppendingString:@".dontLogM105"]];
    [d setDouble:width forKey:[b stringByAppendingString:@".width"]];
    [d setDouble:height forKey:[b stringByAppendingString:@".height"]];
    [d setDouble:depth forKey:[b stringByAppendingString:@".depth"]];
    [d setDouble:xMin forKey:[b stringByAppendingString:@".xMin"]];
    [d setDouble:xMax forKey:[b stringByAppendingString:@".xMax"]];
    [d setDouble:yMin forKey:[b stringByAppendingString:@".yMin"]];
    [d setDouble:yMax forKey:[b stringByAppendingString:@".yMax"]];
    [d setDouble:bedLeft forKey:[b stringByAppendingString:@".bedLeft"]];
    [d setDouble:bedFront forKey:[b stringByAppendingString:@".bedFront"]];
    [d setBool:homeXMax forKey:[b stringByAppendingString:@".homeXMax"]];
    [d setBool:homeYMax forKey:[b stringByAppendingString:@".homeYMax"]];
    [d setBool:homeZMax forKey:[b stringByAppendingString:@".homeZMax"]];
    [d setDouble:travelFeedrate forKey:[b stringByAppendingString:@".travelFeedrate"]];
    [d setDouble:travelZFeedrate forKey:[b stringByAppendingString:@".travelZFeedrate"]];
    [d setDouble:disposeX forKey:[b stringByAppendingString:@".disposeX"]];
    [d setDouble:disposeY forKey:[b stringByAppendingString:@".disposeY"]];
    [d setDouble:disposeZ forKey:[b stringByAppendingString:@".disposeZ"]];
    [d setObject:startCode forKey:[b stringByAppendingString:@".startCode"]];
    [d setObject:endCode forKey:[b stringByAppendingString:@".endCode"]];
    [d setObject:jobkillCode forKey:[b stringByAppendingString:@".jobkillCode"]];
    [d setObject:jobpauseCode forKey:[b stringByAppendingString:@".jobpauseCode"]];
    [d setObject:script1Code forKey:[b stringByAppendingString:@".script1Code"]];
    [d setObject:script2Code forKey:[b stringByAppendingString:@".script2Code"]];
    [d setObject:script3Code forKey:[b stringByAppendingString:@".script3Code"]];
    [d setObject:script4Code forKey:[b stringByAppendingString:@".script4Code"]];
    [d setObject:script5Code forKey:[b stringByAppendingString:@".script5Code"]];
    [d setObject:filterPrg forKey:[b stringByAppendingString:@".filterPrg"]];
    [d setBool:enableFilterPrg forKey:[b stringByAppendingString:@".enableFilterPrg"]];
    [d setBool:hasDumpArea forKey:[b stringByAppendingString:@".hasDumpArea"]];
    [d setDouble:dumpAreaLeft forKey:[b stringByAppendingString:@".dumpAreaLeft"]];
    [d setDouble:dumpAreaFront forKey:[b stringByAppendingString:@".dumpAreaFront"]];
    [d setDouble:dumpAreaWidth forKey:[b stringByAppendingString:@".dumpAreaWidth"]];
    [d setDouble:dumpAreaDepth forKey:[b stringByAppendingString:@".dumpAreaDepth"]];
    [d setDouble:addPrintingTime forKey:[b stringByAppendingString:@".addPrintingTime"]];
    [d setInteger:numberOfExtruder forKey:[b stringByAppendingString:@".numberOfExtruder"]];
    if(app!=nil)
        [app->manualControl updateExtruderCount];
}
+(void)initPrinter {
    printerConfigurations = [NSMutableArray new];
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [dict setObject:@"" forKey:@"currentPrinter"];
    [dict setObject:@"" forKey:@"printerList"];
    [d registerDefaults:dict];
    NSString *current = [d objectForKey:@"currentPrinter"];
    NSString *sPrinterList = [d objectForKey:@"printerList"];
    NSMutableArray *plist = [StringUtil explode:sPrinterList sep:@";"];
    if([plist count]==0) { // Make default printer
        currentPrinterConfiguration = [[PrinterConfiguration alloc] init];
        [currentPrinterConfiguration saveToRepository];
        [d setObject:[currentPrinterConfiguration name] forKey:@"currentPrinter"];
        [d setObject:[currentPrinterConfiguration name] forKey:@"printerList"];
    } else {
        for(NSString* s in plist) {
            PrinterConfiguration *pconf = [[PrinterConfiguration alloc] initLoadFromRepository:s];
            [printerConfigurations addObject:pconf];
            [pconf release];
        }
        currentPrinterConfiguration = [PrinterConfiguration findPrinter:current];
        [currentPrinterConfiguration retain];
    }    
}
+(PrinterConfiguration*) findPrinter:(NSString *)name {
    for (PrinterConfiguration* conf in printerConfigurations) {
		if([[conf name] isEqualToString:name])
            return conf;
	}  
    return nil;
}
+(void)fillFormsWithCurrent {
    if(!connection->connected) 
        [connection setConfig:currentPrinterConfiguration];
    [app->gcodeView setContent:1 text:currentPrinterConfiguration->startCode];
    [app->gcodeView setContent:2 text:currentPrinterConfiguration->endCode];
    [app->gcodeView setContent:3 text:currentPrinterConfiguration->jobkillCode];
    [app->gcodeView setContent:4 text:currentPrinterConfiguration->jobpauseCode];
    [app->gcodeView setContent:5 text:currentPrinterConfiguration->script1Code];
    [app->gcodeView setContent:6 text:currentPrinterConfiguration->script2Code];
    [app->gcodeView setContent:7 text:currentPrinterConfiguration->script3Code];
    [app->gcodeView setContent:8 text:currentPrinterConfiguration->script4Code];
    [app->gcodeView setContent:9 text:currentPrinterConfiguration->script5Code];
    [app->manualControl->extruderTempText setIntValue:currentPrinterConfiguration->defaultExtruderTemp];
    [app->manualControl->heatedBedTempText setIntValue:currentPrinterConfiguration->defaultHeatedBedTemp];
    [app->openGLView redraw];
}
+(PrinterConfiguration*)selectPrinter:(NSString *)name {
    currentPrinterConfiguration = [self findPrinter:name];
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setObject:name forKey:@"currentPrinter"];
    return currentPrinterConfiguration;
}
+(BOOL)createPrinter:(NSString *)name {
    PrinterConfiguration *c = [self findPrinter:name];
    if(c!=nil) return NO;
    c = [[PrinterConfiguration alloc] initLoadFromRepository:currentPrinterConfiguration.name];
    [c setName:name];
    [printerConfigurations addObject:c];
    [c release];
    // Update printer list
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:printerConfigurations.count];
    for(PrinterConfiguration *conf in printerConfigurations)
        [arr addObject:conf->name];
    NSString *list = [StringUtil implode:arr sep:@";"];
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setObject:list forKey:@"printerList"];
    [ThreadedNotification notifyNow:@"RHPrinterConfigCreated" object:name];
    [self selectPrinter:name];
    return YES;
}
+(BOOL)deletePrinter:(NSString *)name {
    if(printerConfigurations.count<2) return NO;
    PrinterConfiguration *dconf = [self findPrinter:name];
    if(dconf==nil) return NO;
    [printerConfigurations removeObject:dconf];
    if(currentPrinterConfiguration==dconf)
        [self selectPrinter:[printerConfigurations objectAtIndex:0]];
    // Update printer list
    NSMutableArray *arr = [NSMutableArray arrayWithCapacity:printerConfigurations.count];
    for(PrinterConfiguration *c in printerConfigurations)
        [arr addObject:c->name];
    NSString *list = [StringUtil implode:arr sep:@";"];
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setObject:list forKey:@"printerList"];   
    [ThreadedNotification notifyNow:@"RHPrinterConfigRemoved" object:name];
    return YES;
}
@end

PrinterConfiguration *currentPrinterConfiguration = nil;
NSMutableArray* printerConfigurations = nil;
