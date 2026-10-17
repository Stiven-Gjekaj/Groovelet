// Tests of the sort keys.

#import "GLSort.h"
#import "GLTest.h"

GL_TEST(test_sort_key_ignores_the_article_when_asked) {
    GL_EQUAL(GLSortKey(@"The Beatles", YES), @"beatles");
    GL_EQUAL(GLSortKey(@"A Tribe Called Quest", YES), @"tribe called quest");
    GL_EQUAL(GLSortKey(@"The Beatles", NO), @"the beatles");
    GL_EQUAL(GLSortKey(@"Theatre", YES), @"theatre");
    GL_EQUAL(GLSortKey(@"The", YES), @"the");
}

GL_TEST(test_sort_key_removes_the_accents_and_the_case) {
    GL_EQUAL(GLSortKey(@"  Éric Satie", YES), @"eric satie");
    GL_EXPECT([GLSortKey(@"Beyoncé", YES) compare:GLSortKey(@"Beyonce", YES)] == NSOrderedSame);
}

GL_TEST(test_index_letter_is_a_capital_or_a_hash) {
    GL_EQUAL(GLIndexLetter(@"beatles"), @"B");
    GL_EQUAL(GLIndexLetter(@"2pac"), @"#");
    GL_EQUAL(GLIndexLetter(@""), @"#");
    GL_EQUAL(GLIndexLetter(GLSortKey(@"Ólafur Arnalds", YES)), @"O");
}
