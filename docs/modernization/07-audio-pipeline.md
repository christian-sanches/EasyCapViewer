# Phase 7 — Audio Pipeline Modernization

**Goal:** Verify and update the CoreAudio pipeline for Apple Silicon compatibility. The audio system uses CoreAudio which is fully supported, so changes should be minimal.

---

## 7.1 Current Audio Architecture

```
USB Audio Bulk Transfer → ECVAudioPipe (format conversion) → ECVAudioDevice (CoreAudio output)
                                                              ↓
                                                     AudioDeviceIOProcID (system audio)
                                                              ↓
                                                     System speakers / headphones
```

### Key files
| File | Role |
|------|------|
| `ECVAudioDevice.h/m` | Wraps `AudioDeviceID`; manages IOProc, listeners |
| `ECVAudioPipe.h/m` | Format conversion (mono→stereo, sample rate) |
| `ECVAudioTarget.h/m` | Abstraction for audio output target |
| `ECVAVTarget.h` | Protocol for audio+video targets |

### CoreAudio APIs used
- `AudioObjectGetPropertyData` / `AudioObjectSetPropertyData` — device enumeration, format
- `AudioDeviceCreateIOProcID` — callback-based audio I/O
- `AudioDeviceStart` / `AudioDeviceStop` — start/stop audio
- `AudioBufferList` — audio data transport
- `AudioStreamBasicDescription` — format description

---

## 7.2 Apple Silicon Compatibility

### What works as-is
All CoreAudio APIs listed above are fully supported on Apple Silicon:
- `AudioObject` API — unchanged
- `AudioDevice` — unchanged
- `AudioStreamBasicDescription` — unchanged
- `AudioBufferList` — unchanged

### Potential issues

#### 1. Default audio device changes
Apple Silicon Macs may have different default audio devices (built-in speakers, AirPods, etc.). The current code should handle this, but verify:
- Device enumeration picks up all available output devices
- Hot-plugging audio devices (AirPods connect/disconnect) is handled

#### 2. Audio format
The current code uses 48kHz / 2ch / Float32 PCM:
```objc
static const AudioStreamBasicDescription ECVStandardAudioStreamBasicDescription = {
    .mSampleRate = 48000.0,
    .mFormatID = kAudioFormatLinearPCM,
    .mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
    .mBytesPerPacket = 8,
    .mFramesPerPacket = 1,
    .mBytesPerFrame = 8,
    .mChannelsPerFrame = 2,
    .mBitsPerChannel = 32,
};
```

This is a standard format and should work fine on Apple Silicon.

#### 3. Audio latency
Apple Silicon has very low audio latency. The current `AudioDeviceIOProcID` callback model is optimal — no changes needed.

---

## 7.3 Changes Required

### 7.3.1 ARC conversion
All audio files need ARC conversion (Phase 2). The audio code has manual `retain`/`release` in:
- `ECVAudioTarget.m` — retain/release of `_audioOutput`
- `ECVAudioPipe.m` — buffer management

### 7.3.2 No API changes needed
Unlike OpenGL and QuickTime, CoreAudio has not deprecated any of the APIs used here. The entire audio pipeline can remain as-is after ARC conversion.

### 7.3.3 Optional: Add audio device hot-plug handling
Current code registers `AudioObjectPropertyListenerProc` for device changes. Verify this works correctly with:
- AirPods connecting/disconnecting
- USB audio devices (EasyCap audio) connecting/disconnecting
- Default device switching

---

## 7.4 Future Enhancement: AudioUnit for Effects

If audio effects are desired in the future (volume normalization, noise reduction), the pipeline could be extended with:
- `AudioUnit` processing chain (still CoreAudio, fully supported)
- Or `AVAudioEngine` (higher-level, more features)

This is **not required** for the port but is a natural extension point.

---

## 7.5 Verification

After Phase 7, the project should:
- [x] All audio files compile with ARC
- [x] Audio device enumeration finds all system audio outputs
- [x] 48kHz / 2ch / Float32 PCM format is correctly negotiated
- [ ] Audio playback works through system speakers/headphones
- [ ] Audio works during video capture simultaneously
- [ ] Audio device hot-plug (connect/disconnect) is handled gracefully
- [ ] No audio glitches during capture (buffer underruns)
- [ ] ECVAudioPipe format conversion (mono→stereo) works correctly
