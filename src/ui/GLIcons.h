// The icons of the player. The app draws them with paths at the size and in
// the color that a button needs, so they stay sharp and need no image files.

#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, GLIcon) {
    GLIconPlay,
    GLIconPause,
    GLIconNext,
    GLIconPrevious,
    GLIconShuffle,
    GLIconRepeat,
    GLIconRepeatOne,
    GLIconQueue,
    GLIconTimer,
    GLIconClose,
};

UIImage *GLIconImage(GLIcon icon, CGFloat size, UIColor *color);

// A round thumb for the sliders.
UIImage *GLThumbImage(CGFloat diameter, UIColor *color);
// A thin bar for the track of a slider.
UIImage *GLBarImage(UIColor *color);
