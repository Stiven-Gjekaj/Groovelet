// The directories of the app.

#import <Foundation/Foundation.h>

// Media/Groovelet in the home directory. The music is here.
// The app is in /Applications, so its home directory is /var/mobile, which
// all such apps share. /var/mobile/Media is the root of AFC, so a computer
// copies files into this directory over USB with no jailbreak tool.
NSString *GLMusicDirectory(void);
// Library/Application Support/Groovelet. The index and the state are here.
NSString *GLSupportDirectory(void);
// Library/Caches/Groovelet. The art thumbnails are here.
NSString *GLCacheDirectory(void);

// The full path of a path that is relative to the music directory.
NSString *GLAbsolutePath(NSString *relativePath);
// The path relative to the music directory, or nil for a path outside it.
NSString *GLRelativePath(NSString *absolutePath);

// Changes the root of all paths, for the tests.
void GLSetRootDirectory(NSString *directory);
