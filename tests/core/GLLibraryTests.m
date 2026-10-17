// Tests of GLLibrary with a new database in a temporary directory.

#import "GLLibrary.h"
#import "GLTags.h"
#import "GLTest.h"

static GLLibrary *GLNewLibrary(void) {
    return [[GLLibrary alloc] initWithPath:[GLTestTemporaryDirectory() stringByAppendingPathComponent:@"l.sqlite"]];
}

static GLTrack *GLMakeTrack(NSString *path, NSString *title, NSString *artist, NSString *album, NSInteger number) {
    GLTags *tags = [GLTags new];
    tags.title = title;
    tags.artist = artist;
    tags.album = album;
    tags.trackNumber = number;
    GLTrack *track = [GLTrack trackWithPath:path tags:tags];
    track.fileSize = 1000 + number;
    track.modified = 500;
    track.duration = 60;
    return track;
}

GL_TEST(test_library_saves_and_reads_a_track) {
    GLLibrary *library = GLNewLibrary();
    GL_EXPECT(library != nil);
    GLTrack *track = GLMakeTrack(@"A/1.mp3", @"One", @"Band", @"First", 1);
    track.trackGain = -2.5;
    [library saveTracks:@[ track ]];
    GLTrack *read = [library trackWithPath:@"A/1.mp3"];
    GL_EQUAL(read.title, @"One");
    GL_EQUAL(read.artist, @"Band");
    GL_EQUAL_INT(read.trackNumber, 1);
    GL_EXPECT(read.trackGain == -2.5);
    GL_EXPECT(isnan(read.albumGain));
    GL_EXPECT(read.trackID > 0);
    GL_EXPECT(read.added > 0);
    GL_EQUAL([library fileStamps][@"A/1.mp3"], (@[ @1001, @500 ]));
}

GL_TEST(test_library_keeps_the_id_and_the_play_count_when_a_track_changes) {
    GLLibrary *library = GLNewLibrary();
    [library saveTracks:@[ GLMakeTrack(@"A/1.mp3", @"One", @"Band", @"First", 1) ]];
    GLTrack *first = [library trackWithPath:@"A/1.mp3"];
    [library saveTracks:@[ GLMakeTrack(@"A/1.mp3", @"One (new)", @"Band", @"First", 1) ]];
    GLTrack *second = [library trackWithPath:@"A/1.mp3"];
    GL_EQUAL(second.title, @"One (new)");
    GL_EQUAL_INT(second.trackID, first.trackID);
    GL_EXPECT(second.added == first.added);
    GL_EQUAL_INT([library trackCount], 1);
}

GL_TEST(test_library_groups_the_albums_of_an_artist_by_year) {
    GLLibrary *library = GLNewLibrary();
    GLTrack *late = GLMakeTrack(@"B/1.mp3", @"Late song", @"The Band", @"Zebra", 1);
    late.year = 2001;
    GLTrack *early = GLMakeTrack(@"A/1.mp3", @"Early song", @"The Band", @"Apple", 1);
    early.year = 1990;
    GLTrack *early2 = GLMakeTrack(@"A/2.mp3", @"Early song 2", @"The Band", @"Apple", 2);
    early2.year = 1990;
    early2.hasPicture = YES;
    [library saveTracks:@[ late, early, early2, GLMakeTrack(@"C/1.mp3", @"Other", @"Abba", @"Gold", 1) ]];
    NSArray *artists = [library artists];
    GL_EQUAL_INT(artists.count, 2);
    GL_EQUAL([artists[0] name], @"Abba");
    GL_EQUAL([artists[1] name], @"The Band");
    GL_EQUAL_INT([artists[1] albumCount], 2);
    GL_EQUAL_INT([artists[1] trackCount], 3);
    NSArray *albums = [library albumsOfArtist:@"The Band"];
    GL_EQUAL_INT(albums.count, 2);
    GL_EQUAL([albums[0] title], @"Apple");
    GL_EQUAL_INT([albums[0] trackCount], 2);
    GL_EQUAL([albums[0] artPath], @"A/2.mp3");
    GL_EQUAL([albums[1] title], @"Zebra");
}

GL_TEST(test_library_sorts_with_or_without_the_article) {
    GLLibrary *library = GLNewLibrary();
    [library saveTracks:@[ GLMakeTrack(@"1.mp3", @"x", @"The Cure", @"A", 1),
                           GLMakeTrack(@"2.mp3", @"y", @"Blur", @"B", 1) ]];
    GL_EQUAL([[library artists][0] name], @"Blur");
    library.ignoreArticles = NO;
    GL_EQUAL([[library artists][0] name], @"Blur");
    GL_EQUAL([[library artists][1] name], @"The Cure");
    [library saveTracks:@[ GLMakeTrack(@"3.mp3", @"z", @"Suede", @"C", 1) ]];
    GL_EQUAL([[library artists][1] name], @"Suede");
    library.ignoreArticles = YES;
    GL_EQUAL([[library artists][1] name], @"The Cure");
}

GL_TEST(test_library_orders_the_tracks_of_an_album_by_disc_and_number) {
    GLLibrary *library = GLNewLibrary();
    GLTrack *d2t1 = GLMakeTrack(@"X/d2t1.mp3", @"d2t1", @"Band", @"Double", 1);
    d2t1.discNumber = 2;
    GLTrack *d1t2 = GLMakeTrack(@"X/d1t2.mp3", @"d1t2", @"Band", @"Double", 2);
    d1t2.discNumber = 1;
    GLTrack *d1t1 = GLMakeTrack(@"X/d1t1.mp3", @"d1t1", @"Band", @"Double", 1);
    d1t1.discNumber = 1;
    [library saveTracks:@[ d2t1, d1t2, d1t1 ]];
    NSArray *tracks = [library tracksOfAlbum:d1t1.albumKey];
    GL_EQUAL([tracks valueForKey:@"title"], (@[ @"d1t1", @"d1t2", @"d2t1" ]));
}

GL_TEST(test_library_lists_the_content_of_a_folder) {
    GLLibrary *library = GLNewLibrary();
    [library saveTracks:@[
        GLMakeTrack(@"Rock/Band/1.mp3", @"1", @"B", @"X", 1), GLMakeTrack(@"Rock/2.mp3", @"2", @"B", @"X", 2),
        GLMakeTrack(@"Rock/Alpha/3.mp3", @"3", @"B", @"X", 3), GLMakeTrack(@"Rocker/4.mp3", @"4", @"B", @"X", 4),
        GLMakeTrack(@"top.mp3", @"5", @"B", @"X", 5),
    ]];
    GLFolderContent *top = [library contentOfFolder:@""];
    GL_EQUAL(top.folders, (@[ @"Rock", @"Rocker" ]));
    GL_EQUAL([top.tracks valueForKey:@"path"], (@[ @"top.mp3" ]));
    GLFolderContent *rock = [library contentOfFolder:@"Rock"];
    GL_EQUAL(rock.folders, (@[ @"Alpha", @"Band" ]));
    GL_EQUAL([rock.tracks valueForKey:@"path"], (@[ @"Rock/2.mp3" ]));
}

GL_TEST(test_library_removes_paths) {
    GLLibrary *library = GLNewLibrary();
    [library saveTracks:@[ GLMakeTrack(@"1.mp3", @"1", @"B", @"X", 1), GLMakeTrack(@"2.mp3", @"2", @"B", @"X", 2) ]];
    [library removePaths:@[ @"1.mp3" ]];
    GL_EQUAL([[library allTracks] valueForKey:@"path"], (@[ @"2.mp3" ]));
}

GL_TEST(test_library_opens_an_existing_database_again) {
    NSString *path = [GLTestTemporaryDirectory() stringByAppendingPathComponent:@"l.sqlite"];
    GLLibrary *library = [[GLLibrary alloc] initWithPath:path];
    [library saveTracks:@[ GLMakeTrack(@"1.mp3", @"1", @"B", @"X", 1) ]];
    library = nil;
    GL_EQUAL_INT([[[GLLibrary alloc] initWithPath:path] trackCount], 1);
}
