// Tests of GLFFmpegDecoder on the phone, with the files of scripts/fixtures.sh.
// Each file holds 2 seconds of a sine of 440 Hz.

#import "GLAudioTestSupport.h"
#import "GLDecoders.h"
#import "GLFFmpegDecoder.h"
#import "GLTest.h"

static void GLExpectTwoSeconds(NSString *name) {
    id<GLDecoder> decoder = GLOpenDecoder(GLFixturePath(name), NULL);
    GL_EXPECT(decoder != nil);
    GL_EXPECT([decoder isKindOfClass:[GLFFmpegDecoder class]]);
    GL_EXPECT(fabs(decoder.duration - 2) < 0.05);
    NSUInteger frames = GLCountFrames(decoder);
    // The resampler can keep a few frames, and an Opus file has a small pad.
    GL_EXPECT(frames >= 88200 - 64 && frames <= 88200 + 64);
    if (!(frames >= 88200 - 64 && frames <= 88200 + 64)) printf("  %s: %lu frames\n", name.UTF8String, (unsigned long)frames);
}

GL_TEST(test_ffmpeg_decoder_reads_flac) {
    GLExpectTwoSeconds(@"flac-44100.flac");
}

GL_TEST(test_ffmpeg_decoder_reads_24_bit_96_khz_flac_at_the_output_rate) {
    GLExpectTwoSeconds(@"flac-96000-24.flac");
}

GL_TEST(test_ffmpeg_decoder_reads_mono_opus) {
    GLExpectTwoSeconds(@"opus-48000-mono.opus");
    id<GLDecoder> decoder = GLOpenDecoder(GLFixturePath(@"opus-48000-mono.opus"), NULL);
    int16_t buffer[8192 * 2];
    NSInteger n = [decoder readFrames:buffer count:8192];
    GL_EXPECT(n > 4096);
    int16_t peak = 0;
    for (NSInteger i = 0; i < n; i++) {
        GL_EXPECT(buffer[i * 2] == buffer[i * 2 + 1]);
        peak = MAX(peak, buffer[i * 2]);
    }
    GL_EXPECT(peak > 1000);
}

GL_TEST(test_ffmpeg_decoder_reads_vorbis) {
    GLExpectTwoSeconds(@"vorbis-44100.ogg");
}

GL_TEST(test_ffmpeg_decoder_reads_wavpack) {
    GLExpectTwoSeconds(@"wavpack-44100.wv");
}

GL_TEST(test_ffmpeg_decoder_mixes_5_1_into_stereo) {
    GLExpectTwoSeconds(@"flac-51.flac");
}

GL_TEST(test_ffmpeg_decoder_seeks_to_the_exact_frame) {
    id<GLDecoder> decoder = GLOpenDecoder(GLFixturePath(@"flac-44100.flac"), NULL);
    GL_EXPECT([decoder seekToTime:1.5]);
    GL_EQUAL_INT(GLCountFrames(decoder), 22050);
    GL_EXPECT([decoder seekToTime:0]);
    GL_EQUAL_INT(GLCountFrames(decoder), 88200);
}

GL_TEST(test_ffmpeg_decoder_refuses_a_file_that_is_not_audio) {
    NSString *path = [GLTestTemporaryDirectory() stringByAppendingPathComponent:@"a.flac"];
    [[@"this is text" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:path atomically:YES];
    NSError *error = nil;
    GL_EXPECT(GLOpenDecoder(path, &error) == nil);
    GL_EXPECT(error != nil);
}
