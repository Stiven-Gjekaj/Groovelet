#import "GLTagBuilder.h"
#import "GLTest.h"

static NSData *GLSyncSafeData(uint32_t value) {
    uint8_t b[4] = { (value >> 21) & 0x7f, (value >> 14) & 0x7f, (value >> 7) & 0x7f, value & 0x7f };
    return [NSData dataWithBytes:b length:4];
}

NSData *GLBig32Data(uint32_t value) {
    uint8_t b[4] = { value >> 24, value >> 16, value >> 8, value };
    return [NSData dataWithBytes:b length:4];
}

NSData *GLLittle32Data(uint32_t value) {
    uint8_t b[4] = { value, value >> 8, value >> 16, value >> 24 };
    return [NSData dataWithBytes:b length:4];
}

NSData *GLBytes(NSString *text) {
    return [text dataUsingEncoding:NSUTF8StringEncoding];
}

NSData *GLID3Frame(NSString *frameID, NSData *body, int version) {
    NSMutableData *frame = [NSMutableData dataWithData:GLBytes(frameID)];
    [frame appendData:version == 4 ? GLSyncSafeData((uint32_t)body.length) : GLBig32Data((uint32_t)body.length)];
    uint8_t flags[2] = { 0, 0 };
    [frame appendBytes:flags length:2];
    [frame appendData:body];
    return frame;
}

NSData *GLID3TextFrame(NSString *frameID, NSString *text, uint8_t encoding, int version) {
    NSMutableData *body = [NSMutableData dataWithBytes:&encoding length:1];
    if (encoding == 1) {
        [body appendData:[text dataUsingEncoding:NSUTF16StringEncoding]];  // With a byte order mark.
    } else if (encoding == 0) {
        [body appendData:[text dataUsingEncoding:NSISOLatin1StringEncoding]];
    } else {
        [body appendData:GLBytes(text)];
    }
    return GLID3Frame(frameID, body, version);
}

NSData *GLID3PictureBody(uint8_t type, NSData *picture) {
    NSMutableData *body = [NSMutableData data];
    uint8_t encoding = 0;
    [body appendBytes:&encoding length:1];
    [body appendData:GLBytes(@"image/jpeg")];
    uint8_t zero = 0;
    [body appendBytes:&zero length:1];
    [body appendBytes:&type length:1];
    [body appendData:GLBytes(@"cover")];
    [body appendBytes:&zero length:1];
    [body appendData:picture];
    return body;
}

NSData *GLID3Tag(NSArray *frames, int version, NSUInteger padding) {
    NSMutableData *content = [NSMutableData data];
    for (NSData *frame in frames) [content appendData:frame];
    [content increaseLengthBy:padding];
    NSMutableData *tag = [NSMutableData dataWithData:GLBytes(@"ID3")];
    uint8_t header[3] = { (uint8_t)version, 0, 0 };
    [tag appendBytes:header length:3];
    [tag appendData:GLSyncSafeData((uint32_t)content.length)];
    [tag appendData:content];
    return tag;
}

NSString *GLWriteFile(NSString *name, NSArray *parts) {
    NSMutableData *data = [NSMutableData data];
    for (NSData *part in parts) [data appendData:part];
    NSString *path = [GLTestTemporaryDirectory() stringByAppendingPathComponent:name];
    [data writeToFile:path atomically:YES];
    return path;
}

NSData *GLFakeAudio(NSUInteger length) {
    NSMutableData *data = [NSMutableData dataWithLength:length];
    uint8_t *b = data.mutableBytes;
    for (NSUInteger i = 0; i < length; i++) b[i] = (uint8_t)(i * 7 + 1);
    return data;
}
