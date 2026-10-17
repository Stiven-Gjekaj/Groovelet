// GLScanner makes the index agree with the files in the music directory.
// It reads the tags of each new or changed file, and it removes the rows of
// the files that are gone. A file is "changed" when its size or its time of
// change differs from the row.

#import <Foundation/Foundation.h>
#import "GLLibrary.h"

@interface GLScanResult : NSObject
@property (nonatomic) NSUInteger added;
@property (nonatomic) NSUInteger changed;
@property (nonatomic) NSUInteger removed;
@property (nonatomic) NSUInteger total;
@property (nonatomic) NSTimeInterval seconds;
// The album keys of the files that the scan added, changed, or removed. The
// art of these albums can be different now.
@property (nonatomic, strong) NSSet *changedAlbumKeys;
@end

@interface GLScanner : NSObject

// `isAudio` tells which files to index. `duration` gives the length of a
// file in seconds. Both get the full path.
- (instancetype)initWithLibrary:(GLLibrary *)library
                      directory:(NSString *)directory
                        isAudio:(BOOL (^)(NSString *path))isAudio
                       duration:(double (^)(NSString *path))duration;

// Runs the scan on the calling thread, and posts the change of the library
// when a row changed.
- (GLScanResult *)scan;

@end
