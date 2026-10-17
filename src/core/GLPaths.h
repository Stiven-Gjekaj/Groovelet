// The directories of the app.

#import <Foundation/Foundation.h>

// Documents. iTunes File Sharing shows it. The music is here.
NSString *GLMusicDirectory(void);
// Library/Application Support/Groovelet. The index and the state are here.
NSString *GLSupportDirectory(void);
// Library/Caches/Groovelet. The art thumbnails are here.
NSString *GLCacheDirectory(void);

// The full path of a path that is relative to Documents.
NSString *GLAbsolutePath(NSString *relativePath);
// The path relative to Documents, or nil for a path outside Documents.
NSString *GLRelativePath(NSString *absolutePath);

// Changes the root of all paths, for the tests.
void GLSetRootDirectory(NSString *directory);
