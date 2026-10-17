#import "GLArtistViewController.h"
#import "GLAlbumViewController.h"
#import "GLFormat.h"
#import "GLImageLoader.h"
#import "GLLibrary.h"

@interface GLArtistViewController ()
@property (nonatomic, strong) GLArtist *artist;
@end

@implementation GLArtistViewController

- (instancetype)initWithArtist:(GLArtist *)artist {
    if ((self = [super init])) {
        _artist = artist;
        self.title = artist.name;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.rowHeight = 64;
}

- (NSArray *)loadItems {
    return [[GLLibrary shared] albumsOfArtist:self.artist.name];
}

- (NSString *)searchTextForItem:(GLAlbum *)album {
    return album.title;
}

- (void)configureCell:(GLTrackCell *)cell forItem:(GLAlbum *)album {
    cell.titleLabel.text = album.title;
    NSString *count = GLCountText(album.trackCount, @"song");
    cell.subtitleLabel.text = album.year ? [NSString stringWithFormat:@"%ld · %@", (long)album.year, count] : count;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    [[GLImageLoader shared] showArtOfAlbum:album.key path:album.artPath points:44 inLayer:cell.artLayer];
}

- (void)didSelectItem:(GLAlbum *)album {
    [self.navigationController pushViewController:[[GLAlbumViewController alloc] initWithAlbum:album] animated:YES];
}

@end
