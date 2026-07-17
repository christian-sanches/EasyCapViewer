# Phase 3 — Remove Dead 32-bit Code

**Goal:** Remove all QuickTime component code, QTKit references, and 32-bit-only guards. This must happen before the OpenGL/Metal rewrite so we're not maintaining dead code.

---

## 3.1 Remove the QuickTime Component Target

The `ECVComponent` target is a QuickTime Component (type `thng`) that allowed third-party QuickTime applications to use EasyCapViewer as a video input source. This technology is completely dead — **remove entirely**.

### Files to delete
| File | Reason |
|------|--------|
| `ECVComponent.m` | QuickTime component entry points, ICM compression |
| `ECVComponent.r` | Rez resource file for QuickTime component registration |
| `ECVComponentDispatch.h` | Auto-generated QuickTime dispatch table |
| `ECVComponent-Info.plist` | Component bundle metadata (type `thng`, signature `RNST`) |

### Target to delete
- Remove `ECVComponent` target from Xcode project
- Remove `ECVComponent.component` from Products group

---

## 3.2 Remove QTKit References

### Files to delete
| File | Reason |
|------|--------|
| `ECVQTKitAdditions.h` | Category on `QTMedia` and `QTTrack` (QTKit classes) |
| `ECVQTKitAdditions.m` | Implementation of above |

### Files to audit
- `ECVMovieRecorder.h` — imports `<QTKit/QTKit.h>` — **will be rewritten in Phase 5**, but for now remove the import

---

## 3.3 Remove `#if !__LP64__` Guards

The following code is wrapped in 32-bit guards and will be removed:

```objc
#if !__LP64__
// ... entire file contents ...
#endif
```

### Files with 32-bit guards
| File | Status |
|------|--------|
| `ECVMovieRecorder.m` | Entire implementation wrapped in `#if !__LP64__` — **will be rewritten in Phase 5** |
| `ECVComponent.m` | Being deleted (§3.1) |

---

## 3.4 Remove ICM (Image Compression Manager) References

### Files to delete
| File | Reason |
|------|--------|
| `ECVICM.h` | Macros for `ICMCompressionSessionOptionsSetProperty` — QuickTime ICM API |

### References in remaining code (will be rewritten in Phase 5)
- `ECVMovieRecorder.m` — heavy ICM usage (entire file being replaced)
- `ECVComponent.m` — being deleted

---

## 3.5 Remove Carbon Framework

Carbon is only used for minor helpers. Audit and replace:

### Where Carbon is used
- Check `#import <Carbon/Carbon.h>` in any remaining files
- Replace any `EventRef`, `EventHandlerCallRef`, or Carbon Event Manager calls with Cocoa equivalents (`NSEvent`, `NSResponder`)

### Action
1. Search all `.h` and `.m` files for `Carbon`
2. Remove the framework linkage
3. Replace any remaining Carbon API calls with Cocoa equivalents

---

## 3.6 Clean Up ECVMovieRecorder Stub

After removing QuickTime code, `ECVMovieRecorder.m` will be empty (or just the 32-bit guard). Options:

### Option A: Temporary stub (recommended for incremental progress)
Keep `ECVMovieRecorder.h/m` as a stub that compiles but does nothing:

```objc
// ECVMovieRecorder.h
@interface ECVMovieRecordingOptions : NSObject
// ... keep the property declarations for now ...
@end

@interface ECVMovieRecorder : NSObject
- (instancetype)initWithOptions:(ECVMovieRecordingOptions *)options error:(NSError **)outError;
- (void)addVideoFrame:(ECVVideoFrame *)frame;
- (void)addAudioBufferList:(AudioBufferList const *)bufferList;
- (void)stopRecording;
@end
```

```objc
// ECVMovieRecorder.m
@implementation ECVMovieRecordingOptions
// Empty — properties only
@end

@implementation ECVMovieRecorder
- (instancetype)initWithOptions:(ECVMovieRecordingOptions *)options error:(NSError **)outError {
    if (outError) *outError = [NSError errorWithDomain:@"ECVMovieRecorder" code:-1 
        userInfo:@{NSLocalizedDescriptionKey: @"Recording not yet implemented"}];
    return nil;
}
- (void)addVideoFrame:(ECVVideoFrame *)frame {}
- (void)addAudioBufferList:(AudioBufferList const *)bufferList {}
- (void)stopRecording {}
@end
```

### Option B: Delete and recreate in Phase 5
Remove the files entirely and create fresh in Phase 5. This is cleaner but may cause more compile errors during incremental work.

---

## 3.7 Search & Remove All QTKit/QuickTime/ICM References

Run these searches and clean up any remaining hits:

```
grep -r "QTKit" --include="*.h" --include="*.m" --include="*.plist"
grep -r "QuickTime" --include="*.h" --include="*.m"
grep -r "ICM" --include="*.h" --include="*.m"
grep -r "EnterMovies" --include="*.h" --include="*.m"
grep -r "QT" --include="*.h" --include="*.m" (careful — some "QT" hits may be false positives)
```

---

## 3.8 Verification

After Phase 3, the project should:
- [x] No `ECVComponent*` files exist
- [x] No `ECVQTKitAdditions*` files exist
- [x] No `ECVICM.h` exists
- [x] No `#import <QTKit/...>` anywhere
- [x] No `#import <QuickTime/...>` anywhere
- [x] No `#if !__LP64__` guards anywhere
- [x] No `Carbon.framework` in linked frameworks
- [x] `ECVMovieRecorder` is a working stub (compiles, does nothing)
- [x] Project compiles (with expected warnings about stub recorder)
