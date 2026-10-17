#import "GLDebug.h"

#ifdef GL_DEBUG

#import "GLFoldersViewController.h"
#import "GLLibrary.h"
#import "GLLibraryUpdater.h"
#import "GLListViewController.h"
#import "GLLog.h"

// Measures the frames while the list scrolls by itself from the top to the
// end and back, at a steady speed.
@interface GLScrollBench : NSObject
@property (nonatomic, strong) UIScrollView *view;
@property (nonatomic, strong) CADisplayLink *link;
@property (nonatomic) CFTimeInterval start;
@property (nonatomic) CFTimeInterval last;
@property (nonatomic) double seconds;
@property (nonatomic) NSInteger frames;
@property (nonatomic) NSInteger dropped;
@property (nonatomic, strong) GLScrollBench *keep;
@end

@implementation GLScrollBench

- (void)runOn:(UIScrollView *)view seconds:(double)seconds {
    self.view = view;
    self.seconds = seconds;
    self.keep = self;
    self.link = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
    [self.link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)tick:(CADisplayLink *)link {
    if (!self.start) {
        self.start = link.timestamp;
        self.last = link.timestamp;
        return;
    }
    // A gap of more than 1.5 frames means that frames were dropped.
    double gap = link.timestamp - self.last;
    if (gap > 1.5 / 60) self.dropped += lround(gap * 60) - 1;
    self.frames++;
    self.last = link.timestamp;
    double t = link.timestamp - self.start;
    double range = MAX(0, self.view.contentSize.height - self.view.bounds.size.height);
    // 2000 points each second, down and then up.
    double y = fmod(t * 2000, 2 * range);
    if (y > range) y = 2 * range - y;
    self.view.contentOffset = CGPointMake(0, y);
    if (t >= self.seconds) {
        [self.link invalidate];
        GLLog(@"scroll: %ld frames, %ld dropped, %.1f frames each second", (long)self.frames, (long)self.dropped,
              self.frames / t);
        self.keep = nil;
    }
}

@end

static UIViewController *GLVisibleController(UIViewController *root) {
    UIViewController *controller = root;
    while (YES) {
        if (controller.presentedViewController) controller = controller.presentedViewController;
        else if ([controller isKindOfClass:[UITabBarController class]])
            controller = ((UITabBarController *)controller).selectedViewController;
        else if ([controller isKindOfClass:[UINavigationController class]])
            controller = ((UINavigationController *)controller).topViewController;
        else return controller;
    }
}

static NSDictionary *GLValues(NSURL *url) {
    NSMutableDictionary *values = [NSMutableDictionary dictionary];
    for (NSString *pair in [url.query componentsSeparatedByString:@"&"]) {
        NSArray *parts = [pair componentsSeparatedByString:@"="];
        if (parts.count == 2) values[parts[0]] = [parts[1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    }
    return values;
}

BOOL GLHandleDebugLink(NSURL *url, UIViewController *root) {
    if (![url.host isEqualToString:@"debug"]) return NO;
    NSDictionary *values = GLValues(url);
    NSString *action = values[@"action"];
    UIViewController *visible = GLVisibleController(root);
    GLLog(@"debug %@ on %@", action, NSStringFromClass([visible class]));
    if ([action isEqualToString:@"delete"]) {
        GLTrack *track = [[GLLibrary shared] trackWithPath:values[@"path"]];
        GLListViewController *list = [visible isKindOfClass:[GLListViewController class]] ? (id)visible
                                                                                          : [GLListViewController new];
        if (track) [list deleteItem:track tracks:@[ track ]];
    } else if ([action isEqualToString:@"deletefolder"]) {
        NSString *path = values[@"path"];
        GLFoldersViewController *folders =
            [[GLFoldersViewController alloc] initWithFolder:path.stringByDeletingLastPathComponent];
        [folders deleteItem:path.lastPathComponent tracks:[folders tracksForItem:path.lastPathComponent]];
    } else if ([action isEqualToString:@"playlist"]) {
        GLPlaylist *playlist = [[GLLibrary shared] createPlaylistNamed:values[@"name"]];
        GLTrack *track = [[GLLibrary shared] trackWithPath:values[@"path"]];
        if (track) [[GLLibrary shared] addTracks:@[ track ] toPlaylist:playlist];
    } else if ([action isEqualToString:@"scanall"]) {
        [[GLLibraryUpdater shared] scanAllFiles];
    } else if ([action isEqualToString:@"scroll"]) {
        UIScrollView *view = nil;
        if ([visible isKindOfClass:[UITableViewController class]]) view = ((UITableViewController *)visible).tableView;
        for (UIView *subview in visible.view.subviews) {
            if (!view && [subview isKindOfClass:[UICollectionView class]]) view = (UIScrollView *)subview;
        }
        if (view) [[GLScrollBench new] runOn:view seconds:[values[@"t"] doubleValue] ?: 10];
    }
    return YES;
}

#else

BOOL GLHandleDebugLink(NSURL *url, UIViewController *root) {
    return NO;
}

#endif
