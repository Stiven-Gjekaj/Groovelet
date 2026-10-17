// Tests of GLAppleDecoder on the phone.

#import "GLAppleDecoder.h"
#import "GLAudioTestSupport.h"
#import "GLTest.h"

GL_TEST(test_apple_decoder_reads_a_wav_file_at_the_output_rate) {
    NSString *path = GLWriteSineFile(GLTestTemporaryDirectory(), @"a.wav", kAudioFileWAVEType, kAudioFormatLinearPCM,
                                     44100, 2, 2);
    GL_EXPECT(path != nil);
    GLAppleDecoder *decoder = [GLAppleDecoder decoderWithPath:path error:NULL];
    GL_EXPECT(decoder != nil);
    GL_EXPECT(fabs(decoder.duration - 2) < 0.001);
    GL_EQUAL_INT(GLCountFrames(decoder), 88200);
}

GL_TEST(test_apple_decoder_changes_48_khz_mono_into_44_1_khz_stereo) {
    NSString *path = GLWriteSineFile(GLTestTemporaryDirectory(), @"a.aif", kAudioFileAIFFType, kAudioFormatLinearPCM,
                                     48000, 1, 1);
    GLAppleDecoder *decoder = [GLAppleDecoder decoderWithPath:path error:NULL];
    GL_EXPECT(decoder != nil);
    int16_t buffer[4096 * 2];
    NSInteger n = [decoder readFrames:buffer count:4096];
    GL_EXPECT(n > 0);
    // The sine is the same on the left and on the right.
    int16_t peak = 0;
    for (NSInteger i = 0; i < n; i++) {
        GL_EXPECT(abs(buffer[i * 2] - buffer[i * 2 + 1]) <= 1);
        peak = MAX(peak, buffer[i * 2 + 1]);
    }
    GL_EXPECT(peak > 4000);
    NSUInteger total = (NSUInteger)n + GLCountFrames(decoder);
    GL_EXPECT(total >= 44090 && total <= 44110);
}

GL_TEST(test_apple_decoder_reads_aac_with_no_extra_frames) {
    NSString *path = GLWriteSineFile(GLTestTemporaryDirectory(), @"a.m4a", kAudioFileM4AType, kAudioFormatMPEG4AAC,
                                     44100, 2, 3);
    GL_EXPECT(path != nil);
    GLAppleDecoder *decoder = [GLAppleDecoder decoderWithPath:path error:NULL];
    GL_EXPECT(decoder != nil);
    // The file keeps the length of the sound, so the decoder drops the
    // priming frames and the padding of the encoder. This makes gapless play.
    GL_EQUAL_INT(GLCountFrames(decoder), 132300);
}

GL_TEST(test_apple_decoder_reads_apple_lossless) {
    NSString *path = GLWriteSineFile(GLTestTemporaryDirectory(), @"a.m4a", kAudioFileM4AType, kAudioFormatAppleLossless,
                                     44100, 2, 1);
    GL_EXPECT(path != nil);
    GLAppleDecoder *decoder = [GLAppleDecoder decoderWithPath:path error:NULL];
    GL_EQUAL_INT(GLCountFrames(decoder), 44100);
}

GL_TEST(test_apple_decoder_seeks_to_a_time) {
    NSString *path = GLWriteSineFile(GLTestTemporaryDirectory(), @"a.wav", kAudioFileWAVEType, kAudioFormatLinearPCM,
                                     48000, 2, 4);
    GLAppleDecoder *decoder = [GLAppleDecoder decoderWithPath:path error:NULL];
    GL_EXPECT([decoder seekToTime:3]);
    NSUInteger left = GLCountFrames(decoder);
    GL_EXPECT(left >= 44090 && left <= 44110);
}

GL_TEST(test_apple_decoder_refuses_a_file_that_is_not_audio) {
    NSString *path = [GLTestTemporaryDirectory() stringByAppendingPathComponent:@"a.mp3"];
    [[@"this is text" dataUsingEncoding:NSUTF8StringEncoding] writeToFile:path atomically:YES];
    NSError *error = nil;
    GL_EXPECT([GLAppleDecoder decoderWithPath:path error:&error] == nil);
    GL_EXPECT(error != nil);
}
