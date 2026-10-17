// Tests of GLArtCache with images that the tests draw.

#import <ImageIO/ImageIO.h>
#import "GLArtCache.h"
#import "GLTagBuilder.h"
#import "GLTest.h"

// A PNG of `width` x `height` pixels in one color.
static NSData *GLColorPNG(size_t width, size_t height) {
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(NULL, width, height, 8, width * 4, space,
                                                 (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGContextSetRGBFillColor(context, 1, 0.42, 0.29, 1);
    CGContextFillRect(context, CGRectMake(0, 0, width, height));
    CGImageRef image = CGBitmapContextCreateImage(context);
    NSMutableData *png = [NSMutableData data];
    CGImageDestinationRef destination = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)png,
                                                                         CFSTR("public.png"), 1, NULL);
    CGImageDestinationAddImage(destination, image, NULL);
    CGImageDestinationFinalize(destination);
    CFRelease(destination);
    CGImageRelease(image);
    CGContextRelease(context);
    CGColorSpaceRelease(space);
    return png;
}

static CGSize GLImageSize(NSString *path) {
    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path], NULL);
    NSDictionary *properties = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL));
    CFRelease(source);
    return CGSizeMake([properties[(__bridge NSString *)kCGImagePropertyPixelWidth] doubleValue],
                      [properties[(__bridge NSString *)kCGImagePropertyPixelHeight] doubleValue]);
}

GL_TEST(test_art_cache_makes_a_square_copy_of_the_picture_in_a_file) {
    NSData *frame = GLID3Frame(@"APIC", GLID3PictureBody(3, GLColorPNG(600, 400)), 3);
    NSString *song = GLWriteFile(@"a.mp3", @[ GLID3Tag(@[ frame ], 3, 0), GLFakeAudio(100) ]);
    GLArtCache *cache = [[GLArtCache alloc] initWithDirectory:GLTestTemporaryDirectory()];
    NSString *thumbnail = [cache thumbnailForKey:@"album" audioPath:song pixels:88];
    GL_EXPECT(thumbnail != nil);
    CGSize size = GLImageSize(thumbnail);
    GL_EXPECT(size.width == 88 && size.height == 88);
    // The second call reads the copy, also when the song is gone.
    [[NSFileManager defaultManager] removeItemAtPath:song error:NULL];
    GL_EQUAL([cache thumbnailForKey:@"album" audioPath:song pixels:88], thumbnail);
}

GL_TEST(test_art_cache_uses_the_cover_image_of_the_folder) {
    NSString *song = GLWriteFile(@"b.flac", @[ GLFakeAudio(100) ]);
    NSString *folder = song.stringByDeletingLastPathComponent;
    [GLColorPNG(50, 50) writeToFile:[folder stringByAppendingPathComponent:@"back.png"] atomically:YES];
    [GLColorPNG(300, 300) writeToFile:[folder stringByAppendingPathComponent:@"Folder.PNG"] atomically:YES];
    [GLColorPNG(200, 200) writeToFile:[folder stringByAppendingPathComponent:@"cover.jpg"] atomically:YES];
    GLArtCache *cache = [[GLArtCache alloc] initWithDirectory:GLTestTemporaryDirectory()];
    NSData *original = [cache originalArtForAudioPath:song];
    GL_EQUAL(original, GLColorPNG(200, 200));
    GL_EXPECT([cache backgroundForKey:@"b" audioPath:song] != nil);
}

GL_TEST(test_art_cache_remembers_an_album_with_no_art) {
    NSString *song = GLWriteFile(@"c.mp3", @[ GLFakeAudio(100) ]);
    NSString *directory = GLTestTemporaryDirectory();
    GLArtCache *cache = [[GLArtCache alloc] initWithDirectory:directory];
    GL_EXPECT([cache thumbnailForKey:@"none" audioPath:song pixels:88] == nil);
    // Art that comes later does not show until the cache is cleared.
    [GLColorPNG(100, 100) writeToFile:[song.stringByDeletingLastPathComponent stringByAppendingPathComponent:@"cover.png"]
                           atomically:YES];
    GL_EXPECT([cache thumbnailForKey:@"none" audioPath:song pixels:88] == nil);
    [cache removeKey:@"other"];
    GL_EXPECT([cache thumbnailForKey:@"none" audioPath:song pixels:88] == nil);
    [cache removeKey:@"none"];
    GL_EXPECT([cache thumbnailForKey:@"none" audioPath:song pixels:88] != nil);
    [cache clear];
    GL_EQUAL_INT([[NSFileManager defaultManager] contentsOfDirectoryAtPath:directory error:NULL].count, 0);
}
