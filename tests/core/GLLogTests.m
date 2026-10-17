// Tests of the log file.

#import "GLLog.h"
#import "GLPaths.h"
#import "GLTest.h"

GL_TEST(test_log_keeps_the_lines_in_order) {
    GLSetRootDirectory(GLTestTemporaryDirectory());
    GLLog(@"first %d", 1);
    GLLog(@"second");
    NSString *text = GLLogText();
    NSRange first = [text rangeOfString:@"first 1"];
    NSRange second = [text rangeOfString:@"second"];
    GL_EXPECT(first.location != NSNotFound && second.location != NSNotFound);
    GL_EXPECT(first.location < second.location);
    GLSetRootDirectory(nil);
}
