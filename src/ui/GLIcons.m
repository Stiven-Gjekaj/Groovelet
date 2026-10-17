#import "GLIcons.h"

// Each icon is drawn in a box of 24 x 24 units, scaled to the size.
static void GLDrawIcon(GLIcon icon) {
    UIBezierPath *path = [UIBezierPath bezierPath];
    switch (icon) {
        case GLIconPlay:
            [path moveToPoint:CGPointMake(6, 3)];
            [path addLineToPoint:CGPointMake(21, 12)];
            [path addLineToPoint:CGPointMake(6, 21)];
            [path closePath];
            [path fill];
            return;
        case GLIconPause:
            [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(5, 3, 5, 18) cornerRadius:1] fill];
            [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(14, 3, 5, 18) cornerRadius:1] fill];
            return;
        case GLIconNext:
        case GLIconPrevious: {
            BOOL next = icon == GLIconNext;
            CGFloat d = next ? 1 : -1, x = next ? 0 : 24;
            [path moveToPoint:CGPointMake(x + d * 3, 5)];
            [path addLineToPoint:CGPointMake(x + d * 13, 12)];
            [path addLineToPoint:CGPointMake(x + d * 3, 19)];
            [path closePath];
            [path moveToPoint:CGPointMake(x + d * 11, 5)];
            [path addLineToPoint:CGPointMake(x + d * 21, 12)];
            [path addLineToPoint:CGPointMake(x + d * 11, 19)];
            [path closePath];
            [path fill];
            [[UIBezierPath bezierPathWithRect:CGRectMake(next ? 20 : 2, 5, 2, 14)] fill];
            return;
        }
        case GLIconShuffle:
            path.lineWidth = 2;
            [path moveToPoint:CGPointMake(2, 7)];
            [path addLineToPoint:CGPointMake(7, 7)];
            [path addCurveToPoint:CGPointMake(17, 17) controlPoint1:CGPointMake(12, 7) controlPoint2:CGPointMake(12, 17)];
            [path addLineToPoint:CGPointMake(20, 17)];
            [path moveToPoint:CGPointMake(2, 17)];
            [path addLineToPoint:CGPointMake(7, 17)];
            [path addCurveToPoint:CGPointMake(17, 7) controlPoint1:CGPointMake(12, 17) controlPoint2:CGPointMake(12, 7)];
            [path addLineToPoint:CGPointMake(20, 7)];
            [path stroke];
            for (NSNumber *y in @[ @7, @17 ]) {
                UIBezierPath *head = [UIBezierPath bezierPath];
                [head moveToPoint:CGPointMake(19, y.floatValue - 3.5)];
                [head addLineToPoint:CGPointMake(23, y.floatValue)];
                [head addLineToPoint:CGPointMake(19, y.floatValue + 3.5)];
                [head closePath];
                [head fill];
            }
            return;
        case GLIconRepeat:
        case GLIconRepeatOne: {
            path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(3, 6, 18, 12) cornerRadius:4];
            path.lineWidth = 2;
            [path stroke];
            UIBezierPath *head = [UIBezierPath bezierPath];
            [head moveToPoint:CGPointMake(13, 2.5)];
            [head addLineToPoint:CGPointMake(17.5, 6)];
            [head addLineToPoint:CGPointMake(13, 9.5)];
            [head closePath];
            [head fill];
            if (icon == GLIconRepeatOne) {
                [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(15, 13, 9, 9)] fill];
            }
            return;
        }
        case GLIconQueue:
            for (int i = 0; i < 3; i++) [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(3, 5 + i * 6, 18, 2.2) cornerRadius:1.1] fill];
            return;
        case GLIconTimer: {
            // A moon: a circle with a circle cut out.
            UIBezierPath *moon = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(3, 3, 18, 18)];
            [moon appendPath:[UIBezierPath bezierPathWithOvalInRect:CGRectMake(9, 0, 16, 16)]];
            moon.usesEvenOddFillRule = YES;
            [moon addClip];
            [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(3, 3, 18, 18)] fill];
            return;
        }
        case GLIconClose:
            path.lineWidth = 2.6;
            path.lineCapStyle = kCGLineCapRound;
            path.lineJoinStyle = kCGLineJoinRound;
            [path moveToPoint:CGPointMake(4, 9)];
            [path addLineToPoint:CGPointMake(12, 16)];
            [path addLineToPoint:CGPointMake(20, 9)];
            [path stroke];
            return;
    }
}

UIImage *GLIconImage(GLIcon icon, CGFloat size, UIColor *color) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextScaleCTM(context, size / 24, size / 24);
    [color setFill];
    [color setStroke];
    GLDrawIcon(icon);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

UIImage *GLThumbImage(CGFloat diameter, UIColor *color) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(diameter + 8, diameter + 8), NO, 0);
    [color setFill];
    [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(4, 4, diameter, diameter)] fill];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

UIImage *GLBarImage(UIColor *color) {
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(5, 3), NO, 0);
    [color setFill];
    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, 5, 3) cornerRadius:1.5] fill];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image resizableImageWithCapInsets:UIEdgeInsetsMake(0, 2, 0, 2)];
}
