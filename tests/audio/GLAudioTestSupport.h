// Helpers for the audio tests. They make sound files on the phone, so that
// the repository holds no media files.

#import <Foundation/Foundation.h>
#include <AudioToolbox/AudioToolbox.h>

// Writes `seconds` of a sine wave into a new file. `format` is the format of
// the data in the file, for example kAudioFormatMPEG4AAC. Each channel gets
// the same wave. Returns nil if iOS cannot write it.
NSString *GLWriteSineFile(NSString *directory, NSString *name, AudioFileTypeID type, UInt32 format,
                          double rate, UInt32 channels, double seconds);

// Reads the whole file with `decoder` and returns the number of frames.
// It stops after one hour of sound, for a decoder that never ends.
@protocol GLDecoder;
NSUInteger GLCountFrames(id<GLDecoder> decoder);
