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

// Models
@class ECVDependentVideoStorage;
@class ECVVideoFrame;
@class ECVMetalRenderer;

@protocol ECVVideoViewCell, ECVVideoViewDelegate;

@interface ECVVideoView : MTKView
{
	@private
	IBOutlet __weak NSObject<ECVVideoViewDelegate> *_ecvDelegate;
	ECVDependentVideoStorage *_videoStorage;
	NSSize _aspectRatio;
	NSRect _cropRect;
	BOOL _vsync;
	BOOL _showDroppedFrames;
	NSCell<ECVVideoViewCell> *_cell;
	
	ECVMetalRenderer *_renderer;
	NSRect _outputRect;
}

// These methods must be called from the main thread.
- (void)startDrawing;
- (void)stopDrawing;

// These methods are thread safe.
- (ECVDependentVideoStorage *)videoStorage;
- (void)setVideoStorage:(id)storage;
@property(weak) NSObject<ECVVideoViewDelegate> *ecvDelegate;
@property(assign) NSSize aspectRatio;
@property(assign) NSRect cropRect;
@property(assign) BOOL vsync;
@property(assign) BOOL showDroppedFrames;
@property(nonatomic, strong) NSCell<ECVVideoViewCell> *cell;
- (void)pushFrame:(ECVVideoFrame *)frame;

@end

@protocol ECVVideoViewCell <NSObject>
@required
- (void)drawWithFrame:(NSRect)r inVideoView:(ECVVideoView *)v playing:(BOOL)flag;
@end

@protocol ECVVideoViewDelegate <NSObject>
@optional
- (BOOL)videoView:(ECVVideoView *)sender handleKeyDown:(NSEvent *)anEvent;
@end
