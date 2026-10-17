#import "GLQueueViewController.h"
#import "GLFormat.h"
#import "GLImageLoader.h"
#import "GLPlayback.h"
#import "GLTheme.h"
#import "GLTrackCell.h"

@implementation GLQueueViewController

- (instancetype)init {
    if ((self = [super initWithStyle:UITableViewStylePlain])) self.title = @"Queue";
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    GLStyleTable(self.tableView);
    self.tableView.rowHeight = [GLTrackCell height];
    self.tableView.editing = YES;
    self.tableView.allowsSelectionDuringEditing = YES;
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(close)];
    [[NSNotificationCenter defaultCenter] addObserver:self.tableView selector:@selector(reloadData)
                                                 name:GLPlaybackDidChangeNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self.tableView];
}

- (void)close {
    [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

// Section 0 is the current track. Section 1 holds the tracks after it.
- (NSUInteger)queueIndexForIndexPath:(NSIndexPath *)path {
    GLPlayQueue *queue = [GLPlayback shared].queue;
    return path.section == 0 ? queue.index : queue.index + 1 + path.row;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    GLPlayQueue *queue = [GLPlayback shared].queue;
    if (queue.index == NSNotFound) return 0;
    return section == 0 ? 1 : queue.entries.count - queue.index - 1;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 320, 26)];
    label.backgroundColor = GLSurfaceColor();
    label.textColor = GLAccentColor();
    label.font = GLBoldFont(12);
    label.text = section == 0 ? @"   NOW PLAYING" : @"   UP NEXT";
    return label;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 26;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    GLTrackCell *cell = [tableView dequeueReusableCellWithIdentifier:@"row"];
    if (!cell) cell = [[GLTrackCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"row"];
    GLQueueEntry *entry = [GLPlayback shared].queue.entries[[self queueIndexForIndexPath:indexPath]];
    GLTrack *track = entry.track;
    cell.titleLabel.text = track.title;
    cell.subtitleLabel.text = track.displayArtist;
    cell.current = indexPath.section == 0;
    [[GLImageLoader shared] showArtOfAlbum:track.albumKey path:track.path points:44 inLayer:cell.artLayer];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 1;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 1;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 1 ? UITableViewCellEditingStyleDelete : UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)source
       toProposedIndexPath:(NSIndexPath *)proposed {
    // A track cannot move above the track that plays now.
    return proposed.section == 0 ? [NSIndexPath indexPathForRow:0 inSection:1] : proposed;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)from toIndexPath:(NSIndexPath *)to {
    GLPlayback *playback = [GLPlayback shared];
    [[NSNotificationCenter defaultCenter] removeObserver:self.tableView];
    [playback moveEntryAtIndex:[self queueIndexForIndexPath:from] toIndex:[self queueIndexForIndexPath:to]];
    [[NSNotificationCenter defaultCenter] addObserver:self.tableView selector:@selector(reloadData)
                                                 name:GLPlaybackDidChangeNotification object:nil];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style
    forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (style != UITableViewCellEditingStyleDelete) return;
    [[NSNotificationCenter defaultCenter] removeObserver:self.tableView];
    [[GLPlayback shared] removeEntryAtIndex:[self queueIndexForIndexPath:indexPath]];
    [tableView deleteRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
    [[NSNotificationCenter defaultCenter] addObserver:self.tableView selector:@selector(reloadData)
                                                 name:GLPlaybackDidChangeNotification object:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 1) [[GLPlayback shared] playEntryAtIndex:[self queueIndexForIndexPath:indexPath]];
}

@end
