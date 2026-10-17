// The bar above the tab bar: the art, the title, the artist, play or pause,
// and next. A thin coral line shows the place in the track. A tap on the bar
// opens the player screen.

#import <UIKit/UIKit.h>

@interface GLMiniPlayer : UIView

// Called when the owner taps the bar.
@property (nonatomic, copy) void (^onOpen)(void);

+ (CGFloat)height;

@end
