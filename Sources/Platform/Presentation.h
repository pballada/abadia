#pragma once
#import <CoreGraphics/CoreGraphics.h>
// Returns a retained image. The enhanced path reconstructs the original
// 320x200 pixel grid, then applies two edge-aware Scale2x passes.
CGImageRef CreateGameImage(bool enhanced);
