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
#import "ECVMovieRecorder.h"

// Models
#import "ECVVideoFormat.h"
#import "ECVVideoStorage.h"

@implementation ECVMovieRecordingOptions

@synthesize URL = _URL;
@synthesize videoStorage = _videoStorage;
@synthesize audioInput = _audioInput;

@synthesize videoCodec = _videoCodec;
@synthesize videoQuality = _videoQuality;
@synthesize stretchOutput = _stretchOutput;
@synthesize outputSize = _outputSize;
@synthesize cropRect = _cropRect;
@synthesize upconvertsFromMono = _upconvertsFromMono;
@synthesize frameRate = _frameRate;

@synthesize volume = _volume;

- (NSDictionary *)cleanAperatureDictionary
{
	NSRect const c = [self cropRect];
	ECVIntegerSize const s1 = [[_videoStorage videoFormat] frameSize];
	ECVIntegerSize const s2 = (ECVIntegerSize){round(NSWidth(c) * s1.width), round(NSHeight(c) * s1.height)};
	return [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithDouble:s2.width], kCVImageBufferCleanApertureWidthKey,
		[NSNumber numberWithDouble:s2.height], kCVImageBufferCleanApertureHeightKey,
		[NSNumber numberWithDouble:round(NSMinX(c) * s1.width - (s1.width - s2.width) / 2.0)], kCVImageBufferCleanApertureHorizontalOffsetKey,
		[NSNumber numberWithDouble:round(NSMinY(c) * s1.height - (s1.height - s2.height) / 2.0)], kCVImageBufferCleanApertureVerticalOffsetKey,
		nil];
}

- (instancetype)init
{
	if((self = [super init])) {
		_videoCodec = '@jpeg';
		_videoQuality = 0.5f;
		_stretchOutput = YES;
		_cropRect = ECVUncroppedRect;

		_volume = 1.0f;
	}
	return self;
}

@end

@implementation ECVMovieRecorder

- (instancetype)initWithOptions:(ECVMovieRecordingOptions *)options error:(NSError **)outError
{
	if(outError) *outError = [NSError errorWithDomain:@"ECVMovieRecorder" code:-1
		userInfo:@{NSLocalizedDescriptionKey: @"Recording not yet implemented"}];
	return nil;
}

- (void)addVideoFrame:(ECVVideoFrame *)frame {}
- (void)addAudioBufferList:(AudioBufferList const *)bufferList {}
- (void)stopRecording {}

@end
