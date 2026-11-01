#pragma once
#import <Foundation/Foundation.h>
NSURL *AbadiaSupportDirectory();
NSString *ValidateAssets(NSURL *directory);
BOOL ImportAssets(NSURL *source, NSURL *support, NSError **error);
int RunSelfTests();

NSURL *FindAssetDirectory(NSURL *selection);

// Downloads the data pack from the pinned Abbey commit on GitHub, verifies every
// file by SHA-256, and imports it. Callbacks run on the main queue.
extern NSString *const AbadiaDataSourceURL;
void DownloadAssets(NSURL *support, void (^progress)(double fraction), void (^completion)(NSError *error));
