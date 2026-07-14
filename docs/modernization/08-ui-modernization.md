# Phase 8 — UI & HUD Modernization

**Goal:** Update the UI layer for modern macOS conventions, replace OpenGL-dependent UI with Cocoa views, and optionally modernize the HUD style.

---

## 8.1 Current UI Components

| File | Role | Dependencies |
|------|------|-------------|
| `ECVCaptureController.h/m` | Main capture window controller | OpenGL (crop, play button), Movie recording |
| `ECVConfigController.h/m` | Settings window | None (pure Cocoa) |
| `ECVErrorLogController.h/m` | Error log window | None (pure Cocoa) |
| `MPLWindow.h/m` | Custom NSWindow | None (cursor management) |
| `ECVHUDButtonCell.h/m` | Translucent button cell | QuartzCore (shadow) |
| `ECVHUDSliderCell.h/m` | Translucent slider cell | QuartzCore (shadow) |
| `ECVHUDPopUpButtonCell.h/m` | Translucent popup cell | QuartzCore (shadow) |
| `ECVHUDSwitchButtonCell.h/m` | Translucent switch cell | QuartzCore (shadow) |
| `ECVTickMarkView.h/m` | Tick mark ruler | None (drawn with NSBezierPath) |
| `ECVDividerView.h/m` | Visual divider | None |
| `ECVCropCell.h/m` | Crop rectangle overlay | **OpenGL** (`NSOpenGLContext`) |
| `ECVPlayButtonCell.h/m` | Play/pause button | **OpenGL** (`NSOpenGLContext`) |

### XIB files
| File | Role |
|------|------|
| `ECVCapture.xib` | Main capture window |
| `ECVConfig.xib` | Settings window |
| `ECVErrorLog.xib` | Error log window |
| `ECVMenu.xib` | Menu bar |

---

## 8.2 OpenGL-Dependent UI (Must Rewrite)

### 8.2.1 ECVCropCell
**Current:** Draws crop rectangle using OpenGL (`glBegin/glEnd`, `glColor4f`, `glRectf`)

**Replacement:** NSView overlay with `drawRect:` using AppKit drawing:

```objc
// BEFORE (OpenGL):
- (void)drawWithFrame:(NSRect)r inVideoView:(ECVVideoView *)v playing:(BOOL)flag {
    NSOpenGLContext *context = [v openGLContext];
    [context makeCurrentContext];
    glColor4f(1.0f, 1.0f, 1.0f, 0.5f);
    glBegin(GL_LINE_LOOP);
    glVertex2f(NSMinX(r), NSMinY(r));
    // ... more vertices
    glEnd();
    [context flushBuffer];
}

// AFTER (AppKit):
- (void)drawWithFrame:(NSRect)r inVideoView:(ECVVideoView *)v playing:(BOOL)flag {
    [[NSColor colorWithWhite:1.0 alpha:0.5] setStroke];
    NSBezierPath *path = [NSBezierPath bezierPathWithRect:r];
    [path setLineWidth:2.0];
    [path stroke];
    
    // Draw resize handles at corners
    [self drawResizeHandlesInRect:r];
}
```

### 8.2.2 ECVPlayButtonCell
**Current:** Draws play/pause triangle using OpenGL immediate mode

**Replacement:** NSView overlay with `drawRect:`:

```objc
// Draw play triangle
- (void)drawPlayButton {
    NSBezierPath *path = [NSBezierPath bezierPath];
    [path moveToPoint:NSMakePoint(0, 0)];
    [path lineToPoint:NSMakePoint(0, size)];
    [path lineToPoint:NSMakePoint(size * 0.866, size * 0.5)];
    [path closePath];
    [[NSColor whiteColor] fill];
}
```

### 8.2.3 Remove OpenGL dependencies
After rewriting:
- `ECVCropCell.h` — Remove `#import <OpenGL/...>`, remove `NSOpenGLContext *` parameter
- `ECVPlayButtonCell.h` — Remove `NSOpenGLContext *` ivar and parameter
- `ECVCropCell.m` — Remove all `glBegin`/`glEnd`/`glColor` calls
- `ECVPlayButtonCell.m` — Remove all OpenGL calls

---

## 8.3 HUD Components (Minor Updates)

The HUD (Heads-Up Display) components use Core Animation shadows and custom drawing. They should work as-is after ARC conversion. Optional improvements:

### Current HUD style
Dark translucent panels with custom `NSCell` subclasses. This is a classic macOS look.

### Optional modernization
- Consider using `NSVisualEffectView` for the translucent background (vibrancy)
- Update colors for macOS Ventura/Sonoma design language
- Use SF Symbols for icons instead of custom drawn shapes

### Files to update (minor)
| File | Change |
|------|--------|
| `ECVHUDButtonCell.m` | ARC conversion only |
| `ECVHUDSliderCell.m` | ARC conversion only |
| `ECVHUDPopUpButtonCell.m` | ARC conversion only |
| `ECVHUDSwitchButtonCell.m` | ARC conversion only |
| `ECVTickMarkView.m` | ARC conversion only |
| `ECVDividerView.m` | ARC conversion only |

---

## 8.4 XIB Modernization

### Opening in modern Xcode
The old `.xib` files may need to be re-saved in modern Interface Builder:
1. Open each `.xib` in Xcode
2. Xcode will prompt to update to latest format — accept
3. Verify all connections and outlets are intact
4. Test each window loads correctly

### Layout updates
The XIBs may use old-style autosizing masks. Consider updating to Auto Layout:
- **Not required** for the port (autoresizing still works)
- **Recommended** for proper support of different window sizes and Retina displays

### Specific XIBs
| XIB | Notes |
|-----|-------|
| `ECVCapture.xib` | Main capture window — needs Metal view integration |
| `ECVConfig.xib` | Settings — should be straightforward |
| `ECVErrorLog.xib` | Error log — simple table view |
| `ECVMenu.xib` | Menu bar — minimal changes needed |

### ECVCapture.xib specific changes
The capture window XIB likely references `ECVVideoView` as an `NSOpenGLView`. This needs to be changed to `MTKView`:
1. Open XIB in Interface Builder
2. Find the video view
3. Change custom class from `ECVVideoView` (which will be `MTKView` subclass) — verify class name is correct
4. Connect any missing outlets

---

## 8.5 Document Architecture

The app uses `NSDocument` / `NSDocumentController` / `NSWindowController`. This is fully supported on modern macOS. No architectural changes needed.

### Key classes
- `ECVController` → `NSDocumentController` subclass — ✅ keep as-is
- `ECVCaptureDocument` → `NSDocument` subclass — ✅ keep as-is
- `ECVCaptureController` → `NSWindowController` subclass — ✅ keep as-is

---

## 8.6 NSResponder / Event Handling

Verify keyboard and mouse event handling works correctly:
- The capture view handles key events for playback control
- Window delegate methods for resize, close
- Menu item actions

These should all work unchanged after ARC conversion.

---

## 8.7 Verification

After Phase 8, the project should:
- [x] `ECVCropCell` uses AppKit drawing (no OpenGL) — completed in Phase 4
- [x] `ECVPlayButtonCell` uses AppKit drawing (no OpenGL) — completed in Phase 4
- [x] All HUD cells compile and render correctly with ARC — modernized with nullability and literals
- [ ] All XIBs open in modern Xcode without errors — requires manual verification
- [ ] `ECVCapture.xib` correctly references the new `MTKView`-based view — requires manual verification
- [ ] Settings window opens and functions — requires manual verification
- [ ] Error log window opens and functions — requires manual verification
- [ ] Menu bar works correctly — requires manual verification
- [ ] Window resize works correctly — requires manual verification
- [ ] Keyboard shortcuts work correctly — requires manual verification
- [ ] All UI elements render at correct sizes on Retina displays — requires manual verification

---

## 8.8 Changes Made (Phase 8 — UI Modernization Pass)

### OpenGL Cleanup
- Removed residual `dealloc` methods that only contained `// No OpenGL cleanup needed` comments from `ECVCropCell.m` and `ECVPlayButtonCell.m`
- OpenGL → AppKit rewrite was already completed in Phase 4 (Metal migration)

### Nullability Annotations
Added `NS_ASSUME_NONNULL_BEGIN`/`END` to all UI headers:
- `ECVCropCell.h` — `delegate` property marked `nullable`
- `ECVPlayButtonCell.h`
- `ECVHUDButtonCell.h`
- `ECVHUDSliderCell.h`
- `ECVHUDPopUpButtonCell.h`
- `ECVHUDSwitchButtonCell.h`
- `ECVAppKitAdditions.h` — `sender` parameter in `ECV_toggleWindow:` marked `nullable`

### Modern Objective-C Patterns
- **ECVCaptureController.m**: Replaced `NSDictionary dictionaryWithObjectsAndKeys:` with `@{}` literals, `[NSArray arrayWithObject:]` with `@[]`, `[NSNumber numberWith...]` with `@()` throughout
- **ECVCaptureController.h**: Removed `#if defined(MAC_OS_X_VERSION_10_6)` guard around `NSWindowDelegate` — unconditionally adopted (macOS 14+ target)
- **ECVHUDButtonCell.m**: Replaced dictionary creation with literal
- **ECVHUDPopUpButtonCell.m**: Replaced dictionary creation with literal
- **ECVHUDSwitchButtonCell.m**: Replaced dictionary creation with literal

### XIB Modernization
- XIB files require manual re-saving in modern Interface Builder — not automated
- ECVCapture.xib needs Metal view integration (requires IB changes)
