// A row of the lists: the art or a number on the left, a title, a second
// line, and a time on the right. The art is a CALayer, and the cell draws no
// text with drawRect, so the lists scroll fast.

#import <UIKit/UIKit.h>

@interface GLTrackCell : UITableViewCell

@property (nonatomic, strong, readonly) CALayer *artLayer;
@property (nonatomic, strong, readonly) UILabel *titleLabel;
@property (nonatomic, strong, readonly) UILabel *subtitleLabel;
@property (nonatomic, strong, readonly) UILabel *numberLabel;  // Instead of the art
@property (nonatomic, strong, readonly) UILabel *timeLabel;

// With YES, the left shows the number and no art.
@property (nonatomic) BOOL showsNumber;
// The track of the row plays now. The title is coral.
@property (nonatomic) BOOL current;

+ (CGFloat)height;

@end
