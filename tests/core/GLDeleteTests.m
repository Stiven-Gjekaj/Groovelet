// Tests of the delete of music.

#import "GLDelete.h"
#import "GLTest.h"

static void GLTouch(NSString *root, NSString *path) {
    NSString *full = [root stringByAppendingPathComponent:path];
    [[NSFileManager defaultManager] createDirectoryAtPath:full.stringByDeletingLastPathComponent
                              withIntermediateDirectories:YES attributes:nil error:NULL];
    [@"x" writeToFile:full atomically:YES encoding:NSUTF8StringEncoding error:NULL];
}

static BOOL GLExists(NSString *root, NSString *path) {
    return [[NSFileManager defaultManager] fileExistsAtPath:[root stringByAppendingPathComponent:path]];
}

GL_TEST(test_delete_removes_the_files_and_the_folders_that_become_empty) {
    NSString *music = GLTestTemporaryDirectory();
    GLTouch(music, @"Band/Album/1.mp3");
    GLTouch(music, @"Band/Album/2.mp3");
    GLTouch(music, @"Band/Other/3.mp3");
    NSArray *deleted = GLDeleteFiles(@[ @"Band/Album/1.mp3", @"Band/Album/2.mp3", @"Band/Album/gone.mp3" ], music);
    GL_EQUAL(deleted, (@[ @"Band/Album/1.mp3", @"Band/Album/2.mp3" ]));
    GL_EXPECT(!GLExists(music, @"Band/Album"));
    GL_EXPECT(GLExists(music, @"Band/Other/3.mp3"));
    GLDeleteFiles(@[ @"Band/Other/3.mp3" ], music);
    GL_EXPECT(!GLExists(music, @"Band"));
    GL_EXPECT([[NSFileManager defaultManager] fileExistsAtPath:music]);
}

GL_TEST(test_delete_keeps_a_folder_with_other_files) {
    NSString *music = GLTestTemporaryDirectory();
    GLTouch(music, @"Album/1.mp3");
    GLTouch(music, @"Album/cover.jpg");
    GLDeleteFiles(@[ @"Album/1.mp3" ], music);
    GL_EXPECT(GLExists(music, @"Album/cover.jpg"));
}

GL_TEST(test_delete_refuses_paths_out_of_the_music_directory) {
    NSString *outside = GLTestTemporaryDirectory();
    NSString *music = [outside stringByAppendingPathComponent:@"music"];
    GLTouch(outside, @"keep.mp3");
    GLTouch(music, @"a.mp3");
    GL_EQUAL_INT(GLDeleteFiles(@[ @"../keep.mp3" ], music).count, 0);
    GL_EXPECT(GLExists(outside, @"keep.mp3"));
    GL_EXPECT(!GLDeleteFolder(@"..", music));
    GL_EXPECT(!GLDeleteFolder(@"", music));
    GL_EXPECT(!GLDeleteFolder(@".", music));
    GL_EXPECT(GLExists(music, @"a.mp3"));
}

GL_TEST(test_delete_removes_a_folder_with_its_content) {
    NSString *music = GLTestTemporaryDirectory();
    GLTouch(music, @"Rock/Band/1.mp3");
    GLTouch(music, @"Rock/2.flac");
    GLTouch(music, @"Jazz/3.mp3");
    GL_EXPECT(GLDeleteFolder(@"Rock", music));
    GL_EXPECT(!GLExists(music, @"Rock"));
    GL_EXPECT(GLExists(music, @"Jazz/3.mp3"));
}
