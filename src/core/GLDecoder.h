// The interface of an audio decoder. Each decoder gives the sound of one file
// in the format of the output: 44100 Hz, 2 channels, 16-bit samples, with
// the channels interleaved.

#import <Foundation/Foundation.h>

enum {
    GLOutputRate = 44100,
    GLOutputChannels = 2,
};

@protocol GLDecoder <NSObject>

// The length of the file in seconds. It is 0 when the decoder cannot tell.
@property (nonatomic, readonly) double duration;

// Writes up to `frames` frames into `buffer`. Returns the number of frames
// that it wrote. It returns 0 at the end of the file, and -1 for an error.
- (NSInteger)readFrames:(int16_t *)buffer count:(NSUInteger)frames;

// Moves to the frame at `seconds`. Returns NO if it cannot.
- (BOOL)seekToTime:(double)seconds;

@end
