// Tests of the playlists and the play counts of GLLibrary.

#import "GLLibrary.h"
#import "GLTags.h"
#import "GLTest.h"

static GLLibrary *GLLibraryWithTracks(NSArray *paths) {
    GLLibrary *library = [[GLLibrary alloc] initWithPath:[GLTestTemporaryDirectory() stringByAppendingPathComponent:@"l"]];
    NSMutableArray *tracks = [NSMutableArray array];
    double added = 1000;
    for (NSString *path in paths) {
        GLTrack *track = [GLTrack trackWithPath:path tags:[GLTags new]];
        track.added = added++;
        [tracks addObject:track];
    }
    [library saveTracks:tracks];
    return library;
}

static GLPlaylist *GLFind(GLLibrary *library, GLPlaylistKind kind) {
    for (GLPlaylist *playlist in [library playlists]) {
        if (playlist.kind == kind) return playlist;
    }
    return nil;
}

GL_TEST(test_playlist_keeps_its_tracks_in_order) {
    GLLibrary *library = GLLibraryWithTracks(@[ @"a.mp3", @"b.mp3", @"c.mp3" ]);
    GLPlaylist *mix = [library createPlaylistNamed:@"Mix"];
    GL_EXPECT(mix.playlistID > 0);
    [library addTracks:@[ [library trackWithPath:@"c.mp3"], [library trackWithPath:@"a.mp3"] ] toPlaylist:mix];
    [library addTracks:@[ [library trackWithPath:@"c.mp3"] ] toPlaylist:mix];
    NSArray *tracks = [library tracksOfPlaylist:mix musicDirectory:@"/music"];
    GL_EQUAL([tracks valueForKey:@"path"], (@[ @"c.mp3", @"a.mp3", @"c.mp3" ]));
    [library setTracks:@[ tracks[1], tracks[0] ] ofPlaylist:mix];
    GL_EQUAL([[library tracksOfPlaylist:mix musicDirectory:@"/music"] valueForKey:@"path"], (@[ @"a.mp3", @"c.mp3" ]));
    GL_EQUAL_INT(GLFind(library, GLPlaylistUser).trackCount, 2);
}

GL_TEST(test_playlist_leaves_out_a_file_that_is_gone) {
    GLLibrary *library = GLLibraryWithTracks(@[ @"a.mp3", @"b.mp3" ]);
    GLPlaylist *mix = [library createPlaylistNamed:@"Mix"];
    [library addTracks:[library allTracks] toPlaylist:mix];
    [library removePaths:@[ @"a.mp3" ]];
    GL_EQUAL([[library tracksOfPlaylist:mix musicDirectory:@"/music"] valueForKey:@"path"], (@[ @"b.mp3" ]));
}

GL_TEST(test_playlist_can_be_renamed_and_deleted) {
    GLLibrary *library = GLLibraryWithTracks(@[ @"a.mp3" ]);
    GLPlaylist *mix = [library createPlaylistNamed:@"Mix"];
    [library renamePlaylist:mix to:@"Party"];
    GL_EQUAL(GLFind(library, GLPlaylistUser).name, @"Party");
    [library deletePlaylist:mix];
    GL_EXPECT(GLFind(library, GLPlaylistUser) == nil);
}

GL_TEST(test_playlist_files_come_from_the_scan_and_read_their_m3u) {
    NSString *music = GLTestTemporaryDirectory();
    [[NSFileManager defaultManager] createDirectoryAtPath:[music stringByAppendingPathComponent:@"Lists"]
                              withIntermediateDirectories:YES attributes:nil error:NULL];
    [@"#EXTM3U\n../Songs/b.mp3\n../Songs/gone.mp3\n" writeToFile:[music stringByAppendingPathComponent:@"Lists/fav.m3u8"]
                                                      atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    GLLibrary *library = GLLibraryWithTracks(@[ @"Songs/a.mp3", @"Songs/b.mp3" ]);
    [library setPlaylistFiles:@[ @"Lists/fav.m3u8" ]];
    GLPlaylist *file = GLFind(library, GLPlaylistFile);
    GL_EQUAL(file.name, @"fav");
    GL_EQUAL([[library tracksOfPlaylist:file musicDirectory:music] valueForKey:@"path"], (@[ @"Songs/b.mp3" ]));
}

GL_TEST(test_automatic_playlists_follow_the_plays_and_the_date) {
    GLLibrary *library = GLLibraryWithTracks(@[ @"a.mp3", @"b.mp3", @"c.mp3" ]);
    GL_EQUAL([[library tracksOfPlaylist:GLFind(library, GLPlaylistRecentlyAdded) musicDirectory:@""] valueForKey:@"path"],
             (@[ @"c.mp3", @"b.mp3", @"a.mp3" ]));
    GL_EQUAL_INT([library tracksOfPlaylist:GLFind(library, GLPlaylistMostPlayed) musicDirectory:@""].count, 0);
    [library recordPlayOfPath:@"a.mp3"];
    [library recordPlayOfPath:@"b.mp3"];
    [library recordPlayOfPath:@"b.mp3"];
    GL_EQUAL([[library tracksOfPlaylist:GLFind(library, GLPlaylistMostPlayed) musicDirectory:@""] valueForKey:@"path"],
             (@[ @"b.mp3", @"a.mp3" ]));
    GL_EQUAL_INT([library trackWithPath:@"b.mp3"].playCount, 2);
    GL_EXPECT([library trackWithPath:@"b.mp3"].lastPlayed > 0);
    GL_EQUAL_INT([library tracksOfPlaylist:GLFind(library, GLPlaylistRecentlyPlayed) musicDirectory:@""].count, 2);
}

GL_TEST(test_playlist_file_finds_a_name_with_an_accent_in_the_other_unicode_form) {
    NSString *composed = @"Songs/Mente M\u00c1.mp3";
    NSString *decomposed = composed.decomposedStringWithCanonicalMapping;
    GL_EXPECT(![composed isEqualToString:decomposed] || composed.length != decomposed.length);
    NSString *music = GLTestTemporaryDirectory();
    [[NSFileManager defaultManager] createDirectoryAtPath:[music stringByAppendingPathComponent:@"Songs"]
                              withIntermediateDirectories:YES attributes:nil error:NULL];
    // The playlist has the composed form, as a computer writes it.
    [[NSString stringWithFormat:@"%@\n", [composed substringFromIndex:6]]
        writeToFile:[music stringByAppendingPathComponent:@"Songs/list.m3u8"] atomically:YES
           encoding:NSUTF8StringEncoding error:NULL];
    // The library has the decomposed form, as the file system of iOS gives it.
    GLLibrary *library = GLLibraryWithTracks(@[ decomposed ]);
    [library setPlaylistFiles:@[ @"Songs/list.m3u8" ]];
    GL_EQUAL_INT([library tracksOfPlaylist:GLFind(library, GLPlaylistFile) musicDirectory:music].count, 1);
    GL_EXPECT([library trackWithPath:composed] != nil);
    GL_EQUAL_INT([library contentOfFolder:@"Songs"].tracks.count, 1);
}
