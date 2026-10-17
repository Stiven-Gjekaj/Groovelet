#import "GLAlbumsViewController.h"
#import "GLAlbumViewController.h"
#import "GLImageLoader.h"
#import "GLLibrary.h"
#import "GLTheme.h"

// One album in the grid: the art, the title, and the artist.
@interface GLAlbumCell : UICollectionViewCell
@property (nonatomic, strong) CALayer *art;
@property (nonatomic, strong) UILabel *title;
@property (nonatomic, strong) UILabel *artist;
@end

@implementation GLAlbumCell

- (instancetype)initWithFrame:(CGRect)frame {
    if ((self = [super initWithFrame:frame])) {
        CGFloat side = frame.size.width;
        _art = [CALayer layer];
        _art.frame = CGRectMake(0, 0, side, side);
        _art.contentsGravity = kCAGravityResizeAspectFill;
        _art.masksToBounds = YES;
        _art.cornerRadius = 4;
        _art.backgroundColor = GLSurfaceColor().CGColor;
        _art.actions = @{ @"contents": [NSNull null] };
        [self.contentView.layer addSublayer:_art];
        _title = [[UILabel alloc] initWithFrame:CGRectMake(0, side + 6, side, 18)];
        _title.font = GLBoldFont(13);
        _title.textColor = GLTextColor();
        _artist = [[UILabel alloc] initWithFrame:CGRectMake(0, side + 24, side, 16)];
        _artist.font = GLFont(12);
        _artist.textColor = GLSecondaryTextColor();
        for (UILabel *label in @[ _title, _artist ]) {
            label.backgroundColor = GLBackgroundColor();
            [self.contentView addSubview:label];
        }
    }
    return self;
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    self.art.opacity = highlighted ? 0.6 : 1;
}

@end

@interface GLAlbumsViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UISearchBarDelegate>
@property (nonatomic, strong) UICollectionView *grid;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic, strong) NSArray *albums;
@property (nonatomic, strong) NSArray *visibleAlbums;
@property (nonatomic) NSUInteger loadToken;
@end

@implementation GLAlbumsViewController

- (instancetype)init {
    if ((self = [super init])) {
        self.title = @"Albums";
        self.tabBarItem.image = [UIImage imageNamed:@"Tab-albums.png"];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = GLBackgroundColor();
    CGRect bounds = self.view.bounds;
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, bounds.size.width, 44)];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Search albums";
    self.searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:self.searchBar];
    UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
    layout.itemSize = CGSizeMake(140, 184);
    layout.minimumInteritemSpacing = 12;
    layout.minimumLineSpacing = 14;
    layout.sectionInset = UIEdgeInsetsMake(14, 14, 14, 14);
    self.grid = [[UICollectionView alloc] initWithFrame:CGRectMake(0, 44, bounds.size.width, bounds.size.height - 44)
                                   collectionViewLayout:layout];
    self.grid.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.grid.backgroundColor = GLBackgroundColor();
    self.grid.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    self.grid.alwaysBounceVertical = YES;
    self.grid.dataSource = self;
    self.grid.delegate = self;
    [self.grid registerClass:[GLAlbumCell class] forCellWithReuseIdentifier:@"album"];
    [self.view addSubview:self.grid];
    self.emptyLabel = [[UILabel alloc] initWithFrame:CGRectMake(30, 120, bounds.size.width - 60, 60)];
    self.emptyLabel.font = GLFont(15);
    self.emptyLabel.textColor = GLSecondaryTextColor();
    self.emptyLabel.backgroundColor = [UIColor clearColor];
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.numberOfLines = 0;
    self.emptyLabel.hidden = YES;
    [self.view addSubview:self.emptyLabel];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reload)
                                                 name:GLLibraryDidChangeNotification object:nil];
    [self reload];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)reload {
    NSUInteger token = ++self.loadToken;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSArray *albums = [[GLLibrary shared] albumsOfArtist:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (token != self.loadToken) return;
            self.albums = albums;
            [self applySearch];
        });
    });
}

- (void)applySearch {
    NSString *text = self.searchBar.text;
    if (text.length) {
        NSPredicate *match = [NSPredicate predicateWithFormat:@"title CONTAINS[cd] %@ OR artist CONTAINS[cd] %@", text, text];
        self.visibleAlbums = [self.albums filteredArrayUsingPredicate:match];
    } else {
        self.visibleAlbums = self.albums;
    }
    [self.grid reloadData];
    self.emptyLabel.text = text.length ? @"No results" : @"No albums yet.";
    self.emptyLabel.hidden = self.visibleAlbums.count > 0;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.visibleAlbums.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    GLAlbumCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"album" forIndexPath:indexPath];
    GLAlbum *album = self.visibleAlbums[indexPath.item];
    cell.title.text = album.title;
    cell.artist.text = album.artist;
    [[GLImageLoader shared] showArtOfAlbum:album.key path:album.artPath points:140 inLayer:cell.art];
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [self.searchBar resignFirstResponder];
    GLAlbum *album = self.visibleAlbums[indexPath.item];
    [self.navigationController pushViewController:[[GLAlbumViewController alloc] initWithAlbum:album] animated:YES];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self applySearch];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self.searchBar resignFirstResponder];
}

@end
