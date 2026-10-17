#import "GLAppDelegate.h"
#import "GLFilesViewController.h"
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

// The app delegate is the last responder, so the remote control events
// that no view takes come here.
- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)remoteControlReceivedWithEvent:(UIEvent *)event {
    [[GLPlayback shared] handleRemoteControlEvent:event];
}

@end
