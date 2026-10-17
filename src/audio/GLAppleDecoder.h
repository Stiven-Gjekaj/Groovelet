// A decoder that uses the decoders of iOS through ExtAudioFile. It reads
// MP3, AAC, ALAC, WAV, and AIFF. ExtAudioFile changes the sample rate and
// the channels into the format of the output.

#import "GLDecoder.h"

@interface GLAppleDecoder : NSObject <GLDecoder>

// Opens the file. Returns nil when iOS cannot read it.
+ (instancetype)decoderWithPath:(NSString *)path error:(NSError **)error;

@end
