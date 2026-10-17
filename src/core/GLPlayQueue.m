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
// The entries in the order of the source, for the end of shuffle.
@property (nonatomic, strong) NSMutableArray *sourceOrder;
@property (nonatomic) NSUInteger index;
@end

@implementation GLPlayQueue

- (instancetype)init {
    if ((self = [super init])) {
        _list = [NSMutableArray array];
        _sourceOrder = [NSMutableArray array];
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

// Puts the entries after the current one in a random order.
- (void)shuffleAfterCurrent {
    NSUInteger start = self.index == NSNotFound ? 0 : self.index + 1;
    for (NSUInteger i = self.list.count; i > start + 1; i--) {
        NSUInteger j = start + arc4random_uniform((uint32_t)(i - start));
        [self.list exchangeObjectAtIndex:i - 1 withObjectAtIndex:j];
    }
}

- (void)setTracks:(NSArray *)tracks currentIndex:(NSUInteger)index {
    [self.list removeAllObjects];
    for (GLTrack *track in tracks) [self.list addObject:[GLQueueEntry entryWithTrack:track]];
    self.sourceOrder = [self.list mutableCopy];
    self.index = index < self.list.count ? index : (self.list.count ? 0 : NSNotFound);
    if (self.shuffle && self.index != NSNotFound) {
        // The chosen track plays first. The others follow in a random order.
        [self.list exchangeObjectAtIndex:0 withObjectAtIndex:self.index];
        self.index = 0;
        [self shuffleAfterCurrent];
    }
}

- (void)setShuffle:(BOOL)shuffle {
    if (_shuffle == shuffle) return;
    _shuffle = shuffle;
    GLQueueEntry *current = self.currentEntry;
    if (shuffle) {
        [self shuffleAfterCurrent];
        return;
    }
    // Go back to the order of the source. The entries that came later stay
    // after it, in their order.
    NSMutableArray *ordered = [self.sourceOrder mutableCopy];
    [ordered filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id entry, NSDictionary *bindings) {
        return [self.list indexOfObjectIdenticalTo:entry] != NSNotFound;
    }]];
    for (GLQueueEntry *entry in self.list) {
        if ([ordered indexOfObjectIdenticalTo:entry] == NSNotFound) [ordered addObject:entry];
    }
    self.list = ordered;
    self.index = current ? [self.list indexOfObjectIdenticalTo:current] : NSNotFound;
}

- (GLQueueEntry *)entryAfterCurrent {
    if (self.repeat == GLRepeatOne) return self.currentEntry;
    return [self entryForNext];
}

- (GLQueueEntry *)entryForNext {
    if (self.index == NSNotFound) return nil;
    if (self.index + 1 < self.list.count) return self.list[self.index + 1];
    return self.repeat != GLRepeatOff ? self.list.firstObject : nil;
}

- (GLQueueEntry *)entryBeforeCurrent {
    if (self.index == NSNotFound) return nil;
    if (self.index > 0) return self.list[self.index - 1];
    return self.repeat != GLRepeatOff ? self.list.lastObject : nil;
}

- (BOOL)moveToEntry:(GLQueueEntry *)entry {
    NSUInteger found = [self.list indexOfObjectIdenticalTo:entry];
    if (found == NSNotFound) return NO;
    self.index = found;
    return YES;
}

- (void)insertNext:(NSArray *)tracks {
    NSUInteger at = self.index == NSNotFound ? self.list.count : self.index + 1;
    for (GLTrack *track in tracks) {
        GLQueueEntry *entry = [GLQueueEntry entryWithTrack:track];
        [self.list insertObject:entry atIndex:at++];
        [self.sourceOrder addObject:entry];
    }
    if (self.index == NSNotFound && self.list.count) self.index = 0;
}

- (void)append:(NSArray *)tracks {
    for (GLTrack *track in tracks) {
        GLQueueEntry *entry = [GLQueueEntry entryWithTrack:track];
        [self.list addObject:entry];
        [self.sourceOrder addObject:entry];
    }
    if (self.index == NSNotFound && self.list.count) self.index = 0;
}

- (void)moveEntryAtIndex:(NSUInteger)from toIndex:(NSUInteger)to {
    if (from >= self.list.count || to >= self.list.count || from == to) return;
    GLQueueEntry *current = self.currentEntry;
    GLQueueEntry *entry = self.list[from];
    [self.list removeObjectAtIndex:from];
    [self.list insertObject:entry atIndex:to];
    self.index = [self.list indexOfObjectIdenticalTo:current];
    // A move by the owner makes the new order the order of the source.
    if (!self.shuffle) self.sourceOrder = [self.list mutableCopy];
}

- (BOOL)removeEntryAtIndex:(NSUInteger)index {
    if (index >= self.list.count || index == self.index) return NO;
    GLQueueEntry *entry = self.list[index];
    [self.list removeObjectAtIndex:index];
    [self.sourceOrder removeObjectIdenticalTo:entry];
    if (index < self.index) self.index--;
    return YES;
}

- (void)clear {
    [self.list removeAllObjects];
    [self.sourceOrder removeAllObjects];
    self.index = NSNotFound;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if ((self = [self init])) {
        [_list addObjectsFromArray:[coder decodeObjectForKey:@"entries"] ?: @[]];
        NSArray *source = [coder decodeObjectForKey:@"source"];
        _sourceOrder = source ? [source mutableCopy] : [_list mutableCopy];
        NSInteger index = [coder decodeIntegerForKey:@"index"];
        _index = index >= 0 && (NSUInteger)index < _list.count ? (NSUInteger)index : (_list.count ? 0 : NSNotFound);
        _shuffle = [coder decodeBoolForKey:@"shuffle"];
        _repeat = [coder decodeIntegerForKey:@"repeat"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.list forKey:@"entries"];
    [coder encodeObject:self.sourceOrder forKey:@"source"];
    [coder encodeInteger:self.index == NSNotFound ? -1 : (NSInteger)self.index forKey:@"index"];
    [coder encodeBool:self.shuffle forKey:@"shuffle"];
    [coder encodeInteger:self.repeat forKey:@"repeat"];
}

@end
