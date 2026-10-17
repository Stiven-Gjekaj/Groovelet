// Tests of the text of times and counts.

#import "GLFormat.h"
#import "GLTest.h"

GL_TEST(test_time_text_has_minutes_and_seconds) {
    GL_EQUAL(GLTimeText(0), @"0:00");
    GL_EQUAL(GLTimeText(187.9), @"3:07");
    GL_EQUAL(GLTimeText(3723), @"1:02:03");
    GL_EQUAL(GLTimeText(NAN), @"--:--");
}

GL_TEST(test_count_text_has_the_right_form) {
    GL_EQUAL(GLCountText(1, @"song"), @"1 song");
    GL_EQUAL(GLCountText(12, @"album"), @"12 albums");
    GL_EQUAL(GLCountText(0, @"song"), @"0 songs");
}
