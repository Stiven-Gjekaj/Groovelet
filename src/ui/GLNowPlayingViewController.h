// The player screen: the art on a blurred copy of the art, the names, the
// place in the track, the controls, the volume with the AirPlay button, and
// the buttons for shuffle, repeat, and the queue.

#import <UIKit/UIKit.h>

@interface GLNowPlayingViewController : UIViewController
// Opens the queue over the player screen.
- (void)showQueue;
@end
