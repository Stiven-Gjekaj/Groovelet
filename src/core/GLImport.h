// Moves a file that another app opened in Groovelet into the music
// directory. iOS puts such a file in Documents/Inbox.

#import <Foundation/Foundation.h>

// Moves the file at `source` into Imported/ in `musicDirectory`. A name that
// is in use gets a number: "Song 2.mp3". Returns the path relative to the
// music directory, or nil.
NSString *GLImportFile(NSString *source, NSString *musicDirectory, NSError **error);
