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
#import "ECVVideoFrame.h"
#import "ECVPixelBuffer.h"
#import "ECVPixelFormat.h"
#import "ECVDebug.h"

// Audio
#import "ECVAudioDevice.h"
#import "ECVAudioPipe.h"

static AVVideoCodecType ECVAVVideoCodecTypeForOSType(OSType const codec)
{
	switch(codec) {
		case 'jpeg': return AVVideoCodecTypeJPEG;
		case 'avc1': return AVVideoCodecTypeH264;
		case 'hvc1': return AVVideoCodecTypeHEVC;
		case 'yv42': return AVVideoCodecTypeAppleProRes422;
	}
	return AVVideoCodecTypeJPEG;
}

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
		_videoCodec = 'jpeg';
		_videoQuality = 0.5f;
		_stretchOutput = YES;
		_cropRect = ECVUncroppedRect;

		_volume = 1.0f;
	}
	return self;
}

@end

@implementation ECVMovieRecorder
{
	AVAssetWriter *_writer;
	AVAssetWriterInput *_videoInput;
	AVAssetWriterInput *_audioInput;
	AVAssetWriterInputPixelBufferAdaptor *_pixelBufferAdaptor;
	dispatch_queue_t _videoQueue;
	dispatch_queue_t _audioQueue;
	CMTime _startTime;
	BOOL _started;
	NSUInteger _frameCount;
	ECVMovieRecordingOptions *_options;
	CMTime _frameRate;
	AudioStreamBasicDescription _audioStreamDescription;
}

- (instancetype)initWithOptions:(ECVMovieRecordingOptions *)options error:(NSError **)outError
{
	if(!(self = [super init])) return nil;
	_options = options;
	_frameRate = [options frameRate];

	NSError *error = nil;

	// Create AVAssetWriter
	_writer = [[AVAssetWriter alloc] initWithURL:[options URL]
		fileType:AVFileTypeQuickTimeMovie error:&error];
	if(!_writer) {
		if(outError) *outError = error;
		return nil;
	}

	// Determine video settings
	ECVIntegerSize const outputSize = [options outputSize];
	AVVideoCodecType const codecType = ECVAVVideoCodecTypeForOSType([options videoCodec]);
	CGFloat const quality = [options videoQuality];

	NSMutableDictionary *compressionProperties = [NSMutableDictionary dictionary];

	// Set quality-based bitrate for lossy codecs
	if(codecType == AVVideoCodecTypeJPEG) {
		[compressionProperties setObject:@(quality) forKey:AVVideoQualityKey];
	} else if(codecType == AVVideoCodecTypeH264 || codecType == AVVideoCodecTypeHEVC) {
		// For H.264/HEVC, compute bitrate from quality
		// Range: 1 Mbps (low quality) to 20 Mbps (high quality)
		NSUInteger const bitrate = (NSUInteger)(1000000 + quality * 19000000);
		[compressionProperties setObject:@(bitrate) forKey:AVVideoAverageBitRateKey];
		[compressionProperties setObject:@(30) forKey:AVVideoMaxKeyFrameIntervalKey];
	}

	NSDictionary *videoSettings = @{
		AVVideoCodecKey: codecType,
		AVVideoWidthKey: @(outputSize.width),
		AVVideoHeightKey: @(outputSize.height),
		AVVideoCompressionPropertiesKey: compressionProperties,
	};

	_videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
		outputSettings:videoSettings];
	_videoInput.expectsMediaDataInRealTime = YES;

	// Create pixel buffer adaptor
	NSDictionary *sourcePixelBufferAttributes = @{
		(NSString *)kCVPixelBufferPixelFormatTypeKey: @(k2vuyPixelFormat),
		(NSString *)kCVPixelBufferWidthKey: @(outputSize.width),
		(NSString *)kCVPixelBufferHeightKey: @(outputSize.height),
	};
	_pixelBufferAdaptor = [AVAssetWriterInputPixelBufferAdaptor
		assetWriterInputPixelBufferAdaptorWithAssetWriterInput:_videoInput
		sourcePixelBufferAttributes:sourcePixelBufferAttributes];

	[_writer addInput:_videoInput];

	// Create audio input if audio is enabled
	if([options audioInput]) {
		// Get the audio format from the device's stream and store it
		_audioStreamDescription = [[[options audioInput] stream] basicDescription];

		NSDictionary *audioSettings = @{
			(NSString *)AVFormatIDKey: @(_audioStreamDescription.mFormatID),
			(NSString *)AVSampleRateKey: @(_audioStreamDescription.mSampleRate),
			(NSString *)AVNumberOfChannelsKey: @(_audioStreamDescription.mChannelsPerFrame),
			(NSString *)AVLinearPCMBitDepthKey: @(_audioStreamDescription.mBitsPerChannel),
			(NSString *)AVLinearPCMIsFloatKey: @((_audioStreamDescription.mFormatFlags & kLinearPCMFormatFlagIsFloat) != 0),
			(NSString *)AVLinearPCMIsNonInterleaved: @(NO),
		};
		_audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio
			outputSettings:audioSettings];
		_audioInput.expectsMediaDataInRealTime = YES;
		[_writer addInput:_audioInput];
	}

	// Create dispatch queues
	_videoQueue = dispatch_queue_create("com.ecvviewer.recorder.video", DISPATCH_QUEUE_SERIAL);
	_audioQueue = dispatch_queue_create("com.ecvviewer.recorder.audio", DISPATCH_QUEUE_SERIAL);

	return self;
}

- (void)addVideoFrame:(ECVVideoFrame *)frame
{
	if(!frame || !_videoInput.readyForMoreMediaData) return;

	// Start the writer on first frame
	if(!_started) {
		if(![_writer startWriting]) {
			NSLog(@"ECVMovieRecorder: failed to start writing: %@", [_writer error]);
			return;
		}
		[_writer startSessionAtSourceTime:CMTimeMake(0, 1)];
		_startTime = CMTimeMake(0, 1);
		_started = YES;
	}

	// Get frame dimensions from the pixel buffer adaptor's source attributes
	NSDictionary *sourceAttrs = [_pixelBufferAdaptor sourcePixelBufferAttributes];
	OSType const pixelFormat = (OSType)[[sourceAttrs objectForKey:(NSString *)kCVPixelBufferPixelFormatTypeKey] unsignedIntValue];
	NSInteger const width = [[sourceAttrs objectForKey:(NSString *)kCVPixelBufferWidthKey] integerValue];
	NSInteger const height = [[sourceAttrs objectForKey:(NSString *)kCVPixelBufferHeightKey] integerValue];

	// Create a CVPixelBuffer from the frame's raw bytes
	CVPixelBufferRef pixelBuffer = NULL;
	CVPixelBufferCreate(kCFAllocatorDefault,
		width, height, pixelFormat,
		NULL, &pixelBuffer);
	if(!pixelBuffer) return;

	CVPixelBufferLockBaseAddress(pixelBuffer, 0);

	// Copy frame data into the pixel buffer
	void const *srcBytes = [frame bytes];
	if(srcBytes) {
		void *dstBytes = CVPixelBufferGetBaseAddress(pixelBuffer);
		size_t dstBytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
		size_t srcBytesPerRow = [frame bytesPerRow];
		size_t const rowBytes = MIN(srcBytesPerRow, dstBytesPerRow);

		for(NSInteger y = 0; y < height; y++) {
			memcpy((uint8_t *)dstBytes + y * dstBytesPerRow, (uint8_t const *)srcBytes + y * srcBytesPerRow, rowBytes);
		}
	}

	// Apply clean aperture if crop rect is set
	NSRect const cropRect = [_options cropRect];
	if(!NSEqualRects(cropRect, ECVUncroppedRect)) {
		NSDictionary *cleanAperture = [_options cleanAperatureDictionary];
		NSDictionary *attachments = @{
			(NSString *)kCVImageBufferCleanApertureKey: cleanAperture,
		};
		CVBufferSetAttachments(pixelBuffer, (__bridge CFDictionaryRef)attachments, kCVAttachmentMode_ShouldPropagate);
	}

	CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

	// Calculate presentation time using frame count and frame rate
	CMTime pts = CMTimeMake(_frameCount * _frameRate.timescale, _frameRate.timescale * (int32_t)_frameRate.value);
	_frameCount++;

	// Append to adaptor
	if(![_pixelBufferAdaptor appendPixelBuffer:pixelBuffer withPresentationTime:pts]) {
		NSLog(@"ECVMovieRecorder: failed to append video frame at count %lu", (unsigned long)_frameCount - 1);
	}

	CVPixelBufferRelease(pixelBuffer);
}

- (void)addAudioBufferList:(AudioBufferList const *)bufferList
{
	if(!bufferList || !_audioInput.readyForMoreMediaData || !_started) return;

	// Use the stored audio format description
	AudioStreamBasicDescription const asbd = _audioStreamDescription;

	// Create format description
	CMFormatDescriptionRef formatDesc = NULL;
	CMAudioFormatDescriptionCreate(kCFAllocatorDefault, &asbd, 0, NULL, 0, NULL, NULL, &formatDesc);
	if(!formatDesc) return;

	// Create block buffer from the audio data
	CMBlockBufferRef blockBuffer = NULL;
	UInt32 const totalDataSize = bufferList->mNumberBuffers > 0 ? bufferList->mBuffers[0].mDataByteSize : 0;
	OSStatus blockStatus = CMBlockBufferCreateWithMemoryBlock(
		kCFAllocatorDefault,
		bufferList->mBuffers[0].mData,
		totalDataSize,
		kCFAllocatorNull,   // blockAllocator - NULL means the data is already allocated
		NULL,               // customBlockSource
		0,                  // offsetToData
		totalDataSize,      // dataLength
		0,                  // flags
		&blockBuffer);

	if(blockStatus != noErr || !blockBuffer) {
		CFRelease(formatDesc);
		NSLog(@"ECVMovieRecorder: failed to create block buffer: %d", (int)blockStatus);
		return;
	}

	// Create sample buffer
	CMSampleBufferRef sampleBuffer = NULL;
	CMSampleTimingInfo timingInfo;
	timingInfo.duration = CMTimeMake(1, (int32_t)asbd.mSampleRate);
	timingInfo.presentationTimeStamp = CMTimeMake(_frameCount * _frameRate.timescale, _frameRate.timescale * (int32_t)_frameRate.value);
	timingInfo.decodeTimeStamp = kCMTimeInvalid;

	OSStatus status = CMSampleBufferCreateReady(
		kCFAllocatorDefault,
		blockBuffer,
		formatDesc,
		totalDataSize,
		1,              // numSampleTimingEntries
		&timingInfo,
		0,              // numSampleSizeEntries
		NULL,           // sampleSizeArray
		&sampleBuffer);

	CFRelease(blockBuffer);
	CFRelease(formatDesc);

	if(status != noErr || !sampleBuffer) {
		NSLog(@"ECVMovieRecorder: failed to create audio sample buffer: %d", (int)status);
		return;
	}

	[_audioInput appendSampleBuffer:sampleBuffer];
	CFRelease(sampleBuffer);
}

- (void)stopRecording
{
	if(!_started) return;

	[_videoInput markAsFinished];
	if(_audioInput) [_audioInput markAsFinished];
	[_writer finishWritingWithCompletionHandler:^{
		dispatch_async(dispatch_get_main_queue(), ^{
			if(self->_writer.status == AVAssetWriterStatusCompleted) {
				NSLog(@"ECVMovieRecorder: recording finished successfully");
			} else {
				NSLog(@"ECVMovieRecorder: recording failed: %@", self->_writer.error);
			}
		});
	}];
}

@end
