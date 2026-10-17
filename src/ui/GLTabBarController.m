#import "GLTabBarController.h"
#import "GLMiniPlayer.h"
#import "GLNavigationController.h"
#import "GLNowPlayingViewController.h"
#import "GLPlayback.h"

@interface GLTabBarController ()
@property (nonatomic, strong) GLMiniPlayer *miniPlayer;
@end

@implementation GLTabBarController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.miniPlayer = [[GLMiniPlayer alloc] initWithFrame:CGRectMake(0, 0, 320, [GLMiniPlayer height])];
    __weak GLTabBarController *weakSelf = self;
    self.miniPlayer.onOpen = ^{ [weakSelf showPlayer]; };
    [self.view addSubview:self.miniPlayer];
    [[NSNotificationCenter defaultCenter] addObserver:self.view selector:@selector(setNeedsLayout)
                                                 name:GLPlaybackDidChangeNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self.view];
}

// The first subview holds the screens of the tabs. It gets shorter, so that
// the mini player does not cover the end of a list.
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    BOOL show = [GLPlayback shared].currentTrack != nil;
    CGFloat mini = show ? [GLMiniPlayer height] : 0;
    CGRect bar = self.tabBar.frame;
    self.miniPlayer.hidden = !show;
    self.miniPlayer.frame = CGRectMake(0, bar.origin.y - mini, bar.size.width, mini);
    UIView *content = self.view.subviews.firstObject;
    if (content != self.tabBar && content != self.miniPlayer) {
        content.frame = CGRectMake(0, 0, self.view.bounds.size.width, bar.origin.y - mini);
    }
    [self.view bringSubviewToFront:self.miniPlayer];
}

- (void)showPlayer {
    if (self.presentedViewController || ![GLPlayback shared].currentTrack) return;
    [self presentViewController:[GLNowPlayingViewController new] animated:YES completion:nil];
}

- (void)showQueue {
    [self showPlayer];
    GLNowPlayingViewController *player = (GLNowPlayingViewController *)self.presentedViewController;
    if ([player isKindOfClass:[GLNowPlayingViewController class]]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [player showQueue];
        });
    }
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

- (BOOL)shouldAutorotate {
    return NO;
}

@end
