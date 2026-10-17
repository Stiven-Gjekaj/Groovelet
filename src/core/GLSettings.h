// The settings of the owner. They stay in the user defaults.

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, GLReplayGainMode) {
    GLReplayGainOff = 0,
    GLReplayGainTrack = 1,
    GLReplayGainAlbum = 2,
};

// Posted when a setting changes.
extern NSString *const GLSettingsDidChangeNotification;

@interface GLSettings : NSObject

+ (instancetype)shared;

// The lists sort "The Beatles" under B. Default: YES.
@property (nonatomic) BOOL ignoreArticles;
// More shows the Folders row. Default: YES.
@property (nonatomic) BOOL showFolders;
// Default: track.
@property (nonatomic) GLReplayGainMode replayGainMode;

@end
