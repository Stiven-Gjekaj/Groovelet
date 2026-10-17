// GLUploadServer serves the Wi-Fi upload page on the local network. A
// browser on a computer drops files or folders on the page. The page sends
// each file with "PUT /upload?path=PATH" and the bytes as the body. The
// server writes the file into the music directory at PATH.
//
// The server takes only audio files, images, and playlists. It refuses a path
// that goes out of the music directory. It cannot list, read, or delete files.

#import <Foundation/Foundation.h>

@interface GLUploadServer : NSObject

// Called on the main thread after each file that the server wrote. The path
// is relative to the music directory.
@property (nonatomic, copy) void (^onFile)(NSString *path);

@property (nonatomic, readonly) uint16_t port;
@property (nonatomic, readonly) BOOL running;

// The directory that gets the files.
- (instancetype)initWithDirectory:(NSString *)directory;

// Listens on all addresses. It tries `port` first, and then a free port.
// With `loopbackOnly`, it listens on 127.0.0.1 only, for the tests.
- (BOOL)startOnPort:(uint16_t)port loopbackOnly:(BOOL)loopbackOnly error:(NSError **)error;
- (void)stop;

// The path that the server writes for an upload path, or nil when the path is
// not allowed. It is relative to the directory.
+ (NSString *)safePathForUploadPath:(NSString *)path;

// The IPv4 address of the Wi-Fi interface, or nil.
+ (NSString *)wifiAddress;

@end
