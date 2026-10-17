// Tests of GLScanner with files that the tests write.

#import "GLScanner.h"
#import "GLTagBuilder.h"
#import "GLTest.h"

static NSString *GLWriteSong(NSString *directory, NSString *path, NSString *title) {
    NSString *full = [directory stringByAppendingPathComponent:path];
    [[NSFileManager defaultManager] createDirectoryAtPath:full.stringByDeletingLastPathComponent
                              withIntermediateDirectories:YES attributes:nil error:NULL];
    NSMutableData *data = [GLID3Tag(@[ GLID3TextFrame(@"TIT2", title, 0, 3) ], 3, 0) mutableCopy];
    [data appendData:GLFakeAudio(300)];
    [data writeToFile:full atomically:YES];
    return full;
}

static GLScanner *GLNewScanner(GLLibrary *library, NSString *directory, NSUInteger *probes) {
    return [[GLScanner alloc] initWithLibrary:library directory:directory
        isAudio:^BOOL(NSString *path) { return [path.pathExtension isEqualToString:@"mp3"]; }
        duration:^double(NSString *path) {
            if (probes) (*probes)++;
            return 42;
        }];
}

GL_TEST(test_scanner_adds_the_audio_files_with_their_tags) {
    NSString *music = GLTestTemporaryDirectory();
    GLWriteSong(music, @"Band/Album/01.mp3", @"First");
    GLWriteSong(music, @"loose.mp3", @"Loose");
    [@"not audio" writeToFile:[music stringByAppendingPathComponent:@"notes.txt"] atomically:YES
                     encoding:NSUTF8StringEncoding error:NULL];
    GLWriteSong(music, @".hidden/secret.mp3", @"Secret");
    GLLibrary *library = [[GLLibrary alloc] initWithPath:[GLTestTemporaryDirectory() stringByAppendingPathComponent:@"l"]];
    GLScanResult *result = [GLNewScanner(library, music, NULL) scan];
    GL_EQUAL_INT(result.added, 2);
    GL_EQUAL_INT(result.total, 2);
    // The two files are in two folders, so they make two albums.
    GL_EQUAL_INT(result.changedAlbumKeys.count, 2);
    GLTrack *track = [library trackWithPath:@"Band/Album/01.mp3"];
    GL_EQUAL(track.title, @"First");
    GL_EXPECT(track.duration == 42);
    GL_EQUAL(track.displayAlbum, @"Album");
}

GL_TEST(test_scanner_reads_only_the_changed_files_again) {
    NSString *music = GLTestTemporaryDirectory();
    GLWriteSong(music, @"a.mp3", @"A");
    NSString *b = GLWriteSong(music, @"b.mp3", @"B");
    GLLibrary *library = [[GLLibrary alloc] initWithPath:[GLTestTemporaryDirectory() stringByAppendingPathComponent:@"l"]];
    NSUInteger probes = 0;
    [GLNewScanner(library, music, &probes) scan];
    GL_EQUAL_INT(probes, 2);
    // A new title makes a new size. The time of change also moves.
    GLWriteSong(music, @"b.mp3", @"B, longer title");
    [[NSFileManager defaultManager] setAttributes:@{ NSFileModificationDate: [NSDate dateWithTimeIntervalSinceNow:60] }
                                     ofItemAtPath:b error:NULL];
    probes = 0;
    GLScanResult *result = [GLNewScanner(library, music, &probes) scan];
    GL_EQUAL_INT(probes, 1);
    GL_EQUAL_INT(result.changed, 1);
    GL_EQUAL_INT(result.added, 0);
    GL_EQUAL([library trackWithPath:@"b.mp3"].title, @"B, longer title");
}

GL_TEST(test_scanner_removes_the_rows_of_deleted_files) {
    NSString *music = GLTestTemporaryDirectory();
    GLWriteSong(music, @"a.mp3", @"A");
    NSString *b = GLWriteSong(music, @"b.mp3", @"B");
    GLLibrary *library = [[GLLibrary alloc] initWithPath:[GLTestTemporaryDirectory() stringByAppendingPathComponent:@"l"]];
    [GLNewScanner(library, music, NULL) scan];
    [[NSFileManager defaultManager] removeItemAtPath:b error:NULL];
    GLScanResult *result = [GLNewScanner(library, music, NULL) scan];
    GL_EQUAL_INT(result.removed, 1);
    GL_EQUAL_INT(result.changedAlbumKeys.count, 1);
    GL_EQUAL([[library allTracks] valueForKey:@"path"], (@[ @"a.mp3" ]));
}

GL_TEST(test_scanner_gives_the_playlist_files_to_the_library) {
    NSString *music = GLTestTemporaryDirectory();
    GLWriteSong(music, @"a.mp3", @"A");
    [@"a.mp3\n" writeToFile:[music stringByAppendingPathComponent:@"list.m3u"] atomically:YES
                   encoding:NSUTF8StringEncoding error:NULL];
    GLLibrary *library = [[GLLibrary alloc] initWithPath:[GLTestTemporaryDirectory() stringByAppendingPathComponent:@"l"]];
    GLScanner *scanner = GLNewScanner(library, music, NULL);
    scanner.isPlaylist = ^BOOL(NSString *path) { return [path.pathExtension isEqualToString:@"m3u"]; };
    GLScanResult *result = [scanner scan];
    GL_EQUAL_INT(result.total, 1);
    NSArray *files = [[library playlists] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"kind == %d",
                                                                                                       GLPlaylistFile]];
    GL_EQUAL([files valueForKey:@"path"], (@[ @"list.m3u" ]));
}

GL_TEST(test_scanner_reads_all_files_again_when_asked) {
    NSString *music = GLTestTemporaryDirectory();
    GLWriteSong(music, @"a.mp3", @"A");
    GLWriteSong(music, @"b.mp3", @"B");
    GLLibrary *library = [[GLLibrary alloc] initWithPath:[GLTestTemporaryDirectory() stringByAppendingPathComponent:@"l"]];
    [GLNewScanner(library, music, NULL) scan];
    NSUInteger probes = 0;
    GLScanner *scanner = GLNewScanner(library, music, &probes);
    scanner.readAll = YES;
    GLScanResult *result = [scanner scan];
    GL_EQUAL_INT(probes, 2);
    GL_EQUAL_INT(result.changed, 2);
}
