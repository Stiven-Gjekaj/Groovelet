// Tests of the groovelet:// links.

#import "GLLink.h"
#import "GLTest.h"

GL_TEST(test_link_reads_play_with_a_path_and_a_time) {
    GLLink *link = GLParseLink([NSURL URLWithString:@"groovelet://play?path=Samples/Tones/01%20Low.mp3&t=12.5"]);
    GL_EQUAL_INT(link.kind, GLLinkPlay);
    GL_EQUAL(link.path, @"Samples/Tones/01 Low.mp3");
    GL_EXPECT(link.time == 12.5);
}

GL_TEST(test_link_reads_the_commands) {
    GL_EQUAL_INT(GLParseLink([NSURL URLWithString:@"groovelet://pause"]).kind, GLLinkPause);
    GL_EQUAL_INT(GLParseLink([NSURL URLWithString:@"groovelet://next"]).kind, GLLinkNext);
    GL_EQUAL_INT(GLParseLink([NSURL URLWithString:@"GROOVELET://Previous"]).kind, GLLinkPrevious);
    GLLink *seek = GLParseLink([NSURL URLWithString:@"groovelet://seek?t=30"]);
    GL_EQUAL_INT(seek.kind, GLLinkSeek);
    GL_EXPECT(seek.time == 30);
    GL_EQUAL(GLParseLink([NSURL URLWithString:@"groovelet://open?name=albums"]).name, @"albums");
    GLLink *sleep = GLParseLink([NSURL URLWithString:@"groovelet://sleep?t=90"]);
    GL_EQUAL_INT(sleep.kind, GLLinkSleep);
    GL_EXPECT(sleep.time == 90);
}

GL_TEST(test_link_refuses_an_unknown_or_incomplete_link) {
    GL_EXPECT(GLParseLink([NSURL URLWithString:@"groovelet://dance"]) == nil);
    GL_EXPECT(GLParseLink([NSURL URLWithString:@"groovelet://play"]) == nil);
    GL_EXPECT(GLParseLink([NSURL URLWithString:@"groovelet://open"]) == nil);
    GL_EXPECT(GLParseLink([NSURL URLWithString:@"http://play?path=a.mp3"]) == nil);
}
