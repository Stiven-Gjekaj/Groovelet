// Reads the length of an MP3 file from the frame count in its Xing, Info, or
// VBRI header. iOS 6 can get the length wrong: for a CBR file it divides the
// size by the bitrate of the first frame. An encoder can write that first
// frame, which holds the Info header, at a higher bitrate. A test on the
// iPhone 4S (2026-10-18) showed 85.2 seconds for a file of 149 seconds at
// 32 kbit/s, whose Info frame had 56 kbit/s.

#import <Foundation/Foundation.h>

// The length in seconds, or -1 when the file has no such header.
double GLMP3Duration(NSString *path);
