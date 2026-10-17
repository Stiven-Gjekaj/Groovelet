// Tests of GLTags with files that the tests build.

#import "GLTagBuilder.h"
#import "GLTags.h"
#import "GLTest.h"

GL_TEST(test_tags_read_the_text_frames_of_id3v2_3) {
    NSData *tag = GLID3Tag(@[
        GLID3TextFrame(@"TIT2", @"Hello", 0, 3), GLID3TextFrame(@"TPE1", @"Adèle", 1, 3),
        GLID3TextFrame(@"TALB", @"Twenty", 0, 3), GLID3TextFrame(@"TPE2", @"Various", 0, 3),
        GLID3TextFrame(@"TRCK", @"3/12", 0, 3), GLID3TextFrame(@"TPOS", @"2/2", 0, 3),
        GLID3TextFrame(@"TYER", @"2015", 0, 3), GLID3TextFrame(@"TCON", @"(17)Rock", 0, 3),
        GLID3TextFrame(@"TCMP", @"1", 0, 3),
    ], 3, 256);
    GLTags *tags = GLReadTags(GLWriteFile(@"a.mp3", @[ tag, GLFakeAudio(4000) ]), NO);
    GL_EQUAL(tags.title, @"Hello");
    GL_EQUAL(tags.artist, @"Adèle");
    GL_EQUAL(tags.album, @"Twenty");
    GL_EQUAL(tags.albumArtist, @"Various");
    GL_EQUAL_INT(tags.trackNumber, 3);
    GL_EQUAL_INT(tags.discNumber, 2);
    GL_EQUAL_INT(tags.year, 2015);
    GL_EQUAL(tags.genre, @"Rock");
    GL_EXPECT(tags.compilation);
    GL_EXPECT(!tags.hasPicture);
}

GL_TEST(test_tags_read_utf8_and_the_date_of_id3v2_4) {
    NSData *tag = GLID3Tag(@[
        GLID3TextFrame(@"TIT2", @"Ðoom ☂", 3, 4), GLID3TextFrame(@"TDRC", @"1999-04-01", 3, 4),
        GLID3TextFrame(@"TSOP", @"Beatles, The", 3, 4),
    ], 4, 0);
    GLTags *tags = GLReadTags(GLWriteFile(@"a.mp3", @[ tag, GLFakeAudio(100) ]), NO);
    GL_EQUAL(tags.title, @"Ðoom ☂");
    GL_EQUAL_INT(tags.year, 1999);
    GL_EQUAL(tags.sortArtist, @"Beatles, The");
}

GL_TEST(test_tags_read_replaygain_from_txxx_frames) {
    NSMutableData *gain = [NSMutableData dataWithBytes:"\x00" length:1];
    [gain appendData:GLBytes(@"REPLAYGAIN_TRACK_GAIN")];
    [gain appendBytes:"\x00" length:1];
    [gain appendData:GLBytes(@"-7.25 dB")];
    NSMutableData *peak = [NSMutableData dataWithBytes:"\x00" length:1];
    [peak appendData:GLBytes(@"replaygain_album_peak")];
    [peak appendBytes:"\x00" length:1];
    [peak appendData:GLBytes(@"0.987")];
    NSData *tag = GLID3Tag(@[ GLID3Frame(@"TXXX", gain, 3), GLID3Frame(@"TXXX", peak, 3) ], 3, 0);
    GLTags *tags = GLReadTags(GLWriteFile(@"a.mp3", @[ tag ]), NO);
    GL_EXPECT(fabs(tags.trackGain + 7.25) < 1e-9);
    GL_EXPECT(fabs(tags.albumPeak - 0.987) < 1e-9);
    GL_EXPECT(isnan(tags.albumGain));
}

GL_TEST(test_tags_skip_the_picture_unless_asked) {
    NSData *front = GLFakeAudio(5000);
    NSData *back = GLFakeAudio(300);
    NSData *tag = GLID3Tag(@[
        GLID3Frame(@"APIC", GLID3PictureBody(4, back), 3), GLID3Frame(@"APIC", GLID3PictureBody(3, front), 3),
        GLID3TextFrame(@"TIT2", @"After the picture", 0, 3),
    ], 3, 0);
    NSString *path = GLWriteFile(@"a.mp3", @[ tag, GLFakeAudio(100) ]);
    GLTags *quick = GLReadTags(path, NO);
    GL_EXPECT(quick.hasPicture);
    GL_EXPECT(quick.picture == nil);
    GL_EQUAL(quick.title, @"After the picture");
    GLTags *full = GLReadTags(path, YES);
    GL_EQUAL(full.picture, front);
}

GL_TEST(test_tags_give_an_empty_result_for_a_file_with_no_tags) {
    GLTags *tags = GLReadTags(GLWriteFile(@"a.mp3", @[ GLFakeAudio(1000) ]), YES);
    GL_EXPECT(tags != nil);
    GL_EXPECT(tags.title == nil);
    GL_EXPECT(GLReadTags(@"/no/such/file.mp3", NO) == nil);
}

GL_TEST(test_tags_stop_at_a_frame_that_is_longer_than_the_tag) {
    NSMutableData *tag = [GLID3Tag(@[ GLID3TextFrame(@"TIT2", @"Fine", 0, 3) ], 3, 0) mutableCopy];
    // A broken frame header that says 1 MB.
    [tag appendData:GLBytes(@"TALB")];
    [tag appendData:GLBig32Data(1 << 20)];
    [tag appendBytes:"\x00\x00" length:2];
    uint8_t *b = tag.mutableBytes;
    uint32_t size = (uint32_t)tag.length - 10;
    b[6] = (size >> 21) & 0x7f;
    b[7] = (size >> 14) & 0x7f;
    b[8] = (size >> 7) & 0x7f;
    b[9] = size & 0x7f;
    GLTags *tags = GLReadTags(GLWriteFile(@"a.mp3", @[ tag, GLFakeAudio(10) ]), NO);
    GL_EQUAL(tags.title, @"Fine");
    GL_EXPECT(tags.album == nil);
}

GL_TEST(test_tags_read_the_items_of_an_m4a_file) {
    uint8_t track[8] = { 0, 0, 0, 7, 0, 12, 0, 0 };
    uint8_t disc[6] = { 0, 0, 0, 1, 0, 2 };
    uint8_t yes = 1;
    NSData *file = GLMP4File(@[
        GLMP4TextItem(@"©nam", @"Song"), GLMP4TextItem(@"©ART", @"Singer"),
        GLMP4TextItem(@"©alb", @"Record"), GLMP4TextItem(@"aART", @"Band"),
        GLMP4TextItem(@"©day", @"2011-02-03T08:00:00Z"), GLMP4TextItem(@"soaa", @"Band, The"),
        GLMP4Item(@"trkn", 0, [NSData dataWithBytes:track length:8]),
        GLMP4Item(@"disk", 0, [NSData dataWithBytes:disc length:6]),
        GLMP4Item(@"cpil", 21, [NSData dataWithBytes:&yes length:1]),
        GLMP4FreeformItem(@"replaygain_track_gain", @"+1.50 dB"),
    ]);
    GLTags *tags = GLReadTags(GLWriteFile(@"a.m4a", @[ file ]), NO);
    GL_EQUAL(tags.title, @"Song");
    GL_EQUAL(tags.artist, @"Singer");
    GL_EQUAL(tags.album, @"Record");
    GL_EQUAL(tags.albumArtist, @"Band");
    GL_EQUAL(tags.sortAlbumArtist, @"Band, The");
    GL_EQUAL_INT(tags.year, 2011);
    GL_EQUAL_INT(tags.trackNumber, 7);
    GL_EQUAL_INT(tags.discNumber, 1);
    GL_EXPECT(tags.compilation);
    GL_EXPECT(fabs(tags.trackGain - 1.5) < 1e-9);
}

GL_TEST(test_tags_read_the_cover_of_an_m4a_file_only_when_asked) {
    NSData *cover = GLFakeAudio(3000);
    NSString *path = GLWriteFile(@"a.m4a", @[ GLMP4File(@[ GLMP4Item(@"covr", 13, cover),
                                                           GLMP4TextItem(@"©nam", @"Song") ]) ]);
    GLTags *quick = GLReadTags(path, NO);
    GL_EXPECT(quick.hasPicture);
    GL_EXPECT(quick.picture == nil);
    GL_EQUAL(GLReadTags(path, YES).picture, cover);
}
