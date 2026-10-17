// Deletes music from the phone. The delete cannot be undone, so the screens
// ask first.

#import <Foundation/Foundation.h>

// Deletes the files at `paths`, relative to `musicDirectory`. A folder that
// becomes empty goes too, up to the music directory, which stays. Returns the
// paths that it deleted.
NSArray *GLDeleteFiles(NSArray *paths, NSString *musicDirectory);

// Deletes the folder at `folder`, relative to `musicDirectory`, with all its
// content. It refuses the music directory itself and a path that goes out of
// it. Returns YES when the folder is gone.
BOOL GLDeleteFolder(NSString *folder, NSString *musicDirectory);
