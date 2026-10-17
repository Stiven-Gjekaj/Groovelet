// GLPlayback is the one player of the app. It joins the play queue and the
// audio player. It keeps the next track ready for gapless play, obeys the
// remote controls, and shows the track on the lock screen.

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

// Replaces the queue with `tracks`, and plays the track at `index`.
- (void)playTracks:(NSArray *)tracks startAtIndex:(NSUInteger)index;

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

@end
