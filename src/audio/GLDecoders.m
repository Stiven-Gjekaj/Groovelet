#import "GLDecoders.h"
#import "GLAppleDecoder.h"

static NSSet *GLAppleExtensions(void) {
    static NSSet *set;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        set = [NSSet setWithObjects:@"mp3", @"m4a", @"m4b", @"aac", @"mp4", @"wav", @"aif", @"aiff", @"aifc", @"caf", nil];
    });
    return set;
}

id<GLDecoder> GLOpenDecoder(NSString *path, NSError **error) {
    return [GLAppleDecoder decoderWithPath:path error:error];
}

BOOL GLIsAudioPath(NSString *path) {
    return [GLAppleExtensions() containsObject:path.pathExtension.lowercaseString];
}
