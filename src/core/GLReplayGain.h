// ReplayGain: the loudness change that the tags of a track ask for.

#import "GLDecoder.h"
#import "GLSettings.h"
#import "GLTrack.h"

// The factor that the samples of `track` get. Album mode uses the album gain
// and falls back to the track gain. Track mode does the opposite. The factor
// is never so large that the peak goes above full scale. With no gain, or
// with the mode off, the factor is 1.
double GLReplayGainFactor(GLTrack *track, GLReplayGainMode mode);

// A decoder that multiplies the samples of another decoder by a factor.
@interface GLGainDecoder : NSObject <GLDecoder>
// Returns `decoder` itself when the factor is 1.
+ (id<GLDecoder>)decoderWithDecoder:(id<GLDecoder>)decoder factor:(double)factor;
@end
