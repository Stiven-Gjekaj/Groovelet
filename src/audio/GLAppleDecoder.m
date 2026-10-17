#import "GLAppleDecoder.h"
#import "GLMP3.h"
#include <AudioToolbox/AudioToolbox.h>

@interface GLAppleDecoder ()
@property (nonatomic) ExtAudioFileRef file;
@property (nonatomic) double fileRate;
@property (nonatomic) double duration;
@end

@implementation GLAppleDecoder

+ (instancetype)decoderWithPath:(NSString *)path error:(NSError **)error {
    ExtAudioFileRef file = NULL;
    OSStatus status = ExtAudioFileOpenURL((__bridge CFURLRef)[NSURL fileURLWithPath:path], &file);
    AudioStreamBasicDescription fileFormat = {0};
    UInt32 size = sizeof(fileFormat);
    if (status == noErr) {
        status = ExtAudioFileGetProperty(file, kExtAudioFileProperty_FileDataFormat, &size, &fileFormat);
    }
    SInt64 frames = 0;
    size = sizeof(frames);
    if (status == noErr) {
        status = ExtAudioFileGetProperty(file, kExtAudioFileProperty_FileLengthFrames, &size, &frames);
    }
    if (status == noErr) {
        AudioStreamBasicDescription client = {0};
        client.mSampleRate = GLOutputRate;
        client.mFormatID = kAudioFormatLinearPCM;
        client.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        client.mChannelsPerFrame = GLOutputChannels;
        client.mBitsPerChannel = 16;
        client.mBytesPerFrame = 2 * GLOutputChannels;
        client.mFramesPerPacket = 1;
        client.mBytesPerPacket = client.mBytesPerFrame;
        status = ExtAudioFileSetProperty(file, kExtAudioFileProperty_ClientDataFormat, sizeof(client), &client);
    }
    if (status != noErr || fileFormat.mSampleRate <= 0) {
        if (file) ExtAudioFileDispose(file);
        if (error) *error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        return nil;
    }
    GLAppleDecoder *decoder = [GLAppleDecoder new];
    decoder.file = file;
    decoder.fileRate = fileFormat.mSampleRate;
    decoder.duration = frames / fileFormat.mSampleRate;
    // iOS can get the length of an MP3 file wrong. Its own header is exact.
    if ([path.pathExtension.lowercaseString isEqualToString:@"mp3"]) {
        double exact = GLMP3Duration(path);
        if (exact > 0) decoder.duration = exact;
    }
    return decoder;
}

- (void)dealloc {
    if (_file) ExtAudioFileDispose(_file);
}

- (NSInteger)readFrames:(int16_t *)buffer count:(NSUInteger)frames {
    AudioBufferList list;
    list.mNumberBuffers = 1;
    list.mBuffers[0].mNumberChannels = GLOutputChannels;
    list.mBuffers[0].mDataByteSize = (UInt32)(frames * GLOutputChannels * sizeof(int16_t));
    list.mBuffers[0].mData = buffer;
    UInt32 count = (UInt32)frames;
    OSStatus status = ExtAudioFileRead(self.file, &count, &list);
    if (status != noErr) return -1;
    return count;
}

- (BOOL)seekToTime:(double)seconds {
    // The offset is in the frames of the file, not in the frames of the output.
    SInt64 frame = (SInt64)llround(MAX(0, seconds) * self.fileRate);
    return ExtAudioFileSeek(self.file, frame) == noErr;
}

@end
