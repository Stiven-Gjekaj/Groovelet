// GLPlayback is the one player of the app. It joins the play queue and the
// audio player. It keeps the next track ready for gapless play, obeys the
// remote controls, shows the track on the lock screen, and keeps the queue
// and the place for the next start of the app.

#import <UIKit/UIKit.h>
#import "GLPlayQueue.h"

// Posted on each change: a new track, play, pause, or a change of the queue.
extern NSString *const GLPlaybackDidChangeNotification;

@interface GLPlayback : NSObject

+ (instancetype)shared;

@property (nonatomic, strong, readonly) GLPlayQueue *queue;
@property (nonatomic, readonly) BOOL playing;
@property (nonatomic, readonly) GLTrack *currentTrack;
@property (nonatomic, readonly) double currentTime;
@property (nonatomic, readonly) double duration;
@property (nonatomic) BOOL shuffle;
@property (nonatomic) GLRepeatMode repeat;

// Replaces the queue with `tracks`, and plays the track at `index`.
- (void)playTracks:(NSArray *)tracks startAtIndex:(NSUInteger)index;
// Replaces the queue with `tracks` in a random order, and plays.
- (void)shuffleTracks:(NSArray *)tracks;
// Puts the tracks after the current track, or at the end of the queue.
- (void)playNext:(NSArray *)tracks;
- (void)addToQueue:(NSArray *)tracks;
// Changes the queue. The current entry stays.
- (void)moveEntryAtIndex:(NSUInteger)from toIndex:(NSUInteger)to;
- (void)removeEntryAtIndex:(NSUInteger)index;
// Plays the entry at `index` of the queue.
- (void)playEntryAtIndex:(NSUInteger)index;

- (void)togglePlay;
- (void)play;
- (void)pause;
- (void)next;
// Goes to the start of the track, or to the track before it when the time is
// less than 3 seconds.
- (void)previous;
- (void)seekToTime:(double)seconds;

// Call it from the first responder for each remote control event.
- (void)handleRemoteControlEvent:(UIEvent *)event;

// Loads the queue and the place of the last run, away from the main thread.
// The player waits at the place, paused.
- (void)restore;
// Writes the queue and the place. The app calls it when it goes to the back.
- (void)save;

@end
