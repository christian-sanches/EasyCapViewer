# Phase 9 — Project Folder Restructuring

**Goal:** Reorganize the project into a clean, modern directory structure with logical grouping, clear naming, and separation of concerns.

---

## 9.1 Current Structure (Flat)

The current project has all `.h` and `.m` files in the root directory, grouped only in the Xcode project navigator:

```
EasyCapViewer/
├── ECV*.h / ECV*.m (50+ files in root)
├── ECVCapture.xib
├── ECVConfig.xib
├── ECVErrorLog.xib
├── ECVMenu.xib
├── EasyCapViewer.icns
├── EasyCapViewer.xcodeproj/
├── EasyCapViewer-Info.plist
├── ECVDevices.plist
├── en.lproj/
└── misc (cursor images, prefix header, etc.)
```

---

## 9.2 Proposed New Structure

```
EasyCapViewer/
├── EasyCapViewer.xcodeproj/
├── EasyCapViewer/
│   ├── App/
│   │   ├── main.m                           (was EasyCapViewer.m)
│   │   ├── EasyCapViewer-Prefix.pch         (was EasyCapViewer_Prefix.pch)
│   │   ├── EasyCapViewer-Info.plist
│   │   └── ECVDevices.plist
│   │
│   ├── Controllers/
│   │   ├── ECVController.h/m                (NSDocumentController)
│   │   ├── ECVCaptureController.h/m         (capture window controller)
│   │   ├── ECVConfigController.h/m          (settings window controller)
│   │   └── ECVErrorLogController.h/m        (error log window controller)
│   │
│   ├── Models/
│   │   ├── Capture/
│   │   │   ├── ECVCaptureDocument.h/m       (NSDocument subclass)
│   │   │   ├── ECVCaptureDevice.h/m         (abstract capture device)
│   │   │   ├── ECVVideoSource.h/m           (video source)
│   │   │   ├── ECVVideoFormat.h/m           (video format)
│   │   │   ├── ECVPixelFormat.h             (pixel format constants)
│   │   │   └── ECVDeinterlacingMode.h/m     (deinterlacing modes)
│   │   │
│   │   ├── Video/
│   │   │   ├── ECVVideoFrame.h/m            (single video frame)
│   │   │   ├── ECVVideoStorage.h/m          (video frame storage base)
│   │   │   ├── ECVIndependentVideoStorage.h/m
│   │   │   ├── ECVDependentVideoStorage.h/m
│   │   │   ├── ECVPixelBuffer.h/m           (CVPixelBuffer wrapper)
│   │   │   └── ECVFrameRateConverter.h/m    (frame rate conversion)
│   │   │
│   │   ├── Audio/
│   │   │   ├── ECVAudioDevice.h/m           (CoreAudio device)
│   │   │   ├── ECVAudioPipe.h/m             (audio format pipe)
│   │   │   ├── ECVAudioTarget.h/m           (audio output target)
│   │   │   └── ECVAVTarget.h                (AV target protocol)
│   │   │
│   │   ├── Recording/
│   │   │   └── ECVMovieRecorder.h/m         (AVFoundation recorder)
│   │   │
│   │   └── Math/
│   │       └── ECVRational.h/m              (rational numbers)
│   │
│   ├── Drivers/
│   │   ├── STK1160/
│   │   │   ├── ECVSTK1160Device.h/m
│   │   │   ├── stk11xx.h
│   │   │   └── stk11xx-dev-0408.m
│   │   ├── EM2860/
│   │   │   └── ECVEM2860Device.h/m
│   │   ├── Somagic/
│   │   │   ├── ECVSomagicDevice.h/m
│   │   │   └── ECVSomagicDevice_Unloaded.h/m
│   │   ├── Fushicai/
│   │   │   └── ECVFushicaiDevice.h/m
│   │   └── ECVUSBTransferList.h/m          (shared USB transfer helper)
│   │
│   ├── Rendering/
│   │   ├── ECVVideoView.h/m                 (MTKView subclass)
│   │   ├── ECVMetalRenderer.h/m             (Metal rendering engine)
│   │   └── Shaders/
│   │       └── ECVMetalShaders.metal        (Metal shader file)
│   │
│   ├── Views/
│   │   ├── ECVCropCell.h/m                  (crop overlay - AppKit)
│   │   ├── ECVPlayButtonCell.h/m            (play button - AppKit)
│   │   ├── MPLWindow.h/m                    (custom NSWindow)
│   │   └── HUD/
│   │       ├── ECVHUDButtonCell.h/m
│   │       ├── ECVHUDSliderCell.h/m
│   │       ├── ECVHUDPopUpButtonCell.h/m
│   │       ├── ECVHUDSwitchButtonCell.h/m
│   │       ├── ECVTickMarkView.h/m
│   │       └── ECVDividerView.h/m
│   │
│   ├── Utilities/
│   │   ├── ECVDebug.h/m                     (logging)
│   │   ├── ECVLocalizing.h/m                (localization)
│   │   ├── ECVFoundationAdditions.h/m       (Foundation categories)
│   │   ├── ECVReadWriteLock.h/m             (thread safety)
│   │   ├── ECVAppKitAdditions.h/m           (AppKit categories)
│   │   └── ECVRectEdgeMask.h/m              (edge mask constants)
│   │
│   └── Resources/
│       ├── ECVCapture.xib
│       ├── ECVConfig.xib
│       ├── ECVErrorLog.xib
│       ├── ECVMenu.xib
│       ├── EasyCapViewer.icns
│       ├── Cursor-Resize-45.tiff
│       ├── Cursor-Resize-135.tiff
│       ├── Log-Clear.png
│       └── en.lproj/
│           ├── Credits.rtf
│           ├── ECVCapture.strings
│           ├── ECVConfig.strings
│           ├── ECVErrorLog.strings
│           ├── ECVMenu.strings
│           ├── InfoPlist.strings
│           └── Localizable.strings
│
└── docs/
    └── modernization/
        ├── 01-project-setup.md
        ├── 02-arc-migration.md
        ├── ...
        └── 10-testing-distribution.md
```

---

## 9.3 Files to Delete (Already Removed in Phase 3)

These files should not exist in the new structure:
- `ECVComponent.h/m/r`
- `ECVComponentDispatch.h`
- `ECVComponent-Info.plist`
- `ECVQTKitAdditions.h/m`
- `ECVICM.h`
- `ECVOpenGLAdditions.h/m` (removed in Phase 4)

---

## 9.4 Rename Convention

The current naming is consistent (`ECV` prefix). Keep this convention. Consider these renames for clarity:

| Current | Proposed | Reason |
|---------|----------|--------|
| `EasyCapViewer.m` | `main.m` | Standard entry point name |
| `ECVAppKitAdditions.h/m` | Split or remove | `ECVLockContext` is OpenGL-specific (delete), other additions keep |
| `ECVFoundationAdditions.h` | Keep as-is | Utility category |
| `stk11xx-dev-0408.m` | `ECVSTK1160Registry.m` | More descriptive, follows ECV convention |

---

## 9.5 Migration Steps

### 9.5.1 Create new directory structure
```bash
mkdir -p EasyCapViewer/{App,Controllers,Models/{Capture,Video,Audio,Recording,Math},Drivers/{STK1160,EM2860,Somagic,Fushicai},Rendering/Shaders,Views/HUD,Utilities,Resources/en.lproj}
```

### 9.5.2 Move files (git mv to preserve history)
```bash
# App
git mv EasyCapViewer.m EasyCapViewer/App/main.m
git mv EasyCapViewer_Prefix.pch EasyCapViewer/App/EasyCapViewer-Prefix.pch
git mv EasyCapViewer-Info.plist EasyCapViewer/App/EasyCapViewer-Info.plist
git mv ECVDevices.plist EasyCapViewer/App/ECVDevices.plist

# Controllers
git mv ECVController.h ECVController.m EasyCapViewer/Controllers/
# ... etc for all controller files

# Continue for each category...
```

**Important:** Use `git mv` to preserve file history in git.

### 9.5.3 Update Xcode project
After moving files, Xcode project will break. Update by:
1. Remove old file references from Xcode
2. Add files from new locations
3. Update group structure in Xcode to match filesystem
4. Update any path-dependent build settings

### 9.5.4 Update imports
If any files use path-dependent imports (unlikely with Xcode), update them. Most Objective-C imports use framework-style imports (`#import "ECVVideoView.h"`) which Xcode resolves via header search paths, so this should be mostly automatic.

### 9.5.5 Update header search paths
Ensure Xcode's "Header Search Paths" includes the new directory structure:
```
$(SRCROOT)/EasyCapViewer/**          (recursive)
```

---

## 9.6 Group Structure in Xcode

Match the Xcode project navigator to the filesystem:

```
EasyCapViewer (project)
├── App
├── Controllers
├── Models
│   ├── Capture
│   ├── Video
│   ├── Audio
│   ├── Recording
│   └── Math
├── Drivers
│   ├── STK1160
│   ├── EM2860
│   ├── Somagic
│   └── Fushicai
├── Rendering
│   └── Shaders
├── Views
│   └── HUD
├── Utilities
└── Resources
    └── en.lproj
```

---

## 9.7 Verification

After Phase 9, the project should:
- [x] All source files in logical subdirectories
- [x] No source files in the project root (only `EasyCapViewer.xcodeproj/`, `docs/`, `README.md`)
- [x] Xcode project navigator matches filesystem structure
- [x] All imports resolve correctly
- [x] Project builds successfully from new structure
- [x] Git history preserved (use `git mv`)
- [x] Dead files (ECVComponent, QTKit, OpenGL additions) are gone
