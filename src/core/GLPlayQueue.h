// The tracks that play, in the order that they play.
// Each place in the queue is one GLQueueEntry, so that the same track can
// be in the queue two times. The player plays entries, not tracks.

#import <Foundation/Foundation.h>
#import "GLTrack.h"

@interface GLQueueEntry : NSObject <NSCoding>
@property (nonatomic, strong, readonly) GLTrack *track;
+ (instancetype)entryWithTrack:(GLTrack *)track;
@end

@interface GLPlayQueue : NSObject <NSCoding>

@property (nonatomic, readonly) NSArray *entries;
// The place of the current entry, or NSNotFound when the queue is empty.
@property (nonatomic, readonly) NSUInteger index;
@property (nonatomic, strong, readonly) GLQueueEntry *currentEntry;

// Replaces the queue with `tracks`, and makes the track at `index` current.
- (void)setTracks:(NSArray *)tracks currentIndex:(NSUInteger)index;

// The entry that plays after the current one, or nil.
- (GLQueueEntry *)entryAfterCurrent;
// The entry before the current one, or nil.
- (GLQueueEntry *)entryBeforeCurrent;

// Makes `entry` current. Returns NO when it is not in the queue.
- (BOOL)moveToEntry:(GLQueueEntry *)entry;

- (void)clear;

@end
