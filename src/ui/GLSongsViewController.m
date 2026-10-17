#import "GLSongsViewController.h"
#import "GLFormat.h"
#import "GLImageLoader.h"
#import "GLLibrary.h"
#import "GLPlayback.h"
#import "GLSettings.h"
#import "GLSort.h"

@implementation GLSongsViewController

- (instancetype)init {
    if ((self = [super init])) {
        self.title = @"Songs";
        self.tabBarItem.image = [UIImage imageNamed:@"Tab-songs.png"];
    }
    return self;
}

- (NSArray *)loadItems {
    return [[GLLibrary shared] allTracks];
}

- (NSString *)sortKeyForItem:(GLTrack *)track {
    return GLSortKey(track.sortTitle ?: track.title, [GLSettings shared].ignoreArticles);
}

- (NSString *)searchTextForItem:(GLTrack *)track {
    return [NSString stringWithFormat:@"%@ %@ %@", track.title, track.displayArtist, track.displayAlbum];
}

- (void)configureCell:(GLTrackCell *)cell forItem:(GLTrack *)track {
    cell.titleLabel.text = track.title;
    cell.subtitleLabel.text = [NSString stringWithFormat:@"%@ · %@", track.displayArtist, track.displayAlbum];
    cell.timeLabel.text = GLTimeText(track.duration);
    cell.current = [[GLPlayback shared].currentTrack.path isEqualToString:track.path];
    [[GLImageLoader shared] showArtOfAlbum:track.albumKey path:track.path points:44 inLayer:cell.artLayer];
}

- (void)didSelectItem:(GLTrack *)track {
    NSArray *tracks = self.visibleItems;
    [[GLPlayback shared] playTracks:tracks startAtIndex:[tracks indexOfObjectIdenticalTo:track]];
}

- (NSString *)emptyText {
    return @"No music yet.\n\nCopy files into Media/Groovelet over USB, or use Upload in More.";
}

- (BOOL)showsCurrentTrack {
    return YES;
}

@end
