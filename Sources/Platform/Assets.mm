#import "Assets.h"
#import <CommonCrypto/CommonDigest.h>
#include <cstdio>

static NSDictionary<NSString *, NSString *> *RequiredAssets() {
    return @{
        @"abadia.dsk": @"282d7263c5e0129d5f88b33afe890eb6188b0c79bed9344c4b8562135d49f6f5",
        @"GraficosCPC": @"aeeebc6a3ad95a83ab314dd3a15630f787ea36bfc57ed25e15c0c9c0d26a53b2",
        @"GraficosVGA": @"5947879e5217a3e3a54db293955c40edc7765c9958d82d58ecc9ede628d2dafe"
    };
}

NSURL *AbadiaSupportDirectory() {
    NSURL *base = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
    return [base URLByAppendingPathComponent:@"Abadia" isDirectory:YES];
}

NSString *ValidateAssets(NSURL *directory) {
    for (NSString *name in [RequiredAssets().allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        NSURL *url = [directory URLByAppendingPathComponent:name];
        NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:url.path error:nil];
        NSUInteger expectedSize = [name isEqual:@"abadia.dsk"] ? 160768 : 174065;
        if (![attributes[NSFileType] isEqual:NSFileTypeRegular] || [attributes[NSFileSize] unsignedLongLongValue] != expectedSize)
            return [NSString stringWithFormat:@"Missing or unsupported %@. Select the folder containing abadia.dsk, GraficosCPC and GraficosVGA from the Abbey data pack.", name];
        NSData *data = [NSData dataWithContentsOfURL:url];
        if (!data) return [NSString stringWithFormat:@"Could not read %@.", name];
        unsigned char digest[CC_SHA256_DIGEST_LENGTH];
        CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
        NSMutableString *hash = [NSMutableString string];
        for (unsigned char byte : digest) [hash appendFormat:@"%02x", byte];
        if (![hash isEqual:RequiredAssets()[name]])
            return [NSString stringWithFormat:@"%@ is not the supported version. This port requires the unchanged Abbey / VIGASOCO data pack. Your files have not been changed.", name];
    }
    return nil;
}

NSURL *FindAssetDirectory(NSURL *selection) {
    for (NSString *path in @[@"", @"abadia", @"roms/abadia", @"build/roms/abadia"]) {
        NSURL *candidate = path.length ? [selection URLByAppendingPathComponent:path] : selection;
        if (!ValidateAssets(candidate)) return candidate;
    }
    return nil;
}

BOOL ImportAssets(NSURL *source, NSURL *support, NSError **error) {
    NSString *problem = ValidateAssets(source);
    if (problem) {
        if (error) *error = [NSError errorWithDomain:@"Abadia" code:1 userInfo:@{NSLocalizedDescriptionKey:problem}];
        return NO;
    }
    NSFileManager *fm = NSFileManager.defaultManager;
    NSURL *roms = [support URLByAppendingPathComponent:@"roms" isDirectory:YES];
    if (![fm createDirectoryAtURL:roms withIntermediateDirectories:YES attributes:nil error:error]) return NO;
    NSURL *target = [roms URLByAppendingPathComponent:@"abadia" isDirectory:YES];
    NSURL *staging = [roms URLByAppendingPathComponent:NSUUID.UUID.UUIDString isDirectory:YES];
    if (![fm createDirectoryAtURL:staging withIntermediateDirectories:NO attributes:nil error:error]) return NO;
    NSMutableArray *files = [NSMutableArray arrayWithArray:RequiredAssets().allKeys];
    [files addObjectsFromArray:@[@"inicio.wav", @"final.wav", @"fondo.wav", @"abrir.wav", @"aporrear.wav", @"campanas.wav", @"cerrar.wav", @"coger.wav", @"dejar.wav", @"espejo.wav", @"pasos.wav", @"tintineo.wav"]];
    for (NSString *name in files) {
        NSURL *from = [source URLByAppendingPathComponent:name];
        if (![fm fileExistsAtPath:from.path]) continue; // Audio is optional.
        if (![fm copyItemAtURL:from toURL:[staging URLByAppendingPathComponent:name] error:error]) {
            [fm removeItemAtURL:staging error:nil];
            return NO;
        }
    }
    // Validate the staged bytes, too, before exposing them to the legacy engine.
    problem = ValidateAssets(staging);
    if (problem) {
        [fm removeItemAtURL:staging error:nil];
        if (error) *error = [NSError errorWithDomain:@"Abadia" code:2 userInfo:@{NSLocalizedDescriptionKey:problem}];
        return NO;
    }
    BOOL ok;
    if ([fm fileExistsAtPath:target.path])
        ok = [fm replaceItemAtURL:target withItemAtURL:staging backupItemName:nil options:0 resultingItemURL:nil error:error];
    else ok = [fm moveItemAtURL:staging toURL:target error:error];
    if (!ok) [fm removeItemAtURL:staging error:nil];
    return ok;
}

int RunSelfTests() {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSURL *temp = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString] isDirectory:YES];
    [fm createDirectoryAtURL:temp withIntermediateDirectories:YES attributes:nil error:nil];
    int failures = 0;
    auto check = [&](bool condition, const char *name) {
        printf("%s %s\n", condition ? "PASS" : "FAIL", name);
        if (!condition) ++failures;
    };
    check(ValidateAssets(temp) != nil, "missing data is rejected before engine initialization");
    [NSData.data writeToURL:[temp URLByAppendingPathComponent:@"abadia.dsk"] atomically:YES];
    check(ValidateAssets(temp) != nil, "truncated disk image is rejected");
    for (NSString *name in [RequiredAssets().allKeys sortedArrayUsingSelector:@selector(compare:)]) {
        NSMutableData *data = [NSMutableData dataWithLength:[name isEqual:@"abadia.dsk"] ? 160768 : 174065];
        [data writeToURL:[temp URLByAppendingPathComponent:name] atomically:YES];
    }
    check(ValidateAssets(temp) != nil, "same-size corrupt assets fail SHA-256 validation");
    NSURL *destination = [temp URLByAppendingPathComponent:@"destination"];
    NSError *error = nil;
    check(!ImportAssets(temp, destination, &error) && error != nil, "invalid import returns a useful error");
    check(![fm fileExistsAtPath:destination.path], "invalid import does not alter destination");
    [fm removeItemAtURL:temp error:nil];
    return failures ? 1 : 0;
}
