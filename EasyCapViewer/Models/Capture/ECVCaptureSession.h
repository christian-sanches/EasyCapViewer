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
#import "ECVAudioDevice.h"
#import "ECVCaptureDevice.h"
#import "ECVVideoFrame.h"

@class ECVAudioTarget;
@class ECVCaptureDevice;
@class ECVCaptureSession;
@class ECVReadWriteLock;

@protocol ECVCaptureSessionDelegate <NSObject>
@optional
- (void)captureSessionDidStartPlaying:(ECVCaptureSession *)session;
- (void)captureSessionDidStopPlaying:(ECVCaptureSession *)session;
- (void)captureSession:(ECVCaptureSession *)session didReceiveVideoFrame:(ECVVideoFrame *)frame;
- (void)captureSession:(ECVCaptureSession *)session didReceiveAudioBuffer:(NSValue *)bufferListValue;
@end

@interface ECVCaptureSession : NSObject <ECVAudioDeviceDelegate>
{
	@private
	ECVCaptureDevice *_videoDevice;
	ECVAudioInput *_audioDevice;
	NSUInteger _pauseCount;
	BOOL _pausedFromUI;

	ECVReadWriteLock *_targetsLock;
	NSMutableArray *_targets;
	ECVAudioTarget *_audioTarget;

	NSTimeInterval _lastStopTime;
}

@property(weak) id<ECVCaptureSessionDelegate> delegate;

- (NSArray *)targets;
- (void)addTarget:(id)target;
- (void)removeTarget:(id)target;
- (ECVAudioTarget *)audioTarget;

- (ECVCaptureDevice *)videoDevice;
- (void)setVideoDevice:(ECVCaptureDevice *const)source;

- (ECVAudioInput *)audioDevice;
- (void)setAudioDevice:(ECVAudioInput *const)target;

- (NSUInteger)pauseCount;
- (BOOL)isPaused;
- (void)setPaused:(BOOL const)flag;
- (BOOL)isPausedFromUI;
- (void)setPausedFromUI:(BOOL const)flag;

- (void)pushVideoFrame:(ECVVideoFrame *const)frame;
- (void)pushAudioBufferListValue:(NSValue *const)bufferListValue;

- (void)workspaceWillSleep:(NSNotification *const)aNotif;

@end
