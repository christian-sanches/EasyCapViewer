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

#import "ECVVideoView.h"
#import "ECVMetalRenderer.h"

// Models
#import "ECVVideoFormat.h"
#import "ECVDependentVideoStorage.h"
#import "ECVVideoFrame.h"

// Other Sources
#import "ECVDebug.h"

@implementation ECVVideoView

#pragma mark -ECVVideoView

- (void)startDrawing
{
	[_renderer startRendering];
}

- (void)stopDrawing
{
	[_renderer stopRendering];
}

#pragma mark -

- (ECVDependentVideoStorage *)videoStorage
{
	return _videoStorage;
}

- (void)setVideoStorage:(id)storage
{
	NSLog(@"[ECV-TRACE] VideoView.setVideoStorage: storage=%@ renderer=%@", storage, _renderer);
	NSParameterAssert([storage isKindOfClass:[ECVDependentVideoStorage class]]);
	
	if (storage == _videoStorage) return;
	
	_videoStorage = storage;
	_renderer.videoStorage = storage;
	NSLog(@"[ECV-TRACE] VideoView.setVideoStorage: done, renderer.storage=%@", _renderer.videoStorage);
}

@synthesize ecvDelegate;
@synthesize showDroppedFrames = _showDroppedFrames;

- (NSSize)aspectRatio
{
	return _aspectRatio;
}

- (void)setAspectRatio:(NSSize)ratio
{
	_aspectRatio = ratio;
	_renderer.aspectRatio = ratio;
	[self setNeedsDisplay:YES];
}

- (NSRect)cropRect
{
	return _cropRect;
}

- (void)setCropRect:(NSRect)aRect
{
	_cropRect = aRect;
	_renderer.cropRect = aRect;
	[self setNeedsDisplay:YES];
}

- (BOOL)vsync
{
	return _vsync;
}

- (void)setVsync:(BOOL)flag
{
	_vsync = flag;
	// MTKView handles vsync automatically
}

- (NSCell<ECVVideoViewCell> *)cell
{
	return _cell;
}

- (void)setCell:(NSCell<ECVVideoViewCell> *)cell
{
	if (cell == _cell) return;
	_cell = cell;
	[self setNeedsDisplay:YES];
	[[self window] invalidateCursorRectsForView:self];
}

- (void)pushFrame:(ECVVideoFrame *)frame
{
	NSLog(@"[ECV-TRACE] VideoView.pushFrame: frame=%@ renderer=%@", frame, _renderer);
	[_renderer pushFrame:frame];
}

#pragma mark -Private

- (NSRect)outputRect
{
	return _outputRect;
}

- (void)_updateOutputRect
{
	NSRect const b = [self bounds];
	NSSize const aspectRatio = [self aspectRatio];
	_outputRect = b;
	
	if (aspectRatio.width > 0 && aspectRatio.height > 0) {
		CGFloat const r = (aspectRatio.width / aspectRatio.height) / (NSWidth(b) / NSHeight(b));
		if (r > 1.0f) _outputRect.size.height *= 1.0f / r;
		else _outputRect.size.width *= r;
		_outputRect.origin = NSMakePoint(NSMidX(b) - NSWidth(_outputRect) / 2.0f, NSMidY(b) - NSHeight(_outputRect) / 2.0f);
	}
}

- (void)_drawResizeHandle
{
	NSWindow *const w = [self window];
	if (!w || ![w showsResizeIndicator] || !([w styleMask] & NSWindowStyleMaskResizable)) return;
	
	// This will need to be reimplemented using Metal or AppKit drawing
	// For now, skip the resize handle drawing
}

#pragma mark -NSView

- (BOOL)isFlipped
{
	return YES;
}

- (BOOL)isOpaque
{
	return YES;
}

- (void)resetCursorRects
{
	[[self cell] resetCursorRect:_outputRect inView:self];
}

- (void)viewWillMoveToWindow:(NSWindow *)aWindow
{
	if ([self window]) {
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidChangeScreenNotification object:[self window]];
	}
	if (aWindow) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidChangeScreen) name:NSWindowDidChangeScreenNotification object:aWindow];
	}
}

- (void)viewDidMoveToWindow
{
	[self windowDidChangeScreen];
}

#pragma mark -NSResponder

- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (void)keyDown:(NSEvent *)anEvent
{
	if (![[self ecvDelegate] videoView:self handleKeyDown:anEvent]) [super keyDown:anEvent];
}

- (void)mouseDown:(NSEvent *)anEvent
{
	NSCell *const cell = [self cell];
	if ([[cell class] prefersTrackingUntilMouseUp]) {
		[cell trackMouse:anEvent inRect:_outputRect ofView:self untilMouseUp:YES];
		return;
	}
	
	BOOL const playing = [_renderer isPlaying];
	NSEvent *latestEvent = anEvent;
	do {
		if ([self mouse:[self convertPoint:[latestEvent locationInWindow] fromView:nil] inRect:_outputRect]) {
			[cell setHighlighted:YES];
			if (!playing) [self setNeedsDisplay:YES];
			if ([cell trackMouse:latestEvent inRect:_outputRect ofView:self untilMouseUp:NO]) break;
			[cell setHighlighted:NO];
			if (!playing) [self setNeedsDisplay:YES];
		}
		latestEvent = [[self window] nextEventMatchingMask:NSEventMaskLeftMouseUp | NSEventMaskLeftMouseDragged untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:YES];
	} while ([latestEvent type] != NSEventTypeLeftMouseUp);
	[[self window] discardEventsMatchingMask:NSEventMaskAny beforeEvent:latestEvent];
	[cell setHighlighted:NO];
	if (!playing) [self setNeedsDisplay:YES];
}

#pragma mark -NSObject

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark -NSObject(NSNibAwaking)

- (void)awakeFromNib
{
	NSLog(@"[ECV-TRACE] VideoView.awakeFromNib");
	_cropRect = ECVUncroppedRect;
	
	// Initialize Metal renderer
	_renderer = [[ECVMetalRenderer alloc] initWithView:self];
	NSLog(@"[ECV-TRACE] VideoView.awakeFromNib: renderer=%@", _renderer);
}

#pragma mark -Window Notifications

- (void)windowDidChangeScreen
{
	// Update renderer for screen changes if needed
}

@end

@implementation NSObject(ECVVideoViewDelegate)

- (BOOL)videoView:(ECVVideoView *)sender handleKeyDown:(NSEvent *)anEvent
{
	return NO;
}

@end
