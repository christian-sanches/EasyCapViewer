# Phase 10 — Testing, Signing & Distribution

**Goal:** Comprehensive testing across Apple Silicon hardware, code signing, notarization, and distribution.

---

## 10.1 Testing Matrix

### Hardware Required

| Device | Chipset | Priority | Notes |
|--------|---------|----------|-------|
| EasyCap (Fushicai variant) | Fushicai | High | Most common, cheapest |
| EasyCap (STK1160 variant) | Syntek STK1160 | High | Common variant |
| EasyCap (EM2860 variant) | Empia EM2860 | Medium | Less common |
| EasyCap (Somagic variant) | Somagic | Low | Rarest, requires firmware |

### Mac Required

| Mac | Chip | macOS | Priority |
|-----|------|-------|----------|
| MacBook Pro / Air (M1/M2/M3/M4) | Apple Silicon | 14.x / 15.x | High |
| Mac mini / iMac (Intel) | Intel | 13.x+ | Medium (universal binary testing) |
| Any Mac | Either | 13.0 (minimum) | Medium |

---

## 10.2 Test Plan

### 10.2.1 Unit Tests (if applicable)

The current codebase has no test suite. Creating comprehensive unit tests is recommended but may be deferred. Priority tests:

| Test | What to verify |
|------|----------------|
| `ECVRational` math | Rational number arithmetic |
| `ECVFrameRateConverter` | Frame rate conversion logic |
| `ECVDeinterlacingMode` | All 7 deinterlacing modes produce correct output |
| `ECVPixelBuffer` | CVPixelBuffer creation and data copy |
| `ECVVideoFormat` | Format enumeration and menu generation |

### 10.2.2 Integration Tests (Manual)

#### Video Capture
| Test | Steps | Expected Result |
|------|-------|-----------------|
| Device discovery | Plug in EasyCap | Device appears in device list |
| Video preview | Select device, start capture | Live video displays in window |
| Resolution detection | Check video format menu | NTSC (720x480) and/or PAL (720x576) listed |
| Frame rate | Check captured frame rate | 29.97fps (NTSC) or 25fps (PAL) |
| Color accuracy | Display color bars | Colors match source |
| Deinterlacing | Test all 7 modes | Each mode produces expected visual output |
| Crop | Drag crop handles | Video crops correctly |
| Fullscreen | Enter fullscreen | Video scales correctly |
| Multiple windows | Open two captures | Both windows show video simultaneously |

#### Audio Capture
| Test | Steps | Expected Result |
|------|-------|-----------------|
| Audio output | Play captured video with audio | Audio heard through speakers |
| Audio levels | Check audio meter | Levels respond to input |
| Mono→stereo upconvert | Enable upconvert | Mono audio plays on both channels |
| Audio sync | Compare lip movement | Audio in sync with video |

#### Recording
| Test | Steps | Expected Result |
|------|-------|-----------------|
| Record start/stop | Click record, stop after 10s | .mov file created |
| Motion JPEG codec | Record with MJPEG | File plays in QuickTime Player |
| H.264 codec | Record with H.264 | File plays, hardware accelerated |
| HEVC codec | Record with HEVC | File plays, hardware accelerated |
| Audio in recording | Record with audio enabled | Audio plays in recorded file |
| Crop in recording | Set crop, record | Recorded video is cropped |
| Long recording | Record for 5+ minutes | No drops, no crashes |
| Disk space | Record until disk full | Graceful error handling |

#### USB Driver Tests (per chipset)
| Test | STK1160 | EM2860 | Somagic | Fushicai |
|------|---------|--------|---------|----------|
| Device enumeration | ☐ | ☐ | ☐ | ☐ |
| Video capture | ☐ | ☐ | ☐ | ☐ |
| Audio capture | ☐ | ☐ | ☐ | ☐ |
| Recording | ☐ | ☐ | ☐ | ☐ |

#### System Tests
| Test | Steps | Expected Result |
|------|-------|-----------------|
| App launch | Double-click app | Opens without crash |
| Sleep/wake | Capture video → sleep → wake | Video resumes after wake |
| Device disconnect | Unplug during capture | Graceful error, no crash |
| Device reconnect | Reconnect after disconnect | Device re-enumerated |
| Multiple devices | Two EasyCaps plugged in | Both listed, both work |
| Retina display | Run on Retina Mac | UI scales correctly |
| External display | Move window to external display | Video renders correctly |
| Permission prompts | First launch | USB device access works (non-sandboxed) |

---

## 10.3 Code Signing

### Development
```
Code Sign Identity: "-" (ad-hoc)
Team: Your Developer Team
```

### Distribution
```
Code Sign Identity: Developer ID Application
Team: Your Developer Team
Hardened Runtime: YES
```

### Hardened Runtime entitlements
```xml
<!-- EasyCapViewer.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
```

Note: **Do NOT enable App Sandbox** — USB device access via IOKit is incompatible with sandboxing.

---

## 10.4 Notarization (Required for Distribution)

Since macOS 10.15, apps distributed outside the App Store must be notarized:

### Steps
1. Archive the app: Product → Archive → Distribute → Developer ID
2. Or manually:
```bash
# Build release
xcodebuild -configuration Release -archivePath EasyCapViewer.xcarchive archive

# Export
xcodebuild -exportArchive EasyCapViewer.xcarchive -exportOptionsPlist ExportOptions.plist -exportPath ./build

# Zip for notarization
ditto -c -k --sequesterRsrc --keepParent EasyCapViewer.app EasyCapViewer.zip

# Submit for notarization
xcrun notarytool submit EasyCapViewer.zip --apple-id "your@email.com" --team-id "TEAMID" --wait

# Staple the notarization ticket
xcrun stapler staple EasyCapViewer.app
```

### ExportOptions.plist
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
</dict>
</plist>
```

---

## 10.5 Distribution

### Option A: Direct download (recommended for open source)
- Host `.dmg` on GitHub Releases
- Users download and drag to Applications
- Requires notarization for clean install experience

### Option B: Homebrew Cask
```ruby
cask "easycap-viewer" do
  version "1.0.0"
  sha256 "..."
  url "https://github.com/.../EasyCapViewer-#{version}.dmg"
  name "EasyCapViewer"
  desc "USB video capture viewer"
  homepage "https://github.com/..."
  app "EasyCapViewer.app"
end
```

### Option C: App Store
Not recommended — IOKit USB access is restricted in sandboxed apps.

---

## 10.6 Version Numbering

Current version: `0.6.3a` (from `EasyCapViewer-Info.plist`)

Suggested new version: `1.0.0` (major rewrite)

```
CFBundleVersion: 100 (internal build number)
CFBundleShortVersionString: "1.0.0"
```

---

## 10.7 Documentation Updates

- [ ] Update `README.md` with:
  - New installation instructions
  - Supported devices list
  - macOS version requirements (13.0+)
  - Building from source instructions
  - Known issues
- [ ] Add screenshots/GIFs of the app running
- [ ] Update license files (BSD + GPL as per original)

---

## 10.8 Final Checklist

Before release:
- [ ] All Phase 1-9 tasks completed
- [ ] Universal binary (arm64 + x86_64) builds successfully
- [ ] Tested on Apple Silicon Mac with each device chipset
- [ ] Tested on Intel Mac (at least basic capture)
- [ ] No memory leaks (Instruments → Leaks)
- [ ] No crashes during normal operation
- [ ] Recording produces valid files
- [ ] Code signed with Developer ID
- [ ] Notarized by Apple
- [ ] DMG created for distribution
- [ ] README updated
- [ ] Version number updated
- [ ] GitHub Release created (if open source)
