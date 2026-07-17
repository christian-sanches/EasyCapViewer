# Phase 2 — ARC Migration (Manual → Automatic Reference Counting)

**Goal:** Convert the entire codebase from Manual Reference Counting (MRC) to Automatic Reference Counting (ARC).

---

## Overview

Every `.m` file in the project uses MRC (`retain`, `release`, `autorelease`, `dealloc`, `NSAutoreleasePool`). This is the most **mechanical** but **widest-reaching** change.

### Scale of the problem
Based on grep results: **100+ occurrences** of `retain]`, `release]`, `autorelease]`, `NSAutoreleasePool`, and manual `dealloc` methods across the entire codebase.

---

## 2.1 Enable ARC in Build Settings

Set the following in the Xcode project build settings (per target):

```
CLANG_ENABLE_OBJC_ARC = YES
```

This will immediately cause **compiler errors** for every MRC pattern in the code.

---

## 2.2 Mechanical Transformations

### 2.2.1 Remove `retain` / `release` / `autorelease` calls

| MRC Pattern | ARC Equivalent |
|-------------|----------------|
| `[obj retain]` | Remove — ARC handles it |
| `[obj release]` | Remove — ARC handles it |
| `[obj autorelease]` | Remove — ARC handles it |
| `[[[Foo alloc] init] autorelease]` | `[[Foo alloc] init]` |
| `_ivar = [obj retain]` | `_ivar = obj;` (ARC strong by default) |
| `[_ivar release]` | Remove from `dealloc` |

### 2.2.2 Replace `NSAutoreleasePool`

| MRC Pattern | ARC Equivalent |
|-------------|----------------|
| `NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];` | `@autoreleasepool {` |
| `[pool drain];` / `[pool release];` | `}` (closing brace) |

**Files with `NSAutoreleasePool` usage:**
- `EasyCapViewer.m:27` — main function
- `ECVMovieRecorder.m:248,256,299,333` — thread pools
- `ECVDebug.m:40` — logging thread

### 2.2.3 Replace `dealloc` methods

**Remove all `dealloc` methods entirely** — ARC automatically releases all strong ivars.

**Exception:** If a `dealloc` calls `[super dealloc]`, remove the entire method. If it does non-memory cleanup (like removing observers), convert to `[super dealloc]` replacement:

```objc
// BEFORE (MRC):
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_ivar release];
    [super dealloc];
}

// AFTER (ARC):
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    // No [super dealloc] needed — ARC inserts it
}
```

### 2.2.4 Update property attributes

| MRC Property | ARC Property |
|-------------|-------------|
| `@property(retain)` | `@property(strong)` |
| `@property(assign)` (for objects) | `@property(weak)` or `@property(unsafe_unretained)` |
| `@property(assign)` (for scalars) | `@property(assign)` (unchanged) |

**Files with `retain` properties:**
- `ECVVideoView.h:67` — `@property(nonatomic, retain) NSCell<ECVVideoViewCell> *cell;`
  → Change to `@property(nonatomic, strong)`

**Files with `assign` for object pointers (likely should be `weak`):**
- `ECVVideoView.h:61` — `@property(assign) NSObject<ECVVideoViewDelegate> *delegate;`
  → Change to `@property(weak)` (if not already a weak reference)

### 2.2.5 Remove `retain` property implementation patterns

In `.m` files, manual `retain`/`release` in property setters:

```objc
// BEFORE:
- (void)setFoo:(Foo *)foo {
    [foo retain];
    [_foo release];
    _foo = foo;
}

// AFTER:
- (void)setFoo:(Foo *)foo {
    _foo = foo;
}
// Or just use @synthesize and let ARC handle it
```

---

## 2.3 Files Requiring Changes (Complete List)

Every `.m` file in the project needs ARC conversion. The most impacted files:

### High-impact (many manual memory calls)
| File | Approx. MRC calls | Notes |
|------|-------------------|-------|
| `ECVMovieRecorder.m` | 20+ | Thread pools, retain/release cycles |
| `ECVCaptureDocument.m` | 15+ | Device retain/release |
| `ECVCaptureController.m` | 10+ | Object creation with autorelease |
| `ECVController.m` | 8+ | Singleton retain, IOKit cleanup |
| `ECVErrorLogController.m` | 8+ | Attributed string creation |
| `ECVPlayButtonCell.m` | 5+ | OpenGL context retain |
| `ECVEM2860Device.m` | 5+ | Chip retain/release |
| `ECVAudioTarget.m` | 5+ | Audio output retain |

### Medium-impact
| File | Approx. MRC calls |
|------|-------------------|
| `ECVVideoFormat.m` | 4 |
| `ECVFrameRateConverter.m` | 3 |
| `ECVVideoView.m` | 3 |
| `ECVCropCell.m` | 3 |
| `ECVAudioPipe.m` | 2 |
| `ECVHUDPopUpButtonCell.m` | 3 |
| `ECVHUDSliderCell.m` | 2 |

### Low-impact (1-2 calls each)
All remaining `.m` files.

---

## 2.4 ARC-Specific Considerations for This Codebase

### 2.4.1 Toll-Free Bridging
Check for `CFBridgingRetain` / `CFBridgingRelease` / `__bridge` casts. The codebase uses CoreFoundation types (`CFURLRef`, `CFDictionaryRef`, `CFAllocatorRef`) extensively.

```objc
// BEFORE: Implicit toll-free bridge
(CFURLRef)someNSURL

// AFTER: Explicit bridge cast
(__bridge CFURLRef)someNSURL
```

**Key locations:**
- `ECVMovieRecorder.m` — `QTNewDataReferenceFromCFURL((CFURLRef)[options URL], ...)`
- `ECVController.m` — IOKit dictionary casts
- `ECVMovieRecorder.m:120` — `ICMCompressionSessionCreate` CFDictionary casts
- `ECVComponent.m` — Multiple CF bridges (being removed in Phase 3, but if kept temporarily)

### 2.4.2 CoreFoundation Object Leaks
With ARC, CF objects created by `Create` functions need `CFBridgingRelease()` or explicit `CFRelease()`:

```objc
// BEFORE:
CFDictionaryRef dict = (CFDictionaryRef)someNSDictionary;
// No release needed (toll-free bridged)

// AFTER:
CFDictionaryRef dict = (__bridge_retained CFDictionaryRef)someNSDictionary;
// or use (__bridge) if not taking ownership
```

### 2.4.3 Weak References
`NSWindowDelegate`, `NSDocument` delegates, and `NSNotificationCenter` observers should use `weak`:
- `ECVVideoView.h:40` — `IBOutlet NSObject<ECVVideoViewDelegate> *delegate;` → `weak`
- `MPLWindow.h` — Any delegate references

### 2.4.4 __unsafe_unretained
For performance-critical delegate properties where `weak` overhead is unacceptable, consider `__unsafe_unretained` (same as MRC `assign`).

---

## 2.5 Conversion Strategy

### Recommended approach: Use Xcode's built-in ARC migrator

1. **Before converting:** Commit everything (git snapshot)
2. Xcode → Edit → Refactor → Convert to Objective-C ARC
3. Review each change manually (the migrator is good but not perfect)
4. Pay special attention to:
   - CoreFoundation bridging casts
   - `dealloc` methods that do non-memory cleanup
   - Thread-local ownership patterns

### Alternative: Manual conversion
If the migrator has issues with the old project format, convert file-by-file:
1. Enable ARC for the target
2. Fix each file one at a time (start with leaf files that don't import project headers)
3. Compile after each file to catch errors incrementally

---

## 2.6 Verification

After Phase 2, the project should:
- [x] Compile with `CLANG_ENABLE_OBJC_ARC = YES` with no ARC-related warnings
- [x] No `retain`, `release`, `autorelease`, `NSAutoreleasePool` in any source file
- [x] No `[super dealloc]` in any `dealloc` method
- [x] All `@property(retain)` converted to `@property(strong)`
- [x] All object-pointer `@property(assign)` converted to `@property(weak)` where appropriate
- [x] All `__bridge` casts are correct and don't leak or over-release
- [ ] No memory leaks (run Instruments → Leaks)
