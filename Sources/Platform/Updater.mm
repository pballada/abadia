#import "Updater.h"
#import <Security/Security.h>
#include <unistd.h>

static NSString *const LatestReleaseAPI = @"https://api.github.com/repos/pballada/abadia/releases/latest";
static NSString *const ReleaseAssetName = @"Abadia-macOS.zip";
static NSString *const LastCheckKey = @"UpdaterLastCheck";
static NSString *const SkippedVersionKey = @"UpdaterSkippedVersion";
static NSString *const AutomaticKey = @"UpdaterAutomaticallyChecks";
// Developer ID Application certificate of team 5UXXXESGMK, signing this bundle identifier.
static NSString *const ReleaseRequirement =
    @"anchor apple generic and identifier \"net.pballada.abadia\" "
    @"and certificate 1[field.1.2.840.113635.100.6.2.6] exists "
    @"and certificate leaf[field.1.2.840.113635.100.6.1.13] exists "
    @"and certificate leaf[subject.OU] = \"5UXXXESGMK\"";

NSComparisonResult AbadiaCompareVersions(NSString *a, NSString *b) {
    NSArray<NSString *> *x = [a componentsSeparatedByString:@"."], *y = [b componentsSeparatedByString:@"."];
    for (NSUInteger i = 0; i < MAX(x.count, y.count); ++i) {
        NSInteger p = i < x.count ? x[i].integerValue : 0, q = i < y.count ? y[i].integerValue : 0;
        if (p != q) return p < q ? NSOrderedAscending : NSOrderedDescending;
    }
    return NSOrderedSame;
}

static NSString *CurrentVersion() {
    return NSBundle.mainBundle.infoDictionary[@"CFBundleShortVersionString"] ?: @"0";
}

static SecRequirementRef CreateRequirement() {
    SecRequirementRef requirement = nullptr;
    SecRequirementCreateWithString((__bridge CFStringRef)ReleaseRequirement, kSecCSDefaultFlags, &requirement);
    return requirement;
}

// Development builds are ad-hoc signed; they never check automatically.
static BOOL RunningReleaseBuild() {
    SecCodeRef code = nullptr;
    SecRequirementRef requirement = CreateRequirement();
    BOOL ok = requirement && SecCodeCopySelf(kSecCSDefaultFlags, &code) == errSecSuccess &&
              SecCodeCheckValidity(code, kSecCSDefaultFlags, requirement) == errSecSuccess;
    if (code) CFRelease(code);
    if (requirement) CFRelease(requirement);
    return ok;
}

static BOOL IsTrustedRelease(NSURL *app, NSString **version) {
    SecStaticCodeRef code = nullptr;
    SecRequirementRef requirement = CreateRequirement();
    BOOL ok = requirement && SecStaticCodeCreateWithPath((__bridge CFURLRef)app, kSecCSDefaultFlags, &code) == errSecSuccess &&
              SecStaticCodeCheckValidity(code, kSecCSCheckAllArchitectures | kSecCSStrictValidate | kSecCSCheckNestedCode, requirement) == errSecSuccess;
    if (code) CFRelease(code);
    if (requirement) CFRelease(requirement);
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfURL:[app URLByAppendingPathComponent:@"Contents/Info.plist"]];
    *version = info[@"CFBundleShortVersionString"];
    return ok && [info[@"CFBundleIdentifier"] isEqual:NSBundle.mainBundle.bundleIdentifier];
}

static NSError *UpdateError(NSString *message) {
    return [NSError errorWithDomain:@"AbadiaUpdater" code:1 userInfo:@{NSLocalizedDescriptionKey:message}];
}

@implementation AbadiaUpdater {
    BOOL _busy;
}

- (BOOL)automaticallyChecks {
    id value = [NSUserDefaults.standardUserDefaults objectForKey:AutomaticKey];
    return value ? [value boolValue] : YES;
}
- (void)setAutomaticallyChecks:(BOOL)value { [NSUserDefaults.standardUserDefaults setBool:value forKey:AutomaticKey]; }

- (void)checkInBackgroundIfDue {
    if (!self.automaticallyChecks || !RunningReleaseBuild()) return;
    NSDate *last = [NSUserDefaults.standardUserDefaults objectForKey:LastCheckKey];
    if (last && -last.timeIntervalSinceNow < 24 * 60 * 60) return;
    [self checkInteractively:NO];
}

- (void)checkForUpdates:(id)sender { [self checkInteractively:YES]; }

- (void)show:(NSString *)title detail:(NSString *)detail buttons:(NSArray<NSString *> *)buttons completion:(void (^)(NSModalResponse))completion {
    NSAlert *alert = [NSAlert new];
    alert.messageText = title; alert.informativeText = detail;
    for (NSString *button in buttons) [alert addButtonWithTitle:button];
    if (self.presentAlert) self.presentAlert(alert, completion ?: ^(NSModalResponse) {});
}

- (void)checkInteractively:(BOOL)interactive {
    if (_busy) return;
    _busy = YES;
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:LatestReleaseAPI]];
    [request setValue:@"application/vnd.github+json" forHTTPHeaderField:@"Accept"];
    [request setValue:[@"Abadia/" stringByAppendingString:CurrentVersion()] forHTTPHeaderField:@"User-Agent"];
    request.timeoutInterval = 20;
    [[NSURLSession.sharedSession dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSDictionary *release = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_busy = NO;
            NSInteger status = [response isKindOfClass:NSHTTPURLResponse.class] ? ((NSHTTPURLResponse *)response).statusCode : 0;
            if (status != 200 || ![release isKindOfClass:NSDictionary.class]) {
                if (interactive) [self show:@"Could not check for updates" detail:error.localizedDescription ?: @"GitHub did not return release information. Try again later." buttons:@[@"OK"] completion:nil];
                return;
            }
            [NSUserDefaults.standardUserDefaults setObject:NSDate.date forKey:LastCheckKey];
            [self handleRelease:release interactive:interactive];
        });
    }] resume];
}

- (void)handleRelease:(NSDictionary *)release interactive:(BOOL)interactive {
    NSString *tag = [release[@"tag_name"] isKindOfClass:NSString.class] ? release[@"tag_name"] : @"";
    NSString *version = [tag hasPrefix:@"v"] ? [tag substringFromIndex:1] : tag;
    NSString *page = [release[@"html_url"] isKindOfClass:NSString.class] ? release[@"html_url"] : @"https://github.com/pballada/abadia/releases/latest";
    NSURL *asset = nil;
    for (NSDictionary *item in release[@"assets"])
        if ([item isKindOfClass:NSDictionary.class] && [item[@"name"] isEqual:ReleaseAssetName])
            asset = [NSURL URLWithString:item[@"browser_download_url"]];
    if (!version.length || AbadiaCompareVersions(version, CurrentVersion()) != NSOrderedDescending) {
        if (interactive) [self show:@"You’re up to date" detail:[NSString stringWithFormat:@"La abadía del crimen %@ is the latest version.", CurrentVersion()] buttons:@[@"OK"] completion:nil];
        return;
    }
    if (!interactive && [[NSUserDefaults.standardUserDefaults stringForKey:SkippedVersionKey] isEqual:version]) return;
    NSString *notes = [release[@"body"] isKindOfClass:NSString.class] ? release[@"body"] : @"";
    if (notes.length > 700) notes = [[notes substringToIndex:700] stringByAppendingString:@"…"];
    NSString *detail = [NSString stringWithFormat:@"You have %@. The update keeps your game data and saves. The app relaunches to finish; save your game first.\n\n%@", CurrentVersion(), notes];
    NSArray *buttons = interactive ? @[@"Install and Relaunch", @"Later"] : @[@"Install and Relaunch", @"Later", @"Skip This Version"];
    [self show:[NSString stringWithFormat:@"Version %@ is available", version] detail:detail buttons:buttons completion:^(NSModalResponse response) {
        if (response == NSAlertThirdButtonReturn) [NSUserDefaults.standardUserDefaults setObject:version forKey:SkippedVersionKey];
        if (response != NSAlertFirstButtonReturn) return;
        if (!asset || ![self canReplaceRunningApp]) { [self offerManualDownload:page]; return; }
        [self install:asset page:page];
    }];
}

- (BOOL)canReplaceRunningApp {
    NSURL *bundle = NSBundle.mainBundle.bundleURL;
    NSFileManager *fm = NSFileManager.defaultManager;
    return ![bundle.path containsString:@"/AppTranslocation/"] &&
           [fm isWritableFileAtPath:bundle.URLByDeletingLastPathComponent.path] &&
           [fm isWritableFileAtPath:bundle.path];
}

- (void)offerManualDownload:(NSString *)page {
    [self show:@"Install this update manually"
        detail:@"This copy of the app cannot replace itself. Move it to your Applications folder for automatic updates next time. For now, download the new version and replace the app; your game data and saves are kept."
       buttons:@[@"Open Download Page", @"Cancel"]
    completion:^(NSModalResponse response) {
        if (response == NSAlertFirstButtonReturn) [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:page]];
    }];
}

- (void)install:(NSURL *)asset page:(NSString *)page {
    if (_busy) return;
    _busy = YES;
    NSURL *bundle = NSBundle.mainBundle.bundleURL;
    [[NSURLSession.sharedSession downloadTaskWithURL:asset completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        NSError *failure = error;
        NSURL *newApp = nil;
        NSFileManager *fm = NSFileManager.defaultManager;
        // Stage on the app's volume so the final swap is a rename.
        NSURL *staging = [fm URLForDirectory:NSItemReplacementDirectory inDomain:NSUserDomainMask appropriateForURL:bundle create:YES error:nil];
        NSInteger status = [response isKindOfClass:NSHTTPURLResponse.class] ? ((NSHTTPURLResponse *)response).statusCode : 0;
        if (!failure && (status != 200 || !location || !staging)) failure = UpdateError(@"The update could not be downloaded.");
        if (!failure) {
            NSURL *zip = [staging URLByAppendingPathComponent:ReleaseAssetName];
            [fm moveItemAtURL:location toURL:zip error:nil];
            NSTask *ditto = [NSTask launchedTaskWithExecutableURL:[NSURL fileURLWithPath:@"/usr/bin/ditto"]
                arguments:@[@"-x", @"-k", zip.path, staging.path] error:&failure terminationHandler:nil];
            [ditto waitUntilExit];
            if (!failure && ditto.terminationStatus != 0) failure = UpdateError(@"The update archive could not be opened.");
            for (NSURL *item in [fm contentsOfDirectoryAtURL:staging includingPropertiesForKeys:nil options:0 error:nil])
                if ([item.pathExtension isEqual:@"app"]) newApp = item;
        }
        NSString *version = nil;
        if (!failure && (!newApp || !IsTrustedRelease(newApp, &version)))
            failure = UpdateError(@"The downloaded app is not signed by the La abadía del crimen release team. Nothing was changed.");
        if (!failure && AbadiaCompareVersions(version, CurrentVersion()) != NSOrderedDescending)
            failure = UpdateError(@"The downloaded app is not newer than this version. Nothing was changed.");
        if (!failure) [fm replaceItemAtURL:bundle withItemAtURL:newApp backupItemName:nil options:0 resultingItemURL:nil error:&failure];
        if (staging) [fm removeItemAtURL:staging error:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            self->_busy = NO;
            if (failure) {
                [self show:@"The update could not be installed" detail:failure.localizedDescription buttons:@[@"Open Download Page", @"Cancel"] completion:^(NSModalResponse response) {
                    if (response == NSAlertFirstButtonReturn) [NSWorkspace.sharedWorkspace openURL:[NSURL URLWithString:page]];
                }];
                return;
            }
            [self relaunch:bundle];
        });
    }] resume];
}

- (void)relaunch:(NSURL *)bundle {
    // Wait for this process to exit, then open the replaced bundle.
    NSString *script = @"while /bin/kill -0 \"$0\" 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open \"$1\"";
    [NSTask launchedTaskWithExecutableURL:[NSURL fileURLWithPath:@"/bin/sh"]
        arguments:@[@"-c", script, @(getpid()).stringValue, bundle.path] error:nil terminationHandler:nil];
    [NSApp terminate:nil];
}
@end
