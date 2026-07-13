# EasyCapViewer - Agent Knowledge Base

> macOS document-based application for capturing live video/audio from USB analog capture dongles (EasyCap family). Written in Objective-C by Ben Trask (2009-2013), actively being modernized for Apple Silicon macOS 13.0+.

---

## Build & Development

```bash
# Build (requires Xcode with macOS 13+ SDK)
xcodebuild -project EasyCapViewer.xcodeproj -scheme EasyCapViewer -configuration Debug build

# Build release
xcodebuild -project EasyCapViewer.xcodeproj -scheme EasyCapViewer -configuration Release build

# Clean
xcodebuild -project EasyCapViewer.xcodeproj -scheme EasyCapViewer clean
```

**No test suite exists.** There are no unit tests, UI tests, or test targets.

---

## Project Structure

```
EasyCapViewer/
├── EasyCapViewer.xcodeproj/     # Xcode project (objectVersion 46, Xcode 3-era)
├── EasyCapViewer-Info.plist     # App plist (macOS 13.0+ deployment target)
├── EasyCapViewer_Prefix.pch     # Precompiled header (global types & macros)
├── EasyCapViewer.m              # main() entry point (installs auto-localization swizzle)
│
├── ECVController.h/m            # App controller (NSDocumentController subclass, singleton)
├── ECVCaptureDocument.h/m       # Document model (NSDocument, central data pipeline hub)
├── ECVCaptureDevice.h/m         # Abstract USB capture device base class
│
├── ECVSTK1160Device.h/m         # STK1160 chipset driver
├── stk11xx.h / stk11xx-dev-0408.m  # STK1160 low-level register I/O
├── ECVEM2860Device.h/m          # EM2860 chipset driver
├── ECVSomagicDevice.h/m         # Somagic chipset driver (with firmware upload)
├── ECVSomagicDevice_Unloaded.h/m # Somagic stub (firmware unavailable)
├── ECVFushicaiDevice.h/m        # Fushicai chipset driver
├── SAA711XChip.h/m              # SAA711X video decoder chip abstraction
├── VT1612AChip.h/m              # VT1612A audio chip abstraction
├── ECVDevices.plist             # USB vendor/product ID -> class mapping
│
├── ECVVideoView.h/m             # OpenGL video display (NSOpenGLView + CVDisplayLink)
├── ECVMovieRecorder.h/m         # QuickTime movie recorder (32-bit only, dead on 64-bit)
├── ECVICM.h                     # ICM compression macros (32-bit only, #if !__LP64__)
│
├── ECVVideoSource.h/m           # Video input source (Composite / S-Video)
├── ECVVideoFormat.h/m           # Video formats (NTSC, PAL, SECAM variants)
├── ECVVideoStorage.h/m          # Abstract frame buffer pool
├── ECVDependentVideoStorage.h/m # Fixed 16-buffer pool (zero-copy OpenGL)
├── ECVIndependentVideoStorage.h/m # Per-frame allocation (fallback)
├── ECVVideoFrame.h/m            # Completed displayable frame
├── ECVPixelBuffer.h/m           # CVPixelBuffer wrapper with field drawing
├── ECVPixelFormat.h             # UYVY / YVYU pixel format constants
├── ECVDeinterlacingMode.h/m     # 7 deinterlacing algorithms
├── ECVFrameRateConverter.h/m    # Frame rate conversion by frame repetition
├── ECVRational.h/m              # Exact rational arithmetic (avoids float precision issues)
│
├── ECVAudioDevice.h/m           # CoreAudio device wrapper (input & output)
├── ECVAudioPipe.h/m             # Audio format conversion (AudioConverterFillComplexBuffer)
├── ECVAudioTarget.h/m           # Audio output target (speakers)
├── ECVAVTarget.h                # Central protocol: play/stop/pushVideoFrame/pushAudioBuffer
│
├── ECVCaptureController.h/m     # Primary window controller (ECVAVTarget, manages video view + recorder)
├── ECVConfigController.h/m      # Settings panel (singleton, video/audio/image settings)
├── ECVErrorLogController.h/m    # Error log window
├── MPLWindow.h/m                # Custom NSWindow (cursor auto-hide)
│
├── ECVHUD*.h/m                  # Dark translucent HUD overlay cells (button, slider, popup, switch)
├── ECVCropCell.h/m              # Interactive crop handles (OpenGL overlay)
├── ECVPlayButtonCell.h/m        # Large play icon overlay (OpenGL texture)
├── ECVTickMarkView.h/m          # Decorative tick marks for sliders
├── ECVDividerView.h/m           # Horizontal divider line
├── ECVRectEdgeMask.h/m          # Edge/corner bitmask + geometry functions
│
├── ECVAppKitAdditions.h/m       # NSBezierPath gradients, NSBitmapImageRep->GL texture, window toggle
├── ECVOpenGLAdditions.h/m       # GL quad drawing, border drawing
├── ECVDebug.h/m                 # Logging (ECVLog), error-checking macros, error->string converters
├── ECVLocalizing.h/m            # Auto-localization via NIB-loading swizzle
├── ECVFoundationAdditions.h/m   # Method swizzling, notification helpers, high-precision timing
├── ECVReadWriteLock.h/m         # pthread_rwlock wrapper
│
├── ECVCapture.xib               # Document window (MPLWindow + ECVVideoView)
├── ECVConfig.xib                # Settings panel (NSPanel with video/audio controls)
├── ECVErrorLog.xib              # Error log window
├── ECVMenu.xib                  # Main menu bar
├── en.lproj/                    # English localization strings
│
├── EasyCapViewer.icns           # App icon
├── Cursor-Resize-*.tiff         # Crop cursors
├── Log-Clear.png                # Error log toolbar icon
│
├── MODERNIZATION.md             # Modernization plan (10 phases)
└── docs/modernization/          # Detailed phase-by-phase documentation
```

---

## Architecture

### Data Pipeline

```
USB Hardware
    | (isochronous reads on dedicated thread)
    v
ECVCaptureDevice subclass (writeBytes:length:toStorage:)
    |
    v
ECVVideoStorage -> ECVDeinterlacingMode -> ECVVideoFrame
    | (pushVideoFrame:)
    v
ECVCaptureDocument (fan-out via ECVReadWriteLock)
    |                    |                    |
    v                    v                    v
ECVCaptureController   ECVAudioTarget     ECVMovieRecorder
(video display)       (speaker output)   (movie file)
```

### Key Abstractions

- **ECVAVTarget protocol** -- Unified interface for any audio/video consumer: `play`, `stop`, `pushVideoFrame:`, `pushAudioBufferListValue:`
- **ECVCaptureDevice** -- Abstract base class for USB hardware. Subclasses implement `writeBytes:length:toStorage:` to parse device-specific byte streams into pixel data. Uses Template Method pattern.
- **ECVCaptureDocument** -- NSDocument subclass acting as the central router. Maintains a thread-safe list of ECVAVTarget objects and fans out frames to all targets.
- **ECVVideoStorage** -- Abstract frame buffer pool. Two concrete subclasses: `ECVDependentVideoStorage` (16-buffer pool for zero-copy OpenGL) and `ECVIndependentVideoStorage` (per-frame allocation fallback).
- **ECVDeinterlacingMode** -- Abstract base with 7 concrete algorithms: Progressive, Weave, LineDoubleHQ, LineDoubleLQ, Alternate, Blur, Drop. Stored as a Class (not instance) for polymorphic dispatch.

### Supported Hardware

| Class | Chipset | USB VID:PID |
|-------|---------|-------------|
| ECVSTK1160Device | Syntek STK1160 | 1505:1032 |
| ECVEM2860Device | Empia EM2860 | 60186:10337 |
| ECVSomagicDevice | Somagic | 7304:63 |
| ECVSomagicDevice_Unloaded | Somagic (stub) | 7304:7 |
| ECVFushicaiDevice | Fushicai | 7025:12290 |

### Video Formats

- 60Hz: NTSC-M, NTSC-J, NTSC-443/60Hz, PAL-60, PAL-M (704x240 interlaced, ~29.97fps)
- 50Hz: PAL-BGDHI, PAL-N, PAL-443/50Hz, SECAM, NTSC-N (704x288 interlaced, 25fps)

### Deinterlacing Modes

| Mode | Spatial | Temporal | frameGroupSize | Description |
|------|---------|----------|----------------|-------------|
| Progressive | native | native | 2 | Passthrough for progressive sources |
| Weave | 1/1 | 1/1 | 1 | Combine both fields (full quality) |
| Line Double HQ | 1/1 | 1/1 | 2 | Double each field's lines |
| Alternate | 1/1 | 1/1 | 2 | Alternate active field per frame |
| Drop | 1/2 | 1/2 | 1 | Drop one field entirely |
| Line Double LQ | 1/2 | 1/1 | 2 | Half height, both fields |
| Blur | 1/2 | 1/1 | 1 | Blend successive frames at half height |

### Thread Model

- **Main thread**: UI, Cocoa run loop, NIB loading
- **USB read thread** (one per device): Isochronous USB reads, byte parsing, frame production
- **CVDisplayLink thread**: OpenGL rendering at display refresh rate
- **Compression thread** (when recording): ICM compression session
- **Record thread** (when recording): QuickTime movie file writing

Thread safety is provided by:
- `ECVReadWriteLock` (pthread_rwlock) for frame distribution and video storage access
- `NSRecursiveLock` for video storage base operations
- OpenGL context locking via `CGLLockContext` / `CGLUnlockContext`
- `NSLock` for audio pipe buffer arrays
- `NSConditionLock` queues for producer-consumer in movie recorder

---

## Code Conventions

### Naming

- **Prefix**: All classes use `ECV` prefix (except `MPLWindow` and chip classes `SAA711XChip`, `VT1612AChip`)
- **Private methods**: Underscore-prefixed (e.g., `-_read`, `-_drawOneFrame`)
- **Categories**: Named as `ClassName(CategoryName)` (e.g., `ECVCaptureDevice(ECVRead_Thread)`)
- **Constants**: `ECV` prefix + PascalCase (e.g., `ECVFullFrame`, `ECVUncroppedRect`)
- **Types**: PascalCase with `ECV` prefix (e.g., `ECVFieldType`, `ECVIntegerSize`, `ECVRectEdgeMask`)

### Memory Management

**Currently uses Manual Retain Release (MRC)** -- ARC is enabled in the project but the code has NOT been migrated yet. This is Phase 2 of the modernization plan.

Key patterns:
- `NSAutoreleasePool` in main() (will become `@autoreleasepool`)
- Explicit `retain`, `release`, `autorelease` calls throughout
- `dealloc` methods release ivars

### Error Handling

ECVDebug.h provides error-checking macros that log and return:
- `ECVOSStatus(expr)` -- checks against `noErr`
- `ECVIOReturn(expr)` -- checks against `kIOReturnSuccess`
- `ECVCVReturn(expr)` -- checks against `kCVReturnSuccess`
- `ECVGLError(expr)` -- drains `glGetError()` after execution
- `ECVErrno(expr)` -- checks `errno` after system calls

Logging via `ECVLog(level, format, ...)` with levels: ECVNotice, ECVWarning, ECVError, ECVCritical.

### Localization

Automatic localization via method swizzling: `ECVLocalizing.h` swizzles `NSBundle`'s NIB loading to call `ECV_localizeFromTable:` on all top-level objects. The NIB filename (minus extension) is used as the strings table name.

---

## Modernization Status

The project is undergoing a 10-phase modernization. See `MODERNIZATION.md` and `docs/modernization/` for details.

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | Project Setup & Build System | DONE |
| 2 | ARC Migration (MRC -> ARC) | NEXT |
| 3 | Remove Dead 32-bit Code | Pending |
| 4 | OpenGL -> Metal (Video Rendering) | Pending |
| 5 | QuickTime -> AVFoundation (Recording) | Pending |
| 6 | USB Drivers Modernization | Pending |
| 7 | Audio Pipeline Modernization | Pending |
| 8 | UI & HUD Modernization | Pending |
| 9 | Project Folder Restructuring | Pending |
| 10 | Testing, Signing & Distribution | Pending |

### Current Branch

`modernization-mvp` -- Main modernization branch. Phase 1 changes will be applied here.

### What Still Needs Modernization

- **MRC -> ARC**: Code still uses manual retain/release despite ARC being enabled. This will cause compiler errors until Phase 2 is completed.
- **OpenGL -> Metal**: ECVVideoView uses NSOpenGLView, CVDisplayLink, glTexImage2D, GL_TEXTURE_RECTANGLE_EXT. Must be replaced with MTKView and Metal texture pipeline.
- **QuickTime -> AVFoundation**: ECVMovieRecorder uses ICMCompressionSession, Movie, Track, Media (all 32-bit only, wrapped in `#if !__LP64__`). Recording is completely non-functional on 64-bit.
- **UI**: HUD cells use custom OpenGL drawing. ECVCropCell and ECVPlayButtonCell render via OpenGL overlays.
- **Carbon remnants**: Some Carbon APIs may still be referenced.

---

## File Roles Quick Reference

| File | Role | Key Dependencies |
|------|------|-----------------|
| ECVController | App singleton, USB discovery, sleep/wake | IOKit, NSDocumentController |
| ECVCaptureDocument | Central pipeline hub, frame fan-out | ECVAVTarget, ECVReadWriteLock |
| ECVCaptureDevice | Abstract USB device, read thread | IOKit USB, ECVVideoStorage |
| ECVVideoView | OpenGL video display | NSOpenGLView, CVDisplayLink, GL |
| ECVCaptureController | Window controller, UI bridge | ECVVideoView, ECVMovieRecorder |
| ECVMovieRecorder | QuickTime recording (32-bit dead) | QuickTime, ICM, ECVFrameRateConverter |
| ECVAudioTarget | Speaker output | CoreAudio, ECVAudioPipe |
| ECVConfigController | Settings panel | ECVCaptureDevice, ECVAudioDevice |
| ECVDeinterlacingMode | 7 deinterlacing algorithms | Accelerate (vDSP), ECVPixelBuffer |
| ECVDependentVideoStorage | 16-buffer pool for zero-copy GL | CVPixelBuffer, ECVReadWriteLock |
| ECVDebug | Logging + error formatting | NSLog, ECVErrorLogController |
