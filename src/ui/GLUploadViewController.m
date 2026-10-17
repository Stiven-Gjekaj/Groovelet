#import "GLUploadViewController.h"
#import "GLFormat.h"
#import "GLLibraryUpdater.h"
#import "GLPaths.h"
#import "GLTheme.h"
#import "GLUploadServer.h"

@interface GLUploadViewController ()
@property (nonatomic, strong) GLUploadServer *server;
@property (nonatomic, strong) UILabel *addressLabel;
@property (nonatomic, strong) UILabel *hintLabel;
@property (nonatomic, strong) UILabel *countLabel;
@property (nonatomic, strong) UILabel *lastLabel;
@property (nonatomic) NSInteger received;
@end

@implementation GLUploadViewController

- (instancetype)init {
    if ((self = [super init])) self.title = @"Upload";
    return self;
}

- (UILabel *)labelAt:(CGFloat)y height:(CGFloat)height font:(UIFont *)font color:(UIColor *)color {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 280, height)];
    label.font = font;
    label.textColor = color;
    label.backgroundColor = [UIColor clearColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    [self.view addSubview:label];
    return label;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = GLBackgroundColor();
    UILabel *intro = [self labelAt:30 height:44 font:GLFont(15) color:GLSecondaryTextColor()];
    intro.text = @"On a computer on the same Wi-Fi, open this address in a browser:";
    self.addressLabel = [self labelAt:84 height:34 font:GLBoldFont(22) color:GLAccentColor()];
    // One line, so that a long address makes the font smaller.
    self.addressLabel.numberOfLines = 1;
    self.addressLabel.adjustsFontSizeToFitWidth = YES;
    self.addressLabel.minimumScaleFactor = 0.6;
    self.hintLabel = [self labelAt:126 height:80 font:GLFont(13) color:GLSecondaryTextColor()];
    self.hintLabel.text = @"Drop files or whole folders on the page. They go into Media/Groovelet.\n"
                          @"The page works only while this screen is open.";
    self.countLabel = [self labelAt:230 height:24 font:GLBoldFont(16) color:GLTextColor()];
    self.lastLabel = [self labelAt:256 height:40 font:GLFont(13) color:GLSecondaryTextColor()];
    __weak GLUploadViewController *weakSelf = self;
    self.server = [[GLUploadServer alloc] initWithDirectory:GLMusicDirectory()];
    self.server.onFile = ^(NSString *path) { [weakSelf receivedFile:path]; };
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    [self.server startOnPort:8080 loopbackOnly:NO error:NULL];
    [self showAddress];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [self.server stop];
    if (self.received) [[GLLibraryUpdater shared] scan];
}

- (void)showAddress {
    NSString *address = [GLUploadServer wifiAddress];
    if (!address || !self.server.running) {
        self.addressLabel.text = @"No Wi-Fi";
        self.countLabel.text = @"Connect the phone to Wi-Fi, and open this screen again.";
        return;
    }
    self.addressLabel.text = self.server.port == 80 ? [NSString stringWithFormat:@"http://%@", address]
                                                    : [NSString stringWithFormat:@"http://%@:%u", address, self.server.port];
    self.countLabel.text = self.received ? GLCountText(self.received, @"file") : @"Waiting for files";
}

- (void)receivedFile:(NSString *)path {
    self.received++;
    self.countLabel.text = [GLCountText(self.received, @"file") stringByAppendingString:@" received"];
    self.lastLabel.text = path;
    // Scan when no file came for 3 seconds, so that a large upload does not
    // make a scan for each file.
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(scanNow) object:nil];
    [self performSelector:@selector(scanNow) withObject:nil afterDelay:3];
}

- (void)scanNow {
    [[GLLibraryUpdater shared] scan];
}

@end
