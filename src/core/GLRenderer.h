// GLRenderer joins the sound of the tracks into one stream for the output.
// When the current track ends inside a buffer, the next track starts in the
// same buffer, so there is no gap between the tracks.
//
// The renderer counts the frames that it gives to the output from 0. Each
// track starts at a known frame of that count. The output tells the frame
// that it plays now, and the renderer tells which track that is and where.
// All methods are safe to call from any thread.

#import "GLDecoder.h"

@interface GLRendererPosition : NSObject
@property (nonatomic, strong, readonly) id item;  // nil before the first frame or after the end
@property (nonatomic, readonly) double time;      // seconds from the start of the item
// The frame where this play of the item starts. An item that plays two times
// in a row, for repeat one, has two start frames.
@property (nonatomic, readonly) int64_t startFrame;
@end

@interface GLRenderer : NSObject

// Starts the stream again from frame 0 with `decoder`, at `seconds` into
// the item. The next track stays. Call it to start, and after a seek.
- (void)startItem:(id)item decoder:(id<GLDecoder>)decoder atTime:(double)seconds;

// Starts the stream again from frame 0 at `seconds` into the current track.
// The next track stays. Returns NO when no track is left.
- (BOOL)restartAtTime:(double)seconds;

// Sets the track that follows the current track. nil removes it. When the
// stream already ended, the next render continues with this track.
- (void)setNextItem:(id)item decoder:(id<GLDecoder>)decoder;

// The track that the renderer reads now. It can be ahead of the track that
// the output plays, by the length of the buffers of the output.
@property (nonatomic, strong, readonly) id currentItem;

// The item that follows the current track, or nil.
@property (nonatomic, strong, readonly) id nextItem;

// Fills `buffer` with up to `frames` frames. Returns the number of frames.
// The number is less than `frames` only when no track is left.
- (NSUInteger)renderInto:(int16_t *)buffer frames:(NSUInteger)frames;

// The item and the time at `frame` of the stream.
- (GLRendererPosition *)positionAtFrame:(int64_t)frame;

// The frame where the sound ends, or -1 while a track is left.
@property (nonatomic, readonly) int64_t endFrame;

// Removes all tracks.
- (void)clear;

@end
