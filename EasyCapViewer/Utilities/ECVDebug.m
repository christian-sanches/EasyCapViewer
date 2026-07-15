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
#import "ECVDebug.h"
#if defined(ECV_ENABLE_AUDIO)
	#import <AudioToolbox/AudioToolbox.h>
#endif
#import <IOKit/usb/IOUSBLib.h>
#import <IOKit/IOMessage.h>
#import <mach/mach_port.h>
#import <Foundation/NSDebug.h>
#import <string.h>

// Controllers
#import "ECVErrorLogBridge.h"

void ECVLog(ECVErrorLevel level, NSString *format, ...)
{
	@autoreleasepool {
		va_list arguments;
#if defined(ECV_LOG_TO_CONSOLE)
		va_start(arguments, format);
		NSLogv(format, arguments);
		va_end(arguments);
#endif
#if defined(ECV_LOG_TO_WINDOW)
		va_start(arguments, format);
		[[ECVErrorLogBridge sharedBridge] logLevel:level format:format arguments:arguments];
		va_end(arguments);
#endif
#if defined(ECV_LOG_TO_DESKTOP)
		NSOutputStream *const stream = [NSOutputStream outputStreamToFileAtPath:[@"~/Desktop/ECVViewer.log" stringByExpandingTildeInPath] append:YES];
		[stream open];
		va_start(arguments, format);
		NSData *const data = [[[NSString alloc] initWithFormat:format arguments:arguments] stringByAppendingString:@"\n"];
		va_end(arguments);
		[stream write:[data bytes] maxLength:[data length]];
		[stream close];
#endif
	}
}

#pragma mark -

#define ERROR_CASE(val) case (val): return [NSString stringWithUTF8String:#val];

NSString *ECVOSStatusToString(OSStatus error)
{
	switch(error) {
		/* Most are listed in MacErrors.h. There are WAY too many to define them all. */
		ERROR_CASE(noErr)

		ERROR_CASE(badDragRefErr)
		ERROR_CASE(badDragItemErr)
		ERROR_CASE(badDragFlavorErr)
		ERROR_CASE(duplicateFlavorErr)
		ERROR_CASE(cantGetFlavorErr)
		ERROR_CASE(duplicateHandlerErr)
		ERROR_CASE(handlerNotFoundErr)
		ERROR_CASE(dragNotAcceptedErr)
		ERROR_CASE(unsupportedForPlatformErr)
		ERROR_CASE(noSuitableDisplaysErr)
		ERROR_CASE(badImageRgnErr)
		ERROR_CASE(badImageErr)
		ERROR_CASE(nonDragOriginatorErr)

#if defined(ECV_ENABLE_AUDIO)
		ERROR_CASE(kAudioConverterErr_FormatNotSupported)
		ERROR_CASE(kAudioConverterErr_OperationNotSupported)
		ERROR_CASE(kAudioConverterErr_PropertyNotSupported)
		ERROR_CASE(kAudioConverterErr_InvalidInputSize)
		ERROR_CASE(kAudioConverterErr_InvalidOutputSize)
		ERROR_CASE(kAudioConverterErr_UnspecifiedError) // AKA kAudioHardwareUnspecifiedError
		ERROR_CASE(kAudioConverterErr_BadPropertySizeError) // AKA kAudioHardwareBadPropertySizeError
		ERROR_CASE(kAudioConverterErr_RequiresPacketDescriptionsError)
		ERROR_CASE(kAudioConverterErr_InputSampleRateOutOfRange)
		ERROR_CASE(kAudioConverterErr_OutputSampleRateOutOfRange)

		ERROR_CASE(kAudioHardwareNotRunningError)
		ERROR_CASE(kAudioHardwareUnknownPropertyError)
		ERROR_CASE(kAudioHardwareIllegalOperationError)
		ERROR_CASE(kAudioHardwareBadObjectError)
		ERROR_CASE(kAudioHardwareBadDeviceError)
		ERROR_CASE(kAudioHardwareBadStreamError)
		ERROR_CASE(kAudioHardwareUnsupportedOperationError)
		ERROR_CASE(kAudioDeviceUnsupportedFormatError)
		ERROR_CASE(kAudioDevicePermissionsError)
#endif
	}
	return [NSString stringWithFormat:@"Unknown error %ld (0x%08x)", (long)error, (unsigned int)error];
}
NSString *ECVIOKitErrorToString(IOReturn error)
{
	switch(error) {
		ERROR_CASE(kIOReturnSuccess)
		ERROR_CASE(kIOReturnError)
		ERROR_CASE(kIOReturnNoMemory)
		ERROR_CASE(kIOReturnNoResources)
		ERROR_CASE(kIOReturnIPCError)
		ERROR_CASE(kIOReturnNoDevice)
		ERROR_CASE(kIOReturnNotPrivileged)
		ERROR_CASE(kIOReturnBadArgument)
		ERROR_CASE(kIOReturnLockedRead)
		ERROR_CASE(kIOReturnLockedWrite)
		ERROR_CASE(kIOReturnExclusiveAccess)
		ERROR_CASE(kIOReturnBadMessageID)
		ERROR_CASE(kIOReturnUnsupported)
		ERROR_CASE(kIOReturnVMError)
		ERROR_CASE(kIOReturnInternalError)
		ERROR_CASE(kIOReturnIOError)
		ERROR_CASE(kIOReturnCannotLock)
		ERROR_CASE(kIOReturnNotOpen)
		ERROR_CASE(kIOReturnNotReadable)
		ERROR_CASE(kIOReturnNotWritable)
		ERROR_CASE(kIOReturnNotAligned)
		ERROR_CASE(kIOReturnBadMedia)
		ERROR_CASE(kIOReturnStillOpen)
		ERROR_CASE(kIOReturnRLDError)
		ERROR_CASE(kIOReturnDMAError)
		ERROR_CASE(kIOReturnBusy)
		ERROR_CASE(kIOReturnTimeout)
		ERROR_CASE(kIOReturnOffline)
		ERROR_CASE(kIOReturnNotReady)
		ERROR_CASE(kIOReturnNotAttached)
		ERROR_CASE(kIOReturnNoChannels)
		ERROR_CASE(kIOReturnNoSpace)
		ERROR_CASE(kIOReturnPortExists)
		ERROR_CASE(kIOReturnCannotWire)
		ERROR_CASE(kIOReturnNoInterrupt)
		ERROR_CASE(kIOReturnNoFrames)
		ERROR_CASE(kIOReturnMessageTooLarge)
		ERROR_CASE(kIOReturnNotPermitted)
		ERROR_CASE(kIOReturnNoPower)
		ERROR_CASE(kIOReturnNoMedia)
		ERROR_CASE(kIOReturnUnformattedMedia)
		ERROR_CASE(kIOReturnUnsupportedMode)
		ERROR_CASE(kIOReturnUnderrun)
		ERROR_CASE(kIOReturnOverrun)
		ERROR_CASE(kIOReturnDeviceError)
		ERROR_CASE(kIOReturnNoCompletion)
		ERROR_CASE(kIOReturnAborted)
		ERROR_CASE(kIOReturnNoBandwidth)
		ERROR_CASE(kIOReturnNotResponding)
		ERROR_CASE(kIOReturnIsoTooOld)
		ERROR_CASE(kIOReturnIsoTooNew)
		ERROR_CASE(kIOReturnNotFound)
		ERROR_CASE(kIOReturnInvalid)

		ERROR_CASE(kIOUSBUnknownPipeErr)
		ERROR_CASE(kIOUSBTooManyPipesErr)
		ERROR_CASE(kIOUSBNoAsyncPortErr)
		ERROR_CASE(kIOUSBNotEnoughPipesErr)
		ERROR_CASE(kIOUSBNotEnoughPowerErr)
		ERROR_CASE(kIOUSBEndpointNotFound)
		ERROR_CASE(kIOUSBConfigNotFound)
		ERROR_CASE(kIOUSBTransactionTimeout)
		ERROR_CASE(kIOUSBTransactionReturned)
		ERROR_CASE(kIOUSBPipeStalled)
		ERROR_CASE(kIOUSBInterfaceNotFound)
		ERROR_CASE(kIOUSBLowLatencyBufferNotPreviouslyAllocated)
		ERROR_CASE(kIOUSBLowLatencyFrameListNotPreviouslyAllocated)
		ERROR_CASE(kIOUSBHighSpeedSplitError)
		ERROR_CASE(kIOUSBSyncRequestOnWLThread)
		ERROR_CASE(kIOUSBDeviceNotHighSpeed)
		ERROR_CASE(kIOUSBLinkErr)
		ERROR_CASE(kIOUSBNotSent2Err)
		ERROR_CASE(kIOUSBNotSent1Err)
		ERROR_CASE(kIOUSBBufferUnderrunErr)
		ERROR_CASE(kIOUSBBufferOverrunErr)
		ERROR_CASE(kIOUSBReserved2Err)
		ERROR_CASE(kIOUSBReserved1Err)
		ERROR_CASE(kIOUSBWrongPIDErr)
		ERROR_CASE(kIOUSBPIDCheckErr)
		ERROR_CASE(kIOUSBDataToggleErr)
		ERROR_CASE(kIOUSBBitstufErr)
		ERROR_CASE(kIOUSBCRCErr)

		ERROR_CASE(kIOMessageServiceIsTerminated)
		ERROR_CASE(kIOMessageServiceIsSuspended)
		ERROR_CASE(kIOMessageServiceIsResumed)
		ERROR_CASE(kIOMessageServiceIsRequestingClose)
		ERROR_CASE(kIOMessageServiceIsAttemptingOpen)
		ERROR_CASE(kIOMessageServiceWasClosed)
		ERROR_CASE(kIOMessageServiceBusyStateChange)
		ERROR_CASE(kIOMessageServicePropertyChange)
		ERROR_CASE(kIOMessageCanDevicePowerOff)
		ERROR_CASE(kIOMessageDeviceWillPowerOff)
		ERROR_CASE(kIOMessageDeviceWillNotPowerOff)
		ERROR_CASE(kIOMessageDeviceHasPoweredOn)
		ERROR_CASE(kIOMessageDeviceWillPowerOn)
		ERROR_CASE(kIOMessageDeviceHasPoweredOff)
		ERROR_CASE(kIOMessageCanSystemPowerOff)
		ERROR_CASE(kIOMessageSystemWillPowerOff)
		ERROR_CASE(kIOMessageSystemWillNotPowerOff)
		ERROR_CASE(kIOMessageCanSystemSleep)
		ERROR_CASE(kIOMessageSystemWillSleep)
		ERROR_CASE(kIOMessageSystemWillNotSleep)
		ERROR_CASE(kIOMessageSystemHasPoweredOn)
		ERROR_CASE(kIOMessageSystemWillRestart)
		ERROR_CASE(kIOMessageSystemWillPowerOn)
		ERROR_CASE(kIOMessageCopyClientID)
	}
	return [NSString stringWithFormat:@"Unknown IOReturn %d (Code: 0x%x; Sub: 0x%x; System: 0x%x)", error, err_get_code(error), err_get_sub(error), err_get_system(error)];
}
NSString *ECVCVReturnToString(CVReturn error)
{
	switch(error) {
		ERROR_CASE(kCVReturnSuccess)
		ERROR_CASE(kCVReturnError)
		ERROR_CASE(kCVReturnInvalidArgument)
		ERROR_CASE(kCVReturnAllocationFailed)
		ERROR_CASE(kCVReturnInvalidDisplay)
		ERROR_CASE(kCVReturnDisplayLinkAlreadyRunning)
		ERROR_CASE(kCVReturnDisplayLinkNotRunning)
		ERROR_CASE(kCVReturnDisplayLinkCallbacksNotSet)
		ERROR_CASE(kCVReturnInvalidPixelFormat)
		ERROR_CASE(kCVReturnInvalidSize)
		ERROR_CASE(kCVReturnInvalidPixelBufferAttributes)
		ERROR_CASE(kCVReturnPixelBufferNotOpenGLCompatible)
		ERROR_CASE(kCVReturnPoolAllocationFailed)
		ERROR_CASE(kCVReturnInvalidPoolAttributes)
	}
	return [NSString stringWithFormat:@"Unknown CVReturn %d", error];
}
NSString *ECVErrnoToString(int error)
{
	return [NSString stringWithFormat:@"%s", strerror(error)];
}

#pragma mark -

NSString *ECVAudioFormatIDToString(UInt32 const formatID)
{
	switch(formatID) {
		ERROR_CASE(kAudioFormatLinearPCM)
		ERROR_CASE(kAudioFormatAC3)
		ERROR_CASE(kAudioFormat60958AC3)
		ERROR_CASE(kAudioFormatAppleIMA4)
		ERROR_CASE(kAudioFormatMPEG4AAC)
		ERROR_CASE(kAudioFormatMPEG4CELP)
		ERROR_CASE(kAudioFormatMPEG4HVXC)
		ERROR_CASE(kAudioFormatMPEG4TwinVQ)
		ERROR_CASE(kAudioFormatMACE3)
		ERROR_CASE(kAudioFormatMACE6)
		ERROR_CASE(kAudioFormatULaw)
		ERROR_CASE(kAudioFormatALaw)
		ERROR_CASE(kAudioFormatQDesign)
		ERROR_CASE(kAudioFormatQDesign2)
		ERROR_CASE(kAudioFormatQUALCOMM)
		ERROR_CASE(kAudioFormatMPEGLayer1)
		ERROR_CASE(kAudioFormatMPEGLayer2)
		ERROR_CASE(kAudioFormatMPEGLayer3)
		ERROR_CASE(kAudioFormatTimeCode)
		ERROR_CASE(kAudioFormatMIDIStream)
		ERROR_CASE(kAudioFormatParameterValueStream)
		ERROR_CASE(kAudioFormatAppleLossless)
		ERROR_CASE(kAudioFormatMPEG4AAC_HE)
		ERROR_CASE(kAudioFormatMPEG4AAC_LD)
		ERROR_CASE(kAudioFormatMPEG4AAC_HE_V2)
		ERROR_CASE(kAudioFormatMPEG4AAC_Spatial)
		ERROR_CASE(kAudioFormatAMR)
		ERROR_CASE(kAudioFormatAudible)
		ERROR_CASE(kAudioFormatiLBC)
		ERROR_CASE(kAudioFormatDVIIntelIMA)
		ERROR_CASE(kAudioFormatMicrosoftGSM)
		ERROR_CASE(kAudioFormatAES3)
	}
	return [NSString stringWithFormat:@"Unknown audio format ID %lu", (unsigned long)formatID];
}

#define ADD_FORMAT_FLAG(flags, flag, array) ({ if((flags) & (flag)) [(array) addObject:[NSString stringWithUTF8String:#flag]]; })

NSString *ECVAudioFormatFlagsToString(UInt32 const formatID, UInt32 const formatFlags)
{
	NSMutableArray *const results = [NSMutableArray array];
	ADD_FORMAT_FLAG(formatFlags, kAudioFormatFlagIsFloat, results);
	ADD_FORMAT_FLAG(formatFlags, kAudioFormatFlagIsBigEndian, results);
	ADD_FORMAT_FLAG(formatFlags, kAudioFormatFlagIsSignedInteger, results);
	ADD_FORMAT_FLAG(formatFlags, kAudioFormatFlagIsPacked, results);
	ADD_FORMAT_FLAG(formatFlags, kAudioFormatFlagIsAlignedHigh, results);
	ADD_FORMAT_FLAG(formatFlags, kAudioFormatFlagIsNonInterleaved, results);
	ADD_FORMAT_FLAG(formatFlags, kAudioFormatFlagIsNonMixable, results);
	ADD_FORMAT_FLAG(formatFlags, kAudioFormatFlagsAreAllClear, results);
	ADD_FORMAT_FLAG(formatFlags, kAudioFormatFlagsNativeEndian, results);
	return [results componentsJoinedByString:@" | "];
}
NSString *ECVAudioStreamBasicDescriptionToString(AudioStreamBasicDescription const d)
{
	return [NSString stringWithFormat:
		@"{\n"
		@"mSampleRate %f\n"
		@"mFormatID %@\n"
		@"mFormatFlags %@\n"
		@"mBytesPerPacket %lu\n"
		@"mFramesPerPacket %lu\n"
		@"mBytesPerFrame %lu\n"
		@"mChannelsPerFrame %lu\n"
		@"mBitsPerChannel %lu\n"
		@"}",
		d.mSampleRate,
		ECVAudioFormatIDToString(d.mFormatID),
		ECVAudioFormatFlagsToString(d.mFormatID, d.mFormatFlags),
		(unsigned long)d.mBytesPerPacket,
		(unsigned long)d.mFramesPerPacket,
		(unsigned long)d.mBytesPerFrame,
		(unsigned long)d.mChannelsPerFrame,
		(unsigned long)d.mBitsPerChannel
	];
}
