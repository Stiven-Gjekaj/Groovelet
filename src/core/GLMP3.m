#import "GLMP3.h"

static uint32_t GLBig32At(const uint8_t *p) {
    return (uint32_t)p[0] << 24 | (uint32_t)p[1] << 16 | (uint32_t)p[2] << 8 | p[3];
}

double GLMP3Duration(NSString *path) {
    NSFileHandle *file = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!file) return -1;
    NSData *head = [file readDataOfLength:10];
    unsigned long long start = 0;
    const uint8_t *h = head.bytes;
    // Skip an ID3v2 tag.
    if (head.length == 10 && memcmp(h, "ID3", 3) == 0) {
        start = 10 + ((uint32_t)(h[6] & 0x7f) << 21 | (uint32_t)(h[7] & 0x7f) << 14 | (uint32_t)(h[8] & 0x7f) << 7 |
                      (h[9] & 0x7f));
        if (h[5] & 0x10) start += 10;  // A footer
    }
    [file seekToFileOffset:start];
    NSData *data = [file readDataOfLength:8192];
    [file closeFile];
    const uint8_t *d = data.bytes;
    NSUInteger length = data.length;
    // The first frame header: 11 bits of sync, a version, and layer III.
    NSUInteger p = 0;
    while (p + 4 <= length && !(d[p] == 0xff && (d[p + 1] & 0xe0) == 0xe0 && ((d[p + 1] >> 1) & 3) == 1)) p++;
    if (p + 4 > length) return -1;
    int version = (d[p + 1] >> 3) & 3;  // 3: MPEG-1, 2: MPEG-2, 0: MPEG-2.5
    int rateIndex = (d[p + 2] >> 2) & 3;
    BOOL mono = ((d[p + 3] >> 6) & 3) == 3;
    static const int rates[3] = { 44100, 48000, 32000 };
    if (version == 1 || rateIndex == 3) return -1;
    int rate = rates[rateIndex] / (version == 3 ? 1 : version == 2 ? 2 : 4);
    int samples = version == 3 ? 1152 : 576;
    // The Xing or Info header follows the side information.
    NSUInteger side = version == 3 ? (mono ? 17 : 32) : (mono ? 9 : 17);
    NSUInteger x = p + 4 + side;
    uint32_t frames = 0;
    if (x + 12 <= length && (memcmp(d + x, "Xing", 4) == 0 || memcmp(d + x, "Info", 4) == 0)) {
        if (!(GLBig32At(d + x + 4) & 1)) return -1;  // The header has no frame count.
        frames = GLBig32At(d + x + 8);
    } else if (p + 36 + 18 <= length && memcmp(d + p + 36, "VBRI", 4) == 0) {
        frames = GLBig32At(d + p + 36 + 14);
    } else {
        return -1;
    }
    return frames > 0 ? (double)frames * samples / rate : -1;
}
