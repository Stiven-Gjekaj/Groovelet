#import "GLArtistsViewController.h"
#import "GLArtistViewController.h"
#import "GLFormat.h"
#import "GLLibrary.h"

@implementation GLArtistsViewController

- (instancetype)init {
    if ((self = [super init])) {
        self.title = @"Artists";
        self.tabBarItem.image = [UIImage imageNamed:@"Tab-artists.png"];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = 50;
}

- (NSArray *)loadItems {
    return [[GLLibrary shared] artists];
}

- (NSString *)sortKeyForItem:(GLArtist *)artist {
    return artist.sortKey;
}

- (NSString *)searchTextForItem:(GLArtist *)artist {
    return artist.name;
}

- (void)configureCell:(GLTrackCell *)cell forItem:(GLArtist *)artist {
    cell.showsNumber = YES;
    cell.numberLabel.text = @"";
    cell.titleLabel.text = artist.name;
    cell.subtitleLabel.text = [NSString stringWithFormat:@"%@, %@", GLCountText(artist.albumCount, @"album"),
                                                                    GLCountText(artist.trackCount, @"song")];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}

- (void)didSelectItem:(GLArtist *)artist {
    [self.navigationController pushViewController:[[GLArtistViewController alloc] initWithArtist:artist] animated:YES];
}

- (NSString *)emptyText {
    return @"No artists yet.";
}

@end
