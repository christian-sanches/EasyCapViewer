# Phase: Single-Window UI Architecture

> **Status: ✅ Complete** — Implemented on `modernization-mvp` branch. Old controllers (ECVCaptureController, ECVConfigController, ECVErrorLogController, ECVWelcomeWindowController) deleted. Replaced by `MainWindowController.swift` with `NSSplitViewController`.

## Goal

Replace the multi-window architecture (separate welcome, config, error log, and capture windows) with a single unified window containing an `NSSplitViewController` with three panes:
- **Left sidebar**: Settings (ConfigView)
- **Center**: Video view (ECVVideoView) or Welcome screen
- **Right sidebar**: Error logs (ErrorLogView)

All new UI code is written in Swift.

## Architecture Changes

### Before
- `NSDocument`-based: `ECVCaptureDocument` → `ECVCaptureController` → `ECVCapture.xib`
- Separate singleton windows for config, error log, and welcome
- `ECVController` subclasses `NSDocumentController`

### After
- Single `MainWindowController` (Swift) hosting `NSSplitViewController`
- No `NSDocument` inheritance — `ECVCaptureDocument` becomes `ECVCaptureSession` (plain `NSObject`)
- `ECVController` becomes a plain `NSObject` for USB device discovery
- `AppDelegate` manages app lifecycle and window ownership

## Key Features

### Window Layout
```
┌─────────────┬──────────────────────────┬─────────────┐
│  Settings   │                          │  Error Log  │
│  Sidebar    │      Video / Welcome     │  Sidebar    │
│  (Cmd+,)    │                          │  (Cmd+E)    │
│             │                          │             │
└─────────────┴──────────────────────────┴─────────────┘
```

### Welcome Screen Mutation
- When no device: center shows WelcomeView, window sized to ~420×200
- When device connects: window animates to video size (e.g., 704×480 for NTSC)
- Content swaps from WelcomeView to ECVVideoView

### Keyboard Shortcuts
| Shortcut | Action |
|----------|--------|
| `Cmd+,` | Toggle left sidebar (settings) |
| `Cmd+E` | Toggle right sidebar (error log) |
| `Space` | Toggle play/pause |
| `Cmd+W` | Close window → quit app |
| `Cmd+F` | Toggle full screen |

### Quit on Window Close
- `applicationShouldTerminateAfterLastWindowClosed` returns `true`
- `windowWillClose` calls `NSApp.terminate(nil)`

## Files Created
| File | Role |
|------|------|
| `SwiftUI/AppDelegate.swift` | App lifecycle, keyboard shortcuts, window ownership |
| `SwiftUI/MainWindowController.swift` | NSSplitViewController-based unified window |

## Files Modified
| File | Change |
|------|--------|
| `Models/Capture/ECVCaptureDocument.h/m` | Convert from NSDocument to NSObject (rename to ECVCaptureSession) |
| `Controllers/ECVController.h/m` | Change from NSDocumentController to NSObject |
| `SwiftUI/ConfigViewModel.swift` | Use ECVCaptureSession instead of ECVCaptureDocument |
| `SwiftUI/WelcomeView.swift` | Remove ECVWelcomeSwiftHelper |
| `SwiftUI/ErrorLogView.swift` | Remove ECVErrorLogSwiftHelper |
| `Bridging-Header.h` | Update imports |
| `Resources/ECVMenu.xib` | Update menu actions and shortcuts |

## Files Deleted
| File | Reason |
|------|--------|
| `Controllers/ECVCaptureController.h/m` | Replaced by MainWindowController.swift |
| `Controllers/ECVWelcomeWindowController.h/m` | Welcome is now in split view |
| `Controllers/ECVErrorLogController.h/m` | Error log is now in split view |
| `SwiftUI/ConfigWindowController.swift` | Config is now in split view sidebar |
| `Resources/ECVCapture.xib` | Replaced by programmatic UI |
| `Resources/ECVConfig.xib` | Already orphaned, removed |

## Implementation Steps

1. Create `AppDelegate.swift` with quit-on-close and keyboard shortcuts
2. Create `MainWindowController.swift` with NSSplitViewController
3. Convert `ECVCaptureDocument` to `ECVCaptureSession` (plain NSObject)
4. Modify `ECVController` for single-window architecture
5. Update `ConfigViewModel` to use `ECVCaptureSession`
6. Update `WelcomeView` and `ErrorLogView` (remove window factories)
7. Delete obsolete files
8. Update `Bridging-Header.h` and `ECVMenu.xib`
9. Update Xcode project file
10. Build and fix compilation errors

## Risks

| Risk | Mitigation |
|------|-----------|
| ECVCaptureDocument rename breaks ObjC references | Use @objc alias or keep original name |
| USB discovery timing (1s delay) | Preserve existing performSelector:withObject:afterDelay: pattern |
| Full screen mode | Adapt setFullScreen: to work with split view |
| Menu validation | Move validateMenuItem: to MainWindowController |
| Recording logic | Move recording to MainWindowController |
