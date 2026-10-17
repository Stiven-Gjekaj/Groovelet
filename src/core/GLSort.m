#import "GLSort.h"

NSString *GLSortKey(NSString *text, BOOL ignoreArticles) {
    NSMutableString *key = [[text ?: @"" stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]]
        mutableCopy];
    CFStringTransform((__bridge CFMutableStringRef)key, NULL, kCFStringTransformStripCombiningMarks, false);
    NSString *lower = key.lowercaseString;
    if (ignoreArticles) {
        for (NSString *article in @[ @"the ", @"a " ]) {
            if ([lower hasPrefix:article] && lower.length > article.length) {
                lower = [lower substringFromIndex:article.length];
                break;
            }
        }
    }
    return lower;
}

NSString *GLIndexLetter(NSString *sortKey) {
    if (!sortKey.length) return @"#";
    unichar c = [sortKey characterAtIndex:0];
    if (c >= 'a' && c <= 'z') return [NSString stringWithFormat:@"%C", (unichar)(c - 'a' + 'A')];
    return @"#";
}
