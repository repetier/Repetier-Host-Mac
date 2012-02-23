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
#import "PrinterConfiguration.h"
#import "GCodeAnalyzer.h"
#import "RHPrintjob.h"
#import "VirtualPrinter.h"

@protocol ResponseDelegate
-(void) responseReceived:(NSString*)line;
@end
@class EEPROMStorage;
@class TemperatureHistory;

@protocol temperatureReceivedDelegate

-(void)monitoredTemperatureAt:(int)time temp:(int)temp target:(int)tTemp output:(int)out;
-(void)receivedTemperature:(double)temp bed:(double)tempBed;
@end

@interface PrinterConnection : NSObject<AMSerialPortReadDelegate> {
    AMSerialPort *port;
    id<ResponseDelegate> responseDelegate;
    id<temperatureReceivedDelegate> temperatureDelegate;
    NSNotification *notifyOpen;
    NSNotification *notifyTemp;
@public    
    GCodeAnalyzer *analyzer;
    RHPrintjob *job;
    
    NSString *printerName;
    int binaryVersion;
    BOOL garbageCleared; // Skip old output
    BOOL sdcardMounted;
    NSMutableString *read;
    //public int maxLogLines = 1000;
    BOOL readyForNextSend;
    //public bool pingpong = false;
    RHLinkedList *injectCommands;
    RHLinkedList *history;
    RHListNode *resendNode;
    EEPROMStorage *eeprom;
    NSLock *nextlineLock;
    NSLock *historyLock;
    NSLock *injectLock;
    NSLock *nackLock;
    // Printer data
    NSString *machine;
    NSString *firmware;
    NSString *firmwareUrl;
    NSString *protocol;
    int numberExtruder;
    double extruderTemp;
    double bedTemp;
    double x, y, z, e;
    int lastline;
    long lastReceived;
    //public bool autocheckTemp = true;
    //long autocheckInterval = 3000;
    double lastAutocheck;
    NSTimer *timer;
    int resendError;
    int linesSend, errorsReceived,comErrorsReceived;
    int bytesSend;
    BOOL ignoreNextOk;
  //  private ManualResetEvent injectLock = new ManualResetEvent(true);
    //string nextPrinterAction = null;
    double lastCommandSend;
    NSString *lastPrinterAction ;
//    public int receiveCacheSize = 120;
    RHLinkedList *nackLines; // Lines, whoses receivement were not acknowledged
    PrinterConfiguration *config;
    BOOL connected;
    VirtualPrinter *virtualPrinter;
    BOOL isVirtualActive;
    BOOL paused;
    float lastProgress;
    TemperatureHistory *tempHistory;
    double lastETA;
    BOOL closeAfterM112;
    BOOL isRepetier; // Printer is running Repetier-Firmware
    BOOL isMarlin; // Printer is running Marlin firmware
}
@property (retain) AMSerialPort *port;
@property (retain) PrinterConfiguration *config;
@property (retain) RHPrintjob *job; 
@property (retain) NSString* machine;
@property (retain) NSString* firmware;
@property (retain) NSString* firmwareUrl;
@property (retain) NSString* protocol;
@property (retain) NSString* lastPrinterAction;
@property (retain) id<ResponseDelegate> responseDelegate;
-(void)open;
-(void)close;
-(void)writeString:(NSString*)text;
-(void)writeData:(NSData*)data;
// Send RHPrinterInfo notification with stateInfo as printer state
-(void)firePrinterState:(NSString*)stateInfo;
-(void)injectManualCommandFirst:(NSString*)command;
-(void)injectManualCommand:(NSString*)command;
-(void)doDispose;
-(BOOL)hasInjectedMCommand:(int)code;
-(void)handleTimer:(NSTimer*)theTimer;
-(void)storeHistory:(GCode*)gcode;
-(int)receivedCount;
-(void)resendLine:(int)line;
-(void)trySendNextLine;
-(void)getInjectLock;
-(void)returnInjectLock;
-(void)analyzeResponse:(NSString*) res;
-(NSString*)extract:(NSString*)source identifier:(NSString*)ident;
-(void)virtualResponse:(NSString*)response;
-(void)pause:(NSString*) text;
@end

extern PrinterConnection *connection;