// The tracks that play, in the order that they play.
// Each place in the queue is one GLQueueEntry, so that the same track can
// be in the queue two times. The player plays entries, not tracks.
//
// With shuffle, the entries after the current one are in a random order. The
// queue keeps the order of the source, so that the order comes back when
// shuffle goes off.

#import <Foundation/Foundation.h>
#import "GLTrack.h"

typedef NS_ENUM(NSInteger, GLRepeatMode) {
    GLRepeatOff = 0,
    GLRepeatAll = 1,
    GLRepeatOne = 2,
};

@interface GLQueueEntry : NSObject
@property (nonatomic, strong, readonly) GLTrack *track;
+ (instancetype)entryWithTrack:(GLTrack *)track;
@end

@interface GLPlayQueue : NSObject <NSCopying>

@property (nonatomic, readonly) NSArray *entries;
// The place of the current entry, or NSNotFound when the queue is empty.
@property (nonatomic, readonly) NSUInteger index;
@property (nonatomic, strong, readonly) GLQueueEntry *currentEntry;
@property (nonatomic) BOOL shuffle;
@property (nonatomic) GLRepeatMode repeat;

// Replaces the queue with `tracks`, and makes the track at `index` current.
// With shuffle on, the other tracks follow in a random order.
- (void)setTracks:(NSArray *)tracks currentIndex:(NSUInteger)index;

// The entry that plays after the current one, or nil. With repeat all, the
// first entry follows the last. With repeat one, it is the current entry.
- (GLQueueEntry *)entryAfterCurrent;
// The entry after the current one for the Next button. Repeat one does not
// hold it on the same entry.
- (GLQueueEntry *)entryForNext;
// The entry before the current one, or nil.
- (GLQueueEntry *)entryBeforeCurrent;

// Makes `entry` current. Returns NO when it is not in the queue.
- (BOOL)moveToEntry:(GLQueueEntry *)entry;

// Puts the tracks right after the current entry.
- (void)insertNext:(NSArray *)tracks;
// Puts the tracks at the end.
- (void)append:(NSArray *)tracks;
// Moves an entry to another place. The current entry stays current.
- (void)moveEntryAtIndex:(NSUInteger)from toIndex:(NSUInteger)to;
// Removes an entry. The current entry cannot be removed.
- (BOOL)removeEntryAtIndex:(NSUInteger)index;

- (void)clear;

// A copy shares the entries, not the lists. Another thread can read the
// state of a copy while this queue changes.
- (id)copyWithZone:(NSZone *)zone;

// The queue as a property list: the paths, the order of the source, the
// place, shuffle, and repeat. A property list of 10000 paths is fast to
// write, and a keyed archive of 10000 tracks is not.
- (NSDictionary *)state;
// A queue from a state. `lookup` gives the track of a path, or nil for a file
// that is gone. The entries of the files that are gone are dropped.
+ (instancetype)queueWithState:(NSDictionary *)state lookup:(GLTrack *(^)(NSString *path))lookup;

@end
