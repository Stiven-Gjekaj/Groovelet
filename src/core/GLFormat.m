#import "GLFormat.h"

NSString *GLTimeText(double seconds) {
    if (isnan(seconds) || seconds < 0) return @"--:--";
    long total = lround(floor(seconds));
    long hours = total / 3600, minutes = (total / 60) % 60, rest = total % 60;
    if (hours > 0) return [NSString stringWithFormat:@"%ld:%02ld:%02ld", hours, minutes, rest];
    return [NSString stringWithFormat:@"%ld:%02ld", minutes, rest];
}

NSString *GLCountText(NSInteger count, NSString *word) {
    return [NSString stringWithFormat:@"%ld %@%@", (long)count, word, count == 1 ? @"" : @"s"];
}
