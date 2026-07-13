# EasyCapViewer — Modernization Plan

**Target:** Native Apple Silicon macOS 13.0+ (Ventura and later)  
**Language:** Objective-C with ARC, potential Swift interop  
**Status:** In Progress  

---

## Progress Tracker

- [x] Phase 1 — Project Setup & Build System
- [ ] Phase 2 — ARC Migration (Manual → Automatic Reference Counting)
- [ ] Phase 3 — Remove Dead 32-bit Code (QuickTime Component, QTKit)
- [ ] Phase 4 — OpenGL → Metal (Video Rendering)
- [ ] Phase 5 — QuickTime/ICM → AVFoundation (Movie Recording)
- [ ] Phase 6 — USB Drivers Modernization
- [ ] Phase 7 — Audio Pipeline Modernization
- [ ] Phase 8 — UI & HUD Modernization
- [ ] Phase 9 — Project Folder Restructuring
- [ ] Phase 10 — Testing, Signing & Distribution

---

## Overview

EasyCapViewer is a macOS document-based application for capturing video from USB analog capture dongles (EasyCap family). It was last updated circa 2013 and targets Mac OS X 10.5+. The codebase uses **manual reference counting (MRC)**, **OpenGL** for rendering, **QuickTime/ICM** for movie recording, and **QTKit** for a QuickTime component target. None of these APIs are available or supported on modern macOS / Apple Silicon.

### What works today on Apple Silicon
| API | Status | Notes |
|-----|--------|-------|
| IOKit | ✅ Still works | USB device enumeration and isochronous transfers |
| CoreAudio / AudioToolbox | ✅ Still works | Audio device I/O, streams, hardware |
| CoreVideo (CVPixelBuffer) | ✅ Still works | Pixel buffer management |
| Accelerate | ✅ Still works | vDSP/vImage for deinterlacing |
| QuartzCore / CoreAnimation | ✅ Still works | Layer composition |
| Cocoa (AppKit / Foundation) | ✅ Still works | Document architecture, UI |
| Swift / Objective-C runtime | ✅ Still works | ARC, modern ObjC features |

### What is dead and must be replaced
| API | Status | Replacement |
|-----|--------|-------------|
| OpenGL (`NSOpenGLView`, `NSOpenGLContext`, `glTexImage2D`) | ❌ Deprecated 10.14, no future | **Metal** + `MTKView` |
| QuickTime (`EnterMovies`, `ICMCompressionSession`, `Movie`, `Track`, `Media`) | ❌ Removed 10.15 | **AVFoundation** (`AVAssetWriter`, `AVAssetExportSession`) |
| QTKit | ❌ Removed 10.15 | **Remove entirely** (component target) |
| Carbon (parts used) | ⚠️ Mostly deprecated | Replace with Cocoa equivalents |
| `NSAutoreleasePool` | ⚠️ ARC replacement | `@autoreleasepool {}` |
| Manual retain/release | ⚠️ ARC replacement | Enable ARC compiler flag |
| `CVDisplayLink` | ⚠️ Deprecated 14.0 | `CADisplayLink` (macOS 14+) or keep as-is with fallback |

---

## File Inventory

### Device Drivers (IOKit USB) — **Keep & Modernize**
| File | Chipset | Notes |
|------|---------|-------|
| `ECVSTK1160Device.h/m` | Syntek STK1160 | Uses `stk11xx.h` registry helpers |
| `stk11xx.h`, `stk11xx-dev-0408.m` | STK1160 low-level | Register read/write over USB |
| `ECVEM2860Device.h/m` | Empia EM2860 | GPIO, audio bulk, video isoc |
| `ECVSomagicDevice.h/m` | Somagic | Requires firmware upload |
| `ECVSomagicDevice_Unloaded.h/m` | Somagic (unloaded variant) | Stub when firmware unavailable |
| `ECVFushicaiDevice.h/m` | Fushicai | NTSC/PAL mode switching |
| `ECVDevices.plist` | — | USB vendor/product ID database |

### Core Architecture — **Keep & Modernize**
| File | Role | Changes Needed |
|------|------|----------------|
| `ECVController.h/m` | App controller (NSDocumentController) | IOKit enumeration OK; remove MRC |
| `ECVCaptureDocument.h/m` | Document model (NSDocument) | Core logic OK; remove MRC, update recording |
| `ECVCaptureDevice.h/m` | Abstract capture device | OK; remove MRC |
| `ECVUSBTransferList.h/m` | Isochronous USB ring buffer | IOKit OK; remove MRC |
| `ECVVideoSource.h/m` | Video source abstraction | OK; remove MRC |
| `ECVVideoFormat.h/m` | Video format (resolution, framerate) | OK; remove MRC |
| `ECVPixelFormat.h` | Pixel format constants | OK as-is |
| `ECVDeinterlacingMode.h/m` | 7 deinterlacing modes | OK; Accelerate still works |
| `ECVRational.h/m` | Rational number math | OK as-is |
| `ECVFrameRateConverter.h/m` | Frame rate conversion | OK; remove MRC |

### Video Rendering — **Full Rewrite Required**
| File | Current | Target |
|------|---------|--------|
| `ECVVideoView.h/m` | `NSOpenGLView` subclass, `glTexImage2D`, PBO textures, `CVDisplayLink` | `MTKView` subclass, Metal texture pipeline, `CADisplayLink` |
| `ECVOpenGLAdditions.h/m` | OpenGL helper categories | Remove; replace with Metal equivalents |
| `ECVAppKitAdditions.h` | `ECVLockContext()` — OpenGL lock helper | Remove or replace |
| `ECVCropCell.h/m` | `NSOpenGLContext`-based crop drawing | Metal overlay or `NSView`-based |
| `ECVPlayButtonCell.h/m` | `NSOpenGLContext`-based play button | Metal overlay or `NSView`-based |

### Movie Recording — **Full Rewrite Required**
| File | Current | Target |
|------|---------|--------|
| `ECVMovieRecorder.h/m` | QuickTime `ICMCompressionSession`, `Movie`, `Media` | `AVAssetWriter` with `AVAssetWriterInput` |
| `ECVICM.h` | ICM compression session macros | Remove; AVFoundation has its own API |
| `ECVComponent.h/m` | QuickTime component (32-bit only) | **Remove entirely** |
| `ECVComponent.r` | QuickTime component resource | **Remove entirely** |
| `ECVComponentDispatch.h` | QuickTime dispatch table | **Remove entirely** |
| `ECVComponent-Info.plist` | QuickTime component plist | **Remove entirely** |
| `ECVQTKitAdditions.h/m` | QTKit categories | **Remove entirely** |

### Audio Pipeline — **Minor Updates**
| File | Role | Changes Needed |
|------|------|----------------|
| `ECVAudioDevice.h/m` | CoreAudio device wrapper | CoreAudio OK; remove MRC |
| `ECVAudioPipe.h/m` | Audio format conversion pipe | OK; remove MRC |
| `ECVAudioTarget.h/m` | Audio target abstraction | OK; remove MRC |
| `ECVAVTarget.h` | AV target protocol | OK as-is |

### UI Components — **Modernize**
| File | Role | Changes Needed |
|------|------|----------------|
| `ECVCaptureController.h/m` | Capture UI controller | Remove MRC, update recording calls |
| `ECVConfigController.h/m` | Settings window | Remove MRC |
| `ECVErrorLogController.h/m` | Error log window | Remove MRC |
| `MPLWindow.h/m` | Custom NSWindow | Remove MRC |
| `ECVHUDButtonCell.h/m` | HUD button cell | Remove MRC, may update for modern HUD |
| `ECVHUDSliderCell.h/m` | HUD slider cell | Remove MRC |
| `ECVHUDPopUpButtonCell.h/m` | HUD popup cell | Remove MRC |
| `ECVHUDSwitchButtonCell.h/m` | HUD switch cell | Remove MRC |
| `ECVTickMarkView.h/m` | Tick mark view | Remove MRC |
| `ECVDividerView.h/m` | Divider view | Remove MRC |
| `ECVRectEdgeMask.h/m` | Edge mask constants | OK as-is |

### Utilities — **Keep**
| File | Role | Changes Needed |
|------|------|----------------|
| `ECVDebug.h/m` | Logging, error formatting | Remove MRC |
| `ECVLocalizing.h/m` | Localization helpers | Remove MRC |
| `ECVFoundationAdditions.h/m` | Foundation categories | Remove MRC |
| `ECVPixelBuffer.h/m` | CVPixelBuffer wrapper | Remove MRC |
| `ECVReadWriteLock.h/m` | Read-write lock | Remove MRC |
| `EasyCapViewer_Prefix.pch` | Prefix header | Modernize |

### Resources — **Update**
| File | Changes Needed |
|------|----------------|
| `ECVCapture.xib` | Update to modern XIB format |
| `ECVConfig.xib` | Update to modern XIB format |
| `ECVErrorLog.xib` | Update to modern XIB format |
| `ECVMenu.xib` | Update to modern XIB format |
| `EasyCapViewer.icns` | Possibly add @2x icon |
| `EasyCapViewer-Info.plist` | Update deployment target, remove 32-bit keys |
| Localization `.strings` files | Keep as-is |

---

## Detailed Step Plans

Each phase has its own detailed document:

1. [Phase 1 — Project Setup](docs/modernization/01-project-setup.md)
2. [Phase 2 — ARC Migration](docs/modernization/02-arc-migration.md)
3. [Phase 3 — Remove 32-bit Code](docs/modernization/03-remove-32bit.md)
4. [Phase 4 — OpenGL → Metal](docs/modernization/04-opengl-to-metal.md)
5. [Phase 5 — QuickTime → AVFoundation](docs/modernization/05-quicktime-to-avfoundation.md)
6. [Phase 6 — USB Drivers](docs/modernization/06-usb-drivers.md)
7. [Phase 7 — Audio Pipeline](docs/modernization/07-audio-pipeline.md)
8. [Phase 8 — UI Modernization](docs/modernization/08-ui-modernization.md)
9. [Phase 9 — Project Restructuring](docs/modernization/09-project-restructuring.md)
10. [Phase 10 — Testing & Distribution](docs/modernization/10-testing-distribution.md)

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Metal rendering complexity | High | Start with simple texture blit; iterate |
| AVFoundation recording latency | Medium | Use async writing with buffer queues |
| USB isochronous transfer changes on Apple Silicon | High | Test early; IOKit USB should work but verify |
| Missing hardware for testing | High | Acquire EasyCap devices for each chipset |
| Xcode project format incompatibility | Low | Create new project, migrate sources |
| Carbon API removal | Low | Only used for minor helpers; replace with Cocoa |

---

## Estimated Effort

| Phase | Estimated Time |
|-------|---------------|
| Phase 1 — Project Setup | 1–2 hours |
| Phase 2 — ARC Migration | 4–8 hours (mechanical but large) |
| Phase 3 — Remove 32-bit Code | 1–2 hours |
| Phase 4 — OpenGL → Metal | 2–3 days |
| Phase 5 — QuickTime → AVFoundation | 2–3 days |
| Phase 6 — USB Drivers | 1 day (mostly testing) |
| Phase 7 — Audio Pipeline | 0.5 day |
| Phase 8 — UI Modernization | 1 day |
| Phase 9 — Restructuring | 1 day |
| Phase 10 — Testing | 2–3 days |
| **Total** | **~2–3 weeks** |
