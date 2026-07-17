<p align="center">
  <img src="EasyCapViewer.icns" alt="EasyCapViewer Icon" width="128" height="128">
</p>

<h1 align="center">EasyCapViewer</h1>

<p align="center">
  <strong>Capture live video and audio from USB analog capture dongles on macOS</strong>
</p>

<p align="center">
  <a href="#features">Features</a> &middot;
  <a href="#supported-hardware">Hardware</a> &middot;
  <a href="#installation">Installation</a> &middot;
  <a href="#usage">Usage</a> &middot;
  <a href="#architecture">Architecture</a> &middot;
  <a href="#building">Building</a> &middot;
  <a href="#modernization">Modernization</a> &middot;
  <a href="#license">License</a>
</p>

---

## Overview

**EasyCapViewer** is a native macOS application for capturing live video and audio from inexpensive USB analog capture dongles — the kind commonly known as "EasyCap" devices. These compact USB devices accept composite (RCA) or S-Video input from analog sources like VCRs, camcorders, security cameras, and game consoles, and convert them to digital video streams.

Built entirely in Objective-C using Cocoa's document-based architecture, EasyCapViewer provides real-time video preview with hardware-accelerated rendering, configurable deinterlacing, recording to QuickTime movies, and a dark HUD-style control interface.

> **Note:** This project is undergoing a 10-phase modernization to bring it to Apple Silicon macOS 13.0+. See the [Modernization](#modernization) section for current status.

---

## Features

### Video Capture
- **Real-time preview** via OpenGL texture rendering with CVDisplayLink vsync
- **Composite and S-Video** input selection
- **NTSC, PAL, and SECAM** video standards (10 format variants)
- **7 deinterlacing modes**: Progressive, Weave, Line Double HQ/LQ, Alternate, Blur, Drop

### Video Processing
- **Aspect ratio** presets: 4:3, 16:10, 16:9 (and custom)
- **Interactive cropping** with draggable handles and border trimming
- **Brightness, contrast, saturation, and hue** adjustments (device-dependent)
- **Integer scaling**: Half, Actual, and Double size
- **Full-screen mode** with auto-hiding cursor
- **Frame drop indicator** when the system can't keep up

### Audio
- **Live audio monitoring** through system speakers
- **Volume control** with mute toggle
- **Mono-to-stereo upconversion** for devices that output mono audio
- **Audio input selection** from any connected CoreAudio device

### Recording
- **QuickTime .mov** export with codec and quality selection
- **Frame rate conversion** for recording at different rates than capture
- **Video codecs**: Motion JPEG, MPEG-4, YUV2

### Interface
- **Dark HUD overlay** controls that blend with the video
- **Configurable settings panel** for all video, audio, and image parameters
- **Error log window** with timestamped messages
- **Localization** infrastructure (English included)
- **Multi-window cloning** — view the same capture in multiple windows

---

## Supported Hardware

| Chipset | Device Examples | Status |
|---------|----------------|--------|
| **Syntek STK1160** | EasyCap DC60, various generic dongles | Supported |
| **Empia EM2860** | EM2860-based capture devices | Supported |
| **Somagic** | Somagic EasyCap variants | Supported |
| **Fushicai** | Fushicai UTV007 devices | Supported |

All supported devices are identified by USB Vendor ID and Product ID pairs defined in `ECVDevices.plist`. The application supports:

| Input | Connector |
|-------|-----------|
| **Composite Video** | RCA jack (yellow) |
| **S-Video** | Mini-DIN 4-pin |
| **Stereo Audio** | RCA jacks (red/white) — device-dependent |

---

## Installation

### Requirements

- **macOS 13.0** (Ventura) or later
- A supported USB capture device
- An analog video source (VCR, camera, console, etc.)

### Download

Pre-built binaries are not yet available for the modernized version. To use EasyCapViewer, build from source using the instructions below.

---

## Usage

1. **Connect** your USB capture device to a USB port
2. **Launch** EasyCapViewer — it automatically detects connected devices
3. **Plug in** your video source (composite or S-Video cable)
4. Click **Play** in the menu bar or press **Space** to start capture
5. Use **Cmd+,** to open the settings panel and adjust video/audio parameters

### Keyboard Shortcuts

| Key | Action |
|-----|--------|
| Space | Toggle play/pause |
| Cmd+F | Toggle full screen |
| Cmd+T | Toggle float on top |
| Cmd+S | Start recording |
| Cmd+. | Stop recording |
| Cmd+Up/Down | Adjust volume |
| Cmd+Opt+Up/Down | Toggle mute |

### Menu Bar

- **File**: Play, Start/Stop Recording, Clone Viewer
- **View**: Size (Half/Actual/Double), Full Screen, Aspect Ratio, Crop, V-Sync, Smoothing
- **Window**: Error Log
- **EasyCapViewer**: Configure Device (Cmd+,)

---

## Architecture

EasyCapViewer follows a **producer-consumer pipeline** architecture built on Apple's document-based application model:

```
USB Hardware
    | (isochronous reads on dedicated thread)
    v
ECVCaptureDevice subclass
    | writeBytes:length:toStorage: (Template Method)
    v
ECVVideoStorage + Deinterlacing
    | 16-buffer pool -> 7 deinterlacing modes -> VideoFrame
    v
ECVCaptureDocument
    | Thread-safe fan-out (ECVReadWriteLock)
    |
    +---> ECVVideoView (OpenGL GL, CVDisplayLink)
    +---> ECVAudioTarget (CoreAudio speakers)
    +---> ECVMovieRecorder (QuickTime/ICM, 32-bit only)
```

### Key Design Patterns

- **NSDocument Architecture** — Each capture session is a document with its own window
- **Abstract Base Classes** — ECVCaptureDevice, ECVVideoStorage, ECVDeinterlacingMode
- **Strategy Pattern** — Deinterlacing modes are swappable at runtime
- **Producer-Consumer** — USB reads, frame distribution, and display are decoupled via queues and locks
- **Singleton** — ECVController (app), ECVConfigController (settings)

### Thread Model

| Thread | Purpose |
|--------|---------|
| Main thread | UI, Cocoa run loop, NIB loading |
| USB read thread | Isochronous reads, byte parsing, frame production (one per device) |
| CVDisplayLink | OpenGL rendering at display refresh rate |
| Compression thread | ICM compression (when recording) |
| Record thread | QuickTime movie file writing (when recording) |

---

## Building

### Prerequisites

- **Xcode** with macOS 13+ SDK
- **macOS Ventura** or later (for running)

### Build Commands

```bash
# Debug build
xcodebuild -project EasyCapViewer.xcodeproj \
           -scheme EasyCapViewer \
           -configuration Debug build

# Release build
xcodebuild -project EasyCapViewer.xcodeproj \
           -scheme EasyCapViewer \
           -configuration Release build

# Clean
xcodebuild -project EasyCapViewer.xcodeproj \
           -scheme EasyCapViewer clean
```

### Build Settings

| Setting | Value |
|---------|-------|
| Deployment Target | macOS 13.0 |
| Architecture | Universal (arm64 + x86_64) |
| ARC | Enabled |
| Hardened Runtime | Enabled |
| Sandboxing | Disabled (IOKit USB access required) |

---

## Project Files

### Core Pipeline
| File | Description |
|------|-------------|
| `ECVController` | App-level singleton. USB device discovery, system sleep prevention, document creation. |
| `ECVCaptureDocument` | Document model. Central hub routing video/audio from device to all targets. |
| `ECVCaptureDevice` | Abstract USB device base class. Manages IOKit, isochronous reads, frame production. |
| `ECVAVTarget` | Protocol defining `play`/`stop`/`pushVideoFrame:`/`pushAudioBufferListValue:`. |

### Device Drivers
| File | Description |
|------|-------------|
| `ECVSTK1160Device` | Syntek STK1160 chipset driver |
| `ECVEM2860Device` | Empia EM2860 chipset driver |
| `ECVSomagicDevice` | Somagic chipset driver (with firmware upload) |
| `ECVFushicaiDevice` | Fushicai chipset driver |
| `SAA711XChip` | SAA711X video decoder chip abstraction |
| `VT1612AChip` | VT1612A audio chip abstraction |

### Video Pipeline
| File | Description |
|------|-------------|
| `ECVVideoView` | NSOpenGLView subclass. CVDisplayLink-driven real-time rendering. |
| `ECVVideoStorage` | Abstract frame buffer pool (16-buffer or per-frame allocation). |
| `ECVDeinterlacingMode` | 7 deinterlacing algorithms (Progressive, Weave, LineDouble, etc.). |
| `ECVPixelBuffer` | CVPixelBuffer wrapper with field-aware drawing. |
| `ECVFrameRateConverter` | Frame rate conversion by frame repetition with rational arithmetic. |

### Audio Pipeline
| File | Description |
|------|-------------|
| `ECVAudioDevice` | CoreAudio device wrapper (input and output). |
| `ECVAudioPipe` | Audio format conversion via AudioConverterFillComplexBuffer. |
| `ECVAudioTarget` | Bridges audio pipeline to system speaker output. |

### Recording
| File | Description |
|------|-------------|
| `ECVMovieRecorder` | QuickTime recording (32-bit only, requires modernization). |

### UI
| File | Description |
|------|-------------|
| `ECVCaptureController` | Primary window controller. Bridges data pipeline to video view and recorder. |
| `ECVConfigController` | Settings panel singleton (video/audio/image controls). |
| `ECVErrorLogController` | Timestamped error log window. |
| `MPLWindow` | Custom NSWindow with auto-hiding cursor. |
| `ECVHUD*Cell` | Dark translucent overlay cells for buttons, sliders, popups, checkboxes. |
| `ECVCropCell` | Interactive crop handles rendered as OpenGL overlay. |
| `ECVPlayButtonCell` | Play icon overlay for paused state. |

### Utilities
| File | Description |
|------|-------------|
| `ECVDebug` | Logging framework with error-checking macros (ECVOSStatus, ECIOReturn, etc.). |
| `ECVLocalizing` | Automatic NIB localization via method swizzling. |
| `ECVReadWriteLock` | Thread-safe pthread_rwlock wrapper. |
| `ECVRational` | Exact rational number arithmetic for frame rate calculations. |

---

## Modernization

EasyCapViewer is undergoing a **10-phase modernization** to bring it to Apple Silicon and modern macOS. The goal is to replace deprecated APIs while preserving the existing architecture.

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | Project Setup & Build System | **Done** |
| 2 | ARC Migration (MRC -> ARC) | In Progress |
| 3 | Remove Dead 32-bit Code | Pending |
| 4 | OpenGL -> Metal (Video Rendering) | Pending |
| 5 | QuickTime -> AVFoundation (Recording) | Pending |
| 6 | USB Drivers Modernization | Pending |
| 7 | Audio Pipeline Modernization | Pending |
| 8 | UI & HUD Modernization | Pending |
| 9 | Project Folder Restructuring | Pending |
| 10 | Testing, Signing & Distribution | Pending |

See [`MODERNIZATION.md`](MODERNIZATION.md) for the full plan, and [`docs/modernization/`](docs/modernization/) for detailed phase-by-phase documentation.

---

## Privacy & Security

- EasyCapViewer accesses USB hardware directly via IOKit, which **cannot run in a sandboxed environment**
- No data is sent to any remote server
- No analytics or telemetry
- Recording creates local .mov files only

---

## License

**BSD License** — Copyright (c) 2009-2013, Ben Trask. All rights reserved.

See individual source files for the full license text.

---

## Credits

Written by **Ben Trask** (2009-2013).

Modernization contributions welcome. See the [modernization plan](MODERNIZATION.md) for how to help.
