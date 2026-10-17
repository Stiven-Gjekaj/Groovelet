// The tracks of one playlist, with Play and Shuffle. A playlist of the app
// can change its order, lose tracks, get a new name, or be deleted.

#import "GLListViewController.h"

@class GLPlaylist;

@interface GLPlaylistViewController : GLListViewController
- (instancetype)initWithPlaylist:(GLPlaylist *)playlist;
@end
