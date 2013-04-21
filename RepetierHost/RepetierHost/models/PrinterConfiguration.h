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
#import "AMSerialPort.h"

@interface PrinterConfiguration : NSObject {
    NSString *name;
    NSString *port;
@public
    int printerType; // 0 = normal, 1 = normal dump, 2 = delta round
    int baud;
    AMSerialParity parity;
    AMSerialStopBits stopBits;
    int databits;
    int protocol; // 0 = autodetect, 1 = ASCII, 2 = repetier
    double deltaDiameter;
    double deltaHeight;
    double width,height,depth;
    double xMin,xMax,yMin,yMax;
    double bedLeft,bedFront;
    //  BOOL homeXMax,homeYMax,homeZMax;
    int homeX,homeY,homeZ;
    double travelFeedrate;
    double travelZFeedrate;
    double disposeX,disposeY,disposeZ;
    BOOL afterJobGoDispose;
    BOOL afterJobDisableExtruder;
    BOOL afterJobDisableHeatedBed;
    BOOL afterJobDisableMotors;
    BOOL autocheckTemp;
    BOOL dontLogM105;
    int autocheckInterval;
    BOOL okAfterResend;
    int defaultExtruderTemp;
    int defaultHeatedBedTemp;
    int receiveCacheSize;
    BOOL pingPongMode;
    double dumpAreaLeft;
    double dumpAreaFront;
    double dumpAreaWidth;
    double dumpAreaDepth;
    double addPrintingTime;
    int numberOfExtruder;
    NSString *startCode;
    NSString *endCode;
    NSString *jobkillCode;
    NSString *jobpauseCode;
    NSString *script1Code;
    NSString *script2Code;
    NSString *script3Code;
    NSString *script4Code;
    NSString *script5Code;
    NSString *filterPrg;
    BOOL enableFilterPrg;
@private
    // These vars are stored on change
    NSUserDefaults *d;
    NSString *b;
    NSString *skeinforgeProfile;
    NSString *slic3rPrint;
    NSString *slic3rPrinter;
    NSString *slic3rFilament1;
    NSString *slic3rFilament2;
    NSString *slic3rFilament3;
    int activeSlicer;
    BOOL importing;
}
@property (copy) NSString *b;
@property (copy) NSString *name;
@property (copy) NSString *port;
@property (copy) NSString *startCode;
@property (copy) NSString *endCode;
@property (copy) NSString *jobkillCode;
@property (copy) NSString *jobpauseCode;
@property (copy) NSString *script1Code;
@property (copy) NSString *script2Code;
@property (copy) NSString *script3Code;
@property (copy) NSString *script4Code;
@property (copy) NSString *script5Code;
@property (copy) NSString *filterPrg;

-(void)setupDefaultsRepository:(NSString*)confname;
-(PrinterConfiguration*)initLoadFromRepository:(NSString*)confname;
-(void)saveToRepository;

// Initialized printer configurations
+(void)initPrinter;
+(PrinterConfiguration*)findPrinter:(NSString *)name;
+(void)fillFormsWithCurrent;
+(PrinterConfiguration*)selectPrinter:(NSString*)name;
+(BOOL)createPrinter:(NSString*)name;
+(BOOL)deletePrinter:(NSString*)name;
-(double)xHomePosition;
-(double)yHomePosition;
-(double)zHomePosition;
-(BOOL)PointInsideX:(float)x Y:(float)y Z:(float) z;
-(NSString*)skeinforgeProfile;
-(void)setSkeinforgeProfile:(NSString*)value;
-(NSString*)slic3rPrint;
-(void)setSlic3rPrint:(NSString*)value;
-(NSString*)slic3rPrinter;
-(void)setSlic3rPrinter:(NSString*)value;
-(NSString*)slic3rFilament1;
-(void)setSlic3rFilament1:(NSString*)value;
-(NSString*)slic3rFilament2;
-(void)setSlic3rFilament2:(NSString*)value;
-(NSString*)slic3rFilament3;
-(void)setSlic3rFilament3:(NSString*)value;
-(int)activeSlicer;
-(void)setActiveSlicer:(int)value;
@end
extern PrinterConfiguration* currentPrinterConfiguration;
extern NSMutableArray* printerConfigurations;
