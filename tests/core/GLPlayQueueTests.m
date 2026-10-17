// Tests of GLPlayQueue.

#import "GLPlayQueue.h"
#import "GLTest.h"

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

GL_TEST(test_queue_comes_back_from_an_archive) {
    GLPlayQueue *queue = [GLPlayQueue new];
    [queue setTracks:GLTracks(@[ @"a", @"b", @"c" ]) currentIndex:2];
    GLPlayQueue *copy = [NSKeyedUnarchiver unarchiveObjectWithData:[NSKeyedArchiver archivedDataWithRootObject:queue]];
    GL_EQUAL_INT(copy.entries.count, 3);
    GL_EQUAL_INT(copy.index, 2);
    GL_EQUAL(copy.currentEntry.track.path, @"c.mp3");
}
