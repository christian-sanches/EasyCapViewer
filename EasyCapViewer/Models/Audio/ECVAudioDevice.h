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
#import <CoreAudio/CoreAudio.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const ECVAudioHardwareDevicesDidChangeNotification;

@class ECVAudioStream;
@protocol ECVAudioDeviceDelegate;

@interface ECVAudioDevice : NSObject

@property (nonatomic, weak, nullable) IBOutlet NSObject<ECVAudioDeviceDelegate> *delegate;
@property (nonatomic, readonly) AudioDeviceID deviceID;
@property (nonatomic, copy, nullable) NSString *name;

+ (NSArray<ECVAudioDevice *> *)allDevices;
+ (instancetype)defaultDevice;
+ (instancetype)deviceWithUID:(NSString *)UID;
+ (nullable instancetype)deviceWithIODevice:(io_service_t)device;

- (nullable instancetype)initWithDeviceID:(AudioDeviceID)deviceID;

- (BOOL)isInput;
- (NSString *)UID;
- (NSArray<ECVAudioStream *> *)streams;
- (nullable ECVAudioStream *)stream;

- (BOOL)start;
- (void)stop;

@end

@interface ECVAudioDevice(ECVAbstract)

+ (BOOL)isInput;

@end

@interface ECVAudioInput : ECVAudioDevice
@end
@interface ECVAudioOutput : ECVAudioDevice
@end

@protocol ECVAudioDeviceDelegate <NSObject>

@optional
- (void)audioInput:(ECVAudioInput *)sender didReceiveBufferList:(AudioBufferList const *)bufferList atTime:(AudioTimeStamp const *)t;
- (void)audioOutput:(ECVAudioOutput *)sender didRequestBufferList:(inout AudioBufferList *)bufferList forTime:(AudioTimeStamp const *)t;

@end

@interface ECVAudioStream : NSObject

- (instancetype)initWithStreamID:(AudioStreamID)streamID;
@property (nonatomic, readonly) AudioStreamID streamID;

- (AudioStreamBasicDescription)basicDescription;

@end

NS_ASSUME_NONNULL_END
