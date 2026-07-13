# Phase 1 — Project Setup & Build System

**Goal:** Get the project compiling with modern Xcode targeting Apple Silicon, before any API changes.

---

## 1.1 Create a Fresh Xcode Project (Recommended)

The existing `project.pbxproj` uses `objectVersion = 46` (Xcode 3-era format). Rather than trying to repair this, **create a new Xcode project** and migrate sources into it.

### Steps
1. Open Xcode → File → New → Project → macOS → App
   - Product Name: `EasyCapViewer`
   - Language: Objective-C
   - Interface: XIB
   - Bundle Identifier: match existing (`com.vcviewer.EasyCapViewer` or similar)
   - Deployment Target: **macOS 13.0** (Ventura) — covers Apple Silicon + modern APIs
2. Delete the auto-generated source files (AppDelegate, ViewController, etc.)
3. Copy all `.h` / `.m` files from the old project into the new project
4. Copy all `.xib` files, `.strings` files, `.plist` files, and resources (`.icns`, `.tiff`, `.png`)
5. Link required frameworks (see §1.3)

### Why a new project?
- Old project may have broken build settings from Xcode 3/4 era
- Old `.xib` files may need regeneration in modern Interface Builder
- Clean slate for build settings, signing, and architecture

---

## 1.2 Build Settings

| Setting | Value |
|---------|-------|
| **Deployment Target** | `13.0` (macOS Ventura) |
| **Architecture** | `arm64` (primary), `x86_64` (universal binary) |
| **Valid Architectures** | `arm64 x86_64` |
| **Objective-C ARC** | `YES` (enable in Phase 2, or now) |
| **Objective-C Garbage Collection** | `Unsupported` |
| **C Language Standard** | `gnu11` |
| **Objective-C Language Standard** | `Objective-C20` (or latest) |
| **SDK** | Latest available (macOS 15 SDK or whatever ships with Xcode) |
| **Enable Hardened Runtime** | `YES` (required for notarization) |
| **Sandboxing** | `NO` (USB device access requires raw IOKit, incompatible with sandbox) |
| **Code Signing** | Ad-hoc for development; Developer ID for distribution |
| **Generate Info.plist** | Off (use custom `EasyCapViewer-Info.plist`) |

---

## 1.3 Frameworks to Link

### Keep (still available on Apple Silicon)
| Framework | Purpose | Status |
|-----------|---------|--------|
| `Cocoa.framework` | AppKit + Foundation | ✅ Keep |
| `IOKit.framework` | USB device access | ✅ Keep |
| `CoreVideo.framework` | CVPixelBuffer, pixel buffers | ✅ Keep |
| `CoreAudio.framework` | Audio device enumeration | ✅ Keep |
| `AudioToolbox.framework` | Audio format conversion | ✅ Keep |
| `QuartzCore.framework` | Core Animation layers | ✅ Keep |
| `Accelerate.framework` | vDSP for deinterlacing | ✅ Keep |
| `Metal.framework` | GPU rendering | 🆕 Add |
| `MetalKit.framework` | MTKView | 🆕 Add |

### Remove
| Framework | Reason |
|-----------|--------|
| `OpenGL.framework` | Deprecated, removed from SDK |
| `QTKit.framework` | Removed from SDK |
| `QuickTime.framework` | Removed from SDK |
| `Carbon.framework` | Mostly deprecated; audit usage and remove |
| `CoreMedia.framework` | Only needed if using AVFoundation (re-add in Phase 5) |
| `AVFoundation.framework` | Re-add in Phase 5 when needed |
| `AVKit.framework` | Re-add in Phase 5 when needed |

---

## 1.4 Info.plist Updates

Update `EasyCapViewer-Info.plist`:

```xml
<!-- Remove or update these keys -->

<!-- OLD: 10.5.8 -->
<key>LSMinimumSystemVersion</key>
<string>13.0</string>

<!-- Remove: CFBundleSignature (obsolete) -->
<!-- REMOVE: CFBundleSignature -->
<!-- REMOVE: <string>????</string> -->

<!-- Keep everything else -->
```

### New keys to add:
```xml
<key>LSApplicationArchitectures</key>
<array>
    <string>arm64</string>
    <string>x86_64</string>
</array>

<key>NSHighResolutionCapable</key>
<true/>
```

---

## 1.5 Prefix Header

Update `EasyCapViewer_Prefix.pch`:

```objc
#ifdef __OBJC__
    #import <Cocoa/Cocoa.h>
    #import <IOKit/IOKitLib.h>
    #import <CoreVideo/CoreVideo.h>
#endif
```

Remove any references to deprecated headers.

---

## 1.6 Remove ECVComponent Target

Delete the entire QuickTime component target from the project:
- Remove target `ECVComponent` from Xcode
- Remove files: `ECVComponent.m`, `ECVComponent.r`, `ECVComponentDispatch.h`, `ECVComponent-Info.plist`
- These are 32-bit QuickTime component artifacts with no modern equivalent

---

## 1.7 Verification

After Phase 1, the project should:
- [ ] Open in latest Xcode without errors
- [ ] Have correct deployment target (13.0+)
- [ ] Link only modern frameworks
- [ ] Have the ECVComponent target removed
- [ ] Build will fail (expected — API changes come in later phases), but project structure should be valid
