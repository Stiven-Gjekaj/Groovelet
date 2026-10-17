// Tests of ReplayGain.

#import "GLReplayGain.h"
#import "GLTest.h"

static GLTrack *GLGainTrack(double trackGain, double trackPeak, double albumGain, double albumPeak) {
    GLTrack *track = [GLTrack trackWithPath:@"a.mp3"];
    track.trackGain = trackGain;
    track.trackPeak = trackPeak;
    track.albumGain = albumGain;
    track.albumPeak = albumPeak;
    return track;
}

GL_TEST(test_replaygain_uses_the_gain_of_the_mode) {
    GLTrack *track = GLGainTrack(-6.0206, NAN, -12.0412, NAN);
    GL_EXPECT(fabs(GLReplayGainFactor(track, GLReplayGainTrack) - 0.5) < 1e-4);
    GL_EXPECT(fabs(GLReplayGainFactor(track, GLReplayGainAlbum) - 0.25) < 1e-4);
    GL_EXPECT(GLReplayGainFactor(track, GLReplayGainOff) == 1);
}

GL_TEST(test_replaygain_falls_back_to_the_other_gain) {
    GL_EXPECT(fabs(GLReplayGainFactor(GLGainTrack(NAN, NAN, -6.0206, NAN), GLReplayGainTrack) - 0.5) < 1e-4);
    GL_EXPECT(fabs(GLReplayGainFactor(GLGainTrack(-6.0206, NAN, NAN, NAN), GLReplayGainAlbum) - 0.5) < 1e-4);
    GL_EXPECT(GLReplayGainFactor(GLGainTrack(NAN, NAN, NAN, NAN), GLReplayGainTrack) == 1);
}

GL_TEST(test_replaygain_keeps_the_peak_below_full_scale) {
    // +6 dB doubles the samples. With a peak of 0.8, the factor stops at 1.25.
    GL_EXPECT(fabs(GLReplayGainFactor(GLGainTrack(6.0206, 0.8, NAN, NAN), GLReplayGainTrack) - 1.25) < 1e-4);
}

@interface GLConstantDecoder : NSObject <GLDecoder>
@property (nonatomic) int16_t value;
@end

@implementation GLConstantDecoder
- (double)duration { return 1; }
- (BOOL)seekToTime:(double)seconds { return YES; }
- (NSInteger)readFrames:(int16_t *)buffer count:(NSUInteger)frames {
    for (NSUInteger i = 0; i < frames * GLOutputChannels; i++) buffer[i] = self.value;
    return (NSInteger)frames;
}
@end

GL_TEST(test_gain_decoder_scales_and_clips_the_samples) {
    GLConstantDecoder *source = [GLConstantDecoder new];
    source.value = 10000;
    id<GLDecoder> half = [GLGainDecoder decoderWithDecoder:source factor:0.5];
    int16_t buffer[8];
    [half readFrames:buffer count:4];
    GL_EQUAL_INT(buffer[0], 5000);
    id<GLDecoder> loud = [GLGainDecoder decoderWithDecoder:source factor:4];
    [loud readFrames:buffer count:4];
    GL_EQUAL_INT(buffer[7], 32767);
    source.value = -10000;
    [loud readFrames:buffer count:4];
    GL_EQUAL_INT(buffer[3], -32768);
    GL_EXPECT([GLGainDecoder decoderWithDecoder:source factor:1] == source);
}
