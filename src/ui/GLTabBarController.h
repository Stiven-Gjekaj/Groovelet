// The tabs of the app: Artists, Albums, Songs, Playlists, and More. When a
// track is in the queue, the mini player shows above the tab bar.

#import <UIKit/UIKit.h>

@interface GLTabBarController : UITabBarController
// Opens the player screen.
- (void)showPlayer;
// Opens the player screen and the queue over it.
- (void)showQueue;
@end
