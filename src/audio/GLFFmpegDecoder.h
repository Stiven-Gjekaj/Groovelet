// A decoder that uses FFmpeg. It reads FLAC, Opus, Ogg Vorbis, APE, and
// WavPack. The resampler of FFmpeg changes the sample rate, the sample
// format, and the channels into the format of the output.

#import "GLDecoder.h"

@interface GLFFmpegDecoder : NSObject <GLDecoder>

// Opens the file. Returns nil when FFmpeg cannot read it.
+ (instancetype)decoderWithPath:(NSString *)path error:(NSError **)error;

@end
