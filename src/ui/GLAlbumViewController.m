#import "GLAlbumViewController.h"
#import "GLFormat.h"
#import "GLImageLoader.h"
#import "GLLibrary.h"
#import "GLPlayback.h"
#import "GLTheme.h"

@interface GLAlbumViewController ()
@property (nonatomic, strong) GLAlbum *album;
@property (nonatomic, strong) UIView *header;
@end

@implementation GLAlbumViewController

- (instancetype)initWithAlbum:(GLAlbum *)album {
    if ((self = [super init])) {
        _album = album;
        self.title = album.title;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // The album needs no search box. The header shows the album.
    self.tableView.tableHeaderView = [self makeHeader];
    self.tableView.contentOffset = CGPointZero;
}

- (UIView *)makeHeader {
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 150)];
    header.backgroundColor = GLBackgroundColor();
    CALayer *art = [CALayer layer];
    art.frame = CGRectMake(14, 14, 120, 120);
    art.contentsGravity = kCAGravityResizeAspectFill;
    art.masksToBounds = YES;
    art.cornerRadius = 4;
    [header.layer addSublayer:art];
    [[GLImageLoader shared] showArtOfAlbum:self.album.key path:self.album.artPath points:120 inLayer:art];
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(146, 14, 164, 44)];
    title.text = self.album.title;
    title.font = GLBoldFont(17);
    title.textColor = GLTextColor();
    title.numberOfLines = 2;
    UILabel *artist = [[UILabel alloc] initWithFrame:CGRectMake(146, 58, 164, 20)];
    artist.text = self.album.artist;
    artist.font = GLFont(14);
    artist.textColor = GLAccentColor();
    UILabel *facts = [[UILabel alloc] initWithFrame:CGRectMake(146, 78, 164, 18)];
    NSMutableArray *parts = [NSMutableArray array];
    if (self.album.year) [parts addObject:[NSString stringWithFormat:@"%ld", (long)self.album.year]];
    [parts addObject:GLCountText(self.album.trackCount, @"song")];
    [parts addObject:[NSString stringWithFormat:@"%ld min", lround(self.album.duration / 60)]];
    facts.text = [parts componentsJoinedByString:@" · "];
    facts.font = GLFont(12);
    facts.textColor = GLSecondaryTextColor();
    for (UILabel *label in @[ title, artist, facts ]) {
        label.backgroundColor = [UIColor clearColor];
        [header addSubview:label];
    }
    UIButton *play = [UIButton buttonWithType:UIButtonTypeCustom];
    play.frame = CGRectMake(146, 104, 80, 30);
    play.backgroundColor = GLAccentColor();
    play.layer.cornerRadius = 15;
    play.titleLabel.font = GLBoldFont(14);
    [play setTitle:@"Play" forState:UIControlStateNormal];
    [play setTitleColor:GLBackgroundColor() forState:UIControlStateNormal];
    [play addTarget:self action:@selector(playAll) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:play];
    return header;
}

- (void)playAll {
    if (self.visibleItems.count) [[GLPlayback shared] playTracks:self.visibleItems startAtIndex:0];
}

- (NSArray *)loadItems {
    return [[GLLibrary shared] tracksOfAlbum:self.album.key];
}

- (NSString *)searchTextForItem:(GLTrack *)track {
    return track.title;
}

- (void)configureCell:(GLTrackCell *)cell forItem:(GLTrack *)track {
    cell.showsNumber = YES;
    cell.numberLabel.text = track.trackNumber ? [NSString stringWithFormat:@"%ld", (long)track.trackNumber] : @"";
    cell.titleLabel.text = track.title;
    // Show the artist of a track only when it differs from the album artist.
    BOOL other = track.artist && ![track.artist isEqualToString:self.album.artist];
    cell.subtitleLabel.text = other ? track.artist : nil;
    cell.timeLabel.text = GLTimeText(track.duration);
    cell.current = [[GLPlayback shared].currentTrack.path isEqualToString:track.path];
}

- (void)didSelectItem:(GLTrack *)track {
    [[GLPlayback shared] playTracks:self.visibleItems startAtIndex:[self.visibleItems indexOfObjectIdenticalTo:track]];
}

- (BOOL)showsCurrentTrack {
    return YES;
}

@end
