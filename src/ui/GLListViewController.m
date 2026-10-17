#import "GLListViewController.h"
#import "GLLibrary.h"
#import "GLPlayback.h"
#import "GLSort.h"
#import "GLTheme.h"

@interface GLListViewController ()
@property (nonatomic, strong) NSArray *items;
@property (nonatomic, strong) NSArray *visibleItems;
@property (nonatomic, strong) NSArray *sectionTitles;  // Nil for a flat list
@property (nonatomic, strong) NSArray *sections;       // Arrays of items
@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UILabel *emptyLabel;
@property (nonatomic) NSUInteger loadToken;
@property (nonatomic) BOOL loaded;
@end

@implementation GLListViewController

- (instancetype)init {
    return [super initWithStyle:UITableViewStylePlain];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    GLStyleTable(self.tableView);
    self.tableView.rowHeight = [GLTrackCell height];
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"Search";
    self.tableView.tableHeaderView = self.searchBar;
    // Hide the search box under the bar until the owner pulls the list down.
    self.tableView.contentOffset = CGPointMake(0, 44);
    self.emptyLabel = [UILabel new];
    self.emptyLabel.font = GLFont(15);
    self.emptyLabel.textColor = GLSecondaryTextColor();
    self.emptyLabel.backgroundColor = [UIColor clearColor];
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.numberOfLines = 0;
    self.emptyLabel.hidden = YES;
    [self.tableView addSubview:self.emptyLabel];
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self selector:@selector(reload) name:GLLibraryDidChangeNotification object:nil];
    if ([self showsCurrentTrack]) {
        [center addObserver:self selector:@selector(playbackChanged) name:GLPlaybackDidChangeNotification object:nil];
    }
    [self reload];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.emptyLabel.frame = CGRectMake(30, 90, self.tableView.bounds.size.width - 60, 120);
}

#pragma mark Loading

- (void)reload {
    NSUInteger token = ++self.loadToken;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSArray *items = [self loadItems] ?: @[];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (token != self.loadToken) return;
            self.items = items;
            self.loaded = YES;
            [self applySearch];
        });
    });
}

- (void)applySearch {
    NSString *text = self.searchBar.text;
    if (text.length) {
        NSMutableArray *found = [NSMutableArray array];
        for (id item in self.items) {
            NSString *search = [self searchTextForItem:item];
            if ([search rangeOfString:text options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location !=
                NSNotFound) {
                [found addObject:item];
            }
        }
        self.visibleItems = found;
    } else {
        self.visibleItems = self.items;
    }
    [self buildSections];
    [self.tableView reloadData];
    self.emptyLabel.text = text.length ? @"No results" : [self emptyText];
    self.emptyLabel.hidden = !self.loaded || self.visibleItems.count > 0;
}

// Groups the items by the first letter of the sort key. A list of fewer
// than 30 items, or a search result, has no index.
- (void)buildSections {
    if (self.searchBar.text.length || self.visibleItems.count < 30 || ![self sortKeyForItem:self.visibleItems.firstObject]) {
        self.sectionTitles = nil;
        self.sections = @[ self.visibleItems ?: @[] ];
        return;
    }
    NSMutableArray *titles = [NSMutableArray array];
    NSMutableArray *sections = [NSMutableArray array];
    for (id item in self.visibleItems) {
        NSString *letter = GLIndexLetter([self sortKeyForItem:item]);
        if (![titles.lastObject isEqualToString:letter]) {
            [titles addObject:letter];
            [sections addObject:[NSMutableArray array]];
        }
        [sections.lastObject addObject:item];
    }
    self.sectionTitles = titles;
    self.sections = sections;
}

- (void)playbackChanged {
    for (NSIndexPath *path in self.tableView.indexPathsForVisibleRows) {
        GLTrackCell *cell = (GLTrackCell *)[self.tableView cellForRowAtIndexPath:path];
        [self configureCell:cell forItem:self.sections[path.section][path.row]];
    }
}

#pragma mark For a subclass

- (NSArray *)loadItems {
    return @[];
}

- (NSString *)sortKeyForItem:(id)item {
    return nil;
}

- (NSString *)searchTextForItem:(id)item {
    return [item description];
}

- (void)configureCell:(GLTrackCell *)cell forItem:(id)item {
}

- (void)didSelectItem:(id)item {
}

- (NSString *)emptyText {
    return @"Nothing here yet.";
}

- (BOOL)showsCurrentTrack {
    return NO;
}

#pragma mark The table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.sections[section] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    GLTrackCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"];
    if (!cell) cell = [[GLTrackCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"row"];
    [self configureCell:cell forItem:self.sections[indexPath.section][indexPath.row]];
    return cell;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
    if (!self.sectionTitles) return nil;
    // The magnifier at the top of the index goes to the search box.
    return [@[ UITableViewIndexSearch ] arrayByAddingObjectsFromArray:self.sectionTitles];
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
    if (index == 0) {
        [tableView setContentOffset:CGPointZero animated:NO];
        return NSNotFound;
    }
    return index - 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return self.sectionTitles ? 24 : 0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (!self.sectionTitles) return nil;
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 320, 24)];
    label.backgroundColor = GLSurfaceColor();
    label.textColor = GLAccentColor();
    label.font = GLBoldFont(13);
    label.text = [@"   " stringByAppendingString:self.sectionTitles[section]];
    return label;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self.searchBar resignFirstResponder];
    [self didSelectItem:self.sections[indexPath.section][indexPath.row]];
}

#pragma mark The search

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self applySearch];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    [searchBar setShowsCancelButton:YES animated:YES];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
    [searchBar setShowsCancelButton:searchBar.text.length > 0 animated:YES];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    searchBar.text = @"";
    [searchBar resignFirstResponder];
    [searchBar setShowsCancelButton:NO animated:YES];
    [self applySearch];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self.searchBar resignFirstResponder];
}

@end
