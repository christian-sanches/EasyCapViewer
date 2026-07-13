# EasyCapViewer — Modernization Plan

**Target:** Native Apple Silicon macOS 14.0+ (Sonoma and later)  
**Language:** Objective-C with ARC, potential Swift interop  
**Status:** In Progress  

---

## Progress Tracker

- [x] Phase 1 — Project Setup & Build System
- [x] Phase 2 — ARC Migration (Manual → Automatic Reference Counting)
- [x] Phase 3 — Remove Dead 32-bit Code (QuickTime Component, QTKit)
- [x] Phase 4 — OpenGL → Metal (Video Rendering)
- [x] Phase 5 — QuickTime/ICM → AVFoundation (Movie Recording)
- [x] Phase 6 — USB Drivers Modernization
- [x] Phase 7 — Audio Pipeline Modernization
- [ ] Phase 8 — UI & HUD Modernization
- [ ] Phase 9 — Project Folder Restructuring
- [ ] Phase 10 — Testing, Signing & Distribution

---

## Overview

EasyCapViewer is a macOS document-based application for capturing video from USB analog capture dongles (EasyCap family). It was last updated circa 2013 and targeted Mac OS X 10.5+. Through Phases 1–7, the codebase has been migrated to **ARC**, all **dead 32-bit code** (QuickTime Component, QTKit, ECVICM) has been removed, **OpenGL rendering has been replaced with Metal**, **movie recording has been rewritten from QuickTime/ICM to AVFoundation**, **USB drivers have been modernized** with upgraded interface versions and improved error handling, and the **audio pipeline has been modernized** with modern Objective-C patterns (properties, weak delegates, nullability). The remaining work is UI modernization, project restructuring, and testing.

### What works today on Apple Silicon
| API | Status | Notes |
|-----|--------|-------|
| IOKit | ✅ Still works | USB device enumeration and isochronous transfers (upgraded to IOUSBInterfaceInterface) |
| CoreAudio / AudioToolbox | ✅ Still works | Audio device I/O, streams, hardware |
| CoreVideo (CVPixelBuffer) | ✅ Still works | Pixel buffer management |
| Accelerate | ✅ Still works | vDSP/vImage for deinterlacing |
| QuartzCore / CoreAnimation | ✅ Still works | Layer composition |
| Cocoa (AppKit / Foundation) | ✅ Still works | Document architecture, UI |
| Swift / Objective-C runtime | ✅ Still works | ARC, modern ObjC features |

### What is dead and must be replaced
| API | Status | Replacement | Phase |
|-----|--------|-------------|-------|
| OpenGL (`NSOpenGLView`, `NSOpenGLContext`, `glTexImage2D`) | ~~Deprecated 10.14~~ ✅ Removed | **Metal** + `MTKView` | Phase 4 ✓ |
| QuickTime (`EnterMovies`, `ICMCompressionSession`, `Movie`, `Track`, `Media`) | ~~Removed 10.15~~ ✅ Removed | **AVFoundation** (`AVAssetWriter`, `AVAssetWriterInput`) | Phase 3 ✓ (recording rewrite: Phase 5) |
| QTKit | ~~Removed 10.15~~ ✅ Removed | **Remove entirely** (component target) | Phase 3 ✓ |
| ECVICM.h (ICM macros) | ~~32-bit only~~ ✅ Removed | AVFoundation has its own API | Phase 3 ✓ |
| Carbon (parts used) | ⚠️ Mostly deprecated | Replace with Cocoa equivalents | — |
| `NSAutoreleasePool` | ~~ARC replacement~~ ✅ Done | `@autoreleasepool {}` | Phase 2 ✓ |
| Manual retain/release | ~~ARC replacement~~ ✅ Done | Enable ARC compiler flag | Phase 2 ✓ |
| `CVDisplayLink` | ⚠️ Deprecated 14.0 | `CADisplayLink` (macOS 14+) | Phase 4 ✓ (now using MTKView's built-in display link) |

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

### Core Architecture — ARC Migrated, Deprecations Fixed
| File | Role | Notes |
|------|------|-------|
| `ECVController.h/m` | App controller (NSDocumentController) | IOKit enumeration OK; ARC migrated; deprecation fixes |
| `ECVCaptureDocument.h/m` | Document model (NSDocument) | ARC migrated; recording stub pending Phase 5 |
| `ECVCaptureDevice.h/m` | Abstract capture device | ARC migrated; deprecation fixes; USB interface upgraded to IOUSBInterfaceInterface |
| `ECVUSBTransferList.h/m` | Isochronous USB ring buffer | IOKit OK; ARC migrated; USB interface upgraded to IOUSBInterfaceInterface |
| `ECVVideoSource.h/m` | Video source abstraction | OK |
| `ECVVideoFormat.h/m` | Video format (resolution, framerate) | OK |
| `ECVPixelFormat.h` | Pixel format constants | OpenGL imports removed; Metal helpers added |
| `ECVDeinterlacingMode.h/m` | 7 deinterlacing modes | OK; Accelerate still works |
| `ECVRational.h/m` | Rational number math | OK as-is |
| `ECVFrameRateConverter.h/m` | Frame rate conversion | OK |

### Video Rendering — ~~Full Rewrite Required~~ ✅ Complete (Phase 4)
| File | Before | After |
|------|--------|-------|
| `ECVVideoView.h/m` | `NSOpenGLView` subclass, `glTexImage2D`, PBO textures, `CVDisplayLink` | `MTKView` subclass, delegates rendering to `ECVMetalRenderer` |
| `ECVMetalRenderer.h/m` | — | **New.** Metal pipeline: YUV→RGB fragment shader, frame queue, texture upload from CVPixelBuffer (UYVY + YVYU) |
| `ECVMetalShaders.metal` | — | **New.** Vertex shader + BT.601 YCbCr→RGB conversion |
| `ECVOpenGLAdditions.h/m` | OpenGL helper categories | **Removed** |
| `ECVAppKitAdditions.h` | `ECVLockContext()` — OpenGL lock helper | Removed; `ECV_textureName` removed |
| `ECVCropCell.h/m` | `NSOpenGLContext`-based crop drawing | `NSBezierPath`/`NSBitmapImageRep` overlay drawing |
| `ECVPlayButtonCell.h/m` | `NSOpenGLContext`-based play button | `NSImage`-based overlay drawing |

### Movie Recording — QuickTime/ICM Removed, AVFoundation Rewrite Complete
| File | Status | Notes |
|------|--------|-------|
| `ECVMovieRecorder.h/m` | ✅ Rewritten | Full AVFoundation recording: `AVAssetWriter`, `AVAssetWriterInput`, `AVAssetWriterInputPixelBufferAdaptor` |
| `ECVICM.h` | **Removed** (Phase 3) | ICM compression session macros — no longer needed |
| `ECVComponent.h/m` | **Removed** (Phase 3) | QuickTime component (32-bit only) |
| `ECVComponent.r` | **Removed** (Phase 3) | QuickTime component resource |
| `ECVComponentDispatch.h` | **Removed** (Phase 3) | QuickTime dispatch table |
| `ECVComponent-Info.plist` | **Removed** (Phase 3) | QuickTime component plist |
| `ECVQTKitAdditions.h/m` | **Removed** (Phase 3) | QTKit categories |

### Audio Pipeline — ✅ Complete (Phase 7)
| File | Role | Notes |
|------|------|-------|
| `ECVAudioDevice.h/m` | CoreAudio device wrapper | ✅ Modernized: properties, weak delegate, instancetype, nullability |
| `ECVAudioPipe.h/m` | Audio format conversion pipe | ✅ Modernized: class extension, nullability, instancetype |
| `ECVAudioTarget.h/m` | Audio target abstraction | ✅ Modernized: weak captureDocument, literals, nullability |
| `ECVAVTarget.h` | AV target protocol | OK as-is |

### UI Components — Deprecations Fixed
| File | Role | Notes |
|------|------|-------|
| `ECVCaptureController.h/m` | Capture UI controller | Updated: removed `magFilter` usage, init calls updated for Metal renderer |
| `ECVConfigController.h/m` | Settings window | Deprecation fixes applied |
| `ECVErrorLogController.h/m` | Error log window | OK |
| `MPLWindow.h/m` | Custom NSWindow | Deprecation fixes applied |
| `ECVHUDButtonCell.h/m` | HUD button cell | OK |
| `ECVHUDSliderCell.h/m` | HUD slider cell | Deprecation fixes applied |
| `ECVHUDPopUpButtonCell.h/m` | HUD popup cell | Deprecation fixes applied |
| `ECVHUDSwitchButtonCell.h/m` | HUD switch cell | Deprecation fixes applied |
| `ECVTickMarkView.h/m` | Tick mark view | OK |
| `ECVDividerView.h/m` | Divider view | OK |
| `ECVRectEdgeMask.h/m` | Edge mask constants | OK as-is |

### Utilities — Deprecations Fixed
| File | Role | Notes |
|------|------|-------|
| `ECVDebug.h/m` | Logging, error formatting | `ECVGLError` macro removed; `ECVOpenGLErrorToString` removed |
| `ECVLocalizing.h/m` | Localization helpers | OK |
| `ECVFoundationAdditions.h/m` | Foundation categories | Deprecation fixes: `AbsoluteToNanoseconds` → `mach_absolute_time` |
| `ECVPixelBuffer.h/m` | CVPixelBuffer wrapper | OK |
| `ECVReadWriteLock.h/m` | Read-write lock | OK |
| `EasyCapViewer_Prefix.pch` | Prefix header | OK |

### Resources — Partially Updated
| File | Notes |
|------|-------|
| `ECVCapture.xib` | Still references `openGLView` — needs update to `MTKView` custom class |
| `ECVConfig.xib` | OK |
| `ECVErrorLog.xib` | OK |
| `ECVMenu.xib` | OK |
| `EasyCapViewer.icns` | Possibly add @2x icon |
| `EasyCapViewer-Info.plist` | ✅ Updated: deployment target 14.0, 32-bit keys removed |
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

| Risk | Impact | Mitigation | Status |
|------|--------|------------|--------|
| Metal rendering complexity | High | Start with simple texture blit; iterate | ✅ Resolved (Phase 4) |
| AVFoundation recording latency | Medium | Use async writing with buffer queues | ✅ Resolved (Phase 5) |
| USB isochronous transfer changes on Apple Silicon | High | Upgraded to IOUSBInterfaceInterface; added error handling for power management | ✅ Resolved (Phase 6) |
| Missing hardware for testing | High | Acquire EasyCap devices for each chipset | Pending |
| Xcode project format incompatibility | Low | Create new project, migrate sources | ✅ Resolved (Phase 1) |
| Carbon API removal | Low | Only used for minor helpers; replace with Cocoa | ✅ Resolved (Phase 3) |

---

## Estimated Effort

| Phase | Estimated Time | Status |
|-------|---------------|--------|
| Phase 1 — Project Setup | 1–2 hours | ✅ Done |
| Phase 2 — ARC Migration | 4–8 hours | ✅ Done |
| Phase 3 — Remove 32-bit Code | 1–2 hours | ✅ Done |
| Phase 4 — OpenGL → Metal | 2–3 days | ✅ Done |
| Phase 5 — QuickTime → AVFoundation | 2–3 days | ✅ Done |
| Phase 6 — USB Drivers | 1 day (mostly testing) | ✅ Done |
| Phase 7 — Audio Pipeline | 0.5 day | ✅ Done |
| Phase 8 — UI Modernization | 1 day | Pending |
| Phase 9 — Restructuring | 1 day | Pending |
| Phase 10 — Testing | 2–3 days | Pending |
| **Remaining** | **~3.5–5.5 days** | |
