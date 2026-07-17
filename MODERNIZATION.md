# EasyCapViewer — Modernization Plan

**Target:** Native Apple Silicon macOS 14.0+ (Sonoma and later)  
**Language:** Objective-C with ARC, Swift/SwiftUI  
**Status:** Complete (except testing & distribution)

---

## Progress Tracker

- [x] Phase 1 — Project Setup & Build System
- [x] Phase 2 — ARC Migration (Manual → Automatic Reference Counting)
- [x] Phase 3 — Remove Dead 32-bit Code (QuickTime Component, QTKit)
- [x] Phase 4 — OpenGL → Metal (Video Rendering)
- [x] Phase 5 — QuickTime/ICM → AVFoundation (Movie Recording)
- [x] Phase 6 — USB Drivers Modernization
- [x] Phase 7 — Audio Pipeline Modernization
- [x] Phase 8 — UI & HUD Modernization
- [x] Phase 9 — Project Folder Restructuring
- [ ] Phase 10 — Testing, Signing & Distribution
- [x] Phase 11 — SwiftUI & macOS Modernization (11A-E, 11G complete; 11F, 11H, 11I deferred)
- [x] Single-Window UI Architecture (split view: settings sidebar + video + error log sidebar)

---

## Overview

EasyCapViewer is a macOS application for capturing video from USB analog capture dongles (EasyCap family). Through Phases 1–11 plus the single-window UI rewrite, the codebase has been fully modernized:

- **ARC** — All manual retain/release replaced with automatic reference counting
- **Dead 32-bit code removed** — QuickTime Component, QTKit, ECVICM all deleted
- **Metal rendering** — OpenGL replaced with MTKView + Metal shader pipeline
- **AVFoundation recording** — QuickTime/ICM replaced with AVAssetWriter
- **USB drivers modernized** — Upgraded to IOUSBInterfaceInterface with improved error handling
- **Audio pipeline modernized** — Modern ObjC patterns (properties, weak delegates, nullability)
- **UI modernized** — Nullability annotations, modern ObjC literals, OpenGL references removed
- **Project restructured** — Clean directory hierarchy with logical grouping
- **SwiftUI adopted incrementally** — Settings, welcome window, error log, menu definitions, and state restoration
- **Single-window architecture** — NSSplitViewController with settings sidebar, video center, and error log sidebar

### What works today on Apple Silicon
| API | Status | Notes |
|-----|--------|-------|
| IOKit | ✅ Still works | USB device enumeration and isochronous transfers |
| CoreAudio / AudioToolbox | ✅ Still works | Audio device I/O, streams, hardware |
| CoreVideo (CVPixelBuffer) | ✅ Still works | Pixel buffer management |
| Accelerate | ✅ Still works | vDSP/vImage for deinterlacing |
| Metal | ✅ Active | GPU rendering via MTKView |
| AVFoundation | ✅ Active | Movie recording via AVAssetWriter |
| Cocoa (AppKit / Foundation) | ✅ Still works | Document architecture, UI |
| SwiftUI | ✅ Active | Settings, error log, welcome, menus |
| Swift / Objective-C runtime | ✅ Still works | ARC, modern ObjC features |

### What was removed
| API | Replacement | Phase |
|-----|-------------|-------|
| OpenGL | Metal + MTKView | Phase 4 ✓ |
| QuickTime/ICM | AVFoundation | Phase 3 + 5 ✓ |
| QTKit | Removed entirely | Phase 3 ✓ |
| ECVICM.h | AVFoundation API | Phase 3 ✓ |
| CVDisplayLink | MTKView built-in display link | Phase 4 ✓ |
| NSAutoreleasePool | @autoreleasepool {} | Phase 2 ✓ |
| Manual retain/release | ARC | Phase 2 ✓ |
| NSDocument multi-window | Single-window NSSplitViewController | Done ✓ |

---

## File Inventory

### Device Drivers (IOKit USB) — Modernized
| File | Chipset | Notes |
|------|---------|-------|
| `ECVSTK1160Device.h/m` | Syntek STK1160 | Uses `stk11xx.h` registry helpers |
| `stk11xx.h`, `stk11xx-dev-0408.m` | STK1160 low-level | Register read/write over USB |
| `ECVEM2860Device.h/m` | Empia EM2860 | GPIO, audio bulk, video isoc |
| `ECVSomagicDevice.h/m` | Somagic | Requires firmware upload |
| `ECVSomagicDevice_Unloaded.h/m` | Somagic (unloaded variant) | Stub when firmware unavailable |
| `ECVFushicaiDevice.h/m` | Fushicai | NTSC/PAL mode switching |
| `ECVDevices.plist` | — | USB vendor/product ID database |

### Core Architecture — ARC Migrated
| File | Role | Notes |
|------|------|-------|
| `ECVController.h/m` | App controller | IOKit enumeration; USB device discovery |
| `ECVCaptureSession.h/m` | Capture session (was ECVCaptureDocument) | Plain NSObject, no NSDocument inheritance |
| `ECVCaptureDevice.h/m` | Abstract capture device | ARC migrated; USB interface upgraded |
| `ECVUSBTransferList.h/m` | Isochronous USB ring buffer | ARC migrated; USB interface upgraded |

### Video Rendering — Metal (Phase 4)
| File | Role | Notes |
|------|------|-------|
| `ECVVideoView.h/m` | MTKView subclass | Metal rendering, CVDisplayLink replaced |
| `ECVMetalRenderer.h/m` | Metal rendering engine | YUV→RGB fragment shader, frame queue |
| `ECVMetalShaders.metal` | Metal shaders | BT.601 YCbCr→RGB conversion |

### Movie Recording — AVFoundation (Phase 5)
| File | Role | Notes |
|------|------|-------|
| `ECVMovieRecorder.h/m` | AVAssetWriter-based recorder | H.264, HEVC, Motion JPEG, ProRes |

### Audio Pipeline — Modernized (Phase 7)
| File | Role | Notes |
|------|------|-------|
| `ECVAudioDevice.h/m` | CoreAudio device wrapper | Properties, weak delegate, nullability |
| `ECVAudioPipe.h/m` | Audio format conversion pipe | Class extension, nullability |
| `ECVAudioTarget.h/m` | Audio target abstraction | Weak captureDocument, literals |

### SwiftUI Layer — New (Phase 11 + Single-Window)
| File | Role | Notes |
|------|------|-------|
| `SwiftUI/AppDelegate.swift` | App lifecycle | Window ownership, quit-on-close |
| `SwiftUI/MainWindowController.swift` | Unified window | NSSplitViewController: settings + video + error log |
| `SwiftUI/ConfigViewModel.swift` | Settings model | @Observable, modern onChange |
| `SwiftUI/ConfigView.swift` | Settings panel | @Bindable, macOS 14+ onChange |
| `SwiftUI/WelcomeView.swift` | Welcome window | No-device-found message |
| `SwiftUI/ErrorLogView.swift` | Error log | Color-coded entries, auto-scroll |
| `SwiftUI/AppMenu.swift` | Menu definitions | SwiftUI menu structure |

### Deleted (Phase 11E + Single-Window)
| File | Reason |
|------|--------|
| `ECVConfigController.h/m` | Superseded by ConfigView.swift |
| `ECVHUD*.h/m` (all 4 cells) | Legacy, unused by SwiftUI config |
| `ECVDividerView.h/m` | Legacy, unused |
| `ECVTickMarkView.h/m` | Legacy, unused |
| `ECVCaptureController.h/m` | Replaced by MainWindowController.swift |
| `ECVWelcomeWindowController.h/m` | Welcome now in split view |
| `ECVErrorLogController.h/m` | Error log now in split view |
| `ECVConfigWindowController.swift` | Config now in split view sidebar |
| `ECVErrorLog.xib` | Replaced by ErrorLogView.swift |

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
11. [Phase 11 — SwiftUI & macOS Modernization](docs/modernization/11-swiftui-modernization.md)
12. [Single-Window UI Architecture](docs/modernization/phase-single-window-ui.md)

---

## Risk Assessment

| Risk | Impact | Mitigation | Status |
|------|--------|------------|--------|
| Metal rendering complexity | High | Start with simple texture blit; iterate | ✅ Resolved (Phase 4) |
| AVFoundation recording latency | Medium | Use async writing with buffer queues | ✅ Resolved (Phase 5) |
| USB isochronous transfer changes on Apple Silicon | High | Upgraded to IOUSBInterfaceInterface; error handling | ✅ Resolved (Phase 6) |
| Missing hardware for testing | High | Acquire EasyCap devices for each chipset | ⏳ Pending |
| Xcode project format incompatibility | Low | Create new project, migrate sources | ✅ Resolved (Phase 1) |
| SwiftUI incremental adoption | Low | Keep AppKit where it excels; adopt SwiftUI where it simplifies | ✅ Resolved (Phase 11) |

---

## Estimated Effort

| Phase | Status |
|-------|--------|
| Phase 1 — Project Setup | ✅ Done |
| Phase 2 — ARC Migration | ✅ Done |
| Phase 3 — Remove 32-bit Code | ✅ Done |
| Phase 4 — OpenGL → Metal | ✅ Done |
| Phase 5 — QuickTime → AVFoundation | ✅ Done |
| Phase 6 — USB Drivers | ✅ Done |
| Phase 7 — Audio Pipeline | ✅ Done |
| Phase 8 — UI Modernization | ✅ Done |
| Phase 9 — Restructuring | ✅ Done |
| Phase 10 — Testing | ⏳ Remaining |
| Phase 11 — SwiftUI & macOS | ✅ Done |
| Single-Window UI | ✅ Done |
