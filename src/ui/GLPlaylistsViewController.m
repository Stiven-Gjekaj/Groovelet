#import "GLPlaylistsViewController.h"

@implementation GLPlaylistsViewController

- (instancetype)init {
    if ((self = [super init])) {
        self.title = @"Playlists";
        self.tabBarItem.image = [UIImage imageNamed:@"Tab-playlists.png"];
    }
    return self;
}

- (NSString *)emptyText {
    return @"No playlists yet.";
}

@end
