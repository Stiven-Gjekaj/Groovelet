// Reads a groovelet:// link from another app or from a shell on the phone.
//   groovelet://play?path=PATH&t=SECONDS  plays the folder of PATH from PATH
//   groovelet://pause, groovelet://resume, groovelet://next, groovelet://previous
//   groovelet://seek?t=SECONDS             seeks in the current track
//   groovelet://open?name=NAME             opens a screen: a tab, "folders", or "settings"
//   groovelet://open?name=album&path=PATH  opens the album of the track PATH
// PATH is relative to the music directory. Each value is percent-encoded.

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, GLLinkKind) {
    GLLinkPlay,
    GLLinkPause,
    GLLinkResume,
    GLLinkNext,
    GLLinkPrevious,
    GLLinkSeek,
    GLLinkOpen,
};

@interface GLLink : NSObject
@property (nonatomic) GLLinkKind kind;
@property (nonatomic, copy) NSString *path;
@property (nonatomic, copy) NSString *name;
@property (nonatomic) double time;
@end

// Returns nil for a link that the app does not know.
GLLink *GLParseLink(NSURL *url);
