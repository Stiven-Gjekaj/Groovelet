#import "GLImageLoader.h"
#import <objc/runtime.h>
#import "GLArtCache.h"
#import "GLLibraryUpdater.h"
#import "GLPaths.h"

static char GLRequestKey;

@interface GLImageLoader ()
@property (nonatomic, strong) NSCache *memory;
@property (nonatomic, strong) dispatch_queue_t queue;
@end

@implementation GLImageLoader

+ (instancetype)shared {
    static GLImageLoader *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [GLImageLoader new]; });
    return shared;
}

+ (UIImage *)placeholder {
    return [UIImage imageNamed:@"Cover.png"];
}

- (instancetype)init {
    if ((self = [super init])) {
        _memory = [NSCache new];
        _memory.countLimit = 300;
        // One serial queue: the A5 chip has two cores, and the main thread
        // needs one of them to scroll.
        _queue = dispatch_queue_create("GLImageLoader", DISPATCH_QUEUE_SERIAL);
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(clear)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(scanEnded:)
                                                     name:GLScanDidEndNotification object:nil];
    }
    return self;
}

- (void)clear {
    [self.memory removeAllObjects];
}

- (void)scanEnded:(NSNotification *)notification {
    GLScanResult *result = notification.object;
    if (result.changedAlbumKeys.count) [self clear];
}

- (void)showArtOfAlbum:(NSString *)key path:(NSString *)path points:(CGFloat)points inLayer:(CALayer *)layer {
    CGFloat scale = [UIScreen mainScreen].scale;
    NSUInteger pixels = (NSUInteger)(points * scale);
    NSString *memoryKey = [NSString stringWithFormat:@"%@|%lu", key, (unsigned long)pixels];
    objc_setAssociatedObject(layer, &GLRequestKey, memoryKey, OBJC_ASSOCIATION_COPY_NONATOMIC);
    id cached = [self.memory objectForKey:memoryKey];
    if (cached) {
        UIImage *image = [cached isKindOfClass:[UIImage class]] ? cached : [GLImageLoader placeholder];
        layer.contents = (id)image.CGImage;
        return;
    }
    layer.contents = (id)[GLImageLoader placeholder].CGImage;
    if (!key || !path) return;
    __weak CALayer *weakLayer = layer;
    dispatch_async(self.queue, ^{
        // A request for a layer that shows another album now is dropped.
        __block BOOL wanted = YES;
        dispatch_sync(dispatch_get_main_queue(), ^{
            wanted = weakLayer && [objc_getAssociatedObject(weakLayer, &GLRequestKey) isEqualToString:memoryKey];
        });
        if (!wanted) return;
        NSString *file = [[GLArtCache shared] thumbnailForKey:key audioPath:GLAbsolutePath(path) pixels:pixels];
        UIImage *image = file ? [UIImage imageWithContentsOfFile:file] : nil;
        // Decode the JPEG here, not on the main thread.
        if (image) {
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(points, points), YES, scale);
            [image drawInRect:CGRectMake(0, 0, points, points)];
            image = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.memory setObject:image ?: [NSNull null] forKey:memoryKey];
            CALayer *target = weakLayer;
            if (!image || !target) return;
            if (![objc_getAssociatedObject(target, &GLRequestKey) isEqualToString:memoryKey]) return;
            target.contents = (id)image.CGImage;
        });
    });
}

- (void)loadBackgroundOfAlbum:(NSString *)key path:(NSString *)path completion:(void (^)(UIImage *image))completion {
    if (!key || !path) {
        completion(nil);
        return;
    }
    dispatch_async(self.queue, ^{
        NSString *file = [[GLArtCache shared] backgroundForKey:key audioPath:GLAbsolutePath(path)];
        UIImage *image = file ? [UIImage imageWithContentsOfFile:file] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{ completion(image); });
    });
}

@end
