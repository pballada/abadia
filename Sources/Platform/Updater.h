#pragma once
#import <AppKit/AppKit.h>

// Self-updater backed by GitHub Releases. An update is installed only when the
// downloaded app carries a valid Developer ID signature from the release team
// with this bundle identifier and a newer version.
@interface AbadiaUpdater : NSObject
// Presents an alert as a sheet and reports the button the player chose.
@property(nonatomic, copy) void (^presentAlert)(NSAlert *alert, void (^completion)(NSModalResponse response));
@property(nonatomic) BOOL automaticallyChecks;
- (void)checkInBackgroundIfDue;
- (void)checkForUpdates:(id)sender;
@end

// Exposed for the asset-free self test.
NSComparisonResult AbadiaCompareVersions(NSString *a, NSString *b);
