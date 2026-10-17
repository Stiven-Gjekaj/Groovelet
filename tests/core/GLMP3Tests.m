// Tests of the MP3 length from the Xing, Info, and VBRI headers.

#import "GLMP3.h"
#import "GLTagBuilder.h"
#import "GLTest.h"

// A first frame of MPEG-1 layer III at 44.1 kHz. `mono` sets the channel
// mode, and the header goes after the side information.
static NSData *GLFirstFrame(BOOL mono, NSString *tag, uint32_t frames) {
    NSMutableData *frame = [NSMutableData data];
    uint8_t header[4] = { 0xff, 0xfb, 0x40, (uint8_t)(mono ? 0xc4 : 0x44) };
    [frame appendBytes:header length:4];
    [frame increaseLengthBy:mono ? 17 : 32];
    [frame appendData:GLBytes(tag)];
    [frame appendData:GLBig32Data(15)];  // The flags: frames, bytes, TOC, quality.
    [frame appendData:GLBig32Data(frames)];
    [frame increaseLengthBy:200];
    return frame;
}

GL_TEST(test_mp3_duration_comes_from_the_info_header_after_an_id3_tag) {
    NSData *tag = GLID3Tag(@[ GLID3TextFrame(@"TIT2", @"Song", 0, 3) ], 3, 1000);
    NSString *path = GLWriteFile(@"a.mp3", @[ tag, GLFirstFrame(YES, @"Info", 5705), GLFakeAudio(4000) ]);
    GL_EXPECT(fabs(GLMP3Duration(path) - 5705 * 1152 / 44100.0) < 1e-6);
}

GL_TEST(test_mp3_duration_comes_from_the_xing_header_of_a_stereo_file) {
    NSString *path = GLWriteFile(@"a.mp3", @[ GLFirstFrame(NO, @"Xing", 1000), GLFakeAudio(100) ]);
    GL_EXPECT(fabs(GLMP3Duration(path) - 1000 * 1152 / 44100.0) < 1e-6);
}

GL_TEST(test_mp3_duration_is_unknown_with_no_header) {
    NSMutableData *frame = [NSMutableData dataWithBytes:"\xff\xfb\x40\xc4" length:4];
    [frame increaseLengthBy:300];
    GL_EXPECT(GLMP3Duration(GLWriteFile(@"a.mp3", @[ frame ])) < 0);
    GL_EXPECT(GLMP3Duration(GLWriteFile(@"b.mp3", @[ GLFakeAudio(500) ])) < 0);
    GL_EXPECT(GLMP3Duration(@"/no/such/file.mp3") < 0);
}
