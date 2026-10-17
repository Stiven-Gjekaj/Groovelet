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

GL_TEST(test_tags_read_the_vorbis_comments_and_the_picture_of_flac) {
    NSData *cover = GLFakeAudio(700);
    NSData *comments = GLVorbisCommentBody(@[
        @"TITLE=Ballad", @"Artist=Quartet", @"ALBUM=Live", @"ALBUMARTIST=Quartet & Friends", @"TRACKNUMBER=04",
        @"DISCNUMBER=1/2", @"DATE=1977", @"REPLAYGAIN_ALBUM_GAIN=-3.10 dB", @"broken comment",
    ]);
    NSString *path = GLWriteFile(@"a.flac", @[ GLFLACFile(@[ @[ @4, comments ], @[ @6, GLFLACPictureBody(3, cover) ] ]) ]);
    GLTags *tags = GLReadTags(path, YES);
    GL_EQUAL(tags.title, @"Ballad");
    GL_EQUAL(tags.artist, @"Quartet");
    GL_EQUAL(tags.albumArtist, @"Quartet & Friends");
    GL_EQUAL_INT(tags.trackNumber, 4);
    GL_EQUAL_INT(tags.discNumber, 1);
    GL_EQUAL_INT(tags.year, 1977);
    GL_EXPECT(fabs(tags.albumGain + 3.1) < 1e-9);
    GL_EXPECT(tags.hasPicture);
    GL_EQUAL(tags.picture, cover);
    GL_EXPECT(GLReadTags(path, NO).picture == nil);
}

GL_TEST(test_tags_read_flac_after_an_id3_tag) {
    NSData *id3 = GLID3Tag(@[ GLID3TextFrame(@"TIT2", @"From ID3", 0, 3) ], 3, 0);
    NSData *flac = GLFLACFile(@[ @[ @4, GLVorbisCommentBody(@[ @"TITLE=From FLAC", @"ALBUM=Only in FLAC" ]) ] ]);
    GLTags *tags = GLReadTags(GLWriteFile(@"a.flac", @[ id3, flac ]), NO);
    GL_EQUAL(tags.title, @"From ID3");
    GL_EQUAL(tags.album, @"Only in FLAC");
}

GL_TEST(test_tags_read_the_comments_of_opus) {
    NSMutableData *head = [NSMutableData dataWithData:GLBytes(@"OpusHead")];
    [head increaseLengthBy:11];
    NSMutableData *comments = [NSMutableData dataWithData:GLBytes(@"OpusTags")];
    [comments appendData:GLVorbisCommentBody(@[ @"TITLE=Opus song", @"ARTIST=Opus band" ])];
    GLTags *tags = GLReadTags(GLWriteFile(@"a.opus", @[ GLOggFile(@[ head, comments, GLFakeAudio(300) ]) ]), NO);
    GL_EQUAL(tags.title, @"Opus song");
    GL_EQUAL(tags.artist, @"Opus band");
}

GL_TEST(test_tags_read_vorbis_comments_that_cross_pages) {
    NSMutableData *head = [NSMutableData dataWithData:GLBytes(@"\x01vorbis")];
    [head increaseLengthBy:23];
    // A long comment makes a packet of more than one page of 65025 bytes.
    NSString *longText = [@"" stringByPaddingToLength:70000 withString:@"x" startingAtIndex:0];
    NSMutableData *comments = [NSMutableData dataWithData:GLBytes(@"\x03vorbis")];
    [comments appendData:GLVorbisCommentBody(@[ [@"COMMENT=" stringByAppendingString:longText], @"TITLE=Long" ])];
    uint8_t framing = 1;
    [comments appendBytes:&framing length:1];
    GLTags *tags = GLReadTags(GLWriteFile(@"a.ogg", @[ GLOggFile(@[ head, comments ]) ]), NO);
    GL_EQUAL(tags.title, @"Long");
}

GL_TEST(test_tags_read_a_picture_in_vorbis_comments) {
    NSData *cover = GLFakeAudio(400);
    NSString *encoded = GLBase64Encode(GLFLACPictureBody(3, cover));
    NSMutableData *head = [NSMutableData dataWithData:GLBytes(@"OpusHead")];
    [head increaseLengthBy:11];
    NSMutableData *comments = [NSMutableData dataWithData:GLBytes(@"OpusTags")];
    [comments appendData:GLVorbisCommentBody(@[ [@"METADATA_BLOCK_PICTURE=" stringByAppendingString:encoded] ])];
    GLTags *tags = GLReadTags(GLWriteFile(@"a.opus", @[ GLOggFile(@[ head, comments ]) ]), YES);
    GL_EXPECT(tags.hasPicture);
    GL_EQUAL(tags.picture, cover);
}

GL_TEST(test_tags_read_apev2_at_the_end_of_a_wavpack_file) {
    NSData *cover = GLFakeAudio(250);
    NSMutableData *pictureValue = [NSMutableData dataWithData:GLBytes(@"cover.jpg")];
    [pictureValue appendBytes:"\0" length:1];
    [pictureValue appendData:cover];
    NSData *ape = GLAPETag(@[
        @[ @"Title", @"Wave" ], @[ @"Artist", [NSString stringWithFormat:@"Packer%COther", (unichar)0] ], @[ @"Album Artist", @"Packers" ], @[ @"Track", @"9/10" ],
        @[ @"Year", @"2003" ], @[ @"REPLAYGAIN_TRACK_PEAK", @"0.5" ], @[ @"Cover Art (Front)", pictureValue ],
    ]);
    NSMutableData *head = [NSMutableData dataWithData:GLBytes(@"wvpk")];
    [head appendData:GLFakeAudio(400)];
    NSString *path = GLWriteFile(@"a.wv", @[ head, ape ]);
    GLTags *tags = GLReadTags(path, YES);
    GL_EQUAL(tags.title, @"Wave");
    GL_EQUAL(tags.artist, @"Packer");
    GL_EQUAL(tags.albumArtist, @"Packers");
    GL_EQUAL_INT(tags.trackNumber, 9);
    GL_EQUAL_INT(tags.year, 2003);
    GL_EXPECT(fabs(tags.trackPeak - 0.5) < 1e-9);
    GL_EQUAL(tags.picture, cover);
}

GL_TEST(test_tags_use_id3v1_only_for_the_empty_fields) {
    NSData *id3 = GLID3Tag(@[ GLID3TextFrame(@"TIT2", @"New title", 0, 3) ], 3, 0);
    NSData *v1 = GLID3v1Tag(@"Old title", @"Old artist", @"Old album", @"1988", 5);
    GLTags *tags = GLReadTags(GLWriteFile(@"a.mp3", @[ id3, GLFakeAudio(900), v1 ]), NO);
    GL_EQUAL(tags.title, @"New title");
    GL_EQUAL(tags.artist, @"Old artist");
    GL_EQUAL(tags.album, @"Old album");
    GL_EQUAL_INT(tags.year, 1988);
    GL_EQUAL_INT(tags.trackNumber, 5);
}

GL_TEST(test_tags_read_apev2_before_id3v1) {
    NSData *ape = GLAPETag(@[ @[ @"Title", @"APE title" ] ]);
    NSData *v1 = GLID3v1Tag(@"V1 title", @"V1 artist", @"", @"", 0);
    GLTags *tags = GLReadTags(GLWriteFile(@"a.mp3", @[ GLFakeAudio(900), ape, v1 ]), NO);
    GL_EQUAL(tags.title, @"APE title");
    GL_EQUAL(tags.artist, @"V1 artist");
    GL_EXPECT(tags.album == nil);
    GL_EQUAL_INT(tags.trackNumber, 0);
}

static NSData *GLChunk(NSString *type, NSData *body, BOOL bigEndian) {
    NSMutableData *chunk = [NSMutableData dataWithData:GLBytes(type)];
    [chunk appendData:bigEndian ? GLBig32Data((uint32_t)body.length) : GLLittle32Data((uint32_t)body.length)];
    [chunk appendData:body];
    if (body.length & 1) [chunk increaseLengthBy:1];
    return chunk;
}

GL_TEST(test_tags_read_the_info_list_of_a_wav_file) {
    NSMutableData *info = [NSMutableData dataWithData:GLBytes(@"INFO")];
    [info appendData:GLChunk(@"INAM", GLBytes(@"Wave song\0"), NO)];
    [info appendData:GLChunk(@"IART", GLBytes(@"Wave band"), NO)];
    [info appendData:GLChunk(@"IPRD", GLBytes(@"Wave album\0"), NO)];
    NSMutableData *file = [NSMutableData dataWithData:GLBytes(@"RIFF")];
    [file appendData:GLLittle32Data(0)];
    [file appendData:GLBytes(@"WAVE")];
    [file appendData:GLChunk(@"fmt ", [NSMutableData dataWithLength:16], NO)];
    [file appendData:GLChunk(@"data", GLFakeAudio(1001), NO)];
    [file appendData:GLChunk(@"LIST", info, NO)];
    GLTags *tags = GLReadTags(GLWriteFile(@"a.wav", @[ file ]), NO);
    GL_EQUAL(tags.title, @"Wave song");
    GL_EQUAL(tags.artist, @"Wave band");
    GL_EQUAL(tags.album, @"Wave album");
}

GL_TEST(test_tags_read_the_id3_chunk_of_an_aiff_file) {
    NSData *id3 = GLID3Tag(@[ GLID3TextFrame(@"TIT2", @"AIFF song", 0, 3), GLID3TextFrame(@"TALB", @"AIFF album", 0, 3) ],
                           3, 0);
    NSMutableData *file = [NSMutableData dataWithData:GLBytes(@"FORM")];
    [file appendData:GLBig32Data(0)];
    [file appendData:GLBytes(@"AIFF")];
    [file appendData:GLChunk(@"COMM", [NSMutableData dataWithLength:18], YES)];
    [file appendData:GLChunk(@"SSND", GLFakeAudio(500), YES)];
    [file appendData:GLChunk(@"ID3 ", id3, YES)];
    GLTags *tags = GLReadTags(GLWriteFile(@"a.aiff", @[ file ]), NO);
    GL_EQUAL(tags.title, @"AIFF song");
    GL_EQUAL(tags.album, @"AIFF album");
}
