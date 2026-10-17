#import "GLLibraryUpdater.h"
#import "GLArtCache.h"
#import "GLDecoders.h"
#import "GLLog.h"
#import "GLPaths.h"

NSString *const GLScanDidStartNotification = @"GLScanDidStart";
NSString *const GLScanDidEndNotification = @"GLScanDidEnd";

@interface GLLibraryUpdater ()
@property (nonatomic) BOOL scanning;
@property (nonatomic) BOOL again;
@property (nonatomic) BOOL readAll;
@property (nonatomic, strong) GLScanResult *lastResult;
@property (nonatomic, strong) dispatch_queue_t queue;
@end

@implementation GLLibraryUpdater

+ (instancetype)shared {
    static GLLibraryUpdater *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [GLLibraryUpdater new]; });
    return shared;
}

- (instancetype)init {
    if ((self = [super init])) {
        _queue = dispatch_queue_create("GLLibraryUpdater", DISPATCH_QUEUE_SERIAL);
        dispatch_set_target_queue(_queue, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0));
    }
    return self;
}

- (void)scanAllFiles {
    self.readAll = YES;
    [self scan];
}

- (void)scan {
    if (self.scanning) {
        self.again = YES;
        return;
    }
    self.scanning = YES;
    BOOL readAll = self.readAll;
    self.readAll = NO;
    [[NSNotificationCenter defaultCenter] postNotificationName:GLScanDidStartNotification object:self];
    dispatch_async(self.queue, ^{
        GLScanner *scanner = [[GLScanner alloc] initWithLibrary:[GLLibrary shared] directory:GLMusicDirectory()
            isAudio:^BOOL(NSString *path) { return GLIsAudioPath(path); }
            duration:^double(NSString *path) { return GLOpenDecoder(path, NULL).duration; }];
        scanner.readAll = readAll;
        scanner.isPlaylist = ^BOOL(NSString *path) {
            NSString *extension = path.pathExtension.lowercaseString;
            return [extension isEqualToString:@"m3u"] || [extension isEqualToString:@"m3u8"];
        };
        GLScanResult *result = [scanner scan];
        // The art of a changed album is made again when a screen asks for it.
        for (NSString *key in result.changedAlbumKeys) [[GLArtCache shared] removeKey:key];
        GLLog(@"scan: %lu files, %lu added, %lu changed, %lu removed, %.1f s", (unsigned long)result.total,
              (unsigned long)result.added, (unsigned long)result.changed, (unsigned long)result.removed, result.seconds);
        dispatch_async(dispatch_get_main_queue(), ^{
            self.lastResult = result;
            self.scanning = NO;
            [[NSNotificationCenter defaultCenter] postNotificationName:GLScanDidEndNotification object:result];
            // The lists show the new art after the cache forgot the old art.
            if (result.changedAlbumKeys.count) [[GLLibrary shared] postChange];
            if (self.again) {
                self.again = NO;
                [self scan];
            }
        });
    });
}

@end
