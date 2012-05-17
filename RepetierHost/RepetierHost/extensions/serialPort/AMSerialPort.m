//
//  AMSerialPort.m
//
//  Created by Andreas on 2002-04-24.
//  Copyright (c) 2001-2009 Andreas Mayer. All rights reserved.
//
//  2002-09-18 Andreas Mayer
//  - added available & owner
//  2002-10-10 Andreas Mayer
//	- some log messages changed
//  2002-10-25 Andreas Mayer
//	- additional locks and other changes for reading and writing in background
//  2003-11-26 James Watson
//	- in dealloc [self close] reordered to execute before releasing closeLock
//  2007-05-22 Nick Zitzmann
//  - added -hash and -isEqual: methods
//  2007-07-18 Sean McBride
//  - behaviour change: -open and -close must now always be matched, -dealloc checks this
//  - added -debugDescription so gdb's 'po' command gives something useful
//  2007-07-25 Andreas Mayer
// - replaced -debugDescription by -description; works for both, gdb's 'po' and NSLog()
//  2007-10-26 Sean McBride
//  - made code 64 bit and garbage collection clean
//  2008-10-21 Sean McBride
//  - Added an API to open a serial port for exclusive use
//  - fixed some memory management issues
//  2009-08-06 Sean McBride
//  - no longer compare BOOL against YES (dangerous!)
//  - renamed method to start with lowercase letter, as per Cocoa convention

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
#import <sys/ioctl.h>

#import "AMSerialPort.h"
#import "AMSerialErrors.h"

#import <IOKit/serial/IOSerialKeys.h>
#import <IOKit/serial/ioss.h>

NSString * const AMSerialErrorDomain = @"de.harmless.AMSerial.ErrorDomain";

NSString * const AMSerialOptionServiceName = @"AMSerialOptionServiceName";
NSString * const AMSerialOptionSpeed = @"AMSerialOptionSpeed";
NSString * const AMSerialOptionDataBits = @"AMSerialOptionDataBits";
NSString * const AMSerialOptionParity = @"AMSerialOptionParity";
NSString * const AMSerialOptionStopBits = @"AMSerialOptionStopBits";
NSString * const AMSerialOptionInputFlowControl = @"AMSerialOptionInputFlowControl";
NSString * const AMSerialOptionOutputFlowControl = @"AMSerialOptionOutputFlowControl";
NSString * const AMSerialOptionEcho = @"AMSerialOptionEcho";
NSString * const AMSerialOptionCanonicalMode = @"AMSerialOptionCanonicalMode";

@interface AMSerialPort()
- (NSFileHandle *)openWithFlags:(int)flags;
- (void)buildOptionsDictionary;
@end

@implementation AMSerialPort

@synthesize bsdPath, name = serviceName, portType = serviceType, readDelegate, writeDelegate;
@dynamic properties, dataBits, parity, stopBits, echoEnabled, RTSInputFlowControl, DTRInputFlowControl, CTSOutputFlowControl, DSROutputFlowControl, CAROutputFlowControl, hangupOnClose, localMode, canonicalMode, endOfLineCharacter;

- (id)initWithPath:(NSString *)path name:(NSString *)name type:(NSString *)type
	// path is a bsdPath
	// name is an IOKit service name
{
    self = [super init];
	if (self) {
		bsdPath = [path copy];
		serviceName = [name copy];
		serviceType = [type copy];
		optionsDictionary = [[NSMutableDictionary dictionaryWithCapacity:8] retain];
		options = (struct termios* __strong)malloc(sizeof(*options));
		originalOptions = (struct termios* __strong)malloc(sizeof(*originalOptions));
		buffer = (char* __strong)malloc(AMSER_MAXBUFSIZE);
		readfds = (fd_set* __strong)malloc(sizeof(*readfds));
		fileDescriptor = -1;
		
		writeLock = [[NSLock alloc] init];
		readLock = [[NSLock alloc] init];
		closeLock = [[NSLock alloc] init];
		
		// By default blocking read attempts will timeout after 1 second
		[self setReadTimeout:1.0];
		
		// These are used by the AMSerialPortAdditions category only; pretend to use them here to silence warnings by the clang static analyzer.
		(void)am_readTarget;
		(void)am_readSelector;
		(void)stopWriteInBackground;
		(void)countWriteInBackgroundThreads;
		(void)stopReadInBackground;
		(void)countReadInBackgroundThreads;
	}
	return self;
}

- (void)dealloc
{
#ifdef AMSerialDebug
	if (fileDescriptor != -1)
		NSLog(@"It is a programmer error to have not called -close on an AMSerialPort you have opened");
#endif

	[readLock release]; readLock = nil;
	[writeLock release]; writeLock = nil;
	[closeLock release]; closeLock = nil;
	[am_readTarget release]; am_readTarget = nil;

	free(readfds); readfds = NULL;
	free(buffer); buffer = NULL;
	free(originalOptions); originalOptions = NULL;
	free(options); options = NULL;
	[optionsDictionary release]; optionsDictionary = nil;
	[serviceName release]; serviceName = nil;
	[serviceType release]; serviceType = nil;
	[bsdPath release]; bsdPath = nil;
	[super dealloc];
}

- (id)copy {
    return [[[self class] alloc] initWithPath:bsdPath name:serviceName type:serviceType];
}

// So NSLog and gdb's 'po' command give something useful
- (NSString *)description
{
	NSString *result= [NSString stringWithFormat:@"<%@: address: %p, name: %@, path: %@, type: %@, fileHandle: %@, fileDescriptor: %d>", NSStringFromClass([self class]), self, self.name, self.bsdPath, self.portType, fileHandle, fileDescriptor];
	return result;
}

- (NSUInteger)hash
{
	return [self.bsdPath hash];
}

- (BOOL)isEqual:(id)otherObject
{
    return [otherObject isKindOfClass:[AMSerialPort class]] && [[(AMSerialPort*)otherObject bsdPath] isEqualToString:self.bsdPath];
}

#pragma mark -

- (NSDictionary *)properties
{
	NSDictionary *result = nil;
	kern_return_t kernResult; 
	CFMutableDictionaryRef matchingDictionary;
	io_service_t serialService;
	
	matchingDictionary = IOServiceMatching(kIOSerialBSDServiceValue);
	CFDictionarySetValue(matchingDictionary, CFSTR(kIOTTYDeviceKey), (CFStringRef)[self name]);
	if (matchingDictionary != NULL) {
		CFRetain(matchingDictionary);
		// This function decrements the refcount of the dictionary passed it
		serialService = IOServiceGetMatchingService(kIOMasterPortDefault, matchingDictionary);
		
		if (serialService) {
			CFMutableDictionaryRef propertiesDict = NULL;
			kernResult = IORegistryEntryCreateCFProperties(serialService, &propertiesDict, kCFAllocatorDefault, 0);
			if (kernResult == KERN_SUCCESS) {
				result = [[(NSDictionary*)propertiesDict copy] autorelease];
			}
			if (propertiesDict) {
				CFRelease(propertiesDict);
			}
			// We have sucked this service dry of information so release it now.
			(void)IOObjectRelease(serialService);
		} else {
#ifdef AMSerialDebug
			NSLog(@"properties: no matching service for %@", matchingDictionary);
#endif
		}
		CFRelease(matchingDictionary);
	}
	return result;
}

#pragma mark -

- (BOOL)isOpen
{
	// YES if port is open
	return (fileDescriptor >= 0);
}

- (AMSerialPort *)obtainBy:(id)sender
{
	// get this port exclusively; NULL if it's not free
	if (!owner) {
		owner = sender;
		return self;
	} else
		return nil;
}

- (void)free
{
	// give it back
	owner = nil;
	[self close];	// you never know ...
}

- (BOOL)available
{
	// check if port is free and can be obtained
	return (owner == nil);
}

- (id)owner
{
	// who obtained the port?
	return owner;
}

// Private
- (NSFileHandle *)openWithFlags:(int)flags // use returned file handle to read and write
{
	NSFileHandle *result = nil;
	
	const char *path = [bsdPath fileSystemRepresentation];
	fileDescriptor = open(path, flags);

#ifdef AMSerialDebug
	NSLog(@"open %@ (%d)\n", bsdPath, fileDescriptor);
#endif
	
	if (fileDescriptor < 0)	{
#ifdef AMSerialDebug
		NSLog(@"Error opening serial port %@ - %s(%d).\n", bsdPath, strerror(errno), errno);
#endif
	} else {
		/*
		 if (fcntl(fileDescriptor, F_SETFL, fcntl(fileDescriptor, F_GETFL, 0) & !O_NONBLOCK) == -1)
		 {
			 NSLog(@"Error clearing O_NDELAY %@ - %s(%d).\n", bsdPath, strerror(errno), errno);
		 } // ... else
		 */

#ifdef AMSerialDebug
        NSLog(@"will get port tty attributes for %@ (%d)", bsdPath, fileDescriptor);
#endif

		// get the current options and save them for later reset
		if (tcgetattr(fileDescriptor, originalOptions) == -1) {
#ifdef AMSerialDebug
			NSLog(@"Error getting tty attributes %@ - %s(%d).\n", bsdPath, strerror(errno), errno);
#endif
		} else {
			// Make an exact copy of the options
			*options = *originalOptions;

#ifdef AMSerialDebug
            NSLog(@"will create NSFileHandle from descriptor (%d) for port %@", fileDescriptor, bsdPath);
#endif

			// This object owns the fileDescriptor and must dispose it later
			// In other words, you must balance calls to -open with -close
			fileHandle = [[NSFileHandle alloc] initWithFileDescriptor:fileDescriptor];
			result = fileHandle;
		}
	}
	if (!result) { // failure
		if (fileDescriptor >= 0) {
			close(fileDescriptor);
		}
		fileDescriptor = -1;
	}
	return result;
}

// TODO: Sean: why is O_NONBLOCK commented?  Do we want it or not?

// use returned file handle to read and write
- (NSFileHandle *)open
{
	return [self openWithFlags:(O_RDWR | O_NOCTTY)]; // | O_NONBLOCK);
}

// use returned file handle to read and write
- (NSFileHandle *)openExclusively
{
	return [self openWithFlags:(O_RDWR | O_NOCTTY | O_EXLOCK | O_NONBLOCK)]; // | O_NONBLOCK);
}

- (void)close
{
	// Traditionally it is good to reset a serial port back to
	// the state in which you found it.  Let's continue that tradition.
	if (fileDescriptor >= 0) {
		//NSLog(@"close - attempt closeLock");
		[closeLock lock];
		//NSLog(@"close - closeLock locked");
		
		// kill pending read by setting O_NONBLOCK
		if (fcntl(fileDescriptor, F_SETFL, fcntl(fileDescriptor, F_GETFL, 0) | O_NONBLOCK) == -1) {
#ifdef AMSerialDebug
			NSLog(@"Error clearing O_NONBLOCK %@ - %s(%d).\n", bsdPath, strerror(errno), errno);
#endif
		}
		if (tcsetattr(fileDescriptor, TCSANOW, originalOptions) == -1) {
#ifdef AMSerialDebug
			NSLog(@"Error resetting tty attributes - %s(%d).\n", strerror(errno), errno);
#endif
		}
		
		// Disallows further access to the communications channel
		[fileHandle closeFile];

		// Release the fileHandle
		[fileHandle release];
		fileHandle = nil;
		
#ifdef AMSerialDebug
		NSLog(@"close (%d)\n", fileDescriptor);
#endif
		// Close the fileDescriptor, that is our responsibility since the fileHandle does not own it
		close(fileDescriptor);
		fileDescriptor = -1;
		
		[closeLock unlock];
		//NSLog(@"close - closeLock unlocked");
	}
}

- (BOOL)drainInput
{
	BOOL result = (tcdrain(fileDescriptor) != -1);
	return result;
}

- (BOOL)flushInput:(BOOL)fIn output:(BOOL)fOut	// (fIn or fOut) must be YES
{
	int mode = 0;
	if (fIn)
		mode = TCIFLUSH;
	if (fOut)
		mode = TCOFLUSH;
	if (fIn && fOut)
		mode = TCIOFLUSH;
	
	BOOL result = (tcflush(fileDescriptor, mode) != -1);
	return result;
}

- (BOOL)sendBreak
{
	BOOL result = (tcsendbreak(fileDescriptor, 0) != -1);
	return result;
}

- (BOOL)setDTR
{
	BOOL result = (ioctl(fileDescriptor, TIOCSDTR) != -1);
	return result;
}

- (BOOL)clearDTR
{
    NSLog(@"Clear error:%i",(int)ioctl(fileDescriptor, TIOCCDTR));
	BOOL result = (ioctl(fileDescriptor, TIOCCDTR) != -1);
	return result;
}

#pragma mark -

// read and write serial port settings through a dictionary

- (void)buildOptionsDictionary
{
	[optionsDictionary removeAllObjects];
	[optionsDictionary setObject:[self name] forKey:AMSerialOptionServiceName];
	[optionsDictionary setObject:[NSString stringWithFormat:@"%ld", [self speed]] forKey:AMSerialOptionSpeed];
	[optionsDictionary setObject:[NSString stringWithFormat:@"%lu", self.dataBits] forKey:AMSerialOptionDataBits];
	switch (self.parity) {
		case kAMSerialParityOdd: {
			[optionsDictionary setObject:@"Odd" forKey:AMSerialOptionParity];
			break;
		}
		case kAMSerialParityEven: {
			[optionsDictionary setObject:@"Even" forKey:AMSerialOptionParity];
			break;
		}
		default:;
	}
	
	[optionsDictionary setObject:[NSString stringWithFormat:@"%d", self.stopBits] forKey:AMSerialOptionStopBits];
	if (self.RTSInputFlowControl)
		[optionsDictionary setObject:@"RTS" forKey:AMSerialOptionInputFlowControl];
    if (self.DTRInputFlowControl)
		[optionsDictionary setObject:@"DTR" forKey:AMSerialOptionInputFlowControl];	
	if (self.CTSOutputFlowControl)
		[optionsDictionary setObject:@"CTS" forKey:AMSerialOptionOutputFlowControl];
	if (self.DSROutputFlowControl)
		[optionsDictionary setObject:@"DSR" forKey:AMSerialOptionOutputFlowControl];
	if (self.CAROutputFlowControl)
		[optionsDictionary setObject:@"CAR" forKey:AMSerialOptionOutputFlowControl];
	
	if (self.isEchoEnabled)
		[optionsDictionary setObject:@"YES" forKey:AMSerialOptionEcho];

	if (self.canonicalMode)
		[optionsDictionary setObject:@"YES" forKey:AMSerialOptionCanonicalMode];

}


- (NSDictionary *)options
{
	// will open the port to get options if neccessary
	if (![optionsDictionary objectForKey:AMSerialOptionServiceName]) {
		if (fileDescriptor < 0) {
			[self open];
			[self close];
		}
		[self buildOptionsDictionary];
	}
	return [NSMutableDictionary dictionaryWithDictionary:optionsDictionary];
}

- (void)setOptions:(NSDictionary *)newOptions
{
	// AMSerialOptionServiceName HAS to match! You may NOT switch ports using this
	// method.
	NSString *temp;
	
	if ([(NSString *)[newOptions objectForKey:AMSerialOptionServiceName] isEqualToString:self.name]) {
		[optionsDictionary addEntriesFromDictionary:newOptions];
		// parse dictionary
		temp = (NSString *)[optionsDictionary objectForKey:AMSerialOptionSpeed];
		[self setSpeed:[temp intValue]];
		
		temp = (NSString *)[optionsDictionary objectForKey:AMSerialOptionDataBits];
		self.dataBits = [temp intValue];
		
		temp = (NSString *)[optionsDictionary objectForKey:AMSerialOptionParity];
		if (!temp)
			self.parity = kAMSerialParityNone;
		else if ([temp isEqualToString:@"Odd"])
			self.parity = kAMSerialParityOdd;
		else
			self.parity = kAMSerialParityEven;
		
		temp = (NSString *)[optionsDictionary objectForKey:AMSerialOptionStopBits];
		AMSerialStopBits numStopBits = (AMSerialStopBits)[temp intValue];
		self.stopBits = numStopBits;
		
		temp = (NSString *)[optionsDictionary objectForKey:AMSerialOptionInputFlowControl];
		self.RTSInputFlowControl = [temp isEqualToString:@"RTS"];
		self.DTRInputFlowControl = [temp isEqualToString:@"DTR"];
		
		temp = (NSString *)[optionsDictionary objectForKey:AMSerialOptionOutputFlowControl];
		self.CTSOutputFlowControl = [temp isEqualToString:@"CTS"];
		self.DSROutputFlowControl = [temp isEqualToString:@"DSR"];
		self.CAROutputFlowControl = [temp isEqualToString:@"CAR"];
		
		temp = (NSString *)[optionsDictionary objectForKey:AMSerialOptionEcho];
		self.echoEnabled = (temp != nil);

		temp = (NSString *)[optionsDictionary objectForKey:AMSerialOptionCanonicalMode];
		self.canonicalMode = (temp != nil);

		[self commitChanges];
	} else {
#ifdef AMSerialDebug
		NSLog(@"Error setting options for port %@ (wrong port name: %@).\n", self.name, [newOptions objectForKey:AMSerialOptionServiceName]);
#endif
	}
}

#pragma mark -

- (long)speed
{
	return cfgetospeed(options);	// we should support cfgetispeed too
}

- (int)setSpeed:(long)speed
{
	// we should support setting input and output speed separately
	int errorCode = 0;

// ***NOTE***: This code does not seem to work.  It was taken from Apple's sample code:
// <http://developer.apple.com/samplecode/SerialPortSample/listing2.html>
// and that code does not work either.  select() times out regularly if this code path is taken.
#if 1 && defined(MAC_OS_X_VERSION_10_4) && (MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_4)
	// Starting with Tiger, the IOSSIOSPEED ioctl can be used to set arbitrary baud rates
	// other than those specified by POSIX. The driver for the underlying serial hardware
	// ultimately determines which baud rates can be used. This ioctl sets both the input
	// and output speed. 
	
	speed_t newSpeed = speed;
	if (fileDescriptor >= 0) {
        cfsetspeed(options, speed);
		errorCode = ioctl(fileDescriptor, IOSSIOSPEED, &newSpeed);
	} else {
		errorCode = EBADF; // Bad file descriptor
	}
#else
	// set both the input and output speed
	errorCode = cfsetspeed(options, speed);
#endif
	if (errorCode == -1) {
		errorCode = errno;
	}

    return errorCode;
}

- (unsigned long)dataBits
{
	return 5 + ((options->c_cflag & CSIZE) >> 8);
	// man ... I *hate* C syntax ...
}

- (void)setDataBits:(unsigned long)bits	// 5 to 8 (5 is marked as "(pseudo)")
{
	// ?? options->c_oflag &= ~OPOST;
	options->c_cflag &= ~CSIZE;
	switch (bits) {
		case 5:	options->c_cflag |= CS5;	// redundant since CS5 == 0
			break;
		case 6:	options->c_cflag |= CS6;
			break;
		case 7:	options->c_cflag |= CS7;
			break;
		case 8:	options->c_cflag |= CS8;
			break;
	}
}


- (AMSerialParity)parity
{
	AMSerialParity result;
	if (options->c_cflag & PARENB) {
		if (options->c_cflag & PARODD) {
			result = kAMSerialParityOdd;
		} else {
			result = kAMSerialParityEven;
		}
	} else {
		result = kAMSerialParityNone;
	}
	return result;
}

- (void)setParity:(AMSerialParity)newParity
{
	switch (newParity) {
		case kAMSerialParityNone: {
			options->c_cflag &= ~PARENB;
			break;
		}
		case kAMSerialParityOdd: {
			options->c_cflag |= PARENB;
			options->c_cflag |= PARODD;
			break;
		}
		case kAMSerialParityEven: {
			options->c_cflag |= PARENB;
			options->c_cflag &= ~PARODD;
			break;
		}
	}
}


- (AMSerialStopBits)stopBits
{
	if (options->c_cflag & CSTOPB)
		return kAMSerialStopBitsTwo;
	else
		return kAMSerialStopBitsOne;
}

- (void)setStopBits:(AMSerialStopBits)numBits
{
	if (numBits == kAMSerialStopBitsOne)
		options->c_cflag &= ~CSTOPB;
	else if (numBits == kAMSerialStopBitsTwo)
		options->c_cflag |= CSTOPB;
}


- (BOOL)isEchoEnabled
{
	return (options->c_lflag & ECHO);
}

- (void)setEchoEnabled:(BOOL)echo
{
	if (echo)
		options->c_lflag |= ECHO;
	else
		options->c_lflag &= ~ECHO;
}


- (BOOL)RTSInputFlowControl
{
	return (options->c_cflag & CRTS_IFLOW) != 0;
}

- (void)setRTSInputFlowControl:(BOOL)rts
{
	if (rts)
		options->c_cflag |= CRTS_IFLOW;
	else
		options->c_cflag &= ~CRTS_IFLOW;
}


- (BOOL)DTRInputFlowControl
{
	return (options->c_cflag & CDTR_IFLOW) != 0;
}

- (void)setDTRInputFlowControl:(BOOL)dtr
{
	if (dtr)
		options->c_cflag |= CDTR_IFLOW;
	else
		options->c_cflag &= ~CDTR_IFLOW;
}


- (BOOL)CTSOutputFlowControl
{
	return (options->c_cflag & CCTS_OFLOW) != 0;
}

- (void)setCTSOutputFlowControl:(BOOL)cts
{
	if (cts)
		options->c_cflag |= CCTS_OFLOW;
	else
		options->c_cflag &= ~CCTS_OFLOW;
}


- (BOOL)DSROutputFlowControl
{
	return (options->c_cflag & CDSR_OFLOW) != 0;
}

- (void)setDSROutputFlowControl:(BOOL)dsr
{
	if (dsr)
		options->c_cflag |= CDSR_OFLOW;
	else
		options->c_cflag &= ~CDSR_OFLOW;
}


- (BOOL)CAROutputFlowControl
{
	return (options->c_cflag & CCAR_OFLOW) != 0;
}

- (void)setCAROutputFlowControl:(BOOL)car
{
	if (car)
		options->c_cflag |= CCAR_OFLOW;
	else
		options->c_cflag &= ~CCAR_OFLOW;
}


- (BOOL)hangupOnClose
{
	return (options->c_cflag & HUPCL) != 0;
}

- (void)setHangupOnClose:(BOOL)hangup
{
	if (hangup)
		options->c_cflag |= HUPCL;
	else
		options->c_cflag &= ~HUPCL;
}

- (BOOL)localMode
{
	return (options->c_cflag & CLOCAL) != 0;
}

- (void)setLocalMode:(BOOL)local
{
	// YES = ignore modem status lines
	if (local)
		options->c_cflag |= CLOCAL;
	else
		options->c_cflag &= ~CLOCAL;
}

- (BOOL)canonicalMode
{
	return (options->c_lflag & ICANON) != 0;
}

- (void)setCanonicalMode:(BOOL)flag
{
	if (flag)
		options->c_lflag |= ICANON;
	else
		options->c_lflag &= ~ICANON;
}

- (char)endOfLineCharacter
{
	return options->c_cc[VEOL];
}

- (void)setEndOfLineCharacter:(char)eol
{
	options->c_cc[VEOL] = eol;
}

- (int)commitChanges
{
    int status = 0;
	if (tcsetattr(fileDescriptor, TCSANOW, options) == -1) {
		// something went wrong
		status = errno;
	} else {
		[self buildOptionsDictionary];
	}
    return status;
}

#pragma mark -

- (NSTimeInterval)readTimeout
{
    return readTimeout;
}

- (void)setReadTimeout:(NSTimeInterval)aReadTimeout
{
    readTimeout = aReadTimeout;
}

- (void)readTimeoutAsTimeval:(struct timeval*)timeout
{
	NSTimeInterval timeoutInterval = [self readTimeout];
	double numSecs = trunc(timeoutInterval);
	double numUSecs = (timeoutInterval-numSecs)*1000000.0;
	timeout->tv_sec = (time_t)lrint(numSecs);
	timeout->tv_usec = (suseconds_t)lrint(numUSecs);
}

@end
