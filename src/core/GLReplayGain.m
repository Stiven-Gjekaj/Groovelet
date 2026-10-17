#import "GLReplayGain.h"

double GLReplayGainFactor(GLTrack *track, GLReplayGainMode mode) {
    if (mode == GLReplayGainOff || !track) return 1;
    BOOL album = mode == GLReplayGainAlbum;
    double gain = album ? track.albumGain : track.trackGain;
    double peak = album ? track.albumPeak : track.trackPeak;
    if (isnan(gain)) {
        gain = album ? track.trackGain : track.albumGain;
        peak = album ? track.trackPeak : track.albumPeak;
    }
    if (isnan(gain)) return 1;
    double factor = pow(10, gain / 20);
    if (!isnan(peak) && peak > 0 && factor * peak > 1) factor = 1 / peak;
    return factor;
}

@interface GLGainDecoder ()
@property (nonatomic, strong) id<GLDecoder> inner;
@property (nonatomic) int32_t factorQ14;  // The factor in 1/16384 units
@end

@implementation GLGainDecoder

+ (id<GLDecoder>)decoderWithDecoder:(id<GLDecoder>)decoder factor:(double)factor {
    if (!decoder || fabs(factor - 1) < 0.001) return decoder;
    GLGainDecoder *gain = [GLGainDecoder new];
    gain.inner = decoder;
    gain.factorQ14 = (int32_t)lround(MIN(factor, 8.0) * 16384);
    return gain;
}

- (double)duration {
    return self.inner.duration;
}

- (NSInteger)readFrames:(int16_t *)buffer count:(NSUInteger)frames {
    NSInteger n = [self.inner readFrames:buffer count:frames];
    int32_t factor = self.factorQ14;
    for (NSInteger i = 0; i < n * GLOutputChannels; i++) {
        int32_t value = (buffer[i] * factor) >> 14;
        buffer[i] = (int16_t)(value > 32767 ? 32767 : value < -32768 ? -32768 : value);
    }
    return n;
}

- (BOOL)seekToTime:(double)seconds {
    return [self.inner seekToTime:seconds];
}

@end
