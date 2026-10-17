// GLLibraryUpdater runs the scan of the music directory away from the main
// thread. Only one scan runs at a time. A request during a scan makes one
// more scan after it.

#import <Foundation/Foundation.h>
#import "GLScanner.h"

// Posted on the main thread when a scan starts and when it ends. The object
// of the end is the GLScanResult.
extern NSString *const GLScanDidStartNotification;
extern NSString *const GLScanDidEndNotification;

@interface GLLibraryUpdater : NSObject

+ (instancetype)shared;

@property (nonatomic, readonly) BOOL scanning;
@property (nonatomic, strong, readonly) GLScanResult *lastResult;

- (void)scan;
// Reads each file again, also when it did not change.
- (void)scanAllFiles;

@end
