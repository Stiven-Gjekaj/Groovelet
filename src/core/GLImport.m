#import "GLImport.h"

NSString *GLImportFile(NSString *source, NSString *musicDirectory, NSError **error) {
    NSFileManager *files = [NSFileManager defaultManager];
    NSString *folder = [musicDirectory stringByAppendingPathComponent:@"Imported"];
    if (![files createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:error]) return nil;
    NSString *name = source.lastPathComponent;
    NSString *base = name.stringByDeletingPathExtension;
    NSString *extension = name.pathExtension;
    NSString *target = [folder stringByAppendingPathComponent:name];
    for (int n = 2; [files fileExistsAtPath:target]; n++) {
        NSString *numbered = [NSString stringWithFormat:@"%@ %d", base, n];
        target = [folder stringByAppendingPathComponent:
            extension.length ? [numbered stringByAppendingPathExtension:extension] : numbered];
    }
    if (![files moveItemAtPath:source toPath:target error:error]) return nil;
    return [@"Imported" stringByAppendingPathComponent:target.lastPathComponent];
}
