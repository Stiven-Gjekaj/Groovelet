#import "GLPlayback.h"
#import <MediaPlayer/MediaPlayer.h>
#import "GLArtCache.h"
#import "GLAudioPlayer.h"
#import "GLLibrary.h"
#import "GLLog.h"
#import "GLPaths.h"

NSString *const GLPlaybackDidChangeNotification = @"GLPlaybackDidChange";

@interface GLPlayback () <GLAudioPlayerDelegate>
@property (nonatomic, strong) GLPlayQueue *queue;
@property (nonatomic, strong) GLAudioPlayer *player;
@property (nonatomic) BOOL queueChanged;
@property (nonatomic, strong) NSTimer *saveTimer;
@property (nonatomic, strong) MPMediaItemArtwork *artwork;
@property (nonatomic, copy) NSString *artworkKey;
// YES while the player starts an entry because of a command, not because the
// track before it ended.
@property (nonatomic) BOOL manualStart;
@end

@implementation GLPlayback

+ (instancetype)shared {
    static GLPlayback *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [GLPlayback new]; });
    return shared;
}

- (instancetype)init {
    if ((self = [super init])) {
        _queue = [GLPlayQueue new];
        _player = [GLAudioPlayer new];
        _player.delegate = self;
        // Save the place now and then, for a stop that gives no warning.
        _saveTimer = [NSTimer scheduledTimerWithTimeInterval:15 target:self selector:@selector(saveIfPlaying)
                                                    userInfo:nil repeats:YES];
    }
    return self;
}

- (BOOL)playing {
    return self.player.playing;
}

- (GLTrack *)currentTrack {
    return self.queue.currentEntry.track;
}

- (double)currentTime {
    return self.player.currentItem ? self.player.currentTime : 0;
}

- (double)duration {
    return self.player.duration ?: self.currentTrack.duration;
}

- (BOOL)shuffle {
    return self.queue.shuffle;
}

- (void)setShuffle:(BOOL)shuffle {
    self.queue.shuffle = shuffle;
    [self queueDidChange];
}

- (GLRepeatMode)repeat {
    return self.queue.repeat;
}

- (void)setRepeat:(GLRepeatMode)repeat {
    self.queue.repeat = repeat;
    [self queueDidChange];
}

#pragma mark The queue

#pragma mark Play counts

// A play counts when the track ends, or when the owner leaves it after more
// than half of it.
- (void)countPlayOfEntry:(GLQueueEntry *)entry {
    NSString *path = entry.track.path;
    if (!path) return;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        [[GLLibrary shared] recordPlayOfPath:path];
    });
}

- (void)countCurrentIfMostlyPlayed {
    double duration = self.duration;
    if (self.player.currentItem && duration > 0 && self.currentTime >= duration / 2) {
        [self countPlayOfEntry:self.queue.currentEntry];
    }
}

#pragma mark The queue

- (void)playTracks:(NSArray *)tracks startAtIndex:(NSUInteger)index {
    [self countCurrentIfMostlyPlayed];
    [self.queue setTracks:tracks currentIndex:index];
    self.queueChanged = YES;
    [self startCurrentAtTime:0 paused:NO];
}

- (void)shuffleTracks:(NSArray *)tracks {
    if (!tracks.count) return;
    self.queue.shuffle = YES;
    [self playTracks:tracks startAtIndex:arc4random_uniform((uint32_t)tracks.count)];
}

- (void)playNext:(NSArray *)tracks {
    BOOL wasEmpty = !self.queue.currentEntry;
    [self.queue insertNext:tracks];
    [self afterAdding:wasEmpty];
}

- (void)addToQueue:(NSArray *)tracks {
    BOOL wasEmpty = !self.queue.currentEntry;
    [self.queue append:tracks];
    [self afterAdding:wasEmpty];
}

- (void)afterAdding:(BOOL)wasEmpty {
    if (wasEmpty) {
        self.queueChanged = YES;
        [self startCurrentAtTime:0 paused:NO];
    } else {
        [self queueDidChange];
    }
}

- (void)moveEntryAtIndex:(NSUInteger)from toIndex:(NSUInteger)to {
    [self.queue moveEntryAtIndex:from toIndex:to];
    [self queueDidChange];
}

- (void)removeEntryAtIndex:(NSUInteger)index {
    if ([self.queue removeEntryAtIndex:index]) [self queueDidChange];
}

- (void)playEntryAtIndex:(NSUInteger)index {
    if (index >= self.queue.entries.count) return;
    [self countCurrentIfMostlyPlayed];
    [self.queue moveToEntry:self.queue.entries[index]];
    [self startCurrentAtTime:0 paused:NO];
}

// The entry after the current one can be another now. Tell the player.
- (void)queueDidChange {
    self.queueChanged = YES;
    [self prepareNext];
    [self changed];
}

- (void)prepareNext {
    if (!self.player.currentItem) return;
    GLQueueEntry *next = self.queue.entryAfterCurrent;
    [self.player setNextItem:next path:next ? GLAbsolutePath(next.track.path) : nil];
}

// Starts the current entry. A file that does not open is skipped.
- (void)startCurrentAtTime:(double)seconds paused:(BOOL)paused {
    NSUInteger tries = self.queue.entries.count;
    while (self.queue.currentEntry && tries-- > 0) {
        GLQueueEntry *entry = self.queue.currentEntry;
        self.manualStart = YES;
        BOOL started = [self.player playItem:entry path:GLAbsolutePath(entry.track.path) atTime:seconds paused:paused];
        self.manualStart = NO;
        if (started) return;
        GLLog(@"cannot open %@", entry.track.path);
        GLQueueEntry *next = self.queue.entryForNext;
        if (!next) break;
        [self.queue moveToEntry:next];
        seconds = 0;
    }
    [self.player stop];
    [self changed];
}

#pragma mark Commands

- (void)togglePlay {
    if (self.playing) [self pause];
    else [self play];
}

- (void)play {
    if (!self.player.currentItem) {
        [self startCurrentAtTime:0 paused:NO];
        return;
    }
    [self.player resume];
    [self changed];
}

- (void)pause {
    [self.player pause];
    [self changed];
    [self save];
}

- (void)next {
    GLQueueEntry *next = self.queue.entryForNext;
    if (!next) return;
    [self countCurrentIfMostlyPlayed];
    [self.queue moveToEntry:next];
    [self startCurrentAtTime:0 paused:!self.playing];
}

- (void)previous {
    GLQueueEntry *before = self.queue.entryBeforeCurrent;
    if (self.currentTime >= 3 || !before) {
        [self seekToTime:0];
        return;
    }
    [self countCurrentIfMostlyPlayed];
    [self.queue moveToEntry:before];
    [self startCurrentAtTime:0 paused:!self.playing];
}

- (void)seekToTime:(double)seconds {
    [self.player seekToTime:seconds];
    [self changed];
}

- (void)handleRemoteControlEvent:(UIEvent *)event {
    if (event.type != UIEventTypeRemoteControl) return;
    switch (event.subtype) {
        case UIEventSubtypeRemoteControlPlay: [self play]; break;
        case UIEventSubtypeRemoteControlPause: [self pause]; break;
        case UIEventSubtypeRemoteControlStop: [self pause]; break;
        case UIEventSubtypeRemoteControlTogglePlayPause: [self togglePlay]; break;
        case UIEventSubtypeRemoteControlNextTrack: [self next]; break;
        case UIEventSubtypeRemoteControlPreviousTrack: [self previous]; break;
        default: break;
    }
}

#pragma mark The audio player

- (void)audioPlayer:(GLAudioPlayer *)player didStartItem:(id)item {
    // The track before this one played to its end.
    if (!self.manualStart) [self countPlayOfEntry:self.queue.currentEntry];
    [self.queue moveToEntry:item];
    GLLog(@"start %@ at %.2f", ((GLQueueEntry *)item).track.path, player.currentTime);
    [self prepareNext];
    [self changed];
    [self save];
}

- (void)audioPlayerDidFinish:(GLAudioPlayer *)player {
    GLLog(@"the queue ended");
    [self countPlayOfEntry:self.queue.currentEntry];
    // Go back to the first track of the queue, and wait.
    GLQueueEntry *first = self.queue.entries.firstObject;
    if (first) {
        [self.queue moveToEntry:first];
        [self startCurrentAtTime:0 paused:YES];
    }
    [self changed];
    [self save];
}

- (void)audioPlayerDidChangeState:(GLAudioPlayer *)player {
    [self changed];
}

#pragma mark The lock screen

- (void)changed {
    GLTrack *track = self.currentTrack;
    NSMutableDictionary *info = nil;
    if (track) {
        info = [NSMutableDictionary dictionary];
        info[MPMediaItemPropertyTitle] = track.title ?: @"";
        info[MPMediaItemPropertyArtist] = track.displayArtist;
        info[MPMediaItemPropertyAlbumTitle] = track.displayAlbum;
        info[MPMediaItemPropertyPlaybackDuration] = @(self.duration);
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(self.currentTime);
        info[MPNowPlayingInfoPropertyPlaybackRate] = @(self.playing ? 1 : 0);
        info[MPNowPlayingInfoPropertyPlaybackQueueIndex] = @(self.queue.index);
        info[MPNowPlayingInfoPropertyPlaybackQueueCount] = @(self.queue.entries.count);
        if ([self.artworkKey isEqualToString:track.albumKey]) {
            if (self.artwork) info[MPMediaItemPropertyArtwork] = self.artwork;
        } else {
            [self loadArtworkOfTrack:track];
        }
    }
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = info;
    [[NSNotificationCenter defaultCenter] postNotificationName:GLPlaybackDidChangeNotification object:self];
}

// Loads the art for the lock screen at 320 pixels, away from the main thread.
- (void)loadArtworkOfTrack:(GLTrack *)track {
    NSString *key = track.albumKey;
    self.artworkKey = key;
    self.artwork = nil;
    NSString *path = GLAbsolutePath(track.path);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
        NSString *file = [[GLArtCache shared] thumbnailForKey:key audioPath:path pixels:320];
        UIImage *image = file ? [UIImage imageWithContentsOfFile:file] : nil;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![self.artworkKey isEqualToString:key] || !image) return;
            self.artwork = [[MPMediaItemArtwork alloc] initWithImage:image];
            [self changed];
        });
    });
}

#pragma mark The state for the next start

- (NSString *)queuePath {
    return [GLSupportDirectory() stringByAppendingPathComponent:@"queue.plist"];
}

- (NSString *)placePath {
    return [GLSupportDirectory() stringByAppendingPathComponent:@"place.plist"];
}

- (void)saveIfPlaying {
    if (self.playing) [self save];
}

- (void)save {
    // The queue is large and changes less often than the place, so it has its
    // own file.
    if (self.queueChanged) {
        self.queueChanged = NO;
        GLPlayQueue *copy = [self.queue copy];
        NSString *path = [self queuePath];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            NSData *data = [NSPropertyListSerialization dataWithPropertyList:copy.state
                                                                      format:NSPropertyListBinaryFormat_v1_0
                                                                     options:0 error:NULL];
            [data writeToFile:path atomically:YES];
        });
    }
    NSDictionary *place = @{ @"index": @(self.queue.index == NSNotFound ? -1 : (NSInteger)self.queue.index),
                             @"time": @(self.currentTime) };
    [place writeToFile:[self placePath] atomically:YES];
}

- (void)restore {
    NSString *queuePath = [self queuePath];
    NSString *placePath = [self placePath];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSData *data = [NSData dataWithContentsOfFile:queuePath];
        NSMutableDictionary *state = data ? [[NSPropertyListSerialization propertyListWithData:data
                                                options:NSPropertyListMutableContainers format:NULL error:NULL]
                                               mutableCopy] : nil;
        NSDictionary *place = [NSDictionary dictionaryWithContentsOfFile:placePath];
        if (![state isKindOfClass:[NSDictionary class]] || ![state[@"paths"] count]) return;
        if (place[@"index"]) state[@"index"] = place[@"index"];
        NSMutableDictionary *tracks = [NSMutableDictionary dictionary];
        for (GLTrack *track in [[GLLibrary shared] allTracks]) tracks[track.path] = track;
        GLPlayQueue *queue = [GLPlayQueue queueWithState:state lookup:^GLTrack *(NSString *path) {
            return tracks[path];
        }];
        double time = [place[@"time"] doubleValue];
        dispatch_async(dispatch_get_main_queue(), ^{
            // A play that the owner started during the load wins.
            if (self.player.currentItem || !queue.currentEntry) return;
            self.queue = queue;
            [self startCurrentAtTime:time paused:YES];
            GLLog(@"restored %lu entries at %.1f s", (unsigned long)queue.entries.count, time);
        });
    });
}

@end
