// One audio file and the facts that the app knows about it.
// The path is relative to the music directory, so that the index stays
// correct when the directory moves.

#import <Foundation/Foundation.h>

@interface GLTrack : NSObject <NSCoding>

@property (nonatomic) int64_t trackID;      // The row in the library, or 0
@property (nonatomic, copy) NSString *path;  // Relative to the music directory
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *artist;
@property (nonatomic, copy) NSString *album;
@property (nonatomic) double duration;

// A track with only a path. The title is the file name with no extension.
+ (instancetype)trackWithPath:(NSString *)path;

@end
