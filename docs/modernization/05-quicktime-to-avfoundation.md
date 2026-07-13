# Phase 5 — QuickTime/ICM → AVFoundation (Movie Recording)

**Goal:** Rewrite the movie recording pipeline from QuickTime ICM to AVFoundation.

---

## 5.1 Current Recording Architecture

The current recording uses QuickTime's **Image Compression Manager (ICM)** which is completely removed from modern macOS:

```
ECVVideoFrame → ECVCVPixelBuffer → ICMCompressionSessionEncodeFrame
                                         ↓
                                   ICMEncodedFrame → AddMediaSample2 (QuickTime Movie)
                                         ↓
                                   QTNewDataReferenceFromCFURL → CreateMovieStorage
```

### Current flow details
1. `ECVMovieRecordingOptions` holds config (codec, quality, crop, framerate, output URL)
2. Two background threads:
   - **Compress thread:** Takes `ECVVideoFrame`, converts to `CVPixelBuffer`, encodes via `ICMCompressionSession`
   - **Record thread:** Takes `ICMEncodedFrame`, writes to QuickTime `Movie` via `AddMediaSample2`
3. Audio is written via `ECVAudioPipe` → `AddMediaSample2`
4. Movie is finalized with `UpdateMovieInStorage` / `CloseMovieStorage`

### Current codec support
- Motion JPEG (`'jpeg'`)
- MPEG-4 (`'mp4v'`)
- Uncompressed YUV2 (`'yuv2'`)

---

## 5.2 AVFoundation Replacement

### Key classes
| QuickTime | AVFoundation | Notes |
|-----------|-------------|-------|
| `ICMCompressionSession` | `AVAssetWriterInput` with `AVVideoEncoderSpecification` | Hardware encoder on Apple Silicon |
| `ICMCompressionSessionOptions` | `AVAssetWriterInput` properties | Bitrate, keyframe interval, etc. |
| `ICMEncodedFrame` | `CMSampleBuffer` | Compressed or raw sample data |
| `Movie`, `Track`, `Media` | `AVAssetWriter` + `AVAssetWriterInput` | File output |
| `QTNewDataReferenceFromCFURL` | `NSURL` | Direct URL |
| `CreateMovieStorage` | `AVAssetWriter.init(url: fileType:)` | File creation |
| `AddMediaSample2` | `[AVAssetWriterInput appendSampleBuffer:]` | Writing samples |
| `EnterMoviesOnThread` | Not needed | AVFoundation handles threading |
| `EnterMovies` | Not needed | AVFoundation is always available |

### New flow
```
ECVVideoFrame → CVPixelBuffer → CMSampleBuffer (with format description)
                                      ↓
                              AVAssetWriterInput (video)
                                      ↓
                              AVAssetWriter → .mov / .mp4 file
```

---

## 5.3 New Files to Create

### `ECVMovieRecorder.h` / `ECVMovieRecorder.m` (rewrite)

```objc
@interface ECVMovieRecordingOptions : NSObject

@property (nonatomic, copy) NSURL *URL;
@property (nonatomic, strong) ECVVideoStorage *videoStorage;
@property (nonatomic, strong) ECVAudioDevice *audioInput;

// Video settings
@property (nonatomic) FourCharCode videoCodec;  // or use AVVideoCodecType
@property (nonatomic) float videoQuality;
@property (nonatomic) BOOL stretchOutput;
@property (nonatomic) NSSize outputSize;
@property (nonatomic) NSRect cropRect;
@property (nonatomic) CMTime frameRate;

// Audio settings
@property (nonatomic) BOOL upconvertsFromMono;
@property (nonatomic) float volume;

@end

@interface ECVMovieRecorder : NSObject

- (instancetype)initWithOptions:(ECVMovieRecordingOptions *)options error:(NSError **)outError;
- (void)addVideoFrame:(ECVVideoFrame *)frame;
- (void)addAudioBufferList:(AudioBufferList const *)bufferList;
- (void)stopRecording;

@end
```

### Implementation outline

```objc
@implementation ECVMovieRecorder {
    AVAssetWriter *_writer;
    AVAssetWriterInput *_videoInput;
    AVAssetWriterInput *_audioInput;
    AVAssetWriterInputPixelBufferAdaptor *_pixelBufferAdaptor;
    dispatch_queue_t _videoQueue;
    dispatch_queue_t _audioQueue;
    CMTime _startTime;
    BOOL _started;
}

- (instancetype)initWithOptions:(ECVMovieRecordingOptions *)options error:(NSError **)outError {
    // 1. Create AVAssetWriter
    _writer = [[AVAssetWriter alloc] initWithURL:options.URL
        fileType:AVFileTypeQuickTimeMovie error:outError];
    
    // 2. Create video input with codec settings
    NSDictionary *videoSettings = @{
        AVVideoCodecKey: [self avVideoCodec:options.videoCodec],
        AVVideoWidthKey: @(options.outputSize.width),
        AVVideoHeightKey: @(options.outputSize.height),
        AVVideoCompressionPropertiesKey: @{
            AVVideoAverageBitRateKey: @(bitrate),
            AVVideoMaxKeyFrameIntervalKey: @(keyframeInterval),
        }
    };
    _videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
        outputSettings:videoSettings];
    _videoInput.expectsMediaDataInRealTime = YES;
    
    // 3. Create pixel buffer adaptor (for CVPixelBuffer input)
    _pixelBufferAdaptor = [AVAssetWriterInputPixelBufferAdaptor
        assetWriterInputPixelBufferAdaptorWithAssetWriterInput:_videoInput
        sourcePixelBufferAttributes:@{
            (NSString *)kCVPixelBufferPixelFormatTypeKey: @(k2vuyPixelFormat)
        }];
    
    // 4. Create audio input if audio is enabled
    if (options.audioInput) {
        NSDictionary *audioSettings = @{
            AVFormatIDKey: @(kAudioFormatLinearPCM),
            AVSampleRateKey: @(48000),
            AVNumberOfChannelsKey: @(2),
            AVLinearPCMBitDepthKey: @(16),
            AVLinearPCMIsFloatKey: @(NO),
        };
        _audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio
            outputSettings:audioSettings];
        _audioInput.expectsMediaDataInRealTime = YES;
    }
    
    // 5. Add inputs to writer
    [_writer addInput:_videoInput];
    if (_audioInput) [_writer addInput:_audioInput];
    
    // 6. Create dispatch queues
    _videoQueue = dispatch_queue_create("com.vcviewer.recorder.video", DISPATCH_QUEUE_SERIAL);
    _audioQueue = dispatch_queue_create("com.vcviewer.recorder.audio", DISPATCH_QUEUE_SERIAL);
    
    return self;
}

- (void)addVideoFrame:(ECVVideoFrame *)frame {
    if (!frame || !_videoInput.readyForMoreMediaData) return;
    
    // First frame starts the writer
    if (!_started) {
        [_writer startWriting];
        [_writer startSessionAtSourceTime:CMTimeMake(0, 1)];
        _started = YES;
    }
    
    // Convert ECVVideoFrame to CVPixelBuffer
    CVPixelBufferRef pixelBuffer = [self pixelBufferFromFrame:frame];
    if (!pixelBuffer) return;
    
    // Calculate presentation time
    CMTime pts = CMTimeMake(frameCount++, frameRateValue);
    
    // Append to adaptor
    if (![_pixelBufferAdaptor appendPixelBuffer:pixelBuffer withPresentationTime:pts]) {
        NSLog(@"Failed to append video frame");
    }
    
    CVPixelBufferRelease(pixelBuffer);
}

- (void)stopRecording {
    [_videoInput markAsFinished];
    [_audioInput markAsFinished];
    [_writer finishWritingWithCompletionHandler:^{
        NSLog(@"Recording finished: %@", self->_writer.status);
    }];
}

@end
```

---

## 5.4 Codec Mapping

| QuickTime Codec | AVFoundation Equivalent | Notes |
|-----------------|------------------------|-------|
| `'jpeg'` (Motion JPEG) | `AVVideoCodecTypeJPEG` | Available on Apple Silicon |
| `'mp4v'` (MPEG-4) | `AVVideoCodecTypeMPEG4Video` | Available |
| `'yuv2'` (Uncompressed) | Not directly supported for file writing | Use `AVVideoCodecTypeAppleProRes422` for lossless, or `kCVPixelFormatType_422YpCbCr8` with raw video settings |

### Apple Silicon hardware encoders
Apple Silicon supports hardware-accelerated encoding for:
- H.264 (`AVVideoCodecTypeH264`)
- H.265/HEVC (`AVVideoCodecTypeHEVC`)
- ProRes 422/4444 (`AVVideoCodecTypeAppleProRes422`, etc.)

**Recommendation:** Add H.264 and HEVC as primary codec options (hardware-accelerated on Apple Silicon, better quality/size than Motion JPEG).

---

## 5.5 PixelBuffer Conversion

The current code converts `ECVVideoFrame` → `CVPixelBuffer` via `ECVCVPixelBuffer`. This wrapper should still work since `CVPixelBuffer` is a CoreVideo API (not deprecated). The key is getting the pixel format right:

```objc
- (CVPixelBufferRef)pixelBufferFromFrame:(ECVVideoFrame *)frame {
    // Use existing ECVCVPixelBuffer or create CVPixelBuffer directly
    // Ensure format matches: k2vuyPixelFormat (422 YCbCr 8-bit)
    
    CVPixelBufferRef pixelBuffer = NULL;
    CVPixelBufferPoolCreatePixelBuffer(NULL, _pool, &pixelBuffer);
    
    // Copy frame data into pixel buffer
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    void *dst = CVPixelBufferGetBaseAddress(pixelBuffer);
    void *src = [frame bytes];
    size_t srcSize = [frame bytesLength];
    memcpy(dst, src, srcSize);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    return pixelBuffer; // Caller must release
}
```

---

## 5.6 Audio Recording

Current: `ECVAudioPipe` → `AddMediaSample2` (QuickTime)  
New: `ECVAudioPipe` → `CMSampleBuffer` → `AVAssetWriterInput`

```objc
- (void)addAudioBufferList:(AudioBufferList const *)bufferList {
    if (!bufferList || !_audioInput.readyForMoreMediaData) return;
    
    CMFormatDescriptionRef formatDesc;
    CMAudioFormatDescriptionCreate(NULL, &audioStreamBasicDesc, 0, NULL, 0, NULL, NULL, &formatDesc);
    
    CMSampleBufferRef sampleBuffer;
    CMSampleBufferCreate(NULL, formatDesc, true, NULL, NULL, bufferList, 1, 0, NULL, 0, NULL, &sampleBuffer);
    
    CMTime pts = ...; // track audio position
    CMSampleBufferSetOutputPresentationTimeStamp(sampleBuffer, pts);
    
    [_audioInput appendSampleBuffer:sampleBuffer];
    CFRelease(sampleBuffer);
    CFRelease(formatDesc);
}
```

---

## 5.7 Integration with ECVCaptureController

The recording call site in `ECVCaptureController.m` should mostly stay the same. The `ECVMovieRecordingOptions` interface is compatible. The key change:

```objc
// BEFORE (current):
ECVMovieRecorder *const recorder = [[[ECVMovieRecorder alloc] initWithOptions:options error:&error] autorelease];

// AFTER (ARC + new API):
ECVMovieRecorder *const recorder = [[ECVMovieRecorder alloc] initWithOptions:options error:&error];
```

The `ECVCaptureController` already handles the recording UI — this should work with minimal changes once `ECVMovieRecorder` is rewritten.

---

## 5.8 Verification

After Phase 5, the project should:
- [ ] `ECVMovieRecorder` uses `AVAssetWriter` / `AVAssetWriterInput`
- [ ] No QuickTime, ICM, or QTKit references remain anywhere
- [ ] Can record video to `.mov` file
- [ ] Can record audio to `.mov` file
- [ ] Motion JPEG codec works (via AVFoundation JPEG encoder)
- [ ] H.264 codec option added (hardware-accelerated)
- [ ] HEVC codec option added (hardware-accelerated)
- [ ] Crop rect is applied to recording output
- [ ] Frame rate conversion still works
- [ ] Recording can be started and stopped cleanly
- [ ] Output file plays correctly in QuickTime Player
- [ ] No memory leaks during recording (Instruments)
