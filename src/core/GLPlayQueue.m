#import "GLPlayQueue.h"

@interface GLQueueEntry ()
@property (nonatomic, strong) GLTrack *track;
@end

@implementation GLQueueEntry

+ (instancetype)entryWithTrack:(GLTrack *)track {
    GLQueueEntry *entry = [GLQueueEntry new];
    entry.track = track;
    return entry;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if ((self = [super init])) _track = [coder decodeObjectForKey:@"track"];
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.track forKey:@"track"];
}

@end

@interface GLPlayQueue ()
@property (nonatomic, strong) NSMutableArray *list;
@property (nonatomic) NSUInteger index;
@end

@implementation GLPlayQueue

- (instancetype)init {
    if ((self = [super init])) {
        _list = [NSMutableArray array];
        _index = NSNotFound;
    }
    return self;
}

- (NSArray *)entries {
    return [self.list copy];
}

- (GLQueueEntry *)currentEntry {
    return self.index < self.list.count ? self.list[self.index] : nil;
}

- (void)setTracks:(NSArray *)tracks currentIndex:(NSUInteger)index {
    [self.list removeAllObjects];
    for (GLTrack *track in tracks) [self.list addObject:[GLQueueEntry entryWithTrack:track]];
    self.index = index < self.list.count ? index : (self.list.count ? 0 : NSNotFound);
}

- (GLQueueEntry *)entryAfterCurrent {
    if (self.index == NSNotFound || self.index + 1 >= self.list.count) return nil;
    return self.list[self.index + 1];
}

- (GLQueueEntry *)entryBeforeCurrent {
    if (self.index == NSNotFound || self.index == 0) return nil;
    return self.list[self.index - 1];
}

- (BOOL)moveToEntry:(GLQueueEntry *)entry {
    NSUInteger found = [self.list indexOfObjectIdenticalTo:entry];
    if (found == NSNotFound) return NO;
    self.index = found;
    return YES;
}

- (void)clear {
    [self.list removeAllObjects];
    self.index = NSNotFound;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if ((self = [self init])) {
        [_list addObjectsFromArray:[coder decodeObjectForKey:@"entries"] ?: @[]];
        NSInteger index = [coder decodeIntegerForKey:@"index"];
        _index = index >= 0 && (NSUInteger)index < _list.count ? (NSUInteger)index : (_list.count ? 0 : NSNotFound);
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.list forKey:@"entries"];
    [coder encodeInteger:self.index == NSNotFound ? -1 : (NSInteger)self.index forKey:@"index"];
}

@end
