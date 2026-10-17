// Reads an M3U or M3U8 playlist file. Each line that is not a comment is a
// path or a URL of a file. A path can be relative to the folder of the
// playlist, or absolute. A playlist from a computer can have "\" between the
// folders, or a file:// URL.

#import <Foundation/Foundation.h>

// The paths of the entries, relative to `musicDirectory`. An entry outside
// the music directory, or a web URL, is dropped. `playlistPath` is relative
// to the music directory.
NSArray *GLReadM3U(NSData *data, NSString *playlistPath, NSString *musicDirectory);
