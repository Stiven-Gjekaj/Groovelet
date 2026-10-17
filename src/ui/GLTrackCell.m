#import "GLTrackCell.h"
#import "GLTheme.h"

@interface GLTrackCell ()
@property (nonatomic, strong) CALayer *artLayer;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UILabel *numberLabel;
@property (nonatomic, strong) UILabel *timeLabel;
@end

@implementation GLTrackCell

+ (CGFloat)height {
    return 58;
}

static UILabel *GLLabel(UIFont *font, UIColor *color) {
    UILabel *label = [UILabel new];
    label.font = font;
    label.textColor = color;
    label.backgroundColor = GLBackgroundColor();  // Opaque, so it blends fast.
    label.highlightedTextColor = GLTextColor();
    return label;
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier])) {
        self.backgroundColor = GLBackgroundColor();
        self.contentView.backgroundColor = GLBackgroundColor();
        UIView *selected = [UIView new];
        selected.backgroundColor = [UIColor colorWithWhite:1 alpha:0.08];
        self.selectedBackgroundView = selected;
        _artLayer = [CALayer layer];
        _artLayer.contentsGravity = kCAGravityResizeAspectFill;
        _artLayer.masksToBounds = YES;
        _artLayer.cornerRadius = 3;
        _artLayer.backgroundColor = GLSurfaceColor().CGColor;
        // No animation when the art changes.
        _artLayer.actions = @{ @"contents": [NSNull null], @"bounds": [NSNull null], @"position": [NSNull null] };
        [self.contentView.layer addSublayer:_artLayer];
        _titleLabel = GLLabel(GLFont(16), GLTextColor());
        _subtitleLabel = GLLabel(GLFont(13), GLSecondaryTextColor());
        _numberLabel = GLLabel(GLFont(14), GLSecondaryTextColor());
        _numberLabel.textAlignment = NSTextAlignmentCenter;
        _timeLabel = GLLabel(GLFont(13), GLSecondaryTextColor());
        _timeLabel.textAlignment = NSTextAlignmentRight;
        for (UILabel *label in @[ _titleLabel, _subtitleLabel, _numberLabel, _timeLabel ]) {
            [self.contentView addSubview:label];
        }
        self.showsNumber = NO;
    }
    return self;
}

- (void)setCurrent:(BOOL)current {
    _current = current;
    self.titleLabel.textColor = current ? GLAccentColor() : GLTextColor();
    self.titleLabel.font = current ? GLBoldFont(16) : GLFont(16);
}

- (void)setShowsNumber:(BOOL)showsNumber {
    _showsNumber = showsNumber;
    self.artLayer.hidden = self.plain || showsNumber;
    self.numberLabel.hidden = self.plain || !showsNumber;
    [self setNeedsLayout];
}

- (void)setPlain:(BOOL)plain {
    _plain = plain;
    self.artLayer.hidden = plain || self.showsNumber;
    self.numberLabel.hidden = plain || !self.showsNumber;
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect bounds = self.contentView.bounds;
    CGFloat left = 10;
    CGFloat leftWidth = self.plain ? 0 : self.showsNumber ? 28 : 44;
    self.artLayer.frame = CGRectMake(left, (bounds.size.height - 44) / 2, 44, 44);
    self.numberLabel.frame = CGRectMake(left - 2, 0, leftWidth, bounds.size.height);
    CGFloat textLeft = self.plain ? 16 : left + leftWidth + 10;
    CGFloat timeWidth = self.timeLabel.text.length ? 52 : 0;
    CGFloat textWidth = bounds.size.width - textLeft - timeWidth - 10;
    BOOL two = self.subtitleLabel.text.length > 0;
    self.titleLabel.frame = CGRectMake(textLeft, two ? 9 : 0, textWidth, two ? 21 : bounds.size.height);
    self.subtitleLabel.frame = CGRectMake(textLeft, 30, textWidth, 18);
    self.subtitleLabel.hidden = !two;
    self.timeLabel.frame = CGRectMake(bounds.size.width - timeWidth - 10, 0, timeWidth, bounds.size.height);
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.artLayer.contents = nil;
    self.current = NO;
    self.timeLabel.text = nil;
    self.subtitleLabel.text = nil;
    self.accessoryType = UITableViewCellAccessoryNone;
}

@end
