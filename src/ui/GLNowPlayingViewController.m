#import "GLNowPlayingViewController.h"
#import <MediaPlayer/MediaPlayer.h>
#import "GLFormat.h"
#import "GLIcons.h"
#import "GLImageLoader.h"
#import "GLNavigationController.h"
#import "GLPlayback.h"
#import "GLQueueViewController.h"
#import "GLTheme.h"

@interface GLNowPlayingViewController () <UIActionSheetDelegate>
@property (nonatomic, strong) UIImageView *background;
@property (nonatomic, strong) CALayer *art;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *artistLabel;
@property (nonatomic, strong) UISlider *scrubber;
@property (nonatomic, strong) UILabel *elapsedLabel;
@property (nonatomic, strong) UILabel *remainingLabel;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UIButton *shuffleButton;
@property (nonatomic, strong) UIButton *repeatButton;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, copy) NSString *artKey;
@property (nonatomic) BOOL scrubbing;
@property (nonatomic, strong) UIButton *timerButton;
@property (nonatomic, strong) UILabel *headingLabel;
@end

@implementation GLNowPlayingViewController

- (UIButton *)buttonWithIcon:(GLIcon)icon size:(CGFloat)size frame:(CGRect)frame action:(SEL)action {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = frame;
    [button setImage:GLIconImage(icon, size, GLTextColor()) forState:UIControlStateNormal];
    button.showsTouchWhenHighlighted = YES;
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:button];
    return button;
}

- (UILabel *)labelWithFrame:(CGRect)frame font:(UIFont *)font color:(UIColor *)color {
    UILabel *label = [[UILabel alloc] initWithFrame:frame];
    label.font = font;
    label.textColor = color;
    label.backgroundColor = [UIColor clearColor];
    label.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:label];
    return label;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = GLBackgroundColor();
    self.background = [[UIImageView alloc] initWithFrame:self.view.bounds];
    self.background.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.background.contentMode = UIViewContentModeScaleAspectFill;
    self.background.clipsToBounds = YES;
    [self.view addSubview:self.background];

    [self buttonWithIcon:GLIconClose size:24 frame:CGRectMake(4, 2, 44, 44) action:@selector(close)];
    self.headingLabel = [self labelWithFrame:CGRectMake(60, 14, 200, 18) font:GLBoldFont(12)
                                       color:GLSecondaryTextColor()];
    self.timerButton = [self buttonWithIcon:GLIconTimer size:20 frame:CGRectMake(228, 2, 44, 44)
                                     action:@selector(chooseSleep)];
    [self buttonWithIcon:GLIconQueue size:24 frame:CGRectMake(272, 2, 44, 44) action:@selector(showQueue)];

    self.art = [CALayer layer];
    // The screen is 460 points high. The art is 200 points, so that the rows
    // below it have room, and the volume has a margin at the bottom.
    self.art.frame = CGRectMake(60, 48, 200, 200);
    self.art.contentsGravity = kCAGravityResizeAspectFill;
    self.art.masksToBounds = YES;
    self.art.cornerRadius = 6;
    self.art.actions = @{ @"contents": [NSNull null] };
    CALayer *shadow = [CALayer layer];
    shadow.frame = self.art.frame;
    shadow.backgroundColor = [UIColor blackColor].CGColor;
    shadow.cornerRadius = 6;
    shadow.shadowColor = [UIColor blackColor].CGColor;
    shadow.shadowOpacity = 0.6;
    shadow.shadowRadius = 12;
    shadow.shadowOffset = CGSizeMake(0, 6);
    shadow.shadowPath = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 200, 200) cornerRadius:6].CGPath;
    [self.view.layer addSublayer:shadow];
    [self.view.layer addSublayer:self.art];

    self.titleLabel = [self labelWithFrame:CGRectMake(20, 262, 280, 24) font:GLBoldFont(18) color:GLTextColor()];
    self.artistLabel = [self labelWithFrame:CGRectMake(20, 286, 280, 20) font:GLFont(14) color:GLAccentColor()];

    self.scrubber = [[UISlider alloc] initWithFrame:CGRectMake(20, 314, 280, 24)];
    [self.scrubber setThumbImage:GLThumbImage(12, GLTextColor()) forState:UIControlStateNormal];
    [self.scrubber setThumbImage:GLThumbImage(16, GLTextColor()) forState:UIControlStateHighlighted];
    [self.scrubber setMinimumTrackImage:GLBarImage(GLAccentColor()) forState:UIControlStateNormal];
    [self.scrubber setMaximumTrackImage:GLBarImage([UIColor colorWithWhite:1 alpha:0.25]) forState:UIControlStateNormal];
    [self.scrubber addTarget:self action:@selector(scrubBegan) forControlEvents:UIControlEventTouchDown];
    [self.scrubber addTarget:self action:@selector(scrubMoved) forControlEvents:UIControlEventValueChanged];
    [self.scrubber addTarget:self action:@selector(scrubEnded)
            forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    [self.view addSubview:self.scrubber];
    self.elapsedLabel = [self labelWithFrame:CGRectMake(20, 338, 80, 14) font:GLFont(11) color:GLSecondaryTextColor()];
    self.elapsedLabel.textAlignment = NSTextAlignmentLeft;
    self.remainingLabel = [self labelWithFrame:CGRectMake(220, 338, 80, 14) font:GLFont(11)
                                         color:GLSecondaryTextColor()];
    self.remainingLabel.textAlignment = NSTextAlignmentRight;

    CGFloat row = 360;
    self.shuffleButton = [self buttonWithIcon:GLIconShuffle size:20 frame:CGRectMake(14, row + 4, 44, 44)
                                       action:@selector(toggleShuffle)];
    [self buttonWithIcon:GLIconPrevious size:28 frame:CGRectMake(72, row, 52, 52) action:@selector(previous)];
    self.playButton = [self buttonWithIcon:GLIconPlay size:40 frame:CGRectMake(130, row - 4, 60, 60)
                                    action:@selector(togglePlay)];
    [self buttonWithIcon:GLIconNext size:28 frame:CGRectMake(196, row, 52, 52) action:@selector(next)];
    self.repeatButton = [self buttonWithIcon:GLIconRepeat size:20 frame:CGRectMake(262, row + 4, 44, 44)
                                      action:@selector(cycleRepeat)];

    MPVolumeView *volume = [[MPVolumeView alloc] initWithFrame:CGRectMake(24, 420, 272, 23)];
    [volume setMinimumVolumeSliderImage:GLBarImage(GLTextColor()) forState:UIControlStateNormal];
    [volume setMaximumVolumeSliderImage:GLBarImage([UIColor colorWithWhite:1 alpha:0.25]) forState:UIControlStateNormal];
    // The slider of the volume view of iOS 6 puts the centre of the thumb 2.5
    // points below the line, so the circle is higher in its image.
    [volume setVolumeThumbImage:GLThumbImageWithOffset(12, GLTextColor(), -2.5) forState:UIControlStateNormal];
    [self.view addSubview:volume];

    UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(close)];
    swipe.direction = UISwipeGestureRecognizerDirectionDown;
    [self.view addGestureRecognizer:swipe];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(update)
                                                 name:GLPlaybackDidChangeNotification object:nil];
    [self update];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(updateTime) userInfo:nil
                                                 repeats:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.timer invalidate];
    self.timer = nil;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

#pragma mark Updates

- (void)update {
    GLPlayback *playback = [GLPlayback shared];
    GLTrack *track = playback.currentTrack;
    if (!track) {
        [self close];
        return;
    }
    self.titleLabel.text = track.title;
    self.artistLabel.text = [NSString stringWithFormat:@"%@ · %@", track.displayArtist, track.displayAlbum];
    [self.playButton setImage:GLIconImage(playback.playing ? GLIconPause : GLIconPlay, 40, GLTextColor())
                     forState:UIControlStateNormal];
    UIColor *off = [UIColor colorWithWhite:1 alpha:0.45];
    [self.shuffleButton setImage:GLIconImage(GLIconShuffle, 20, playback.shuffle ? GLAccentColor() : off)
                        forState:UIControlStateNormal];
    GLIcon repeatIcon = playback.repeat == GLRepeatOne ? GLIconRepeatOne : GLIconRepeat;
    [self.repeatButton setImage:GLIconImage(repeatIcon, 20, playback.repeat != GLRepeatOff ? GLAccentColor() : off)
                       forState:UIControlStateNormal];
    BOOL sleeping = playback.sleepDate || playback.sleepAtEndOfTrack;
    [self.timerButton setImage:GLIconImage(GLIconTimer, 20, sleeping ? GLAccentColor() : off)
                      forState:UIControlStateNormal];
    if (![self.artKey isEqualToString:track.albumKey]) {
        self.artKey = track.albumKey;
        [[GLImageLoader shared] showArtOfAlbum:track.albumKey path:track.path points:240 inLayer:self.art];
        NSString *key = track.albumKey;
        [[GLImageLoader shared] loadBackgroundOfAlbum:key path:track.path completion:^(UIImage *image) {
            if (![self.artKey isEqualToString:key]) return;
            [UIView transitionWithView:self.background duration:0.3
                               options:UIViewAnimationOptionTransitionCrossDissolve
                            animations:^{ self.background.image = image; } completion:nil];
        }];
    }
    [self updateTime];
}

- (void)updateTime {
    GLPlayback *playback = [GLPlayback shared];
    if (playback.sleepAtEndOfTrack) {
        self.headingLabel.text = @"SLEEP AT THE END OF THE TRACK";
    } else if (playback.sleepDate) {
        long minutes = lround(ceil([playback.sleepDate timeIntervalSinceNow] / 60));
        self.headingLabel.text = [NSString stringWithFormat:@"SLEEP IN %ld MIN", MAX(1L, minutes)];
    } else {
        // The bar stays empty, so that the screen shows less text.
        self.headingLabel.text = nil;
    }
    if (self.scrubbing) return;
    double duration = playback.duration;
    self.scrubber.maximumValue = duration > 0 ? duration : 1;
    self.scrubber.value = playback.currentTime;
    [self showTime:playback.currentTime duration:duration];
}

- (void)showTime:(double)time duration:(double)duration {
    self.elapsedLabel.text = GLTimeText(time);
    self.remainingLabel.text = [@"-" stringByAppendingString:GLTimeText(MAX(0, duration - time))];
}

#pragma mark Actions

- (void)close {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

- (void)togglePlay {
    [[GLPlayback shared] togglePlay];
}

- (void)next {
    [[GLPlayback shared] next];
}

- (void)previous {
    [[GLPlayback shared] previous];
}

- (void)toggleShuffle {
    GLPlayback *playback = [GLPlayback shared];
    playback.shuffle = !playback.shuffle;
}

- (void)cycleRepeat {
    GLPlayback *playback = [GLPlayback shared];
    playback.repeat = (playback.repeat + 1) % 3;
}

- (void)showQueue {
    if (self.presentedViewController) return;
    GLNavigationController *navigation =
        [[GLNavigationController alloc] initWithRootViewController:[GLQueueViewController new]];
    [self presentViewController:navigation animated:YES completion:nil];
}

- (void)chooseSleep {
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Sleep Timer" delegate:self cancelButtonTitle:nil
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:@"Off", @"15 Minutes", @"30 Minutes", @"45 Minutes",
                                                                @"1 Hour", @"End of Track", nil];
    sheet.cancelButtonIndex = [sheet addButtonWithTitle:@"Cancel"];
    [sheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
    if (index == sheet.cancelButtonIndex || index < 0) return;
    GLPlayback *playback = [GLPlayback shared];
    if (index == 5) {
        [playback sleepAtEndOfCurrentTrack];
    } else {
        [playback sleepAfterSeconds:[@[ @0, @15, @30, @45, @60 ][index] integerValue] * 60];
    }
    [self update];
}

- (void)scrubBegan {
    self.scrubbing = YES;
}

- (void)scrubMoved {
    [self showTime:self.scrubber.value duration:self.scrubber.maximumValue];
}

- (void)scrubEnded {
    self.scrubbing = NO;
    [[GLPlayback shared] seekToTime:self.scrubber.value];
}

@end
