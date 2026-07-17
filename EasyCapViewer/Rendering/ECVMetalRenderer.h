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

#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

@class ECVVideoFrame;
@class ECVDependentVideoStorage;

@protocol ECVMetalRendererDelegate <NSObject>
@optional
- (void)metalRendererDidDrawFrame:(id)renderer;
@end

@interface ECVMetalRenderer : NSObject <MTKViewDelegate>

@property (nonatomic, readonly, weak) MTKView *view;
@property (nonatomic, weak) id<ECVMetalRendererDelegate> delegate;
@property (nonatomic) NSSize aspectRatio;
@property (nonatomic) NSRect cropRect;
@property (nonatomic) MTLPixelFormat pixelFormat;
@property (nonatomic) BOOL showDroppedFrames;
@property (nonatomic, readonly) BOOL isPlaying;
@property (nonatomic, strong) ECVDependentVideoStorage *videoStorage;

- (instancetype)initWithView:(MTKView *)view;

- (void)startRendering;
- (void)stopRendering;

- (void)pushFrame:(ECVVideoFrame *)frame;

@end
