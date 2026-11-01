#import "Assets.h"
#import "Updater.h"
#import <CommonCrypto/CommonDigest.h>
#include <cstdio>

static NSDictionary<NSString *, NSString *> *RequiredAssets() {
    return @{
        @"abadia.dsk": @"282d7263c5e0129d5f88b33afe890eb6188b0c79bed9344c4b8562135d49f6f5",
        @"GraficosCPC": @"aeeebc6a3ad95a83ab314dd3a15630f787ea36bfc57ed25e15c0c9c0d26a53b2",
        @"GraficosVGA": @"5947879e5217a3e3a54db293955c40edc7765c9958d82d58ecc9ede628d2dafe"
    };
}

// Optional audio from the same Abbey commit. Only used to verify downloads;
// a player's own WAV files are imported as-is.
static NSDictionary<NSString *, NSString *> *KnownAudio() {
    return @{
        @"abrir.wav": @"7e441b66be3e2e75470bd73805a2cd776a995cec7729a8ce21a6c95e10325832",
        @"aporrear.wav": @"47c48e954825dfabd0bf8cf6b3fcb37ae808ad32fabbac6dbc07ed75336a4565",
        @"campanas.wav": @"78a29c8e3cedc500861d8b3c715728d30be49cec53a7266e19794349537d977f",
        @"cerrar.wav": @"ed32189e9131954fbc7d7a2e8ea214dc02d7feab5264ad035a640c6befaab256",
        @"coger.wav": @"d0a8457981615883283be271f3ee07fd30c0ba432e397fbf46196d1df810b3d1",
        @"dejar.wav": @"ad16baaf2ca73faca9179a571e952f9aff41dd43edd6166bac3184de2c300690",
        @"espejo.wav": @"930863e1ee49fecc1c1275b254283d7532b8cd3d03d2ab01fcdd919f7fe7a2ca",
        @"final.wav": @"005979a1822ec9e6c0892b20e4699dbfc0e796209ce5f5d9c5ae259eed3ae422",
        @"fondo.wav": @"ffbe59589a81a86599e4bbcd6509687fd23e3d941ec11fc21c086f9a6ffe22fa",
        @"inicio.wav": @"872f9b2cbb9b9435996f645d842f9a0f420ef66e0376e9287a461e672ba05d2e",
        @"pasos.wav": @"e74322352d7b182bcae04f155bccd888192754daead211aae8c43902957a1268",
        @"tintineo.wav": @"0c055e460087a79b8838cd684814b059056a4c751527b772f8ed1d71e2a28e35"
    };
}

NSString *const AbadiaDataSourceURL = @"https://github.com/Samuel85/Abbey/tree/048c3141f0bd1772c8b0bba82d18ebc72d837be1/build/roms/abadia";
static NSString *const RawDataURL = @"https://raw.githubusercontent.com/Samuel85/Abbey/048c3141f0bd1772c8b0bba82d18ebc72d837be1/build/roms/abadia/";

static NSString *SHA256Hex(NSData *data) {
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
    NSMutableString *hash = [NSMutableString string];
    for (unsigned char byte : digest) [hash appendFormat:@"%02x", byte];
    return hash;
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
        if (![SHA256Hex(data) isEqual:RequiredAssets()[name]])
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

void DownloadAssets(NSURL *support, void (^progress)(double), void (^completion)(NSError *)) {
    NSFileManager *fm = NSFileManager.defaultManager;
    NSURL *staging = [fm.temporaryDirectory URLByAppendingPathComponent:[@"abadia-download-" stringByAppendingString:NSUUID.UUID.UUIDString] isDirectory:YES];
    [fm createDirectoryAtURL:staging withIntermediateDirectories:YES attributes:nil error:nil];
    NSMutableDictionary<NSString *, NSString *> *expected = [RequiredAssets() mutableCopy];
    [expected addEntriesFromDictionary:KnownAudio()];
    // Required files first, so a failure is reported before the larger music downloads.
    NSMutableArray<NSString *> *names = [[RequiredAssets().allKeys sortedArrayUsingSelector:@selector(compare:)] mutableCopy];
    [names addObjectsFromArray:[KnownAudio().allKeys sortedArrayUsingSelector:@selector(compare:)]];
    NSURLSessionConfiguration *config = NSURLSessionConfiguration.ephemeralSessionConfiguration;
    config.timeoutIntervalForRequest = 30;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:config];
    // `next` refers to itself until `finish` breaks the cycle.
    __block void (^next)(NSUInteger) = nil;
    void (^finish)(NSError *) = ^(NSError *error) {
        NSError *importError = error;
        if (!importError) ImportAssets(staging, support, &importError);
        [fm removeItemAtURL:staging error:nil];
        [session finishTasksAndInvalidate];
        // Release the chain only after the running block has returned.
        dispatch_async(dispatch_get_main_queue(), ^{ next = nil; completion(importError); });
    };
    next = ^(NSUInteger index) {
        if (index == names.count) { finish(nil); return; }
        NSString *name = names[index];
        BOOL required = RequiredAssets()[name] != nil;
        dispatch_async(dispatch_get_main_queue(), ^{ progress((double)index / names.count); });
        NSURL *url = [NSURL URLWithString:[RawDataURL stringByAppendingString:name]];
        [[session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSInteger status = [response isKindOfClass:NSHTTPURLResponse.class] ? ((NSHTTPURLResponse *)response).statusCode : 0;
            BOOL valid = data && status == 200 && [SHA256Hex(data) isEqual:expected[name]];
            if (valid) valid = [data writeToURL:[staging URLByAppendingPathComponent:name] atomically:YES];
            if (!valid && required) {
                NSString *reason = error.localizedDescription ?: [NSString stringWithFormat:@"%@ could not be downloaded or did not match the expected checksum.", name];
                finish([NSError errorWithDomain:@"Abadia" code:3 userInfo:@{NSLocalizedDescriptionKey:reason}]);
                return;
            }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-retain-cycles"
            next(index + 1); // Optional audio that fails verification is skipped.
#pragma clang diagnostic pop
        }] resume];
    };
    next(0);
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
    check(AbadiaCompareVersions(@"0.10.0", @"0.9.9") == NSOrderedDescending, "updater compares versions numerically");
    check(AbadiaCompareVersions(@"0.3", @"0.3.0") == NSOrderedSame, "updater treats missing version parts as zero");
    check(AbadiaCompareVersions(@"0.2.2", @"0.3.0") == NSOrderedAscending, "updater never offers an older release");
    return failures ? 1 : 0;
}
