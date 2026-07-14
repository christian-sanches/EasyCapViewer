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
#import "EasyCapViewer-Swift.h"

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
	NSWindow *const window = [ECVWelcomeSwiftHelper createWelcomeWindow];
	[self setWindow:window];
}

@end
