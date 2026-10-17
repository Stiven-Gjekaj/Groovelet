#import "GLPlayback.h"
#import <MediaPlayer/MediaPlayer.h>
#import "GLAudioPlayer.h"
#import "GLLog.h"
#import "GLPaths.h"

NSString *const GLPlaybackDidChangeNotification = @"GLPlaybackDidChange";

@interface GLPlayback () <GLAudioPlayerDelegate>
@property (nonatomic, strong) GLPlayQueue *queue;
@property (nonatomic, strong) GLAudioPlayer *player;
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
    return self.player.currentTime;
}

- (double)duration {
    return self.player.duration ?: self.currentTrack.duration;
}

#pragma mark Commands

- (void)playTracks:(NSArray *)tracks startAtIndex:(NSUInteger)index {
    [self.queue setTracks:tracks currentIndex:index];
    [self startCurrentAtTime:0 paused:NO];
}

// Starts the current entry. A file that does not open is skipped.
- (void)startCurrentAtTime:(double)seconds paused:(BOOL)paused {
    while (self.queue.currentEntry) {
        GLQueueEntry *entry = self.queue.currentEntry;
        if ([self.player playItem:entry path:GLAbsolutePath(entry.track.path) atTime:seconds paused:paused]) return;
        GLLog(@"cannot open %@", entry.track.path);
        GLQueueEntry *next = self.queue.entryAfterCurrent;
        if (!next) break;
        [self.queue moveToEntry:next];
        seconds = 0;
    }
    [self.player stop];
    [self changed];
}

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
}

- (void)next {
    GLQueueEntry *next = self.queue.entryAfterCurrent;
    if (!next) return;
    [self.queue moveToEntry:next];
    [self startCurrentAtTime:0 paused:!self.playing];
}

- (void)previous {
    GLQueueEntry *before = self.queue.entryBeforeCurrent;
    if (self.currentTime >= 3 || !before) {
        [self seekToTime:0];
        return;
    }
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
    [self.queue moveToEntry:item];
    GLLog(@"start %@ at %.2f", ((GLQueueEntry *)item).track.path, player.currentTime);
    GLQueueEntry *next = self.queue.entryAfterCurrent;
    [self.player setNextItem:next path:next ? GLAbsolutePath(next.track.path) : nil];
    [self changed];
}

- (void)audioPlayerDidFinish:(GLAudioPlayer *)player {
    GLLog(@"the queue ended");
    // The queue ended. Go back to its first track, and wait.
    GLQueueEntry *first = self.queue.entries.firstObject;
    if (first) {
        [self.queue moveToEntry:first];
        [self startCurrentAtTime:0 paused:YES];
    }
    [self changed];
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
        if (track.artist) info[MPMediaItemPropertyArtist] = track.artist;
        if (track.album) info[MPMediaItemPropertyAlbumTitle] = track.album;
        info[MPMediaItemPropertyPlaybackDuration] = @(self.duration);
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(self.currentTime);
        info[MPNowPlayingInfoPropertyPlaybackRate] = @(self.playing ? 1 : 0);
        info[MPNowPlayingInfoPropertyPlaybackQueueIndex] = @(self.queue.index);
        info[MPNowPlayingInfoPropertyPlaybackQueueCount] = @(self.queue.entries.count);
    }
    [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = info;
    [[NSNotificationCenter defaultCenter] postNotificationName:GLPlaybackDidChangeNotification object:self];
}

@end
