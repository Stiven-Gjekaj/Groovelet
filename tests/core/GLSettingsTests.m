// Tests of the settings. The test program has its own user defaults.

#import "GLSettings.h"
#import "GLTest.h"

GL_TEST(test_settings_have_their_defaults_and_keep_a_change) {
    GLSettings *settings = [GLSettings shared];
    for (NSString *key in @[ @"ignoreArticles", @"showFolders", @"replayGainMode" ]) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
    }
    GL_EXPECT(settings.ignoreArticles);
    GL_EXPECT(settings.showFolders);
    GL_EQUAL_INT(settings.replayGainMode, GLReplayGainTrack);
    __block int posts = 0;
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:GLSettingsDidChangeNotification object:nil
                                                                     queue:nil usingBlock:^(NSNotification *note) {
                                                                         posts++;
                                                                     }];
    settings.replayGainMode = GLReplayGainAlbum;
    settings.ignoreArticles = NO;
    GL_EQUAL_INT(settings.replayGainMode, GLReplayGainAlbum);
    GL_EXPECT(!settings.ignoreArticles);
    GL_EQUAL_INT(posts, 2);
    [[NSNotificationCenter defaultCenter] removeObserver:observer];
    for (NSString *key in @[ @"ignoreArticles", @"showFolders", @"replayGainMode" ]) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:key];
    }
}
