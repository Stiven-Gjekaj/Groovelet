#import "GLAppDelegate.h"
#import "GLDecoders.h"
#import "GLFilesViewController.h"
#import "GLLink.h"
#import "GLLog.h"
#import "GLPaths.h"
#import "GLPlayback.h"

@implementation GLAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.window.backgroundColor = [UIColor colorWithWhite:0x11 / 255.0 alpha:1];
    self.window.rootViewController =
        [[UINavigationController alloc] initWithRootViewController:[GLFilesViewController new]];
    [self.window makeKeyAndVisible];
    [GLPlayback shared];
    [application beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
    return YES;
}

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication
         annotation:(id)annotation {
    GLLog(@"link %@", url);
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
        case GLLinkOpen: break;
    }
    return YES;
}

// Plays the audio files of the folder of `path`, from `path`.
- (void)playFolderOfPath:(NSString *)path atTime:(double)seconds {
    NSString *folder = path.stringByDeletingLastPathComponent;
    NSArray *names = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:GLAbsolutePath(folder) error:NULL];
    names = [names sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
    NSMutableArray *tracks = [NSMutableArray array];
    NSUInteger start = 0;
    for (NSString *name in names) {
        if (!GLIsAudioPath(name)) continue;
        NSString *relative = [folder stringByAppendingPathComponent:name];
        if ([relative isEqualToString:path]) start = tracks.count;
        [tracks addObject:[GLTrack trackWithPath:relative]];
    }
    if (!tracks.count) return;
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
