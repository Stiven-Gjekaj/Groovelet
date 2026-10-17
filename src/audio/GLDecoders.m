#import "GLDecoders.h"
#import "GLAppleDecoder.h"
#import "GLFFmpegDecoder.h"
#include <libavutil/log.h>

static NSSet *GLAppleExtensions(void) {
    static NSSet *set;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        set = [NSSet setWithObjects:@"mp3", @"m4a", @"m4b", @"aac", @"mp4", @"wav", @"aif", @"aiff", @"aifc", @"caf", nil];
    });
    return set;
}

static NSSet *GLFFmpegExtensions(void) {
    static NSSet *set;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        set = [NSSet setWithObjects:@"flac", @"opus", @"ogg", @"oga", @"ape", @"wv", @"mka", nil];
        av_log_set_level(AV_LOG_ERROR);
    });
    return set;
}

id<GLDecoder> GLOpenDecoder(NSString *path, NSError **error) {
    NSString *extension = path.pathExtension.lowercaseString;
    if ([GLFFmpegExtensions() containsObject:extension]) return [GLFFmpegDecoder decoderWithPath:path error:error];
    // A file with the extension of iOS can hold another format. FFmpeg tries
    // the files that iOS cannot read.
    id<GLDecoder> decoder = [GLAppleDecoder decoderWithPath:path error:error];
    return decoder ?: [GLFFmpegDecoder decoderWithPath:path error:error];
}

BOOL GLIsAudioPath(NSString *path) {
    NSString *extension = path.pathExtension.lowercaseString;
    return [GLAppleExtensions() containsObject:extension] || [GLFFmpegExtensions() containsObject:extension];
}
