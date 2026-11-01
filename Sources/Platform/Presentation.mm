#import "Presentation.h"
#include "system.h"

CGImageRef CreateGameImage() {
    constexpr int width=640,height=400;
    CFDataRef data=CFDataCreate(nullptr,reinterpret_cast<const UInt8 *>(sys->framebuffer.data()),width*height*4);
    CGDataProviderRef provider=CGDataProviderCreateWithCFData(data);
    CGColorSpaceRef color=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGImageRef image=CGImageCreate(width,height,8,32,width*4,color,
        kCGBitmapByteOrder32Big|kCGImageAlphaLast,provider,nullptr,false,kCGRenderingIntentDefault);
    CGColorSpaceRelease(color); CGDataProviderRelease(provider); CFRelease(data);
    return image;
}
