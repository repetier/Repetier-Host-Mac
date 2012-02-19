//
//  AMSerialPortList.m
//
//  Created by Andreas on 2002-04-24.
//  Copyright (c) 2001-2010 Andreas Mayer. All rights reserved.
//
//  2002-09-09 Andreas Mayer
//  - reuse AMSerialPort objects when calling init on an existing AMSerialPortList
//  2002-09-30 Andreas Mayer
//  - added +sharedPortList
//  2004-07-05 Andreas Mayer
//  - added some log statements
//  2007-05-22 Nick Zitzmann
//  - added notifications for when serial ports are added/removed
//  2007-07-18 Sean McBride
//  - minor improvements to the added/removed notification support
//  - changed singleton creation technique, now matches Apple's sample code
//  - removed oldPortList as it is no longer needed
//  2007-10-26 Sean McBride
//  - made code 64 bit and garbage collection clean
//  2008-10-21 Sean McBride
//  - fixed some memory management issues
//  2010-01-04 Sean McBride
//  - fixed some memory management issues


#import "AMSerialPortList.h"
#import "AMSerialPort.h"

#import <termios.h>

#import <CoreFoundation/CoreFoundation.h>

#import <IOKit/IOKitLib.h>
#import <IOKit/serial/IOSerialKeys.h>
#import <IOKit/IOBSD.h>

NSString * const AMSerialPortListDidAddPortsNotification = @"AMSerialPortListDidAddPortsNotification";
NSString * const AMSerialPortListDidRemovePortsNotification = @"AMSerialPortListDidRemovePortsNotification";
NSString * const AMSerialPortListAddedPorts = @"AMSerialPortListAddedPorts";
NSString * const AMSerialPortListRemovedPorts = @"AMSerialPortListRemovedPorts";

@implementation AMSerialPortList

+ (AMSerialPortList *)sharedPortList
{
    static dispatch_once_t pred;
    static AMSerialPortList *sharedPortList = nil;

    dispatch_once(&pred, ^{
        sharedPortList = [[AMSerialPortList alloc] init];
    });
    return sharedPortList;
}

- (AMSerialPort *)getNextSerialPort:(io_iterator_t)serialPortIterator
{
	AMSerialPort *serialPort = nil;

	io_object_t serialService = IOIteratorNext(serialPortIterator);
	if (serialService != 0) {
		CFStringRef modemName = (CFStringRef)IORegistryEntryCreateCFProperty(serialService, CFSTR(kIOTTYDeviceKey), kCFAllocatorDefault, 0);
		CFStringRef bsdPath = (CFStringRef)IORegistryEntryCreateCFProperty(serialService, CFSTR(kIOCalloutDeviceKey), kCFAllocatorDefault, 0);
		CFStringRef serviceType = (CFStringRef)IORegistryEntryCreateCFProperty(serialService, CFSTR(kIOSerialBSDTypeKey), kCFAllocatorDefault, 0);
		if (modemName && bsdPath) {
			// If the port already exists in the list of ports, we want that one.  We only create a new one as a last resort.
			serialPort = [self serialPortForName:(NSString*)bsdPath];
			if (!serialPort) {
				serialPort = [[[AMSerialPort alloc] initWithPath:(NSString*)bsdPath name:(NSString*)modemName type:(NSString*)serviceType] autorelease];
			}
		}
		if (modemName) {
			CFRelease(modemName);
		}
		if (bsdPath) {
			CFRelease(bsdPath);
		}
		if (serviceType) {
			CFRelease(serviceType);
		}
		
		// We have sucked this service dry of information so release it now.
		(void)IOObjectRelease(serialService);
	}
	
	return serialPort;
}

- (void)portsWereAdded:(io_iterator_t)iterator
{
	AMSerialPort *serialPort;
	NSMutableArray *addedPorts = [NSMutableArray array];
	
	while ((serialPort = [self getNextSerialPort:iterator]) != nil) {
		[addedPorts addObject:serialPort];
		[portList addObject:serialPort];
	}
	
	NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
	NSDictionary *userInfo = [NSDictionary dictionaryWithObject:addedPorts forKey:AMSerialPortListAddedPorts];
	[notifCenter postNotificationName:AMSerialPortListDidAddPortsNotification object:self userInfo:userInfo];
}

- (void)portsWereRemoved:(io_iterator_t)iterator
{
	AMSerialPort *serialPort;
	NSMutableArray *removedPorts = [NSMutableArray array];
	
	while ((serialPort = [self getNextSerialPort:iterator]) != nil) {
		// Since the port was removed, one should obviously not attempt to use it anymore -- so 'close' it.
		// -close does nothing if the port was never opened.
		[serialPort close];
		
		[removedPorts addObject:serialPort];
		[portList removeObject:serialPort];
	}

	NSNotificationCenter *notifCenter = [NSNotificationCenter defaultCenter];
	NSDictionary *userInfo = [NSDictionary dictionaryWithObject:removedPorts forKey:AMSerialPortListRemovedPorts];
	[notifCenter postNotificationName:AMSerialPortListDidRemovePortsNotification object:self userInfo:userInfo];
}

static void AMSerialPortWasAddedNotification(void *refcon, io_iterator_t iterator)
{
	(void)refcon;
	[[AMSerialPortList sharedPortList] portsWereAdded:iterator];
}

static void AMSerialPortWasRemovedNotification(void *refcon, io_iterator_t iterator)
{
	(void)refcon;
	[[AMSerialPortList sharedPortList] portsWereRemoved:iterator];
}

- (void)registerForSerialPortChangeNotifications
{
	notificationPort = IONotificationPortCreate(kIOMasterPortDefault); 
	if (notificationPort) {
		CFRunLoopSourceRef notificationSource = IONotificationPortGetRunLoopSource(notificationPort);
		if (notificationSource) {
			// Serial devices are instances of class IOSerialBSDClient
			CFMutableDictionaryRef classesToMatch1 = IOServiceMatching(kIOSerialBSDServiceValue);
			if (classesToMatch1) {
				CFDictionarySetValue(classesToMatch1, CFSTR(kIOSerialBSDTypeKey), CFSTR(kIOSerialBSDAllTypes));
				
				// Copy classesToMatch1 now, while it has a non-zero ref count.
				CFMutableDictionaryRef classesToMatch2 = CFDictionaryCreateMutableCopy(kCFAllocatorDefault, 0, classesToMatch1);
				// Add to the runloop
				CFRunLoopAddSource([[NSRunLoop currentRunLoop] getCFRunLoop], notificationSource, kCFRunLoopCommonModes);
				
				// Set up notification for ports being added.
				io_iterator_t unused;
				kern_return_t kernResult = IOServiceAddMatchingNotification(notificationPort, kIOPublishNotification, classesToMatch1, AMSerialPortWasAddedNotification, NULL, &unused); // consumes a reference to classesToMatch1
				if (kernResult != KERN_SUCCESS) {
#ifdef AMSerialDebug
					NSLog(@"Error %d when setting up add notifications!", kernResult);
#endif
				} else {
					while (IOIteratorNext(unused)) {}	// arm the notification
				}
					
				if (classesToMatch2) {
					// Set up notification for ports being removed.
					kernResult = IOServiceAddMatchingNotification(notificationPort, kIOTerminatedNotification, classesToMatch2, AMSerialPortWasRemovedNotification, NULL, &unused); // consumes a reference to classesToMatch2
					if (kernResult != KERN_SUCCESS) {
#ifdef AMSerialDebug
						NSLog(@"Error %d when setting up add notifications!", kernResult);
#endif
					} else {
						while (IOIteratorNext(unused)) {}	// arm the notification
					}
				}
			} else {
#ifdef AMSerialDebug
				NSLog(@"IOServiceMatching returned a NULL dictionary.");
#endif
			}
		}
		// Note that IONotificationPortDestroy(notificationPort) is deliberately not called here because if it were our port change notifications would never fire. It is instead deferred until -dealloc
	}
}

- (void)addAllSerialPortsToArray:(NSMutableArray *)array
{
	kern_return_t kernResult;
	CFMutableDictionaryRef classesToMatch;
	io_iterator_t serialPortIterator;
	AMSerialPort *serialPort;
	
	// Serial devices are instances of class IOSerialBSDClient
	classesToMatch = IOServiceMatching(kIOSerialBSDServiceValue);
	if (classesToMatch != NULL) {
		CFDictionarySetValue(classesToMatch, CFSTR(kIOSerialBSDTypeKey), CFSTR(kIOSerialBSDAllTypes));

		// This function decrements the refcount of the dictionary passed it
		kernResult = IOServiceGetMatchingServices(kIOMasterPortDefault, classesToMatch, &serialPortIterator);
		if (kernResult == KERN_SUCCESS) {
			while ((serialPort = [self getNextSerialPort:serialPortIterator]) != nil) {
				[array addObject:serialPort];
			}
			(void)IOObjectRelease(serialPortIterator);
		} else {
#ifdef AMSerialDebug
			NSLog(@"IOServiceGetMatchingServices returned %d", kernResult);
#endif
		}
	} else {
#ifdef AMSerialDebug
		NSLog(@"IOServiceMatching returned a NULL dictionary.");
#endif
	}
}

#pragma mark -

- (id)init
{
    self = [super init];
    if (self) {
        portList = [[NSMutableArray array] retain];

        [self addAllSerialPortsToArray:portList];
        [self registerForSerialPortChangeNotifications];
    }    
    return self;
}

- (void)dealloc {
    if (notificationPort)
        IONotificationPortDestroy(notificationPort);

    [portList release];

    [super dealloc];
}

#pragma mark -

- (NSArray *)serialPorts
{
	return [[portList copy] autorelease];
}

- (AMSerialPort *)serialPortForPath:(NSString *)bsdPath
{
    __block AMSerialPort *result = nil;
    [portList enumerateObjectsUsingBlock:^(id port, NSUInteger idx, BOOL *stop) {
        if (![[port bsdPath] isEqualToString:bsdPath])
            return;
        result = port;
        *stop = YES;
    }];
    return result;
}

- (AMSerialPort *)serialPortForName:(NSString *)name
{
    __block AMSerialPort *result = nil;
    [portList enumerateObjectsUsingBlock:^(id port, NSUInteger idx, BOOL *stop) {
        if (![[port name] isEqualToString:name])
            return;
        result = port;
        *stop = YES;
    }];
    return result;
}

- (NSArray *)serialPortsOfType:(NSString *)serialTypeKey
{
    __block NSMutableArray *result = [NSMutableArray array];
    [portList enumerateObjectsUsingBlock:^(id port, NSUInteger idx, BOOL *stop) {
        if (![[port portType] isEqualToString:serialTypeKey])
            return;
        [result addObject:port];
    }];
    return result;
}

@end
