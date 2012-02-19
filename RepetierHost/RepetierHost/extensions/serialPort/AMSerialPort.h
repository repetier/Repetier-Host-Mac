//
//  AMSerialPort.h
//
//  Created by Andreas on 2002-04-24.
//  Copyright (c) 2001-2009 Andreas Mayer. All rights reserved.
//
//  2002-09-18 Andreas Mayer
//  - added available & owner
//  2002-10-17 Andreas Mayer
//	- countWriteInBackgroundThreads and countWriteInBackgroundThreadsLock added
//  2002-10-25 Andreas Mayer
//	- more additional instance variables for reading and writing in background
//  2004-02-10 Andreas Mayer
//    - added delegate for background reading/writing
//  2005-04-04 Andreas Mayer
//	- added setDTR and clearDTR
//  2006-07-28 Andreas Mayer
//	- added -canonicalMode, -endOfLineCharacter and friends
//	  (code contributed by Randy Bradley)
//	- cleaned up accessor methods; moved deprecated methods to "Deprecated" category
//	- -setSpeed: does support arbitrary values on 10.4 and later; returns YES on success, NO otherwiese
//  2006-08-16 Andreas Mayer
//	- cleaned up the code and removed some (presumably) unnecessary locks
//  2007-10-26 Sean McBride
//  - made code 64 bit and garbage collection clean
//  2008-10-21 Sean McBride
//  - Added an API to open a serial port for exclusive use
//  - fixed some memory management issues


/*
 * Standard speeds defined in termios.h
 *
#define B0	0
#define B50	50
#define B75	75
#define B110	110
#define B134	134
#define B150	150
#define B200	200
#define B300	300
#define B600	600
#define B1200	1200
#define	B1800	1800
#define B2400	2400
#define B4800	4800
#define B7200	7200
#define B9600	9600
#define B14400	14400
#define B19200	19200
#define B28800	28800
#define B38400	38400
#define B57600	57600
#define B76800	76800
#define B115200	115200
#define B230400	230400
 */

#import <stdio.h>
#import <string.h>
#import <unistd.h>
#import <fcntl.h>
#import <errno.h>
#import <paths.h>
#import <termios.h>
#import <sys/time.h>
#import <sysexits.h>
#import <sys/param.h>

#import <Foundation/Foundation.h>

// By default, debug code is preprocessed out.  If you would like to compile with debug code enabled,
// "#define AMSerialDebug" before including any AMSerialPort headers, as in your prefix header

extern NSString * const AMSerialErrorDomain;

extern NSString * const AMSerialOptionServiceName;
extern NSString * const AMSerialOptionSpeed;
extern NSString * const AMSerialOptionDataBits;
extern NSString * const AMSerialOptionParity;
extern NSString * const AMSerialOptionStopBits;
extern NSString * const AMSerialOptionInputFlowControl;
extern NSString * const AMSerialOptionOutputFlowControl;
extern NSString * const AMSerialOptionEcho;
extern NSString * const AMSerialOptionCanonicalMode;

typedef enum {	
	kAMSerialParityNone = 0,
	kAMSerialParityOdd = 1,
	kAMSerialParityEven = 2
} AMSerialParity;

typedef enum {	
	kAMSerialStopBitsOne = 1,
	kAMSerialStopBitsTwo = 2
} AMSerialStopBits;

// Private constant
#define AMSER_MAXBUFSIZE  4096UL

@class AMSerialPort;

@protocol AMSerialPortReadDelegate
- (void)serialPort:(AMSerialPort *)port didReadData:(NSData *)data;
@end
@protocol AMSerialPortWriteDelegate
// apparently the delegate only gets messaged on longer writes
- (void)serialPort:(AMSerialPort *)port didMakeWriteProgress:(NSUInteger)progress total:(NSUInteger)total;
@end

@interface AMSerialPort : NSObject
{
@private
	NSString *bsdPath;
	NSString *serviceName;
	NSString *serviceType;
	int fileDescriptor;
	struct termios * __strong options;
	struct termios * __strong originalOptions;
	NSMutableDictionary *optionsDictionary;
	NSFileHandle *fileHandle;
	id owner;
	char * __strong buffer;
	NSTimeInterval readTimeout; // for public blocking read methods and doRead
	fd_set * __strong readfds;
	id <AMSerialPortReadDelegate> readDelegate;
	id <AMSerialPortWriteDelegate> writeDelegate;
	NSLock *writeLock;
	NSLock *readLock;
	NSLock *closeLock;

	// used by AMSerialPortAdditions only:
	id am_readTarget;
	SEL am_readSelector;
	BOOL stopWriteInBackground;
	int countWriteInBackgroundThreads;
	BOOL stopReadInBackground;
	int countReadInBackgroundThreads;
}

- (id)initWithPath:(NSString *)path name:(NSString *)name type:(NSString *)type;
// initializes port
// path is a bsdPath
// name is an IOKit service name
// type is an IOKit service type

@property (nonatomic, readonly, assign) NSString *bsdPath;
// bsdPath (e.g. '/dev/cu.modem')

@property (nonatomic, readonly, assign) NSString *name;
// IOKit service name (e.g. 'modem')

@property (nonatomic, readonly, assign) NSString *portType;
// IOKit service type (e.g. kIOSerialBSDRS232Type)

@property (nonatomic, readonly, assign) NSDictionary *properties;
// IORegistry entry properties - see IORegistryEntryCreateCFProperties()


- (BOOL)isOpen;
// YES if port is open

- (AMSerialPort *)obtainBy:(id)sender;
// get this port exclusively; NULL if it's not free

- (void)free;
// give it back (and close the port if still open)

- (BOOL)available;
// check if port is free and can be obtained

- (id)owner;
// who obtained the port?


- (NSFileHandle *)open;
// opens port for read and write operations, allow shared access of port
// to actually read or write data use the methods provided by NSFileHandle
// (alternatively you may use those from AMSerialPortAdditions)

- (NSFileHandle *)openExclusively;
// opens port for read and write operations, insist on exclusive access to port
// to actually read or write data use the methods provided by NSFileHandle
// (alternatively you may use those from AMSerialPortAdditions)

- (void)close;
// close port - no more read or write operations allowed

- (BOOL)drainInput;
- (BOOL)flushInput:(BOOL)fIn output:(BOOL)fOut;	// (fIn or fOut) must be YES
- (BOOL)sendBreak;

- (BOOL)setDTR;
// set DTR - not yet tested!

- (BOOL)clearDTR;
// clear DTR - not yet tested!

// read and write serial port settings through a dictionary

- (NSDictionary *)options;
// will open the port to get options if neccessary

- (void)setOptions:(NSDictionary *)options;
// AMSerialOptionServiceName HAS to match! You may NOT switch ports using this
// method.

// reading and setting parameters is only useful if the serial port is already open
// after changing any of the following, one must send commitChanges
- (long)speed;
- (int)setSpeed:(long)speed; // returns 0 on success, errno on failure
@property (nonatomic) unsigned long dataBits; // 5 to 8 (5 may not work)
@property (nonatomic) AMSerialParity parity;
@property (nonatomic) AMSerialStopBits stopBits;
@property (nonatomic, getter=isEchoEnabled) BOOL echoEnabled;
@property (nonatomic) BOOL RTSInputFlowControl;
@property (nonatomic) BOOL DTRInputFlowControl;
@property (nonatomic) BOOL CTSOutputFlowControl;
@property (nonatomic) BOOL DSROutputFlowControl;
@property (nonatomic) BOOL CAROutputFlowControl;
@property (nonatomic) BOOL hangupOnClose;
@property (nonatomic) BOOL localMode; // YES = ignore modem status lines
@property (nonatomic) BOOL canonicalMode;
@property (nonatomic) char endOfLineCharacter;

- (int)commitChanges; // returns 0 on success, errno on failure


// setting the delegate (for background reading/writing)
@property (nonatomic, assign) id <AMSerialPortReadDelegate> readDelegate;
@property (nonatomic, assign) id <AMSerialPortWriteDelegate> writeDelegate;

// time out for blocking reads in seconds
- (NSTimeInterval)readTimeout;
- (void)setReadTimeout:(NSTimeInterval)aReadTimeout;

- (void)readTimeoutAsTimeval:(struct timeval*)timeout;

@end
