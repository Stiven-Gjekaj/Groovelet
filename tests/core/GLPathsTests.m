// Tests of the paths of the app.

#import "GLPaths.h"
#import "GLTest.h"

GL_TEST(test_paths_change_between_relative_and_absolute) {
    GLSetRootDirectory(GLTestTemporaryDirectory());
    NSString *full = GLAbsolutePath(@"Music/a.mp3");
    GL_EXPECT([full hasPrefix:GLDocumentsDirectory()]);
    GL_EQUAL(GLRelativePath(full), @"Music/a.mp3");
    GL_EXPECT(GLRelativePath(@"/etc/hosts") == nil);
    GL_EXPECT(GLRelativePath(GLDocumentsDirectory()) == nil);
    GLSetRootDirectory(nil);
}

GL_TEST(test_paths_make_the_directories) {
    GLSetRootDirectory(GLTestTemporaryDirectory());
    BOOL isDirectory = NO;
    GL_EXPECT([[NSFileManager defaultManager] fileExistsAtPath:GLSupportDirectory() isDirectory:&isDirectory] &&
              isDirectory);
    GL_EXPECT([GLCacheDirectory() hasSuffix:@"Library/Caches/Groovelet"]);
    GLSetRootDirectory(nil);
}
