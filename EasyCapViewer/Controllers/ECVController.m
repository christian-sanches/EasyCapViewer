/* Copyright (c) 2009, Ben Trask
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY BEN TRASK ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL BEN TRASK BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */
#import "ECVController.h"
#import <IOKit/usb/IOUSBLib.h>
#import <IOKit/pwr_mgt/IOPMLib.h>

// Models
#import "ECVCaptureSession.h"

// Controllers
#import "EasyCapViewer-Swift.h"

// Other Sources
#import "ECVAppKitAdditions.h"
#import "ECVDebug.h"

static NSArray *ECVUSBDevices(void) // TODO: Put this somewhere better.
{
	NSMutableArray *const devices = [NSMutableArray array];
	io_iterator_t iterator = IO_OBJECT_NULL;
	if(kIOReturnSuccess != ECVIOReturn(IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(kIOUSBDeviceClassName), &iterator))) return devices;
	io_service_t service = IO_OBJECT_NULL;
	while((service = IOIteratorNext(iterator))) {
		NSMutableDictionary *properties = nil;
		{
			CFMutableDictionaryRef cfDict = NULL;
			if(kIOReturnSuccess != ECVIOReturn(IORegistryEntryCreateCFProperties(service, &cfDict, kCFAllocatorDefault, kNilOptions))) break;
			properties = (__bridge_transfer NSMutableDictionary *)cfDict;
		}
		[devices addObject:[NSString stringWithFormat:@"(%04x:%04x) %@ - %@",
			[[properties objectForKey:[NSString stringWithUTF8String:kUSBVendorID]] unsignedIntValue],
			[[properties objectForKey:[NSString stringWithUTF8String:kUSBProductID]] unsignedIntValue],
			[properties objectForKey:[NSString stringWithUTF8String:kUSBVendorString]] ?: @"????",
			[properties objectForKey:[NSString stringWithUTF8String:kUSBProductString]] ?: @"????"
			]];
		IOObjectRelease(service);
	}
	return devices;
}

static ECVController *ECVSharedController;

@interface ECVController(Private)

- (void)_userActivity;

@end

static void ECVDeviceAdded(Class deviceClass, io_iterator_t iterator)
{
	[[deviceClass devicesWithIterator:iterator] makeObjectsPerformSelector:@selector(ECV_display)];
	// Don't release the iterator because we want to continue receiving notifications.
}

@implementation ECVController

#pragma mark +ECVController

+ (id)sharedController
{
	return ECVSharedController;
}

#pragma mark -ECVController

- (IBAction)configureDevice:(id)sender
{
	[[[ECVAppDelegate shared] mainWindowController] toggleSettingsSidebar];
}
- (IBAction)showErrorLog:(id)sender
{
	[[[ECVAppDelegate shared] mainWindowController] toggleErrorLogSidebar];
}

#pragma mark -

@synthesize notificationPort = _notificationPort;
- (BOOL)playing
{
	return !!_playCount;
}
- (void)setPlaying:(BOOL)flag
{
	if(flag) {
		if(_playCount < NSUIntegerMax) _playCount++;
		if(1 == _playCount) IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep, kIOPMAssertionLevelOn, CFSTR("EasyCapViewer video capture"), &_sleepAssertion);
	} else {
		NSParameterAssert(_playCount);
		_playCount--;
		if(!_playCount) {
			IOPMAssertionRelease(_sleepAssertion);
			_sleepAssertion = 0;
		}
	}
}

#pragma mark -

- (void)noteCaptureSessionStartedPlaying:(ECVCaptureSession *)session
{
	[self setPlaying:YES];
}
- (void)noteCaptureSessionStoppedPlaying:(ECVCaptureSession *)session
{
	[self setPlaying:NO];
}

#pragma mark -

- (void)workspaceDidWake:(NSNotification *)aNotif
{
	for(NSNumber *const notif in _notifications) IOObjectRelease([notif unsignedIntValue]);
	[_notifications removeAllObjects];

	NSMutableArray *const devices = [NSMutableArray array];
	for(Class const class in [ECVCaptureDevice deviceClasses]) {
		NSDictionary *const matchingDict = [class matchingDictionary];
		io_iterator_t iterator = IO_OBJECT_NULL;
		if(kIOReturnSuccess != ECVIOReturn(IOServiceAddMatchingNotification(_notificationPort, kIOFirstMatchNotification, (__bridge_retained CFDictionaryRef)matchingDict, (IOServiceMatchingCallback)ECVDeviceAdded, (__bridge void *)class, &iterator))) continue;
		[devices addObjectsFromArray:[class devicesWithIterator:iterator]];
		[_notifications addObject:[NSNumber numberWithUnsignedInt:iterator]];
	}
	ECVLog(ECVNotice, @"USB Devices: %@", ECVUSBDevices());
	if([devices count]) return [devices makeObjectsPerformSelector:@selector(ECV_display)];
	// Show welcome view in main window
	[[ECVAppDelegate shared] showMainWindow];
}

#pragma mark -ECVController(Private)

#pragma mark -NSObject

- (id)init
{
	if((self = [super init])) {
		if(!ECVSharedController) ECVSharedController = self;
		_notificationPort = IONotificationPortCreate(kIOMainPortDefault);
		_notifications = [[NSMutableArray alloc] init];
		CFRunLoopAddSource(CFRunLoopGetCurrent(), IONotificationPortGetRunLoopSource(_notificationPort), kCFRunLoopDefaultMode);
	}
	return self;
}
- (void)dealloc
{
	CFRunLoopRemoveSource(CFRunLoopGetCurrent(), IONotificationPortGetRunLoopSource(_notificationPort), kCFRunLoopCommonModes);
	for(NSNumber *const notif in _notifications) IOObjectRelease([notif unsignedIntValue]);

	IONotificationPortDestroy(_notificationPort);
}

#pragma mark -NSObject(NSNibAwaking)

- (void)awakeFromNib
{
	[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(workspaceDidWake:) name:NSWorkspaceDidWakeNotification object:[NSWorkspace sharedWorkspace]];
	[self workspaceDidWake:nil];
}

@end

@implementation ECVCaptureDevice(ECVDisplaying)

- (void)ECV_display
{
	// Delay device setup to allow hardware to reset
	[self performSelector:@selector(ECV_setupDevice) withObject:nil afterDelay:1.0 inModes:[NSArray arrayWithObject:(NSString *)kCFRunLoopCommonModes]];
}
- (void)ECV_setupDevice
{
	if(![self isValid]) return;
	[[ECVAppDelegate shared] showMainWindow];
	[[[ECVAppDelegate shared] mainWindowController] connectDevice:self];
}

@end

@implementation NSError(ECVDisplaying)

- (void)ECV_display
{
	[[NSAlert alertWithError:self] runModal];
}

@end
