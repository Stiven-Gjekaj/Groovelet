#import "GLArtCache.h"
#import <CommonCrypto/CommonDigest.h>
#import <ImageIO/ImageIO.h>
#import "GLPaths.h"
#import "GLTags.h"

@interface GLArtCache ()
@property (nonatomic, copy) NSString *directory;
@end

@implementation GLArtCache

+ (instancetype)shared {
    static GLArtCache *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[GLArtCache alloc] initWithDirectory:[GLCacheDirectory() stringByAppendingPathComponent:@"Art"]];
    });
    return shared;
}

- (instancetype)initWithDirectory:(NSString *)directory {
    if ((self = [super init])) {
        _directory = [directory copy];
        [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil
                                                        error:NULL];
    }
    return self;
}

- (void)clear {
    [[NSFileManager defaultManager] removeItemAtPath:self.directory error:NULL];
    [[NSFileManager defaultManager] createDirectoryAtPath:self.directory withIntermediateDirectories:YES attributes:nil
                                                    error:NULL];
}

// A file name for the key: its SHA-1 in hex.
static NSString *GLDigest(NSString *key) {
    NSData *bytes = [key dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_SHA1_DIGEST_LENGTH];
    CC_SHA1(bytes.bytes, (CC_LONG)bytes.length, digest);
    NSMutableString *hex = [NSMutableString string];
    for (int i = 0; i < CC_SHA1_DIGEST_LENGTH; i++) [hex appendFormat:@"%02x", digest[i]];
    return hex;
}

- (void)removeKey:(NSString *)key {
    NSString *prefix = [GLDigest(key) stringByAppendingString:@"-"];
    NSFileManager *files = [NSFileManager defaultManager];
    for (NSString *name in [files contentsOfDirectoryAtPath:self.directory error:NULL]) {
        if ([name hasPrefix:prefix]) [files removeItemAtPath:[self.directory stringByAppendingPathComponent:name] error:NULL];
    }
}

#pragma mark The source

// An image file in the folder of the audio file, or nil.
static NSString *GLFolderImage(NSString *audioPath) {
    NSString *folder = audioPath.stringByDeletingLastPathComponent;
    NSArray *names = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:folder error:NULL];
    NSString *best = nil;
    NSInteger bestRank = NSIntegerMax;
    NSArray *preferred = @[ @"cover", @"folder", @"front", @"albumart" ];
    for (NSString *name in names) {
        NSString *extension = name.pathExtension.lowercaseString;
        if (![@[ @"jpg", @"jpeg", @"png" ] containsObject:extension]) continue;
        NSString *base = name.stringByDeletingPathExtension.lowercaseString;
        for (NSUInteger rank = 0; rank < preferred.count; rank++) {
            if ([base hasPrefix:preferred[rank]] && (NSInteger)rank < bestRank) {
                best = name;
                bestRank = (NSInteger)rank;
            }
        }
    }
    return best ? [folder stringByAppendingPathComponent:best] : nil;
}

- (NSData *)originalArtForAudioPath:(NSString *)path {
    NSData *picture = GLReadTags(path, YES).picture;
    if (picture.length) return picture;
    NSString *image = GLFolderImage(path);
    return image ? [NSData dataWithContentsOfFile:image] : nil;
}

#pragma mark The copies

static BOOL GLWriteJPEG(CGImageRef image, NSString *path) {
    NSURL *url = [NSURL fileURLWithPath:path];
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)url, CFSTR("public.jpeg"), 1,
                                                                        NULL);
    if (!destination) return NO;
    NSDictionary *options = @{ (__bridge NSString *)kCGImageDestinationLossyCompressionQuality: @0.82 };
    CGImageDestinationAddImage(destination, image, (__bridge CFDictionaryRef)options);
    BOOL ok = CGImageDestinationFinalize(destination);
    CFRelease(destination);
    return ok;
}

// Draws `image` into a square of `pixels`, so that it fills the square and
// its middle stays. With `blur`, it draws a very small copy first and scales
// it up, which blurs it, and it puts a dark layer over it.
static CGImageRef GLSquareImage(CGImageRef image, size_t pixels, BOOL blur) {
    size_t width = CGImageGetWidth(image), height = CGImageGetHeight(image);
    if (!width || !height) return NULL;
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, pixels, pixels, 8, pixels * 4, space,
                                                 kCGImageAlphaNoneSkipLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    if (!context) return NULL;
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
    CGFloat scale = MAX((CGFloat)pixels / width, (CGFloat)pixels / height);
    CGRect rect = CGRectMake((pixels - width * scale) / 2, (pixels - height * scale) / 2, width * scale, height * scale);
    if (blur) {
        CGImageRef small = GLSquareImage(image, 12, NO);
        if (small) {
            CGContextDrawImage(context, CGRectMake(0, 0, pixels, pixels), small);
            CGImageRelease(small);
        }
        CGContextSetRGBFillColor(context, 0, 0, 0, 0.62);
        CGContextFillRect(context, CGRectMake(0, 0, pixels, pixels));
    } else {
        CGContextDrawImage(context, rect, image);
    }
    CGImageRef result = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    return result;
}

// Decodes the art at a size near `pixels`. ImageIO makes the small copy
// while it decodes, which is fast for a large JPEG.
static CGImageRef GLDecodeArt(NSData *data, size_t pixels) {
    CGImageSourceRef source = CGImageSourceCreateWithData((__bridge CFDataRef)data, NULL);
    if (!source) return NULL;
    NSDictionary *options = @{
        (__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
        (__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize: @(pixels * 2),
        (__bridge NSString *)kCGImageSourceCreateThumbnailWithTransform: @YES,
    };
    CGImageRef image = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)options);
    CFRelease(source);
    return image;
}

- (NSString *)copyForKey:(NSString *)key audioPath:(NSString *)path pixels:(NSUInteger)pixels blur:(BOOL)blur {
    NSString *base = [self.directory stringByAppendingPathComponent:
        [NSString stringWithFormat:@"%@-%lu%@", GLDigest(key), (unsigned long)pixels, blur ? @"b" : @""]];
    NSString *jpeg = [base stringByAppendingPathExtension:@"jpg"];
    NSString *none = [base stringByAppendingPathExtension:@"none"];
    NSFileManager *files = [NSFileManager defaultManager];
    if ([files fileExistsAtPath:jpeg]) return jpeg;
    if ([files fileExistsAtPath:none]) return nil;
    NSData *art = [self originalArtForAudioPath:path];
    CGImageRef decoded = art ? GLDecodeArt(art, pixels) : NULL;
    CGImageRef square = decoded ? GLSquareImage(decoded, pixels, blur) : NULL;
    BOOL written = square && GLWriteJPEG(square, jpeg);
    if (decoded) CGImageRelease(decoded);
    if (square) CGImageRelease(square);
    if (written) return jpeg;
    // Remember that the album has no art, so that the next call is fast.
    [[NSData data] writeToFile:none atomically:NO];
    return nil;
}

- (NSString *)thumbnailForKey:(NSString *)key audioPath:(NSString *)path pixels:(NSUInteger)pixels {
    return [self copyForKey:key audioPath:path pixels:pixels blur:NO];
}

- (NSString *)backgroundForKey:(NSString *)key audioPath:(NSString *)path {
    return [self copyForKey:key audioPath:path pixels:320 blur:YES];
}

@end
