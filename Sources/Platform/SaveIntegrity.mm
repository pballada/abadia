#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#include "system.h"
static NSString *Digest(NSData *data) {
    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes,(CC_LONG)data.length,hash);
    NSMutableString *result=[NSMutableString string];
    for (auto byte:hash) [result appendFormat:@"%02x",byte];
    return result;
}
bool System::sealSave(const std::string& path) {
    NSString *name=@(path.c_str());
    NSData *payload=[NSData dataWithContentsOfFile:name];
    if (!payload || !payload.length || payload.length>1024*1024) return false;
    NSMutableData *sealed=[payload mutableCopy];
    NSString *footer=[NSString stringWithFormat:@"// ABADIA-MAC-SAVE-1 %@\n",Digest(payload)];
    [sealed appendData:[footer dataUsingEncoding:NSUTF8StringEncoding]];
    return [sealed writeToFile:name options:NSDataWritingAtomic error:nil];
}
bool System::validateSave(const std::string& path) {
    NSData *data=[NSData dataWithContentsOfFile:@(path.c_str()) options:NSDataReadingMappedIfSafe error:nil];
    if (!data || data.length>1024*1024) return false;
    const NSUInteger footerLength=86; // marker (21), SHA256 (64), newline (1)
    if (data.length<=footerLength) return false;
    NSData *payload=[data subdataWithRange:NSMakeRange(0,data.length-footerLength)];
    NSString *footer=[[NSString alloc] initWithData:[data subdataWithRange:NSMakeRange(data.length-footerLength,footerLength)] encoding:NSUTF8StringEncoding];
    return [footer isEqual:[NSString stringWithFormat:@"// ABADIA-MAC-SAVE-1 %@\n",Digest(payload)]];
}
