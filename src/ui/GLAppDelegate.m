#import "GLAppDelegate.h"
#import "GLAlbumViewController.h"
#import "GLAlbumsViewController.h"
#import "GLArtistsViewController.h"
#import "GLDecoders.h"
#import "GLImport.h"
#import "GLLibrary.h"
#import "GLLibraryUpdater.h"
#import "GLLink.h"
#import "GLLog.h"
#import "GLMoreViewController.h"
#import "GLNavigationController.h"
#import "GLPaths.h"
#import "GLPlayback.h"
#import "GLPlaylistViewController.h"
#import "GLPlaylistsViewController.h"
#import "GLSettings.h"
#import "GLSongsViewController.h"
#import "GLTabBarController.h"
#import "GLTheme.h"

@interface GLAppDelegate ()
@property (nonatomic, strong) GLTabBarController *tabs;
@property (nonatomic, strong) GLMoreViewController *more;
@end

@implementation GLAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    GLLog(@"launch");
    GLApplyTheme();
    [GLLibrary shared].ignoreArticles = [GLSettings shared].ignoreArticles;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsChanged)
                                                 name:GLSettingsDidChangeNotification object:nil];

    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = GLBackgroundColor();
    self.more = [GLMoreViewController new];
    self.tabs = [GLTabBarController new];
    NSArray *roots = @[ [GLArtistsViewController new], [GLAlbumsViewController new], [GLSongsViewController new],
                        [GLPlaylistsViewController new], self.more ];
    NSMutableArray *navigations = [NSMutableArray array];
    for (UIViewController *root in roots) {
        [navigations addObject:[[GLNavigationController alloc] initWithRootViewController:root]];
    }
    self.tabs.viewControllers = navigations;
    self.tabs.selectedIndex = 2;
    self.window.rootViewController = self.tabs;
    [self.window makeKeyAndVisible];

    [[GLPlayback shared] restore];
    [application beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    [[GLPlayback shared] save];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    [[GLPlayback shared] save];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // New files can come over USB while the app is away.
    [[GLLibraryUpdater shared] scan];
}

- (void)settingsChanged {
    if ([GLLibrary shared].ignoreArticles != [GLSettings shared].ignoreArticles) {
        [GLLibrary shared].ignoreArticles = [GLSettings shared].ignoreArticles;
        [[GLLibrary shared] postChange];
    }
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
    GLLog(@"link %@", url);
    if (url.isFileURL) return [self importFile:url];
    GLLink *link = GLParseLink(url);
    if (!link) return NO;
    GLPlayback *playback = [GLPlayback shared];
    switch (link.kind) {
        case GLLinkPlay: [self playFolderOfPath:link.path atTime:link.time]; break;
        case GLLinkPause: [playback pause]; break;
        case GLLinkResume: [playback play]; break;
        case GLLinkNext: [playback next]; break;
        case GLLinkPrevious: [playback previous]; break;
        case GLLinkSeek: [playback seekToTime:link.time]; break;
        case GLLinkOpen: [self openScreen:link.name path:link.path]; break;
        case GLLinkSleep:
            if ([link.name isEqualToString:@"end"]) [playback sleepAtEndOfCurrentTrack];
            else [playback sleepAfterSeconds:link.time];
            break;
    }
    return YES;
}

// Another app opened a file in Groovelet. iOS put it in Documents/Inbox.
- (BOOL)importFile:(NSURL *)url {
    NSError *error = nil;
    NSString *path = GLImportFile(url.path, GLMusicDirectory(), &error);
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:path ? @"Added" : @"Not added"
                                                    message:path ? [NSString stringWithFormat:@"%@ is in Imported.",
                                                                       path.lastPathComponent]
                                                                 : error.localizedDescription
                                                   delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert show];
    if (path) [[GLLibraryUpdater shared] scan];
    return path != nil;
}

// Opens a tab, a screen of More, or the album of a track.
- (void)openScreen:(NSString *)name path:(NSString *)path {
    [self.tabs dismissViewControllerAnimated:NO completion:nil];
    NSArray *tabs = @[ @"artists", @"albums", @"songs", @"playlists", @"more" ];
    NSUInteger tab = [tabs indexOfObject:name];
    if (tab != NSNotFound) {
        self.tabs.selectedIndex = tab;
        [(UINavigationController *)self.tabs.selectedViewController popToRootViewControllerAnimated:NO];
        return;
    }
    if ([name isEqualToString:@"player"]) {
        [self.tabs showPlayer];
        return;
    }
    if ([name isEqualToString:@"queue"]) {
        [self.tabs showQueue];
        return;
    }
    if ([@[ @"folders", @"upload", @"settings" ] containsObject:name]) {
        self.tabs.selectedIndex = 4;
        [self.more.navigationController popToRootViewControllerAnimated:NO];
        [self.more openScreen:name];
        return;
    }
    if ([name isEqualToString:@"playlist"] && path) {
        GLPlaylist *playlist = [GLPlaylist new];
        playlist.kind = GLPlaylistFile;
        playlist.path = path;
        playlist.name = path.lastPathComponent.stringByDeletingPathExtension;
        self.tabs.selectedIndex = 3;
        UINavigationController *navigation = (UINavigationController *)self.tabs.selectedViewController;
        [navigation popToRootViewControllerAnimated:NO];
        [navigation pushViewController:[[GLPlaylistViewController alloc] initWithPlaylist:playlist] animated:NO];
        return;
    }
    if ([name isEqualToString:@"album"] && path) {
        GLTrack *track = [[GLLibrary shared] trackWithPath:path];
        GLAlbum *album = nil;
        for (GLAlbum *candidate in [[GLLibrary shared] albumsOfArtist:track.displayAlbumArtist]) {
            if ([candidate.key isEqualToString:track.albumKey]) album = candidate;
        }
        if (!album) return;
        self.tabs.selectedIndex = 1;
        UINavigationController *navigation = (UINavigationController *)self.tabs.selectedViewController;
        [navigation popToRootViewControllerAnimated:NO];
        [navigation pushViewController:[[GLAlbumViewController alloc] initWithAlbum:album] animated:NO];
    }
}

// Plays the audio files of the folder of `path`, from `path`.
- (void)playFolderOfPath:(NSString *)path atTime:(double)seconds {
    NSString *folder = path.stringByDeletingLastPathComponent;
    NSArray *tracks = [[GLLibrary shared] contentOfFolder:folder].tracks;
    if (!tracks.count) {
        // The scan has not seen the folder yet. Use the files on disk.
        NSArray *names = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:GLAbsolutePath(folder) error:NULL];
        NSMutableArray *found = [NSMutableArray array];
        for (NSString *name in [names sortedArrayUsingSelector:@selector(localizedStandardCompare:)]) {
            if (GLIsAudioPath(name)) [found addObject:[GLTrack trackWithPath:[folder stringByAppendingPathComponent:name]]];
        }
        tracks = found;
    }
    NSUInteger start = [[tracks valueForKey:@"path"] indexOfObject:path];
    if (start == NSNotFound) return;
    [[GLPlayback shared] playTracks:tracks startAtIndex:start];
    if (seconds > 0) [[GLPlayback shared] seekToTime:seconds];
}

// The app delegate is the last responder, so the remote control events
// that no view takes come here.
- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
    [[GLPlayback shared] handleRemoteControlEvent:event];
}

@end
