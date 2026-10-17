// GLArtCache makes small JPEG copies of the art of each album and keeps them
// on disk. A list cell shows a copy at its own size, so the A5 chip never
// scales a large picture while the list scrolls.
//
// The art comes from the picture in a file, or from an image in the folder
// of the file: cover, folder, front, or albumart, as JPEG or PNG.
// The methods read files and decode images. Call them away from the main
// thread.

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

@interface GLArtCache : NSObject

+ (instancetype)shared;

// The cache keeps its files in `directory`.
- (instancetype)initWithDirectory:(NSString *)directory;

// The path of a square JPEG of `pixels` x `pixels` for the album `key`, made
// from the art of the audio file at `path` (a full path). Returns nil when
// the album has no art. The second call for the same key and size reads no
// audio file.
- (NSString *)thumbnailForKey:(NSString *)key audioPath:(NSString *)path pixels:(NSUInteger)pixels;

// A dark, blurred copy of the art for the back of the player screen, or nil.
- (NSString *)backgroundForKey:(NSString *)key audioPath:(NSString *)path;

// The art at full size, as JPEG or PNG data, or nil. The lock screen shows it.
- (NSData *)originalArtForAudioPath:(NSString *)path;

// Removes the copies of the album `key`, of each size.
- (void)removeKey:(NSString *)key;

// Removes all copies.
- (void)clear;

@end
