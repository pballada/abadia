#pragma once
#import <Foundation/Foundation.h>
NSURL *AbadiaSupportDirectory();
NSString *ValidateAssets(NSURL *directory);
BOOL ImportAssets(NSURL *source, NSURL *support, NSError **error);
int RunSelfTests();
