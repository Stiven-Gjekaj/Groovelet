// The albums of one artist, by year.

#import "GLListViewController.h"

@class GLArtist;

@interface GLArtistViewController : GLListViewController
- (instancetype)initWithArtist:(GLArtist *)artist;
@end
