// GLAudioPlayer plays a track and goes on to the next track with no gap.
// It sends the sound of a GLRenderer to an AudioQueue. The owner of the
// player gives it the next track each time that a track starts.
// Call all methods on the main thread. The delegate gets its calls on the
// main thread.

#import <Foundation/Foundation.h>

@class GLAudioPlayer;

@protocol GLAudioPlayerDelegate <NSObject>
// The sound of `item` starts to play. It is the item of playItem: or the
// next item.
- (void)audioPlayer:(GLAudioPlayer *)player didStartItem:(id)item;
// The last item ended, and the player stopped.
- (void)audioPlayerDidFinish:(GLAudioPlayer *)player;
// The player paused or played, for example for a call.
- (void)audioPlayerDidChangeState:(GLAudioPlayer *)player;
@end

@interface GLAudioPlayer : NSObject

@property (nonatomic, weak) id<GLAudioPlayerDelegate> delegate;
@property (nonatomic, readonly) BOOL playing;
@property (nonatomic, strong, readonly) id currentItem;
@property (nonatomic, readonly) double currentTime;
@property (nonatomic, readonly) double duration;
// 0 to 1. The tests set 0, so that they make no sound.
@property (nonatomic) float volume;

// Starts `item` at `seconds`. With `paused`, it gets ready and waits for
// resume. Returns NO if the file does not open.
- (BOOL)playItem:(id)item path:(NSString *)path atTime:(double)seconds paused:(BOOL)paused;
// Sets the track that follows the current one. nil removes it.
- (void)setNextItem:(id)item path:(NSString *)path;
- (void)pause;
- (void)resume;
- (void)seekToTime:(double)seconds;
- (void)stop;

@end
