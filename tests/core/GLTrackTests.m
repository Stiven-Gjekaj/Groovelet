// Tests of the track model.

#import "GLTags.h"
#import "GLTest.h"
#import "GLTrack.h"

GL_TEST(test_track_takes_the_title_and_the_album_from_the_path_when_tags_are_empty) {
    GLTrack *track = [GLTrack trackWithPath:@"Live in Paris/07 Encore.flac" tags:[GLTags new]];
    GL_EQUAL(track.title, @"07 Encore");
    GL_EQUAL(track.displayAlbum, @"Live in Paris");
    GL_EQUAL(track.displayArtist, GLUnknownArtist);
    GL_EQUAL(track.displayAlbumArtist, GLUnknownArtist);
    GL_EXPECT(isnan(track.trackGain));
}

GL_TEST(test_track_groups_a_compilation_under_various_artists) {
    GLTags *tags = [GLTags new];
    tags.title = @"Song";
    tags.artist = @"Singer";
    tags.album = @"Hits";
    tags.compilation = YES;
    GLTrack *one = [GLTrack trackWithPath:@"Hits/1.mp3" tags:tags];
    tags.artist = @"Other singer";
    GLTrack *two = [GLTrack trackWithPath:@"Hits/2.mp3" tags:tags];
    GL_EQUAL(one.displayAlbumArtist, GLVariousArtists);
    GL_EQUAL(one.albumKey, two.albumKey);
    GL_EQUAL(two.displayArtist, @"Other singer");
}

GL_TEST(test_track_prefers_the_album_artist) {
    GLTags *tags = [GLTags new];
    tags.artist = @"Guest";
    tags.albumArtist = @"Band";
    tags.album = @"Record";
    GLTrack *track = [GLTrack trackWithPath:@"x.mp3" tags:tags];
    GL_EQUAL(track.displayAlbumArtist, @"Band");
    GL_EQUAL(track.displayArtist, @"Guest");
    GL_EXPECT([track.albumKey hasPrefix:@"band"]);
}
