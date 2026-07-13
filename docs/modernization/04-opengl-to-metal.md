# Phase 4 — OpenGL → Metal (Video Rendering)

**Goal:** Replace the OpenGL-based video rendering pipeline with Metal. This is the most architecturally significant change.

---

## 4.1 Current OpenGL Architecture

The current rendering is built around:

| Component | File | Current API |
|-----------|------|-------------|
| Video View | `ECVVideoView.h/m` | `NSOpenGLView` subclass |
| Display Link | `ECVVideoView.m` | `CVDisplayLink` (60fps render loop) |
| Texture Upload | `ECVVideoView.m` | `glTexImage2D` / PBO buffer objects |
| Shaders | `ECVVideoView.m` | Hardcoded vertex/fragment via `glGetString` |
| Crop Cell | `ECVCropCell.h/m` | `NSOpenGLContext`-based overlay drawing |
| Play Button | `ECVPlayButtonCell.h/m` | `NSOpenGLContext`-based overlay drawing |
| GL Helpers | `ECVOpenGLAdditions.h/m` | `NSOpenGLContext` category methods |
| GL Lock | `ECVAppKitAdditions.h` | `ECVLockContext()` — `CGLLockContext` wrapper |

### Rendering flow
```
USB → ECVVideoFrame → ECVVideoStorage → ECVVideoView (pushFrame:)
                                            ↓
                                    CVDisplayLink callback
                                            ↓
                                    glTexImage2D (YUV→RGB conversion in shader)
                                            ↓
                                    NSOpenGLView renders to screen
```

---

## 4.2 Metal Replacement Architecture

| Current Component | Metal Replacement | Notes |
|-------------------|-------------------|-------|
| `NSOpenGLView` | `MTKView` | Metal Kit view, handles display link automatically |
| `NSOpenGLContext` | `MTLDevice` + `MTLCommandQueue` | Created once, shared |
| `glTexImage2D` | `MTLTexture` + `MTLBuffer` | Upload YUV data as texture |
| Vertex/Fragment shaders | `.metal` shader file | MSL (Metal Shading Language) |
| `CVDisplayLink` | `MTKView.preferredFramesPerSecond` | Or `CADisplayLink` for macOS 14+ |
| PBO (Pixel Buffer Object) | `MTLBuffer` with `storageModeShared` | Apple Silicon unified memory |
| `glOrtho` projection | Metal projection matrix | Simple orthographic |
| `ECVOpenGLAdditions` | Delete | Not needed |
| `ECVAppKitAdditions.h` `ECVLockContext` | Delete | Not needed |
| `ECVCropCell` | Metal overlay pass or `NSView` overlay | Simpler to use NSView for UI overlays |
| `ECVPlayButtonCell` | `NSView` / `NSButton` overlay | Much simpler without OpenGL |

---

## 4.3 New Files to Create

### `ECVMetalRenderer.h` / `ECVMetalRenderer.m`
Core Metal rendering engine, replacing `ECVVideoView.m`:

```objc
@interface ECVMetalRenderer : NSObject

@property (nonatomic, readonly) MTKView *view;
@property (nonatomic) NSSize aspectRatio;
@property (nonatomic) NSRect cropRect;
@property (nonatomic) GLint magFilter; // → MTLTextureMagFilter
@property (nonatomic) BOOL showDroppedFrames;

- (instancetype)initWithView:(MTKView *)view;
- (void)pushFrame:(ECVVideoFrame *)frame;

@end
```

### `ECVMetalShaders.metal`
Metal Shading Language file for YUV→RGB conversion:

```metal
#include <metal_stdlib>
using namespace metal;

// Vertex shader — simple fullscreen quad
struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

// Fragment shader — YUV (2vuy / 422) to RGB conversion
fragment float4 yuvToRGB(VertexOut in [[stage_in]],
                          texture2d<float> texture [[texture(0)]]) {
    constexpr sampler s(mag_filter::linear, min_filter::linear);
    float4 yuv = texture.sample(s, in.texCoord);
    // BT.601 conversion matrix
    // ... (standard YUV→RGB matrix)
    return float4(rgb, 1.0);
}
```

---

## 4.4 Step-by-Step Implementation

### 4.4.1 Create the Metal renderer (ECVMetalRenderer)
1. Create `MTLDevice`, `MTLCommandQueue`
2. Create `MTLLibrary` from default (or bundled `.metallib`)
3. Create `MTLRenderPipelineState` from vertex + fragment shaders
4. Create a YUV texture descriptor (`MTLPixelFormatR8Unorm` for Y, `MTLPixelFormatRG8Unorm` for UV)
5. Create a fullscreen quad vertex buffer (2 triangles)
6. Implement `pushFrame:` to:
   - Lock the `ECVVideoFrame`
   - Copy pixel data into `MTLBuffer` or `MTLTexture`
   - Unlock frame
   - Mark view as needing display

### 4.4.2 Replace ECVVideoView with MTKView
```objc
// BEFORE:
@interface ECVVideoView : NSOpenGLView

// AFTER:
@interface ECVVideoView : MTKView <MTKViewDelegate>
```

Key differences:
- `MTKView` has its own draw loop (no need for `CVDisplayLink`)
- Implement `MTKViewDelegate` methods: `drawInMTKView:` and `mtkView:drawableSizeDidChange:`
- The renderer does the actual drawing in `drawInMTKView:`

### 4.4.3 YUV→RGB Conversion
The current OpenGL shader does YUV→RGB in the fragment shader. Metal equivalent:

**Input format:** `k2vuyPixelFormat` (422 YUV, 2 bytes/pixel: Cb Y Cr Y)
- Planar layout: Y plane (8-bit) + CbCr plane (16-bit interleaved)

**Metal texture setup:**
```objc
// Y plane: R8Unorm, width = frameWidth, height = frameHeight
MTLTextureDescriptor *yDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Unorm
    width:frameWidth height:frameHeight mipmapped:NO];
yDesc.usage = MTLTextureUsageShaderRead;

// CbCr plane: RG8Unorm, width = frameWidth/2, height = frameHeight
MTLTextureDescriptor *cbcrDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRG8Unorm
    width:frameWidth/2 height:frameHeight mipmapped:NO];
cbcrDesc.usage = MTLTextureUsageShaderRead;
```

### 4.4.4 Handle Aspect Ratio and Crop
- Pass aspect ratio and crop rect as uniform buffer to the vertex shader
- Or compute the viewport/scissor rect in the render pass

### 4.4.5 Remove OpenGL code
After Metal is working:
1. Delete `ECVOpenGLAdditions.h/m`
2. Remove `#import <OpenGL/gl.h>` from all files
3. Remove `#import <OpenGL/OpenGL.h>` from all files
4. Remove `NSOpenGLView`, `NSOpenGLContext`, `NSOpenGLPixelFormat` references
5. Remove `CGLLockContext`, `CGLUnlockContext` calls
6. Remove `ECVLockContext()` from `ECVAppKitAdditions.h`
7. Unlink `OpenGL.framework`

---

## 4.5 Overlay UI (Crop Cell, Play Button)

The current `ECVCropCell` and `ECVPlayButtonCell` draw using OpenGL context. Two options:

### Option A: Metal overlay pass (more complex, more cohesive)
Draw the crop rectangle and play button as additional render passes in the Metal renderer. Requires text/UI rendering in Metal (significant work).

### Option B: NSView overlay (recommended, much simpler)
Place transparent `NSView` subviews on top of the `MTKView`:
- `ECVCropCell` → `NSView` with `drawRect:` using `NSBezierPath` (Cocoa, no OpenGL)
- `ECVPlayButtonCell` → `NSButton` or custom `NSView` with `NSBezierPath`

This is dramatically simpler and maintains clean separation between rendering (Metal) and UI (AppKit).

---

## 4.6 CVDisplayLink Replacement

`CVDisplayLink` is deprecated since macOS 14.0 (Sonoma), but still works. Options:

| Option | Min macOS | Notes |
|--------|-----------|-------|
| `MTKView.preferredFramesPerSecond` | 13.0 | Simplest, built into MTKView |
| `CADisplayLink` (via `NSView`) | 14.0 | New API, more precise |
| Keep `CVDisplayLink` | 13.0 | Deprecated but functional |

**Recommended:** Use `MTKView.preferredFramesPerSecond` for macOS 13-13.5, `CADisplayLink` for 14+. Or just use `MTKView` which handles this automatically.

---

## 4.7 Performance Considerations for Apple Silicon

Apple Silicon uses **unified memory** — CPU and GPU share the same RAM. This means:

1. **No need to copy textures** — CPU can write directly to GPU-visible memory
2. Use `MTLBuffer` with `storageModeShared` for pixel data upload
3. `MTLPixelFormatR8Unorm` / `MTLPixelFormatRG8Unorm` are native formats
4. Single-plane upload is fastest (no separate Y/CbCr texture copies)

### Expected performance
- 1080p30 YUV→RGB: trivial for Apple Silicon GPU
- 1080p60: also trivial
- Multiple simultaneous capture windows: should be fine

---

## 4.8 Verification

After Phase 4, the project should:
- [ ] `ECVVideoView` is an `MTKView` subclass
- [ ] `ECVMetalRenderer` handles texture upload and rendering
- [ ] `.metal` shader file compiles with the project
- [ ] Video displays correctly at native resolution
- [ ] Crop rectangle overlay works (NSView-based)
- [ ] Play button overlay works (NSView-based)
- [ ] No OpenGL references remain in any source file
- [ ] No `OpenGL.framework` in linked frameworks
- [ ] `ECVOpenGLAdditions.h/m` deleted
- [ ] Performance: 30fps and 60fps capture renders smoothly
- [ ] Works on both Apple Silicon and Intel Macs (universal binary)
