#import "GLFoldersViewController.h"
#import "GLFormat.h"
#import "GLLibrary.h"
#import "GLPlayback.h"

@interface GLFoldersViewController ()
@property (nonatomic, copy) NSString *folder;
@property (nonatomic, strong) NSArray *tracks;
@end

@implementation GLFoldersViewController

- (instancetype)initWithFolder:(NSString *)folder {
    if ((self = [super init])) {
        _folder = [folder copy];
        self.title = folder.length ? folder.lastPathComponent : @"Folders";
    }
    return self;
}

- (NSArray *)loadItems {
    GLFolderContent *content = [[GLLibrary shared] contentOfFolder:self.folder];
    self.tracks = content.tracks;
    return [content.folders arrayByAddingObjectsFromArray:content.tracks];
}

- (NSString *)searchTextForItem:(id)item {
    return [item isKindOfClass:[NSString class]] ? item : [item title];
}

- (void)configureCell:(GLTrackCell *)cell forItem:(id)item {
    cell.showsNumber = YES;
    if ([item isKindOfClass:[NSString class]]) {
        cell.numberLabel.text = @"▸";
        cell.titleLabel.text = item;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        return;
    }
    GLTrack *track = item;
    cell.numberLabel.text = @"";
    cell.titleLabel.text = track.path.lastPathComponent;
    cell.subtitleLabel.text = track.displayArtist;
    cell.timeLabel.text = GLTimeText(track.duration);
    cell.current = [[GLPlayback shared].currentTrack.path isEqualToString:track.path];
}

- (void)didSelectItem:(id)item {
    if ([item isKindOfClass:[NSString class]]) {
        NSString *path = self.folder.length ? [self.folder stringByAppendingPathComponent:item] : item;
        [self.navigationController pushViewController:[[GLFoldersViewController alloc] initWithFolder:path] animated:YES];
        return;
    }
    NSArray *tracks = self.tracks;
    [[GLPlayback shared] playTracks:tracks startAtIndex:[tracks indexOfObjectIdenticalTo:item]];
}

- (NSString *)emptyText {
    return @"This folder holds no music.";
}

- (BOOL)showsCurrentTrack {
    return YES;
}

@end
