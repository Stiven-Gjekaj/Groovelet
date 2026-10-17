#import "GLPlaylistsViewController.h"
#import "GLFormat.h"
#import "GLLibrary.h"
#import "GLPaths.h"
#import "GLPlaylistPicker.h"
#import "GLPlaylistViewController.h"
#import "GLTheme.h"

// The item of the row that makes a new playlist.
static NSString *const GLNewPlaylistItem = @"new";

@implementation GLPlaylistsViewController

- (instancetype)init {
    if ((self = [super init])) {
        self.title = @"Playlists";
        self.tabBarItem.image = [UIImage imageNamed:@"Tab-playlists.png"];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = 52;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // The counts change when the owner adds tracks from another tab.
    [self reload];
}

- (NSArray *)loadItems {
    return [@[ GLNewPlaylistItem ] arrayByAddingObjectsFromArray:[[GLLibrary shared] playlists]];
}

- (NSString *)searchTextForItem:(id)item {
    return [item isKindOfClass:[GLPlaylist class]] ? [item name] : @"";
}

- (void)configureCell:(GLTrackCell *)cell forItem:(id)item {
    cell.plain = YES;
    if (item == GLNewPlaylistItem) {
        cell.titleLabel.text = @"New Playlist";
        cell.titleLabel.textColor = GLAccentColor();
        cell.subtitleLabel.text = nil;
        return;
    }
    GLPlaylist *playlist = item;
    cell.titleLabel.text = playlist.name;
    cell.titleLabel.textColor = GLTextColor();
    NSDictionary *kinds = @{ @(GLPlaylistFile): @"M3U file", @(GLPlaylistUser): @"Playlist" };
    NSString *kind = kinds[@(playlist.kind)] ?: @"Automatic";
    cell.subtitleLabel.text = playlist.trackCount >= 0
        ? [NSString stringWithFormat:@"%@ · %@", kind, GLCountText(playlist.trackCount, @"song")] : kind;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}

- (void)didSelectItem:(id)item {
    if (item == GLNewPlaylistItem) {
        [GLPlaylistPicker askForNameWithTitle:@"New Playlist" name:nil completion:^(NSString *name) {
            [[GLLibrary shared] createPlaylistNamed:name];
            [self reload];
        }];
        return;
    }
    [self.navigationController pushViewController:[[GLPlaylistViewController alloc] initWithPlaylist:item] animated:YES];
}

- (NSArray *)tracksForItem:(id)item {
    if (![item isKindOfClass:[GLPlaylist class]]) return nil;
    return [[GLLibrary shared] tracksOfPlaylist:item musicDirectory:GLMusicDirectory()];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    id item = self.visibleItems[indexPath.row];
    return [item isKindOfClass:[GLPlaylist class]] && ((GLPlaylist *)item).kind == GLPlaylistUser;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (style != UITableViewCellEditingStyleDelete) return;
    [[GLLibrary shared] deletePlaylist:self.visibleItems[indexPath.row]];
    [self reload];
}

@end
