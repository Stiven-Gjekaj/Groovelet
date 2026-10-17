#import "GLDelete.h"

// The full path for a relative path, or nil when it goes out of the root or
// is the root.
static NSString *GLInside(NSString *relative, NSString *root) {
    NSString *base = root.stringByStandardizingPath;
    NSString *full = [base stringByAppendingPathComponent:relative].stringByStandardizingPath;
    if (![full hasPrefix:[base stringByAppendingString:@"/"]]) return nil;
    return full;
}

NSArray *GLDeleteFiles(NSArray *paths, NSString *musicDirectory) {
    NSFileManager *files = [NSFileManager defaultManager];
    NSString *root = musicDirectory.stringByStandardizingPath;
    NSMutableArray *deleted = [NSMutableArray array];
    for (NSString *path in paths) {
        NSString *full = GLInside(path, root);
        BOOL isDirectory = NO;
        if (!full || ![files fileExistsAtPath:full isDirectory:&isDirectory] || isDirectory) continue;
        if (![files removeItemAtPath:full error:NULL]) continue;
        [deleted addObject:path];
        // Remove the folders that are empty now. A folder with an image or a
        // hidden file stays.
        NSString *folder = full.stringByDeletingLastPathComponent;
        while ([folder hasPrefix:[root stringByAppendingString:@"/"]] &&
               [[files contentsOfDirectoryAtPath:folder error:NULL] count] == 0) {
            [files removeItemAtPath:folder error:NULL];
            folder = folder.stringByDeletingLastPathComponent;
        }
    }
    return deleted;
}

BOOL GLDeleteFolder(NSString *folder, NSString *musicDirectory) {
    NSString *full = GLInside(folder, musicDirectory);
    if (!full) return NO;
    return [[NSFileManager defaultManager] removeItemAtPath:full error:NULL];
}
