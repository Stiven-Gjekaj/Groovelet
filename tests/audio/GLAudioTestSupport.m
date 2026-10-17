#import "GLAudioTestSupport.h"
#import "GLDecoder.h"

NSString *GLWriteSineFile(NSString *directory, NSString *name, AudioFileTypeID type, UInt32 format,
                          double rate, UInt32 channels, double seconds) {
    NSString *path = [directory stringByAppendingPathComponent:name];
    AudioStreamBasicDescription pcm = {0};
    pcm.mSampleRate = rate;
    pcm.mFormatID = kAudioFormatLinearPCM;
    pcm.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    if (type == kAudioFileAIFFType) pcm.mFormatFlags |= kAudioFormatFlagIsBigEndian;
    pcm.mChannelsPerFrame = channels;
    pcm.mBitsPerChannel = 16;
    pcm.mBytesPerFrame = 2 * channels;
    pcm.mFramesPerPacket = 1;
    pcm.mBytesPerPacket = pcm.mBytesPerFrame;

    AudioStreamBasicDescription fileFormat = pcm;
    if (format != kAudioFormatLinearPCM) {
        memset(&fileFormat, 0, sizeof(fileFormat));
        fileFormat.mSampleRate = rate;
        fileFormat.mFormatID = format;
        fileFormat.mChannelsPerFrame = channels;
        if (format == kAudioFormatAppleLossless) fileFormat.mFormatFlags = kAppleLosslessFormatFlag_16BitSourceData;
    }
    ExtAudioFileRef file = NULL;
    OSStatus status = ExtAudioFileCreateWithURL((__bridge CFURLRef)[NSURL fileURLWithPath:path], type, &fileFormat,
                                                NULL, kAudioFileFlags_EraseFile, &file);
    if (status != noErr) return nil;
    // The software encoder works in a program with no audio session.
    UInt32 software = kAppleSoftwareAudioCodecManufacturer;
    if (format != kAudioFormatLinearPCM) {
        ExtAudioFileSetProperty(file, kExtAudioFileProperty_CodecManufacturer, sizeof(software), &software);
    }
    // The client format is always little-endian.
    pcm.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
    status = ExtAudioFileSetProperty(file, kExtAudioFileProperty_ClientDataFormat, sizeof(pcm), &pcm);
    NSUInteger total = (NSUInteger)llround(seconds * rate);
    int16_t samples[1024 * 8];
    for (NSUInteger done = 0; status == noErr && done < total;) {
        UInt32 n = (UInt32)MIN((NSUInteger)1024, total - done);
        for (UInt32 i = 0; i < n; i++) {
            int16_t value = (int16_t)(8000 * sin(2 * M_PI * 440 * (done + i) / rate));
            for (UInt32 c = 0; c < channels; c++) samples[i * channels + c] = value;
        }
        AudioBufferList list;
        list.mNumberBuffers = 1;
        list.mBuffers[0].mNumberChannels = channels;
        list.mBuffers[0].mDataByteSize = n * pcm.mBytesPerFrame;
        list.mBuffers[0].mData = samples;
        status = ExtAudioFileWrite(file, n, &list);
        done += n;
    }
    OSStatus closed = ExtAudioFileDispose(file);
    return status == noErr && closed == noErr ? path : nil;
}

NSUInteger GLCountFrames(id<GLDecoder> decoder) {
    int16_t buffer[4096 * GLOutputChannels];
    NSUInteger total = 0;
    while (total < 3600u * GLOutputRate) {
        NSInteger n = [decoder readFrames:buffer count:4096];
        if (n <= 0) break;
        total += (NSUInteger)n;
    }
    return total;
}
