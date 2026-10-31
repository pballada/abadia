#import "Presentation.h"
#include "system.h"
#include <vector>
#include <algorithm>

static std::vector<uint32_t> Scale2x(const std::vector<uint32_t>& source, int w, int h) {
    std::vector<uint32_t> result(w*h*4);
    auto pixel = [&](int x, int y) { return source[std::clamp(y,0,h-1)*w+std::clamp(x,0,w-1)]; };
    for (int y=0;y<h;++y) for (int x=0;x<w;++x) {
        auto b=pixel(x,y-1), d=pixel(x-1,y), e=pixel(x,y), f=pixel(x+1,y), g=pixel(x,y+1);
        uint32_t p0=e,p1=e,p2=e,p3=e;
        if (b!=g && d!=f) {
            if (d==b) p0=d;
            if (b==f) p1=f;
            if (d==g) p2=d;
            if (g==f) p3=f;
        }
        int i=y*2*w*2+x*2;
        result[i]=p0; result[i+1]=p1; result[i+w*2]=p2; result[i+w*2+1]=p3;
    }
    return result;
}
CGImageRef CreateGameImage(bool enhanced) {
    int width=640,height=400;
    std::vector<uint32_t> pixels;
    if (enhanced) {
        pixels.resize(320*200);
        for (int y=0;y<200;++y) for (int x=0;x<320;++x)
            pixels[y*320+x]=sys->framebuffer[y*2*640+x*2];
        pixels=Scale2x(pixels,320,200);
        pixels=Scale2x(pixels,640,400);
        width=1280; height=800;
    }
    const void *bytes=enhanced ? pixels.data() : sys->framebuffer.data();
    CFDataRef data=CFDataCreate(nullptr,static_cast<const UInt8 *>(bytes),width*height*4);
    CGDataProviderRef provider=CGDataProviderCreateWithCFData(data);
    CGColorSpaceRef color=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGImageRef image=CGImageCreate(width,height,8,32,width*4,color,
        kCGBitmapByteOrder32Big|kCGImageAlphaLast,provider,nullptr,false,kCGRenderingIntentDefault);
    CGColorSpaceRelease(color); CGDataProviderRelease(provider); CFRelease(data);
    return image;
}
