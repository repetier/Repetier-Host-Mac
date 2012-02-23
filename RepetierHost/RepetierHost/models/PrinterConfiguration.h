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
    int baud;
    AMSerialParity parity;
    AMSerialStopBits stopBits;
    int databits;
    int protocol; // 0 = autodetect, 1 = ASCII, 2 = repetier
    double width,height,depth;
    double travelFeedrate;
    double travelZFeedrate;
    double disposeX,disposeY,disposeZ;
    BOOL afterJobGoDispose;
    BOOL afterJobDisableExtruder;
    BOOL afterJobDisableHeatedBed;
    BOOL autocheckTemp;
    BOOL dontLogM105;
    int autocheckInterval;
    BOOL okAfterResend;
    int defaultExtruderTemp;
    int defaultHeatedBedTemp;
    int receiveCacheSize;
    BOOL pingPongMode;
    BOOL hasDumpArea;
    double dumpAreaLeft;
    double dumpAreaFront;
    double dumpAreaWidth;
    double dumpAreaDepth;
    NSString *startCode;
    NSString *endCode;
    NSString *filterPrg;
    BOOL enableFilterPrg;
}
@property (copy) NSString *name;
@property (copy) NSString *port;
@property (copy) NSString *startCode;
@property (copy) NSString *endCode;
@property (copy) NSString *filterPrg;

-(void)initDefaultsRepository:(NSString*)confname;
-(PrinterConfiguration*)initLoadFromRepository:(NSString*)confname;
-(void)saveToRepository;

// Initialized printer configurations
+(void)initPrinter;
+(PrinterConfiguration*)findPrinter:(NSString *)name;
+(void)fillFormsWithCurrent;
+(PrinterConfiguration*)selectPrinter:(NSString*)name;
+(BOOL)createPrinter:(NSString*)name;
+(BOOL)deletePrinter:(NSString*)name;
@end
extern PrinterConfiguration* currentPrinterConfiguration;
extern NSMutableArray* printerConfigurations;
