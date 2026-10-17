// Tests of the M3U reader.

#import "GLM3U.h"
#import "GLTest.h"

static NSData *GLText(NSString *text) {
    return [text dataUsingEncoding:NSUTF8StringEncoding];
}

GL_TEST(test_m3u_reads_relative_paths_from_the_folder_of_the_playlist) {
    NSArray *paths = GLReadM3U(GLText(@"#EXTM3U\n#EXTINF:123,Band - Song\n01 Song.mp3\n\nCD2/02 Other.flac\r\n"),
                               @"Albums/Best/best.m3u8", @"/music");
    GL_EQUAL(paths, (@[ @"Albums/Best/01 Song.mp3", @"Albums/Best/CD2/02 Other.flac" ]));
}

GL_TEST(test_m3u_reads_windows_paths_and_parent_folders) {
    NSArray *paths = GLReadM3U(GLText(@"..\\Other Album\\03 Third.mp3\r\n"), @"Lists/mix.m3u", @"/music");
    GL_EQUAL(paths, (@[ @"Other Album/03 Third.mp3" ]));
}

GL_TEST(test_m3u_keeps_only_absolute_paths_inside_the_music_directory) {
    NSArray *paths = GLReadM3U(GLText(@"/music/A/1.mp3\n/etc/passwd\nfile:///music/B/2%20two.mp3\n"
                                      @"http://radio.example/stream\n../../escape.mp3\n"),
                               @"top.m3u", @"/music");
    GL_EQUAL(paths, (@[ @"A/1.mp3", @"B/2 two.mp3" ]));
}

GL_TEST(test_m3u_reads_latin1_and_a_byte_order_mark) {
    NSData *latin = [@"Café.mp3\n" dataUsingEncoding:NSISOLatin1StringEncoding];
    GL_EQUAL(GLReadM3U(latin, @"l.m3u", @"/music"), (@[ @"Café.mp3" ]));
    GL_EQUAL(GLReadM3U(GLText(@"﻿a.mp3\n"), @"l.m3u8", @"/music"), (@[ @"a.mp3" ]));
}
