# Phase 11 — SwiftUI & macOS Modernization

**Target:** Incremental SwiftUI adoption + Mac-assed modernization
**Strategy:** Adopt SwiftUI where it simplifies; keep AppKit where it excels
**Estimated Effort:** 6-9 days
**Prerequisites:** Phases 1-10 complete (ARC, Metal, AVFoundation, restructured project)

---

## Guiding Principles

This phase follows Apple's own guidance from WWDC26:

> *"There are no expectations that an app needs to be entirely SwiftUI in order to take advantage of it."*
> — "Use SwiftUI with AppKit and UIKit" (WWDC26 session 272)

The strategy is **incremental adoption**, not a rewrite. We adopt SwiftUI for
windows and views where it provides clear benefits (declarative UI, automatic
state sync, less code), and keep AppKit for components that require precise
control (Metal rendering, custom cell drawing, complex window management).

### Key Research Sources

- **Paulo Andrade**, "Using SwiftUI to Build a Mac-assed App in 2026" — documents
  SwiftUI's current shortcomings on macOS: selection states, drag & drop, keyboard
  shortcuts, toolbar precision. TL;DR: "we're not there yet" for full SwiftUI.
- **Paulo Andrade**, "A WWDC 26 Update" — Apple responded with `\.backgroundProminence`,
  `.onDragSessionUpdated`, `.reorderable`. Core limitations remain.
- **WWDC26 session 272**, "Use SwiftUI with AppKit and UIKit" — `@Observable` for
  auto-updating NSViews, `NSGestureRecognizerRepresentable`, `NSHostingMenu`,
  `NSHostingSceneRepresentation`. The official incremental adoption playbook.
- **WWDC26 session 289**, "Modernize your AppKit app" — replace `mouseDown:` with
  gesture recognizers, control events, `autorecalculatesKeyViewLoop`, state
  restoration, Liquid Glass concentricity.
- **WWDC26 session 269**, "What's new in SwiftUI" — new `Document` protocol,
  `ContentBuilder`, `@State` macro (lazy init).
- **Wallnetic case study** — "SwiftUI as the default, AppKit for surfaces SwiftUI
  cannot reach."

---

## Current State Assessment

| Component | Current | SwiftUI-Ready? | Notes |
|-----------|---------|----------------|-------|
| Video rendering | Metal (MTKView) | **No** | Highly interactive, keyboard/cell system |
| Movie recording | AVFoundation | **No** | Backend, no UI |
| USB drivers | Modernized ObjC | **No** | IOKit, no UI |
| Audio pipeline | Modernized ObjC | **No** | Backend |
| Settings panel | SwiftUI (NSHostingView) | **Done** (needs modernization) | Uses deprecated APIs |
| Welcome window | Programmatic AppKit | **Yes** | Pure informational text |
| Error log | XIB-based AppKit | **Yes** | Text view + toolbar |
| Main menu | XIB (ECVMenu.xib) | **Yes** | Via NSHostingMenu |
| Capture window | XIB + heavy AppKit | **Partially** | Keep as AppKit (complex) |
| Crop cell | AppKit NSCell | **No** | Custom mouse tracking |
| Play button cell | AppKit NSButtonCell | **No** | Overlay drawing |
| HUD cells | AppKit (legacy) | **No** | Dead code, delete |
| ObjC model layer | ObjC classes | **Yes** | Adopt @Observable |

### What Stays as AppKit (and Why)

| Component | Reason |
|-----------|--------|
| `ECVVideoView` (MTKView) | Metal rendering, keyboard delegation, cell overlay system |
| `ECVCropCell` / `ECVPlayButtonCell` | Custom cell drawing with mouse tracking |
| `ECVCaptureController` | Complex window management, fullscreen, recording lifecycle |
| `MPLWindow` | Custom cursor auto-hide, fullscreen window management |
| NSSavePanel accessory | Export UI is AppKit-native |
| USB device management | IOKit callbacks, not UI |

---

## Phase 11A — Modernize Existing SwiftUI Code

**Effort:** ~1 day
**Risk:** Low
**Value:** High — modernizes the foundation for all future SwiftUI work

### Goals

1. Migrate from `ObservableObject` / `@Published` to `@Observable` macro
2. Replace deprecated `onChange(of:perform:)` with the new signature
3. Remove Combine dependency where possible
4. Clean up the NSHostingView bridge in ConfigWindowController

### Detailed Steps

#### 1. Convert ConfigViewModel to @Observable

**Before** (`ConfigViewModel.swift`):
```swift
import Combine

final class ConfigViewModel: ObservableObject {
    @Published var selectedSourceIndex: Int = 0
    @Published var sources: [ECVVideoSource] = []
    // ... all @Published properties
}
```

**After**:
```swift
import Observation

@Observable
final class ConfigViewModel {
    var selectedSourceIndex: Int = 0
    var sources: [ECVVideoSource] = []
    // ... all properties become plain var
    // @Observable auto-tracks reads in SwiftUI view bodies
}
```

**Key changes:**
- Add `import Observation` (replaces `import Combine` for view layer)
- Remove `: ObservableObject` conformance
- Remove all `@Published` wrappers
- Keep `Set<AnyCancellable>` for NotificationCenter subscriptions
  (Observation doesn't replace Combine for notification handling)
- The `autoPlay` `didSet` still works — it's a plain property observer

#### 2. Update ConfigView for @Observable

**Before**:
```swift
struct ConfigView: View {
    @ObservedObject var viewModel: ConfigViewModel
```

**After**:
```swift
struct ConfigView: View {
    var viewModel: ConfigViewModel
    // @Observable objects don't need @ObservedObject;
    // SwiftUI auto-tracks property access in body
```

For bindings to the view model, use `@Bindable`:
```swift
@Bindable var viewModel: ConfigViewModel
```

#### 3. Replace Deprecated onChange

**Before** (deprecated in macOS 14):
```swift
.onChange(of: viewModel.selectedFormatIndex) { _ in viewModel.changeFormat() }
```

**After** (macOS 14+):
```swift
.onChange(of: viewModel.selectedFormatIndex) { oldValue, newValue in
    viewModel.changeFormat()
}
```

Apply to all 10 `onChange` call sites in `ConfigView.swift`.

#### 4. Clean Up ConfigWindowController

- Remove `import Combine` if no longer needed
- Consider converting `ECVSwiftConfigController` from `NSWindowController` subclass
  to a pure SwiftUI approach using `NSHostingSceneRepresentation` (see Phase 11D
  for the menu integration pattern)

### Files Modified

- `EasyCapViewer/SwiftUI/ConfigViewModel.swift`
- `EasyCapViewer/SwiftUI/ConfigView.swift`
- `EasyCapViewer/SwiftUI/ConfigWindowController.swift`

---

## Phase 11B — Welcome Window → SwiftUI

**Effort:** ~0.5 day
**Risk:** Low
**Value:** Medium — removes 100+ lines of programmatic AppKit for a simple view

### Goals

Replace `ECVWelcomeWindowController` (102 lines of manual AppKit) with a
SwiftUI view hosted in a minimal window controller.

### Design

The welcome window is purely informational — two text labels, no interaction
beyond closing. This is the ideal SwiftUI port.

#### New SwiftUI View

```swift
// EasyCapViewer/SwiftUI/WelcomeView.swift

import SwiftUI

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("No capture device found")
                .font(.system(size: 16, weight: .bold))
            Text("Connect an EasyCap DC60 to your computer to begin.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(width: 420, height: 200)
    }
}
```

#### Updated Window Controller

Either:
- **Option A**: Keep `ECVWelcomeWindowController` as a thin `NSWindowController`
  subclass that hosts `WelcomeView` via `NSHostingView` (minimal change)
- **Option B**: Replace entirely with a SwiftUI `WindowGroup` scene and
  `NSHostingSceneRepresentation` (more modern, but requires app delegate changes)

**Recommended**: Option A for now, Option B in Phase 11D when we restructure
the app lifecycle.

### Files Modified

- `EasyCapViewer/SwiftUI/WelcomeView.swift` (new)
- `EasyCapViewer/Controllers/ECVWelcomeWindowController.m` (simplified or replaced)

### Files Deleted

- None yet (keep the controller for now, just replace its `loadWindow`)

---

## Phase 11C — Error Log → SwiftUI

**Effort:** ~1 day
**Risk:** Low
**Value:** Medium — removes XIB, removes attributed string complexity

### Goals

Replace `ECVErrorLogController` (146 lines + `ECVErrorLog.xib`) with SwiftUI.

### Design

The error log has three components:
1. A scrollable text view showing log entries
2. Color coding by error level (notice/warning/error/critical)
3. A toolbar with "Clear Log" button

#### New SwiftUI View

```swift
// EasyCapViewer/SwiftUI/ErrorLogView.swift

import SwiftUI

@Observable
final class ErrorLogModel {
    struct Entry: Identifiable {
        let id = UUID()
        let level: ECVErrorLevel
        let message: String
        let date: Date
    }

    private(set) var entries: [Entry] = []

    var hasContent: Bool { !entries.isEmpty }

    func append(level: ECVErrorLevel, message: String) {
        entries.append(Entry(level: level, message: message, date: Date()))
    }

    func clear() {
        entries.removeAll()
    }
}

struct ErrorLogView: View {
    var model: ErrorLogModel

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(model.entries) { entry in
                        Text(entryText(entry))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(colorForLevel(entry.level))
                            .id(entry.id)
                    }
                }
                .padding(8)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Clear Log") { model.clear() }
                    .disabled(!model.hasContent)
            }
        }
    }

    private func entryText(_ entry: Entry) -> AttributedString {
        // Format: "date: message"
        // Or use Text with concatenation for simpler approach
    }

    private func colorForLevel(_ level: ECVErrorLevel) -> Color {
        switch level {
        case ECVNotice:     return .primary
        case ECVWarning:    return .orange
        case ECVError:      return .red
        case ECVCritical:   return .red
        default:            return .primary
        }
    }
}
```

#### Integration

- Create `ECVErrorLogModel` as the `@Observable` bridge between `ECVDebug.h`
  logging macros and the SwiftUI view
- Host via `NSHostingView` in a window controller, or as a floating panel
- The existing `ECVLog()` C function calls `ECVErrorLogController.logLevel:message:`,
  which will now append to the `ErrorLogModel`

### Files Modified

- `EasyCapViewer/Controllers/ECVErrorLogController.m` (simplified to bridge)
- `EasyCapViewer/Utilities/ECVDebug.h` (may need model reference)

### Files Created

- `EasyCapViewer/SwiftUI/ErrorLogView.swift`

### Files Deleted

- `EasyCapViewer/Resources/ECVErrorLog.xib`

---

## Phase 11D — Main Menu → SwiftUI

**Effort:** ~1-2 days
**Risk:** Medium
**Value:** High — enables state-driven menus, reduces XIB dependency

### Goals

Migrate the menu bar from `ECVMenu.xib` to SwiftUI using `NSHostingMenu`
(as demonstrated in WWDC26 session 272).

### Design

Per the WWDC26 session: build the menu as a SwiftUI `View` with `Button`
actions and keyboard shortcuts, then add it to the AppKit main menu via
`NSMenuItem` + `NSHostingMenu`.

#### SwiftUI Menu Definition

```swift
// EasyCapViewer/SwiftUI/AppMenu.swift

import SwiftUI

struct AppMenu: View {
    @Environment(\.openSettings) var openSettings

    var body: some View {
        // This view is converted to an NSMenu via NSHostingMenu
        Button("About EasyCapViewer") { ... }
        Divider()
        Button("Configure Device...") { ... }
            .keyboardShortcut(",", modifiers: .command)
        // ... etc
    }
}
```

#### Integration with ECVController

```objc
// In ECVController.m or App delegate
- (void)buildMainMenu {
    NSMenu *mainMenu = [[NSMenu alloc] init];

    NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
    NSMenu *appMenu = [[NSHostingMenu alloc] initWith rootView:
        [[AppMenu alloc] init]];
    [appMenuItem setSubmenu:appMenu];
    [mainMenu addItem:appMenuItem];

    // ... repeat for each top-level menu
    [NSApp setMainMenu:mainMenu];
}
```

### Important Considerations

- The menu has many items connected to First Responder (capture controls).
  These must remain as `@IBAction` targets on `ECVCaptureController`, reachable
  via the responder chain.
- Some menu items are state-dependent (e.g., "Start Recording" disabled when
  already recording). SwiftUI buttons with `@Observable` model state can
  handle this automatically.
- **Keep `NSMainNibFile`** initially for backward compatibility, or switch to
  programmatic setup in the app delegate's `applicationWillFinishLaunching:`.

### Files Created

- `EasyCapViewer/SwiftUI/AppMenu.swift`

### Files Modified

- `EasyCapViewer/Controllers/ECVController.m` (menu setup)

### Files Deleted

- `EasyCapViewer/Resources/ECVMenu.xib` (once migration is confirmed working)

---

## Phase 11E — Delete Dead Code

**Effort:** ~0.5 day
**Risk:** Low
**Value:** High — removes confusion, reduces codebase size

### Files to Delete

| File | Reason |
|------|--------|
| `EasyCapViewer/Controllers/ECVConfigController.h` | Superseded by `ECVSwiftConfigController` |
| `EasyCapViewer/Controllers/ECVConfigController.m` | Superseded by `ECVSwiftConfigController` |
| `EasyCapViewer/Resources/ECVConfig.xib` | Superseded by `ConfigView.swift` |
| `EasyCapViewer/Views/HUD/ECVHUDButtonCell.h` | Legacy, unused by SwiftUI config |
| `EasyCapViewer/Views/HUD/ECVHUDButtonCell.m` | Legacy, unused by SwiftUI config |
| `EasyCapViewer/Views/HUD/ECVHUDSliderCell.h` | Legacy, unused by SwiftUI config |
| `EasyCapViewer/Views/HUD/ECVHUDSliderCell.m` | Legacy, unused by SwiftUI config |
| `EasyCapViewer/Views/HUD/ECVHUDPopUpButtonCell.h` | Legacy, unused by SwiftUI config |
| `EasyCapViewer/Views/HUD/ECVHUDPopUpButtonCell.m` | Legacy, unused by SwiftUI config |
| `EasyCapViewer/Views/HUD/ECVHUDSwitchButtonCell.h` | Legacy, unused by SwiftUI config |
| `EasyCapViewer/Views/HUD/ECVHUDSwitchButtonCell.m` | Legacy, unused by SwiftUI config |
| `EasyCapViewer/Views/HUD/ECVDividerView.h` | Legacy, unused by SwiftUI config |
| `EasyCapViewer/Views/HUD/ECVDividerView.m` | Legacy, unused by SwiftUI config |
| `EasyCapViewer/Views/HUD/ECVTickMarkView.h` | Legacy, unused by SwiftUI config |
| `EasyCapViewer/Views/HUD/ECVTickMarkView.m` | Legacy, unused by SwiftUI config |

### Cleanup After Deletion

- Remove HUD file references from `project.pbxproj`
- Remove HUD group from project
- Check if `ECVAppKitAdditions` gradient helpers are still used
  (`ECV_fillWithGradientFromColor:`, `ECV_fillWithHUDButtonGradientWithHighlight:`)
  — if only used by HUD cells, delete those category methods too
- Remove any `#import` references to deleted files

### Pre-Deletion Verification

Before deleting, verify no other file imports or references these:
```bash
grep -r "ECVHUD\|ECVDividerView\|ECVTickMarkView\|ECVConfigController" \
    EasyCapViewer/ --include="*.h" --include="*.m" --include="*.swift"
```

---

## Phase 11F — Gesture Recognizer Modernization

**Effort:** ~1-2 days
**Risk:** Medium (interactive component)
**Value:** Medium — aligns with Apple's explicit guidance

### Context

WWDC26 session 289 is explicit:

> *"mouseDown: overrides and tracking loops must be replaced with modern APIs.
> Gesture recognizers are the modern way to handle mouse events in AppKit."*

`ECVCropCell` currently implements `trackMouse:inRect:ofView:untilMouseUp:`
with manual tracking loops for drag-to-crop interaction.

### Approach

1. Create a custom `NSGestureRecognizer` subclass for crop interaction
2. Handle the recognizer's state transitions (began, changed, ended)
3. Use the gesture recognizer's location and delta for crop rect updates
4. Set appropriate cursors via `NSCursor` push/pop

**Important**: The crop cell also needs hit-testing for 8 resize handles
(corners + edge midpoints). This maps well to `NSGestureRecognizer`'s
`location(in:)` for position-based behavior.

### Alternative: Keep As-Is (Deferred)

Given that `ECVCropCell` is a complex interactive component with specific
requirements (cursor rects, handle hit-testing, delegate callbacks), and the
gesture recognizer migration carries risk of breaking crop behavior, this
phase could be **deferred** until the other phases are stable.

**Recommendation**: Defer to a later iteration unless there are specific
bugs or deprecation warnings driving this change.

---

## Phase 11G — Keyboard Navigation & State Restoration

**Effort:** ~1 day
**Risk:** Low
**Value:** High — Mac-assed feel, "seamless quit and relaunch"

### Keyboard Navigation

Per WWDC26 session 289:

1. **Enable `autorecalculatesKeyViewLoop`** on all windows:
   ```objc
   // In ECVCaptureController's windowDidLoad:
   [window setAutorecalculatesKeyViewLoop:YES];
   ```
   This automatically maintains the Tab key navigation order as views change.

2. **Verify keyboard shortcuts** in the menu match macOS conventions:
   - Cmd+S for recording, Cmd+Q for quit, Cmd+W for close — already present
   - Cmd+, for preferences — already present
   - Check all shortcuts against macOS HIG

### State Restoration

Per WWDC26 session 289, implement `NSWindowRestoration`:

1. **Set window identifiers** on `ECVCaptureController`:
   ```objc
   // In windowDidLoad:
   [window setIdentifier:@"ECVCaptureWindow"];
   ```

2. **Set autosave names** for persistent window frame:
   ```objc
   [window setFrameAutosaveName:@"ECVCaptureWindowFrame"];
   ```

3. **Implement restoration delegate** in `ECVController`:
   ```objc
   - (void)restoreWindowWithIdentifier:(NSString *)identifier
                                 state:(NSCoder *)state
                     completionHandler:(void (^)(NSWindow *, NSError *))handler {
       // Recreate the appropriate window controller
       // Call handler(window, nil) on success
   }
   ```

4. **Opt into state restoration** on the document:
   ```objc
   // In ECVCaptureDocument:
   - (BOOL)hasUnautosavedChanges { return NO; } // or track recording state
   ```

---

## Phase 11H — Liquid Glass & Concentricity (macOS 26+)

**Effort:** ~0.5 day
**Risk:** Low
**Value:** Low — cosmetic polish, conditional on macOS 26 target

### Context

WWDC26 session 289 introduced new `cornerConfiguration` API for concentricity.
macOS 26 introduced Liquid Glass material.

### Steps

1. **Evaluate minimum deployment target**: If targeting macOS 26+, adopt
   Liquid Glass for translucent panels (settings, error log). Otherwise, skip.

2. **Adopt `cornerConfiguration`** on buttons and views where rounded
   rectangles meet the window edge. This makes the UI blend with macOS 26's
   system aesthetic.

3. **Apply `NSScrollEdgeEffectStyle`** to scroll views for the hard-edge
   effect that Apple recommends for free-floating content.

### Recommendation

**Defer** until the macOS 26 deployment target is confirmed. This is purely
cosmetic and can be added at any time without architectural changes.

---

## Phase 11I — App Icon & Distribution Polish

**Effort:** ~0.5 day
**Risk:** Low
**Value:** Medium — professional appearance

### Steps

1. **Add `@2x` icon** to `EasyCapViewer.icns` for Retina displays
2. **Consider asset catalog**: Create `AppIcon.appiconset` with proper size
   variants (16x16, 32x32, 128x128, 256x256, 512x512, @2x variants)
3. **Remove quarantine badge** for development builds:
   ```bash
   xattr -cr ~/Desktop/EasyCapViewer/EasyCapViewer.app
   ```
4. **Prepare notarization** if distributing outside the Mac App Store

---

## Implementation Order

| Order | Phase | Effort | Risk | Value |
|-------|-------|--------|------|-------|
| 1 | **11A** — Modernize SwiftUI | 1 day | Low | High |
| 2 | **11E** — Delete dead code | 0.5 day | Low | High |
| 3 | **11B** — Welcome → SwiftUI | 0.5 day | Low | Medium |
| 4 | **11C** — Error log → SwiftUI | 1 day | Low | Medium |
| 5 | **11D** — Menu → SwiftUI | 1-2 days | Medium | High |
| 6 | **11G** — Keyboard + restoration | 1 day | Low | High |
| 7 | **11I** — Icon + distribution | 0.5 day | Low | Medium |
| 8 | **11F** — Gesture modernization | 1-2 days | Medium | Medium |
| 9 | **11H** — Liquid Glass | 0.5 day | Low | Low |

**Total: ~6-9 days**

### Milestones

- **After 11A + 11E**: Foundation is modern, dead code removed
- **After 11B + 11C**: Welcome and error log are SwiftUI, XIBs reduced
- **After 11D**: Main menu is SwiftUI, only ECVCapture.xib remains
- **After 11G**: App feels "Mac-assed" with keyboard nav + state restoration
- **After 11F + 11H + 11I**: Polish complete

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| `@Observable` back-deployment | Medium | Requires macOS 14+ target (already set) |
| NSHostingMenu menu interop | Medium | Test thoroughly; keep XIB as fallback |
| State restoration complexity | Low | Start with window frame autosave only |
| Gesture recognizer migration | Medium | Defer if crop behavior is stable |
| Liquid Glass API changes | Low | Defer until macOS 26 target confirmed |
| Removing HUD cells breaks something | Low | Grep for all references before deletion |

---

## Files Summary

### New Files

- `EasyCapViewer/SwiftUI/WelcomeView.swift`
- `EasyCapViewer/SwiftUI/ErrorLogView.swift`
- `EasyCapViewer/SwiftUI/AppMenu.swift`

### Modified Files

- `EasyCapViewer/SwiftUI/ConfigViewModel.swift` (ObservableObject → @Observable)
- `EasyCapViewer/SwiftUI/ConfigView.swift` (@ObservedObject → @Bindable, onChange)
- `EasyCapViewer/SwiftUI/ConfigWindowController.swift` (cleanup)
- `EasyCapViewer/Controllers/ECVController.m` (menu setup, state restoration)
- `EasyCapViewer/Controllers/ECVCaptureController.m` (key view loop, restoration)
- `EasyCapViewer/Controllers/ECVWelcomeWindowController.m` (SwiftUI host)
- `EasyCapViewer/Controllers/ECVErrorLogController.m` (SwiftUI bridge)
- `EasyCapViewer/Utilities/ECVDebug.h` (model reference)
- `EasyCapViewer.xcodeproj/project.pbxproj` (add/remove files)

### Deleted Files

- `EasyCapViewer/Controllers/ECVConfigController.h`
- `EasyCapViewer/Controllers/ECVConfigController.m`
- `EasyCapViewer/Resources/ECVConfig.xib`
- `EasyCapViewer/Resources/ECVMenu.xib` (after Phase 11D)
- `EasyCapViewer/Resources/ECVErrorLog.xib` (after Phase 11C)
- `EasyCapViewer/Views/HUD/ECVHUD*.h` (all 4 headers)
- `EasyCapViewer/Views/HUD/ECVHUD*.m` (all 4 implementations)
- `EasyCapViewer/Views/HUD/ECVDividerView.h/.m`
- `EasyCapViewer/Views/HUD/ECVTickMarkView.h/.m`
