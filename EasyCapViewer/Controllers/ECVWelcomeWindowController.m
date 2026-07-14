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
#import "ECVWelcomeWindowController.h"

static ECVWelcomeWindowController *ECVSharedWelcomeWindowController;

@implementation ECVWelcomeWindowController

#pragma mark +ECVWelcomeWindowController

+ (id)sharedWelcomeWindowController
{
	return ECVSharedWelcomeWindowController;
}

#pragma mark +NSObject

+ (void)initialize
{
	if(!ECVSharedWelcomeWindowController) ECVSharedWelcomeWindowController = [[self alloc] init];
}

#pragma mark -ECVWelcomeWindowController

- (void)ECV_showWelcome
{
	[[self window] center];
	[[self window] makeKeyAndOrderFront:nil];
}
- (void)ECV_closeWelcome
{
	[[self window] close];
}

#pragma mark -NSObject

- (id)init
{
	if((self = [super init])) {
		[self loadWindow];
	}
	return self;
}

#pragma mark -NSWindowController

- (void)loadWindow
{
	NSRect const contentRect = NSMakeRect(0, 0, 420, 200);
	NSWindow *const window = [[NSWindow alloc] initWithContentRect:contentRect styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable backing:NSBackingStoreBuffered defer:YES];
	[window setTitle:@"EasyCapViewer"];
	[window setReleasedWhenClosed:NO];
	[window setMinSize:NSMakeSize(420, 200)];

	NSView *const contentView = [window contentView];

	NSTextField *const messageField = [[NSTextField alloc] initWithFrame:NSMakeRect(60, 120, 300, 24)];
	[messageField setStringValue:NSLocalizedString(@"No capture device found", nil)];
	[messageField setFont:[NSFont boldSystemFontOfSize:16]];
	[messageField setBezeled:NO];
	[messageField setDrawsBackground:NO];
	[messageField setEditable:NO];
	[messageField setSelectable:NO];
	[messageField setAlignment:NSTextAlignmentCenter];
	[messageField setAutoresizingMask:NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin];
	[contentView addSubview:messageField];

	NSTextField *const subtitleField = [[NSTextField alloc] initWithFrame:NSMakeRect(60, 90, 300, 17)];
	[subtitleField setStringValue:NSLocalizedString(@"Connect an EasyCap DC60 to your computer to begin.", nil)];
	[subtitleField setFont:[NSFont systemFontOfSize:[NSFont systemFontSize]]];
	[subtitleField setBezeled:NO];
	[subtitleField setDrawsBackground:NO];
	[subtitleField setEditable:NO];
	[subtitleField setSelectable:NO];
	[subtitleField setAlignment:NSTextAlignmentCenter];
	[subtitleField setTextColor:[NSColor secondaryLabelColor]];
	[subtitleField setAutoresizingMask:NSViewMinXMargin | NSViewMaxXMargin | NSViewMinYMargin];
	[contentView addSubview:subtitleField];

	[self setWindow:window];
}

@end
