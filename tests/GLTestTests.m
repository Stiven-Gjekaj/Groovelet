// Tests of the test runner itself.

#import "GLTest.h"

GL_TEST(test_runner_compares_equal_objects) {
    GL_EQUAL(([NSString stringWithFormat:@"%d", 42]), @"42");
    GL_EQUAL_INT(6 * 7, 42);
    GL_EXPECT(YES);
}

GL_TEST(test_runner_makes_an_empty_temporary_directory) {
    NSString *first = GLTestTemporaryDirectory();
    NSString *second = GLTestTemporaryDirectory();
    BOOL isDirectory = NO;
    GL_EXPECT([[NSFileManager defaultManager] fileExistsAtPath:first isDirectory:&isDirectory] && isDirectory);
    GL_EXPECT(![first isEqualToString:second]);
    GL_EQUAL_INT([[NSFileManager defaultManager] contentsOfDirectoryAtPath:first error:NULL].count, 0);
}
