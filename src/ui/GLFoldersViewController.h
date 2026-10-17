// The folders and the files of the music directory, as they are on disk.
// A tap on a file plays the files of its folder from that file.

#import "GLListViewController.h"

@interface GLFoldersViewController : GLListViewController
// `folder` is relative to the music directory. "" is the top.
- (instancetype)initWithFolder:(NSString *)folder;
@end
