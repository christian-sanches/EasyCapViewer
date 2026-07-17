/* Copyright (c) 2012, Ben Trask
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
#import "ECVDebug.h"

/* Equivalent formats (preferred constant listed first):
- k2vuyPixelFormat, kCVPixelFormatType_422YpCbCr8, k422YpCbCr8CodecType
	- kUYVY422PixelFormat seems to be the same but Core Video doesn't like it.
- kYVYU422PixelFormat, kIOYVYU422PixelFormat
*/

static size_t ECVPixelFormatBytesPerPixel(OSType const t)
{
	switch(t) {
		case k2vuyPixelFormat: return 2;
		case kYVYU422PixelFormat: return 2;
	}
	NSLog(@"Unknown pixel format '%d'", (int)t);
	return 0;
}

static uint64_t ECVPixelFormatBlackPattern(OSType const t)
{
	switch(t) {
		case k2vuyPixelFormat: return CFSwapInt64HostToBig(0x8010801080108010ULL);
		case kYVYU422PixelFormat: return CFSwapInt64HostToBig(0x1080108010801080ULL);
	}
	NSLog(@"Unknown pixel format '%d'", (int)t);
	return 0;
}

// Metal pixel format helpers
static BOOL ECVPixelFormatIsUYVY(OSType const t)
{
	return t == k2vuyPixelFormat;
}

static BOOL ECVPixelFormatIsYVYU(OSType const t)
{
	return t == kYVYU422PixelFormat;
}
