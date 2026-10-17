// Loads the art of the albums into the views, away from the main thread.
// It keeps the newest images in memory. A view that gets a new request
// before the old one ends shows only the new image.

#import <UIKit/UIKit.h>

@interface GLImageLoader : NSObject

+ (instancetype)shared;

// Shows the art of the album `key` in `layer`, at `points` x `points`. The
// art comes from the audio file `path` (relative to the music directory) or
// its folder. The layer shows the cover of the app until the art is ready,
// and when there is no art.
- (void)showArtOfAlbum:(NSString *)key path:(NSString *)path points:(CGFloat)points inLayer:(CALayer *)layer;

// Calls `completion` on the main thread with the blurred art, or nil.
- (void)loadBackgroundOfAlbum:(NSString *)key path:(NSString *)path completion:(void (^)(UIImage *image))completion;

// The cover of the app for a track with no art.
+ (UIImage *)placeholder;

// Forgets the images in memory.
- (void)clear;

@end
