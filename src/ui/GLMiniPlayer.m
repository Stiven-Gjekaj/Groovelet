#import "GLMiniPlayer.h"
#import "GLIcons.h"
#import "GLImageLoader.h"
#import "GLPlayback.h"
#import "GLTheme.h"

@interface GLMiniPlayer ()
@property (nonatomic, strong) CALayer *art;
@property (nonatomic, strong) CALayer *progress;
@property (nonatomic, strong) UILabel *title;
@property (nonatomic, strong) UILabel *artist;
@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UIButton *nextButton;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, copy) NSString *artKey;
@end

@implementation GLMiniPlayer

+ (CGFloat)height {
    return 50;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        self.backgroundColor = [UIColor colorWithWhite:0.1 alpha:1];
        CALayer *line = [CALayer layer];
        line.frame = CGRectMake(0, 0, 320, 1);
        line.backgroundColor = GLSeparatorColor().CGColor;
        [self.layer addSublayer:line];
        _progress = [CALayer layer];
        _progress.backgroundColor = GLAccentColor().CGColor;
        _progress.anchorPoint = CGPointZero;
        _progress.frame = CGRectMake(0, 0, 0, 2);
        [self.layer addSublayer:_progress];
        _art = [CALayer layer];
        _art.frame = CGRectMake(8, 6, 38, 38);
        _art.contentsGravity = kCAGravityResizeAspectFill;
        _art.masksToBounds = YES;
        _art.cornerRadius = 3;
        _art.actions = @{ @"contents": [NSNull null] };
        [self.layer addSublayer:_art];
        _title = [[UILabel alloc] initWithFrame:CGRectMake(56, 8, 168, 19)];
        _title.font = GLBoldFont(14);
        _title.textColor = GLTextColor();
        _artist = [[UILabel alloc] initWithFrame:CGRectMake(56, 26, 168, 17)];
        _artist.font = GLFont(12);
        _artist.textColor = GLSecondaryTextColor();
        for (UILabel *label in @[ _title, _artist ]) {
            label.backgroundColor = [UIColor clearColor];
            [self addSubview:label];
        }
        _playButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _playButton.frame = CGRectMake(228, 3, 44, 44);
        [_playButton addTarget:[GLPlayback shared] action:@selector(togglePlay) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_playButton];
        _nextButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _nextButton.frame = CGRectMake(272, 3, 44, 44);
        [_nextButton setImage:GLIconImage(GLIconNext, 20, GLTextColor()) forState:UIControlStateNormal];
        [_nextButton addTarget:[GLPlayback shared] action:@selector(next) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_nextButton];
        [self addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped)]];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(update)
                                                     name:GLPlaybackDidChangeNotification object:nil];
        [self update];
    }
    return self;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_timer invalidate];
}

- (void)tapped {
    if (self.onOpen) self.onOpen();
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    [self.timer invalidate];
    self.timer = nil;
    if (self.window) {
        self.timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(updateProgress) userInfo:nil
                                                     repeats:YES];
    }
}

- (void)update {
    GLPlayback *playback = [GLPlayback shared];
    GLTrack *track = playback.currentTrack;
    self.title.text = track.title;
    self.artist.text = track.displayArtist;
    [self.playButton setImage:GLIconImage(playback.playing ? GLIconPause : GLIconPlay, 22, GLTextColor())
                     forState:UIControlStateNormal];
    if (track && ![self.artKey isEqualToString:track.albumKey]) {
        self.artKey = track.albumKey;
        [[GLImageLoader shared] showArtOfAlbum:track.albumKey path:track.path points:38 inLayer:self.art];
    }
    [self updateProgress];
}

- (void)updateProgress {
    GLPlayback *playback = [GLPlayback shared];
    double fraction = playback.duration > 0 ? MIN(1, playback.currentTime / playback.duration) : 0;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.progress.bounds = CGRectMake(0, 0, self.bounds.size.width * fraction, 2);
    [CATransaction commit];
}

@end
