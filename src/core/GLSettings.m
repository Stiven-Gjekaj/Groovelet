#import "GLSettings.h"

NSString *const GLSettingsDidChangeNotification = @"GLSettingsDidChange";

static NSString *const GLIgnoreArticlesKey = @"ignoreArticles";
static NSString *const GLShowFoldersKey = @"showFolders";
static NSString *const GLReplayGainKey = @"replayGainMode";

@implementation GLSettings

+ (instancetype)shared {
    static GLSettings *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [GLSettings new];
        [[NSUserDefaults standardUserDefaults] registerDefaults:@{
            GLIgnoreArticlesKey: @YES, GLShowFoldersKey: @YES, GLReplayGainKey: @(GLReplayGainTrack),
        }];
    });
    return shared;
}

- (void)setValue:(id)value forSetting:(NSString *)key {
    [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:GLSettingsDidChangeNotification object:self];
}

- (BOOL)ignoreArticles {
    return [[NSUserDefaults standardUserDefaults] boolForKey:GLIgnoreArticlesKey];
}

- (void)setIgnoreArticles:(BOOL)ignoreArticles {
    [self setValue:@(ignoreArticles) forSetting:GLIgnoreArticlesKey];
}

- (BOOL)showFolders {
    return [[NSUserDefaults standardUserDefaults] boolForKey:GLShowFoldersKey];
}

- (void)setShowFolders:(BOOL)showFolders {
    [self setValue:@(showFolders) forSetting:GLShowFoldersKey];
}

- (GLReplayGainMode)replayGainMode {
    NSInteger mode = [[NSUserDefaults standardUserDefaults] integerForKey:GLReplayGainKey];
    return mode >= GLReplayGainOff && mode <= GLReplayGainAlbum ? (GLReplayGainMode)mode : GLReplayGainTrack;
}

- (void)setReplayGainMode:(GLReplayGainMode)replayGainMode {
    [self setValue:@(replayGainMode) forSetting:GLReplayGainKey];
}

@end
