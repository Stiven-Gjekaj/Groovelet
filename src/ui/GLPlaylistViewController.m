#import "GLPlaylistViewController.h"
#import "GLFormat.h"
#import "GLIcons.h"
#import "GLImageLoader.h"
#import "GLLibrary.h"
#import "GLPaths.h"
#import "GLPlayback.h"
#import "GLPlaylistPicker.h"
#import "GLTheme.h"

@interface GLPlaylistViewController () <UIActionSheetDelegate>
@property (nonatomic, strong) GLPlaylist *playlist;
@property (nonatomic, strong) NSMutableArray *editedTracks;
@end

@implementation GLPlaylistViewController

- (instancetype)initWithPlaylist:(GLPlaylist *)playlist {
    if ((self = [super init])) {
        _playlist = playlist;
        self.title = playlist.name;
    }
    return self;
}

- (BOOL)editable {
    return self.playlist.kind == GLPlaylistUser;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.tableHeaderView = [self makeHeader];
    self.tableView.contentOffset = CGPointZero;
    if (self.editable) {
        self.navigationItem.rightBarButtonItem =
            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self
                                                          action:@selector(edit)];
    }
}

- (UIView *)makeHeader {
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 56)];
    header.backgroundColor = GLBackgroundColor();
    UIButton *play = [UIButton buttonWithType:UIButtonTypeCustom];
    play.frame = CGRectMake(14, 12, 140, 32);
    play.backgroundColor = GLAccentColor();
    play.layer.cornerRadius = 16;
    play.titleLabel.font = GLBoldFont(14);
    [play setTitle:@"Play" forState:UIControlStateNormal];
    [play setTitleColor:GLBackgroundColor() forState:UIControlStateNormal];
    [play addTarget:self action:@selector(playAll) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:play];
    UIButton *shuffle = [UIButton buttonWithType:UIButtonTypeCustom];
    shuffle.frame = CGRectMake(166, 12, 140, 32);
    shuffle.backgroundColor = GLSurfaceColor();
    shuffle.layer.cornerRadius = 16;
    shuffle.titleLabel.font = GLBoldFont(14);
    [shuffle setTitle:@" Shuffle" forState:UIControlStateNormal];
    [shuffle setImage:GLIconImage(GLIconShuffle, 16, GLTextColor()) forState:UIControlStateNormal];
    [shuffle addTarget:self action:@selector(shuffleAll) forControlEvents:UIControlEventTouchUpInside];
    [header addSubview:shuffle];
    return header;
}

- (void)playAll {
    if (!self.visibleItems.count) return;
    [GLPlayback shared].shuffle = NO;
    [[GLPlayback shared] playTracks:self.visibleItems startAtIndex:0];
}

- (void)shuffleAll {
    [[GLPlayback shared] shuffleTracks:self.visibleItems];
}

- (NSArray *)loadItems {
    return [[GLLibrary shared] tracksOfPlaylist:self.playlist musicDirectory:GLMusicDirectory()];
}

- (NSString *)searchTextForItem:(GLTrack *)track {
    return [NSString stringWithFormat:@"%@ %@", track.title, track.displayArtist];
}

- (void)configureCell:(GLTrackCell *)cell forItem:(GLTrack *)track {
    cell.titleLabel.text = track.title;
    cell.subtitleLabel.text = track.displayArtist;
    cell.timeLabel.text = GLTimeText(track.duration);
    cell.current = [[GLPlayback shared].currentTrack.path isEqualToString:track.path];
    [[GLImageLoader shared] showArtOfAlbum:track.albumKey path:track.path points:44 inLayer:cell.artLayer];
}

- (void)didSelectItem:(GLTrack *)track {
    [[GLPlayback shared] playTracks:self.visibleItems startAtIndex:[self.visibleItems indexOfObjectIdenticalTo:track]];
}

- (NSString *)emptyText {
    return self.editable ? @"This playlist is empty.\n\nHold a song or an album in a list, and choose Add to Playlist."
                         : @"This playlist is empty.";
}

- (BOOL)showsCurrentTrack {
    return YES;
}

#pragma mark Editing

- (void)edit {
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:self.playlist.name delegate:self cancelButtonTitle:nil
                                         destructiveButtonTitle:@"Delete Playlist"
                                              otherButtonTitles:@"Change the Order", @"Rename", nil];
    sheet.cancelButtonIndex = [sheet addButtonWithTitle:@"Cancel"];
    [sheet showFromTabBar:self.tabBarController.tabBar];
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
    if (index == sheet.destructiveButtonIndex) {
        [[GLLibrary shared] deletePlaylist:self.playlist];
        [self.navigationController popViewControllerAnimated:YES];
    } else if (index == 1) {
        self.editedTracks = [self.visibleItems mutableCopy];
        [self.tableView setEditing:YES animated:YES];
        self.navigationItem.rightBarButtonItem =
            [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self
                                                          action:@selector(endEditing)];
    } else if (index == 2) {
        [GLPlaylistPicker askForNameWithTitle:@"Rename" name:self.playlist.name completion:^(NSString *name) {
            [[GLLibrary shared] renamePlaylist:self.playlist to:name];
            self.title = name;
        }];
    }
}

- (void)endEditing {
    [[GLLibrary shared] setTracks:self.editedTracks ofPlaylist:self.playlist];
    self.editedTracks = nil;
    [self.tableView setEditing:NO animated:YES];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(edit)];
    [self reload];
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return self.editedTracks != nil;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return self.editedTracks != nil;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)from toIndexPath:(NSIndexPath *)to {
    GLTrack *track = self.editedTracks[from.row];
    [self.editedTracks removeObjectAtIndex:from.row];
    [self.editedTracks insertObject:track atIndex:to.row];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (style != UITableViewCellEditingStyleDelete) return;
    [self.editedTracks removeObjectAtIndex:indexPath.row];
    [[GLLibrary shared] setTracks:self.editedTracks ofPlaylist:self.playlist];
    [self reload];
}

@end
