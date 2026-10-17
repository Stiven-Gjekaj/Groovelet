#import "GLPaths.h"

static NSString *gRoot;

void GLSetRootDirectory(NSString *directory) {
    gRoot = [directory copy];
}

static NSString *GLRoot(void) {
    return gRoot ?: NSHomeDirectory();
}

static NSString *GLMakeDirectory(NSString *path) {
    [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL];
    return path;
}

NSString *GLMusicDirectory(void) {
    return GLMakeDirectory([GLRoot() stringByAppendingPathComponent:@"Media/Groovelet"]);
}

NSString *GLSupportDirectory(void) {
    return GLMakeDirectory([GLRoot() stringByAppendingPathComponent:@"Library/Application Support/Groovelet"]);
}

NSString *GLCacheDirectory(void) {
    return GLMakeDirectory([GLRoot() stringByAppendingPathComponent:@"Library/Caches/Groovelet"]);
}

NSString *GLAbsolutePath(NSString *relativePath) {
    return [GLMusicDirectory() stringByAppendingPathComponent:relativePath];
}

NSString *GLRelativePath(NSString *absolutePath) {
    NSString *root = [GLMusicDirectory().stringByStandardizingPath stringByAppendingString:@"/"];
    NSString *path = absolutePath.stringByStandardizingPath;
    if (![path hasPrefix:root]) return nil;
    return [path substringFromIndex:root.length];
}
