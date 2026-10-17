// Tests of GLPlayQueue.

#import "GLPlayQueue.h"
#import "GLTest.h"

static NSArray *GLTitles(NSArray *entries) {
    NSMutableArray *titles = [NSMutableArray array];
    for (GLQueueEntry *entry in entries) [titles addObject:entry.track.title];
    return titles;
}

static NSArray *GLTracks(NSArray *names) {
    NSMutableArray *tracks = [NSMutableArray array];
    for (NSString *name in names) [tracks addObject:[GLTrack trackWithPath:[name stringByAppendingString:@".mp3"]]];
    return tracks;
}

GL_TEST(test_queue_starts_at_the_chosen_track) {
    GLPlayQueue *queue = [GLPlayQueue new];
    [queue setTracks:GLTracks(@[ @"a", @"b", @"c" ]) currentIndex:1];
    GL_EQUAL(queue.currentEntry.track.title, @"b");
    GL_EQUAL(queue.entryAfterCurrent.track.title, @"c");
    GL_EQUAL(queue.entryBeforeCurrent.track.title, @"a");
}

GL_TEST(test_queue_has_no_entry_after_the_last_track) {
    GLPlayQueue *queue = [GLPlayQueue new];
    [queue setTracks:GLTracks(@[ @"a", @"b" ]) currentIndex:1];
    GL_EXPECT(queue.entryAfterCurrent == nil);
    [queue setTracks:@[] currentIndex:0];
    GL_EQUAL_INT(queue.index, NSNotFound);
    GL_EXPECT(queue.currentEntry == nil);
}

GL_TEST(test_queue_keeps_two_places_for_the_same_track) {
    GLTrack *track = [GLTrack trackWithPath:@"a.mp3"];
    GLPlayQueue *queue = [GLPlayQueue new];
    [queue setTracks:@[ track, track ] currentIndex:0];
    GLQueueEntry *second = queue.entryAfterCurrent;
    GL_EXPECT(second != queue.currentEntry);
    GL_EXPECT([queue moveToEntry:second]);
    GL_EQUAL_INT(queue.index, 1);
    GL_EXPECT(![queue moveToEntry:[GLQueueEntry entryWithTrack:track]]);
}

static GLTrack *(^GLLookup)(NSString *) = ^GLTrack *(NSString *path) {
    return [path hasPrefix:@"gone"] ? nil : [GLTrack trackWithPath:path];
};

GL_TEST(test_queue_comes_back_from_its_state) {
    GLPlayQueue *queue = [GLPlayQueue new];
    [queue setTracks:GLTracks(@[ @"a", @"b", @"c" ]) currentIndex:2];
    NSDictionary *state = [NSPropertyListSerialization
        propertyListWithData:[NSPropertyListSerialization dataWithPropertyList:queue.state
                                                                        format:NSPropertyListBinaryFormat_v1_0
                                                                       options:0 error:NULL]
                     options:0 format:NULL error:NULL];
    GLPlayQueue *copy = [GLPlayQueue queueWithState:state lookup:GLLookup];
    GL_EQUAL_INT(copy.entries.count, 3);
    GL_EQUAL_INT(copy.index, 2);
    GL_EQUAL(copy.currentEntry.track.path, @"c.mp3");
}

GL_TEST(test_queue_drops_the_files_that_are_gone_from_its_state) {
    GLPlayQueue *queue = [GLPlayQueue new];
    [queue setTracks:GLTracks(@[ @"a", @"gone1", @"b", @"gone2", @"c" ]) currentIndex:2];
    GLPlayQueue *copy = [GLPlayQueue queueWithState:queue.state lookup:GLLookup];
    GL_EQUAL(GLTitles(copy.entries), (@[ @"a", @"b", @"c" ]));
    GL_EQUAL(copy.currentEntry.track.title, @"b");
}

GL_TEST(test_queue_repeats_all_and_one) {
    GLPlayQueue *queue = [GLPlayQueue new];
    [queue setTracks:GLTracks(@[ @"a", @"b" ]) currentIndex:1];
    GL_EXPECT(queue.entryAfterCurrent == nil);
    queue.repeat = GLRepeatAll;
    GL_EQUAL(queue.entryAfterCurrent.track.title, @"a");
    queue.repeat = GLRepeatOne;
    GL_EXPECT(queue.entryAfterCurrent == queue.currentEntry);
    GL_EQUAL(queue.entryForNext.track.title, @"a");
    [queue moveToEntry:queue.entries[0]];
    GL_EQUAL(queue.entryBeforeCurrent.track.title, @"b");
}

GL_TEST(test_queue_shuffles_the_tracks_after_the_chosen_one) {
    NSArray *names = @[ @"a", @"b", @"c", @"d", @"e", @"f", @"g", @"h" ];
    GLPlayQueue *queue = [GLPlayQueue new];
    queue.shuffle = YES;
    [queue setTracks:GLTracks(names) currentIndex:3];
    GL_EQUAL_INT(queue.index, 0);
    GL_EQUAL(queue.currentEntry.track.title, @"d");
    GL_EQUAL_INT([[NSSet setWithArray:GLTitles(queue.entries)] count], 8);
    queue.shuffle = NO;
    GL_EQUAL(GLTitles(queue.entries), names);
    GL_EQUAL(queue.currentEntry.track.title, @"d");
    GL_EQUAL_INT(queue.index, 3);
}

GL_TEST(test_queue_shuffle_keeps_the_played_entries_before_the_current_one) {
    GLPlayQueue *queue = [GLPlayQueue new];
    [queue setTracks:GLTracks(@[ @"a", @"b", @"c", @"d", @"e" ]) currentIndex:2];
    queue.shuffle = YES;
    GL_EQUAL([GLTitles(queue.entries) subarrayWithRange:NSMakeRange(0, 3)], (@[ @"a", @"b", @"c" ]));
    GL_EQUAL_INT(queue.index, 2);
}

GL_TEST(test_queue_puts_tracks_next_and_at_the_end) {
    GLPlayQueue *queue = [GLPlayQueue new];
    [queue setTracks:GLTracks(@[ @"a", @"b", @"c" ]) currentIndex:0];
    [queue insertNext:GLTracks(@[ @"x", @"y" ])];
    [queue append:GLTracks(@[ @"z" ])];
    GL_EQUAL(GLTitles(queue.entries), (@[ @"a", @"x", @"y", @"b", @"c", @"z" ]));
    GL_EQUAL(queue.entryAfterCurrent.track.title, @"x");
    GLPlayQueue *empty = [GLPlayQueue new];
    [empty append:GLTracks(@[ @"q" ])];
    GL_EQUAL(empty.currentEntry.track.title, @"q");
}

GL_TEST(test_queue_moves_and_removes_entries_and_keeps_the_current_one) {
    GLPlayQueue *queue = [GLPlayQueue new];
    [queue setTracks:GLTracks(@[ @"a", @"b", @"c", @"d" ]) currentIndex:1];
    [queue moveEntryAtIndex:3 toIndex:0];
    GL_EQUAL(GLTitles(queue.entries), (@[ @"d", @"a", @"b", @"c" ]));
    GL_EQUAL(queue.currentEntry.track.title, @"b");
    GL_EXPECT(![queue removeEntryAtIndex:2]);
    GL_EXPECT([queue removeEntryAtIndex:0]);
    GL_EQUAL(GLTitles(queue.entries), (@[ @"a", @"b", @"c" ]));
    GL_EQUAL_INT(queue.index, 1);
}

GL_TEST(test_queue_keeps_shuffle_and_repeat_in_its_state) {
    GLPlayQueue *queue = [GLPlayQueue new];
    queue.repeat = GLRepeatAll;
    queue.shuffle = YES;
    [queue setTracks:GLTracks(@[ @"a", @"b", @"c" ]) currentIndex:1];
    GLPlayQueue *copy = [GLPlayQueue queueWithState:queue.state lookup:GLLookup];
    GL_EXPECT(copy.shuffle);
    GL_EQUAL_INT(copy.repeat, GLRepeatAll);
    copy.shuffle = NO;
    GL_EQUAL(GLTitles(copy.entries), (@[ @"a", @"b", @"c" ]));
    GL_EQUAL(copy.currentEntry.track.title, @"b");
}

GL_TEST(test_queue_copy_does_not_change_with_the_queue) {
    GLPlayQueue *queue = [GLPlayQueue new];
    [queue setTracks:GLTracks(@[ @"a", @"b" ]) currentIndex:0];
    GLPlayQueue *copy = [queue copy];
    [queue append:GLTracks(@[ @"c" ])];
    [queue moveToEntry:queue.entries[2]];
    GL_EQUAL(GLTitles(copy.entries), (@[ @"a", @"b" ]));
    GL_EQUAL_INT(copy.index, 0);
    GL_EXPECT(copy.entries[1] == queue.entries[1]);
}

GL_TEST(test_queue_removes_deleted_tracks_and_moves_on_from_the_current_one) {
    GLPlayQueue *queue = [GLPlayQueue new];
    [queue setTracks:GLTracks(@[ @"a", @"b", @"c", @"d" ]) currentIndex:1];
    GL_EXPECT(![queue removeEntriesWithPaths:[NSSet setWithObject:@"d.mp3"]]);
    GL_EQUAL(queue.currentEntry.track.title, @"b");
    GL_EXPECT(([queue removeEntriesWithPaths:[NSSet setWithObjects:@"b.mp3", @"c.mp3", nil]]));
    GL_EQUAL(GLTitles(queue.entries), (@[ @"a" ]));
    GL_EQUAL(queue.currentEntry.track.title, @"a");
    GL_EXPECT([queue removeEntriesWithPaths:[NSSet setWithObject:@"a.mp3"]]);
    GL_EQUAL_INT(queue.index, NSNotFound);
}
