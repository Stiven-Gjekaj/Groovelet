// The text of times and counts in the lists.

#import <Foundation/Foundation.h>

// "3:07" or "1:02:03". "--:--" for an unknown time.
NSString *GLTimeText(double seconds);
// "1 song", "12 songs". The word is the singular form.
NSString *GLCountText(NSInteger count, NSString *word);
