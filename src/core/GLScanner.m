#import "GLScanner.h"
#import "GLTags.h"

@implementation GLScanResult
@end

@interface GLScanner ()
@property (nonatomic, strong) GLLibrary *library;
@property (nonatomic, copy) NSString *directory;
@property (nonatomic, copy) BOOL (^isAudio)(NSString *path);
@property (nonatomic, copy) double (^duration)(NSString *path);
@end

@implementation GLScanner

- (instancetype)initWithLibrary:(GLLibrary *)library
                      directory:(NSString *)directory
                        isAudio:(BOOL (^)(NSString *path))isAudio
                       duration:(double (^)(NSString *path))duration {
    if ((self = [super init])) {
        _library = library;
        _directory = [directory copy];
        _isAudio = [isAudio copy];
        _duration = [duration copy];
    }
    return self;
}

- (GLScanResult *)scan {
    NSDate *start = [NSDate date];
    GLScanResult *result = [GLScanResult new];
    NSMutableDictionary *stamps = [[self.library fileStamps] mutableCopy];
    NSMutableArray *batch = [NSMutableArray array];
    NSMutableSet *changedAlbums = [NSMutableSet set];
    NSMutableArray *playlists = [NSMutableArray array];
    NSFileManager *files = [NSFileManager new];
    NSDirectoryEnumerator *walk = [files enumeratorAtURL:[NSURL fileURLWithPath:self.directory]
                              includingPropertiesForKeys:@[ NSURLFileSizeKey, NSURLContentModificationDateKey,
                                                            NSURLIsDirectoryKey ]
                                                 options:NSDirectoryEnumerationSkipsHiddenFiles
                                            errorHandler:nil];
    NSString *root = [self.directory.stringByStandardizingPath stringByAppendingString:@"/"];
    for (NSURL *url in walk) {
        @autoreleasepool {
            NSNumber *isDirectory = nil;
            [url getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:NULL];
            NSString *full = url.path.stringByStandardizingPath;
            if (isDirectory.boolValue || ![full hasPrefix:root]) continue;
            NSString *path = [full substringFromIndex:root.length];
            if (self.isPlaylist && self.isPlaylist(full)) {
                [playlists addObject:path];
                continue;
            }
            if (!self.isAudio(full)) continue;
            NSNumber *size = nil;
            NSDate *date = nil;
            [url getResourceValue:&size forKey:NSURLFileSizeKey error:NULL];
            [url getResourceValue:&date forKey:NSURLContentModificationDateKey error:NULL];
            double modified = floor(date.timeIntervalSince1970);
            result.total++;
            NSArray *known = stamps[path];
            [stamps removeObjectForKey:path];
            if (!self.readAll && known && [known[0] longLongValue] == size.longLongValue &&
                [known[1] doubleValue] == modified) {
                continue;
            }
            GLTrack *track = [GLTrack trackWithPath:path tags:GLReadTags(full, NO)];
            track.fileSize = size.longLongValue;
            track.modified = modified;
            track.duration = self.duration ? self.duration(full) : 0;
            [batch addObject:track];
            [changedAlbums addObject:track.albumKey];
            if (known) {
                // The file can have moved to another album. Its old album changed too.
                NSString *old = [self.library trackWithPath:path].albumKey;
                if (old) [changedAlbums addObject:old];
                result.changed++;
            }
            else result.added++;
            // Write in batches, so that a long scan shows its first results.
            if (batch.count >= 200) {
                [self.library saveTracks:batch];
                [batch removeAllObjects];
                [self.library postChange];
            }
        }
    }
    [self.library saveTracks:batch];
    // The rows that no file matched are gone.
    for (NSString *path in stamps) {
        NSString *old = [self.library trackWithPath:path].albumKey;
        if (old) [changedAlbums addObject:old];
    }
    [self.library removePaths:stamps.allKeys];
    result.changedAlbumKeys = changedAlbums;
    if (self.isPlaylist) [self.library setPlaylistFiles:playlists];
    result.removed = stamps.count;
    result.seconds = -[start timeIntervalSinceNow];
    if (result.added || result.changed || result.removed) [self.library postChange];
    return result;
}

@end
