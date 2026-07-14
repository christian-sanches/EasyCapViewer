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
#import "ECVErrorLogController.h"
#import "EasyCapViewer-Swift.h"

static ECVErrorLogController *ECVSharedErrorLogController;

@implementation ECVErrorLogController

#pragma mark +ECVErrorLogController

+ (id)sharedErrorLogController
{
	return ECVSharedErrorLogController;
}

#pragma mark +NSObject

+ (void)initialize
{
	if(!ECVSharedErrorLogController) ECVSharedErrorLogController = [[self alloc] init];
}

#pragma mark -ECVErrorLogController

- (void)logLevel:(ECVErrorLevel)level message:(NSString *)message
{
	NSString *const trimmed = [message stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	dispatch_async(dispatch_get_main_queue(), ^{
		[self->_model appendLevel:(NSUInteger)level message:trimmed];
	});
}
- (void)logLevel:(ECVErrorLevel)level format:(NSString *)format arguments:(va_list)arguments
{
	[self logLevel:level message:[[NSString alloc] initWithFormat:format arguments:arguments]];
}
- (void)logLevel:(ECVErrorLevel)level format:(NSString *)format, ...
{
	va_list arguments;
	va_start(arguments, format);
	[self logLevel:level format:format arguments:arguments];
	va_end(arguments);
}

#pragma mark -NSWindowController

- (void)loadWindow
{
	_model = [[ErrorLogModel alloc] init];
	NSWindow *const window = [ECVErrorLogSwiftHelper createErrorLogWindowWithModel:_model];
	[self setWindow:window];
}

#pragma mark -NSObject

- (id)init
{
	if((self = [super init])) {
		[self loadWindow];
	}
	return self;
}

@end
