// The tracks of one album, with a header of the art and the facts, and a
// Play button.

#import "GLListViewController.h"

@class GLAlbum;

@interface GLAlbumViewController : GLListViewController
- (instancetype)initWithAlbum:(GLAlbum *)album;
@end
