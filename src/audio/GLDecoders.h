// Opens the right decoder for a file.

#import "GLDecoder.h"

id<GLDecoder> GLOpenDecoder(NSString *path, NSError **error);

// YES when the app can play a file with this extension.
BOOL GLIsAudioPath(NSString *path);
