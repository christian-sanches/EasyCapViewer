/* Copyright (c) 2009, Ben Trask
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY BEN TRASK ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL BEN TRASK BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */

#import "ECVMetalRenderer.h"

// Models
#import "ECVVideoFormat.h"
#import "ECVDependentVideoStorage.h"
#import "ECVVideoFrame.h"

// Other Sources
#import "ECVDebug.h"
#import "ECVPixelFormat.h"

typedef struct {
    vector_float4 position;
    vector_float2 texCoord;
} ECVVertex;

typedef struct {
    matrix_float4x4 projectionMatrix;
    matrix_float4x4 modelViewMatrix;
} ECVUniforms;

@interface ECVMetalRenderer ()

@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) id<MTLBuffer> vertexBuffer;
@property (nonatomic, strong) id<MTLBuffer> uniformsBuffer;
@property (nonatomic, strong) id<MTLTexture> yTexture;
@property (nonatomic, strong) id<MTLTexture> cbcrTexture;
@property (nonatomic, strong) id<MTLBuffer> yBuffer;
@property (nonatomic, strong) id<MTLBuffer> cbcrBuffer;
@property (nonatomic, strong) ECVVideoFrame *currentFrame;
@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, assign) vector_uint2 viewportSize;
@property (nonatomic, assign) CGFloat frameDropStrength;
@property (nonatomic, strong) dispatch_semaphore_t frameSemaphore;
@property (nonatomic, strong) NSMutableArray<ECVVideoFrame *> *frameQueue;

@end

@implementation ECVMetalRenderer

- (instancetype)initWithView:(MTKView *)view
{
    if (self = [super init]) {
        _view = view;
        _device = MTLCreateSystemDefaultDevice();
        if (!_device) {
            ECVLog(ECVError, @"Metal is not supported on this device");
            return nil;
        }
        
        _commandQueue = [_device newCommandQueue];
        _pixelFormat = view.colorPixelFormat;
        _frameSemaphore = dispatch_semaphore_create(3);
        _frameQueue = [NSMutableArray array];
        
        [self setupPipeline];
        [self setupVertexBuffer];
        [self setupUniformsBuffer];
        
        view.device = _device;
        view.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
        view.preferredFramesPerSecond = 60;
        view.delegate = self;
        view.paused = YES;
        view.enableSetNeedsDisplay = YES;
    }
    return self;
}

- (void)setupPipeline
{
    NSError *error = nil;
    id<MTLLibrary> library = [_device newDefaultLibrary];
    if (!library) {
        ECVLog(ECVError, @"Failed to create Metal library");
        return;
    }
    
    id<MTLFunction> vertexFunction = [library newFunctionWithName:@"vertexShader"];
    id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"yuvToRGB"];
    
    MTLRenderPipelineDescriptor *pipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDescriptor.vertexFunction = vertexFunction;
    pipelineDescriptor.fragmentFunction = fragmentFunction;
    pipelineDescriptor.colorAttachments[0].pixelFormat = _view.colorPixelFormat;

    MTLVertexDescriptor *vertexDescriptor = [[MTLVertexDescriptor alloc] init];
    vertexDescriptor.attributes[0].format = MTLVertexFormatFloat4;
    vertexDescriptor.attributes[0].offset = offsetof(ECVVertex, position);
    vertexDescriptor.attributes[0].bufferIndex = 0;
    vertexDescriptor.attributes[1].format = MTLVertexFormatFloat2;
    vertexDescriptor.attributes[1].offset = offsetof(ECVVertex, texCoord);
    vertexDescriptor.attributes[1].bufferIndex = 0;
    vertexDescriptor.layouts[0].stride = sizeof(ECVVertex);
    vertexDescriptor.layouts[0].stepRate = 1;
    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
    pipelineDescriptor.vertexDescriptor = vertexDescriptor;
    
    _pipelineState = [_device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    if (!_pipelineState) {
        ECVLog(ECVError, @"Failed to create pipeline state: %@", error);
    }
}

- (void)setupVertexBuffer
{
    static const ECVVertex vertices[] = {
        // Triangle 1
        {{-1.0f, -1.0f, 0.0f, 1.0f}, {0.0f, 1.0f}},
        {{ 1.0f, -1.0f, 0.0f, 1.0f}, {1.0f, 1.0f}},
        {{-1.0f,  1.0f, 0.0f, 1.0f}, {0.0f, 0.0f}},
        // Triangle 2
        {{ 1.0f, -1.0f, 0.0f, 1.0f}, {1.0f, 1.0f}},
        {{ 1.0f,  1.0f, 0.0f, 1.0f}, {1.0f, 0.0f}},
        {{-1.0f,  1.0f, 0.0f, 1.0f}, {0.0f, 0.0f}},
    };
    
    _vertexBuffer = [_device newBufferWithBytes:vertices
                                        length:sizeof(vertices)
                                       options:MTLResourceStorageModeShared];
}

- (void)setupUniformsBuffer
{
    _uniformsBuffer = [_device newBufferWithLength:sizeof(ECVUniforms)
                                          options:MTLResourceStorageModeShared];
}

#pragma mark - Public Methods

- (void)startRendering
{
    _isPlaying = YES;
    _view.paused = NO;
}

- (void)stopRendering
{
    _isPlaying = NO;
    _view.paused = YES;
    [_view setNeedsDisplay:YES];
}

- (void)pushFrame:(ECVVideoFrame *)frame
{
    if (!frame) return;
    
    @synchronized(self) {
        [self.frameQueue insertObject:frame atIndex:0];
        if ([self.videoStorage dropFramesFromArray:self.frameQueue]) {
            self.frameDropStrength = 1.0f;
        }
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.view setNeedsDisplay:YES];
    });
}

- (void)updateTextureForFrame:(ECVVideoFrame *)frame
{
    if (!frame || ![frame lockIfHasBytes]) return;
    
    ECVIntegerSize frameSize = [[self.videoStorage videoFormat] frameSize];
    OSType pixelFormat = [self.videoStorage pixelFormat];
    
    // Create Y texture if needed
    if (!_yTexture || _yTexture.width != frameSize.width || _yTexture.height != frameSize.height) {
        MTLTextureDescriptor *yDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Unorm
                                                                                        width:frameSize.width
                                                                                       height:frameSize.height
                                                                                    mipmapped:NO];
        yDesc.usage = MTLTextureUsageShaderRead;
        _yTexture = [_device newTextureWithDescriptor:yDesc];
    }
    
    // Create CbCr texture if needed
    if (!_cbcrTexture || _cbcrTexture.width != frameSize.width / 2 || _cbcrTexture.height != frameSize.height) {
        MTLTextureDescriptor *cbcrDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRG8Unorm
                                                                                          width:frameSize.width / 2
                                                                                         height:frameSize.height
                                                                                      mipmapped:NO];
        cbcrDesc.usage = MTLTextureUsageShaderRead;
        _cbcrTexture = [_device newTextureWithDescriptor:cbcrDesc];
    }
    
    // Get pixel data pointers
    const uint8_t *bytes = (const uint8_t *)[frame bytes];
    size_t frameSizeInBytes = frameSize.width * frameSize.height * 2; // 2 bytes per pixel for 4:2:2
    
    // For UYVY (k2vuyPixelFormat): Cb Y Cr Y
    // For YVYU: Y Cb Y Cr
    // We need to deinterleave into separate Y and CbCr planes
    
    // Create temporary buffers for deinterleaved data
    size_t ySize = frameSize.width * frameSize.height;
    size_t cbcrSize = frameSize.width * frameSize.height; // Half width, but 2 bytes per pixel
    
    uint8_t *yData = malloc(ySize);
    uint8_t *cbcrData = malloc(cbcrSize);
    
    if (!yData || !cbcrData) {
        free(yData);
        free(cbcrData);
        [frame unlock];
        return;
    }
    
    // Deinterleave based on pixel format
    // UYVY: [Cb Y0 Cr Y1] per pixel pair (4 bytes)
    // YVYU: [Y0 Cb Y1 Cr] per pixel pair (4 bytes)
    size_t dstY = 0;
    size_t dstCbCr = 0;
    size_t totalBytes = frameSize.width * frameSize.height * 2;

    if (pixelFormat == k2vuyPixelFormat) {
        for (size_t src = 0; src < totalBytes; src += 4) {
            cbcrData[dstCbCr++] = bytes[src];     // Cb
            yData[dstY++]       = bytes[src + 1]; // Y0
            cbcrData[dstCbCr++] = bytes[src + 2]; // Cr
            yData[dstY++]       = bytes[src + 3]; // Y1
        }
    } else if (pixelFormat == kYVYU422PixelFormat) {
        for (size_t src = 0; src < totalBytes; src += 4) {
            yData[dstY++]       = bytes[src];     // Y0
            cbcrData[dstCbCr++] = bytes[src + 1]; // Cb
            yData[dstY++]       = bytes[src + 2]; // Y1
            cbcrData[dstCbCr++] = bytes[src + 3]; // Cr
        }
    }
    
    // Upload to textures
    [_yTexture replaceRegion:MTLRegionMake2D(0, 0, frameSize.width, frameSize.height)
                 mipmapLevel:0
                   withBytes:yData
                 bytesPerRow:frameSize.width];
    
    [_cbcrTexture replaceRegion:MTLRegionMake2D(0, 0, frameSize.width / 2, frameSize.height)
                   mipmapLevel:0
                     withBytes:cbcrData
                   bytesPerRow:frameSize.width];
    
    free(yData);
    free(cbcrData);
    
    [frame unlock];
}

#pragma mark - MTKViewDelegate

- (void)drawInMTKView:(nonnull MTKView *)view
{
    if (!_pipelineState) return;
    
    ECVVideoFrame *frame = nil;
    
    @synchronized(self) {
        while ([_frameQueue count]) {
            frame = [_frameQueue lastObject];
            [_frameQueue removeLastObject];
            if ([frame lockIfHasBytes]) break;
            frame = nil;
        }
        if (!frame) {
            frame = [self.videoStorage currentFrame];
            if (![frame lockIfHasBytes]) frame = nil;
        }
    }
    
    if (frame) {
        [self updateTextureForFrame:frame];
    }
    
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    if (!renderPassDescriptor) return;
    
    renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1);
    renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
    
    MTLViewport viewport = {0, 0, (double)self.viewportSize.x, (double)self.viewportSize.y, -1, 1};
    [renderEncoder setViewport:viewport];
    [renderEncoder setRenderPipelineState:_pipelineState];
    
    // Set vertex buffer
    [renderEncoder setVertexBuffer:_vertexBuffer offset:0 atIndex:0];
    
    // Set uniforms
    [self updateUniforms];
    [renderEncoder setVertexBuffer:_uniformsBuffer offset:0 atIndex:1];
    
    // Set textures
    if (_yTexture) [renderEncoder setFragmentTexture:_yTexture atIndex:0];
    if (_cbcrTexture) [renderEncoder setFragmentTexture:_cbcrTexture atIndex:1];
    
    // Draw
    [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
    [renderEncoder endEncoding];
    
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
    
    if (frame) {
        _frameDropStrength *= 0.75f;
        [frame unlock];
    }
    
    [_delegate metalRendererDidDrawFrame:self];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size
{
    self.viewportSize = (vector_uint2){(uint)size.width, (uint)size.height};
}

#pragma mark - Private Methods

- (void)updateUniforms
{
    ECVUniforms *uniforms = (ECVUniforms *)[_uniformsBuffer contents];
    
    // Simple orthographic projection
    float aspectRatio = (float)(_aspectRatio.width / _aspectRatio.height);
    float viewAspect = (float)(self.viewportSize.x / self.viewportSize.y);
    
    float scaleX = 1.0f;
    float scaleY = 1.0f;
    
    if (aspectRatio > viewAspect) {
        scaleY = viewAspect / aspectRatio;
    } else {
        scaleX = aspectRatio / viewAspect;
    }
    
    uniforms->projectionMatrix = matrix_identity_float4x4;
    uniforms->modelViewMatrix = matrix_identity_float4x4;
    
    // Apply scaling for aspect ratio
    uniforms->modelViewMatrix.columns[0][0] = scaleX;
    uniforms->modelViewMatrix.columns[1][1] = scaleY;
}

#pragma mark - Properties

- (void)setAspectRatio:(NSSize)ratio
{
    _aspectRatio = ratio;
    [_view setNeedsDisplay:YES];
}

- (void)setCropRect:(NSRect)rect
{
    _cropRect = rect;
    [_view setNeedsDisplay:YES];
}

- (void)setShowDroppedFrames:(BOOL)flag
{
    _showDroppedFrames = flag;
    [_view setNeedsDisplay:YES];
}

@end
