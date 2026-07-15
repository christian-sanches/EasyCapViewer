/* Copyright (c) 2012, Ben Trask
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE AUTHORS ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */
#import "ECVCaptureSession.h"

#import "ECVAudioDevice.h"
#import "ECVAudioTarget.h"
#import "ECVController.h"
#import "ECVDebug.h"
#import "ECVReadWriteLock.h"
#import "ECVVideoFrame.h"
#import "EasyCapViewer-Swift.h"

static NSString *const ECVAudioInputUIDKey = @"ECVAudioInputUID";
static NSString *const ECVAudioInputNone = @"ECVAudioInputNone";
static NSString *const ECVAudioInputVideoDevice = @"ECVAudioInputVideoDevice";

@implementation ECVCaptureSession

#pragma mark -ECVCaptureSession

- (NSArray *)targets
{
	[_targetsLock readLock];
	NSArray *const targets = [_targets copy];
	[_targetsLock unlock];
	return targets;
}
- (void)addTarget:(id const)target
{
	[_targetsLock writeLock];
	[_targets addObject:target];
	[_targetsLock unlock];
}
- (void)removeTarget:(id const)target
{
	[_targetsLock writeLock];
	[_targets removeObjectIdenticalTo:target];
	[_targetsLock unlock];
}
- (ECVAudioTarget *)audioTarget
{
	return _audioTarget;
}

#pragma mark -

- (ECVCaptureDevice *)videoDevice
{
	return _videoDevice;
}
- (void)setVideoDevice:(ECVCaptureDevice *const)source
{
	if(source == _videoDevice) return;
	[_videoDevice setCaptureSession:nil];
	_videoDevice = source;
	[_videoDevice setCaptureSession:self];

	// Yes, the audio input really is dependent on the video device.
	NSString *const UID = [[NSUserDefaults standardUserDefaults] objectForKey:ECVAudioInputUIDKey];
	if(BTEqualObjects(ECVAudioInputVideoDevice, UID) || !UID) {
		ECVAudioInput *const input = [[self videoDevice] builtInAudioInput];
		[self setAudioDevice:input];
		if(!input) {
			ECVLog(ECVWarning, @"No built-in audio input found for device '%@'. Audio will be silent.", [_videoDevice name]);
		}
	} else if(BTEqualObjects(ECVAudioInputNone, UID)) {
		[self setAudioDevice:nil];
	} else {
		[self setAudioDevice:[ECVAudioInput deviceWithUID:UID]];
	}
}

#pragma mark -

- (NSUInteger)pauseCount
{
	return _pauseCount;
}
- (BOOL)isPaused
{
	return !!_pauseCount;
}
- (void)setPaused:(BOOL const)flag
{
	NSParameterAssert(flag || 0 != _pauseCount);
	if(flag) {
		if(1 == ++_pauseCount) [self stop];
	} else {
		if(0 == --_pauseCount) [self play];
	}
}
- (BOOL)isPausedFromUI
{
	return _pausedFromUI;
}
- (void)setPausedFromUI:(BOOL const)flag
{
	if(flag == _pausedFromUI) return;
	_pausedFromUI = flag;
	[self setPaused:_pausedFromUI];
}

#pragma mark -

- (void)workspaceWillSleep:(NSNotification *const)aNotif
{
	[self setPausedFromUI:YES];
}

#pragma mark -

- (ECVAudioInput *)audioDevice
{
	return _audioDevice;
}
- (void)setAudioDevice:(ECVAudioInput *const)device
{
	if(!BTEqualObjects(device, _audioDevice)) {
		[self setPaused:YES];
		_audioDevice = device;
		[_audioDevice setDelegate:self];
		if(_audioDevice) [_audioTarget setInputBasicDescription:[[_audioDevice stream] basicDescription]];
		[self setPaused:NO];
	}
	NSUserDefaults *const d = [NSUserDefaults standardUserDefaults];
	if(BTEqualObjects([[self videoDevice] builtInAudioInput], device)) {
		[d setObject:ECVAudioInputVideoDevice forKey:ECVAudioInputUIDKey];
	} else if(device) {
		[d setObject:[device UID] forKey:ECVAudioInputUIDKey];
	} else {
		[d setObject:ECVAudioInputNone forKey:ECVAudioInputUIDKey];
	}
}

#pragma mark -ECVCaptureSession<ECVAVTarget>

- (void)play
{
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceReferenceDate:_lastStopTime + 0.75]];
	[self addTarget:_audioTarget];
	[_videoDevice play];
	[_audioDevice start];
	[_targets makeObjectsPerformSelector:@selector(play)];
	[[ECVController sharedController] noteCaptureSessionStartedPlaying:self];
	[_delegate captureSessionDidStartPlaying:self];
}
- (void)stop
{
	[[ECVController sharedController] noteCaptureSessionStoppedPlaying:self];
	[_delegate captureSessionDidStopPlaying:self];
	[_targets makeObjectsPerformSelector:@selector(stop)];
	[_videoDevice stop];
	[_audioDevice stop];
	[self removeTarget:_audioTarget];
	_lastStopTime = [NSDate timeIntervalSinceReferenceDate];
}
- (void)pushVideoFrame:(ECVVideoFrame *const)frame
{
	if(!frame) return;
	[_delegate captureSession:self didReceiveVideoFrame:frame];
	[_targetsLock readLock];
	[_targets makeObjectsPerformSelector:@selector(pushVideoFrame:) withObject:frame];
	[_targetsLock unlock];
}
- (void)pushAudioBufferListValue:(NSValue *const)bufferListValue
{
	if(!bufferListValue) return;
	[_delegate captureSession:self didReceiveAudioBuffer:bufferListValue];
	[_targetsLock readLock];
	[_targets makeObjectsPerformSelector:@selector(pushAudioBufferListValue:) withObject:bufferListValue];
	[_targetsLock unlock];
}

#pragma mark -ECVCaptureSession<ECVAudioDeviceDelegate>

- (void)audioInput:(ECVAudioInput *const)sender didReceiveBufferList:(AudioBufferList const *const)bufferList atTime:(AudioTimeStamp const *const)t
{
	if(sender != _audioDevice) return;
	NSValue *const value = [NSValue valueWithPointer:bufferList];
	[_delegate captureSession:self didReceiveAudioBuffer:value];
	[_targetsLock readLock];
	[_targets makeObjectsPerformSelector:@selector(pushAudioBufferListValue:) withObject:value];
	[_targetsLock unlock];
}

#pragma mark -NSObject

- (id)init
{
	if((self = [super init])) {
		_pauseCount = 1;
		_pausedFromUI = YES;

		_targetsLock = [[ECVReadWriteLock alloc] init];
		_targets = [[NSMutableArray alloc] init];
		_audioTarget = [[ECVAudioTarget alloc] init];
		[_audioTarget setCaptureSession:nil];
		[_audioTarget setAudioOutput:[ECVAudioOutput defaultDevice]];

		[[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self selector:@selector(workspaceWillSleep:) name:NSWorkspaceWillSleepNotification object:[NSWorkspace sharedWorkspace]];
	}
	return self;
}
- (void)dealloc
{
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
}

@end
