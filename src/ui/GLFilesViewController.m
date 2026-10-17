#import "GLFilesViewController.h"
#import "GLDecoders.h"
#import "GLPaths.h"
#import "GLPlayback.h"

@interface GLFilesViewController ()
@property (nonatomic, strong) NSArray *tracks;
@end

@implementation GLFilesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Groovelet";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
        initWithBarButtonSystemItem:UIBarButtonSystemItemPlay target:[GLPlayback shared] action:@selector(togglePlay)];
    self.refreshControl = [UIRefreshControl new];
    [self.refreshControl addTarget:self action:@selector(reload) forControlEvents:UIControlEventValueChanged];
    [[NSNotificationCenter defaultCenter] addObserver:self.tableView selector:@selector(reloadData)
                                                 name:GLPlaybackDidChangeNotification object:nil];
    [self reload];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self.tableView];
}

- (void)reload {
    NSMutableArray *paths = [NSMutableArray array];
    NSDirectoryEnumerator *walk = [[NSFileManager defaultManager] enumeratorAtPath:GLMusicDirectory()];
    for (NSString *path in walk) {
        if (GLIsAudioPath(path)) [paths addObject:path];
    }
    [paths sortUsingSelector:@selector(localizedStandardCompare:)];
    NSMutableArray *tracks = [NSMutableArray array];
    for (NSString *path in paths) [tracks addObject:[GLTrack trackWithPath:path]];
    self.tracks = tracks;
    [self.tableView reloadData];
    [self.refreshControl endRefreshing];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.tracks.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"file"];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"file"];
    GLTrack *track = self.tracks[indexPath.row];
    cell.textLabel.text = track.title;
    cell.detailTextLabel.text = track.path.stringByDeletingLastPathComponent;
    BOOL current = [[GLPlayback shared].currentTrack.path isEqualToString:track.path];
    cell.accessoryType = current ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [[GLPlayback shared] playTracks:self.tracks startAtIndex:indexPath.row];
}

@end
