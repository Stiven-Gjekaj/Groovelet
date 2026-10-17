// Tests of the import of a file from another app.

#import "GLImport.h"
#import "GLTest.h"

GL_TEST(test_import_moves_the_file_and_numbers_a_name_in_use) {
    NSString *inbox = GLTestTemporaryDirectory();
    NSString *music = GLTestTemporaryDirectory();
    NSString *first = [inbox stringByAppendingPathComponent:@"Song.mp3"];
    [@"one" writeToFile:first atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    GL_EQUAL(GLImportFile(first, music, NULL), @"Imported/Song.mp3");
    GL_EXPECT(![[NSFileManager defaultManager] fileExistsAtPath:first]);
    [@"two" writeToFile:first atomically:YES encoding:NSUTF8StringEncoding error:NULL];
    GL_EQUAL(GLImportFile(first, music, NULL), @"Imported/Song 2.mp3");
    NSString *second = [NSString stringWithContentsOfFile:[music stringByAppendingPathComponent:@"Imported/Song 2.mp3"]
                                                  encoding:NSUTF8StringEncoding error:NULL];
    GL_EQUAL(second, @"two");
}

GL_TEST(test_import_reports_a_file_that_is_gone) {
    NSError *error = nil;
    GL_EXPECT(GLImportFile(@"/no/such/file.mp3", GLTestTemporaryDirectory(), &error) == nil);
    GL_EXPECT(error != nil);
}
