#import "GLTags.h"

@implementation GLTags

- (instancetype)init {
    if ((self = [super init])) {
        _trackGain = NAN;
        _trackPeak = NAN;
        _albumGain = NAN;
        _albumPeak = NAN;
    }
    return self;
}

@end

#pragma mark Reading the file

// A small reader that reads parts of a file at an offset.
@interface GLTagFile : NSObject
@property (nonatomic, strong) NSFileHandle *handle;
@property (nonatomic) unsigned long long size;
@end

@implementation GLTagFile

+ (instancetype)fileWithPath:(NSString *)path {
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!handle) return nil;
    GLTagFile *file = [GLTagFile new];
    file.handle = handle;
    file.size = [handle seekToEndOfFile];
    return file;
}

// Returns the bytes, or nil when the file has fewer bytes.
- (NSData *)read:(unsigned long long)offset length:(NSUInteger)length {
    if (offset > self.size || length > self.size - offset) return nil;
    @try {
        [self.handle seekToFileOffset:offset];
        NSData *data = [self.handle readDataOfLength:length];
        return data.length == length ? data : nil;
    } @catch (NSException *exception) {
        return nil;
    }
}

@end

static uint32_t GLBig32(const uint8_t *p) {
    return (uint32_t)p[0] << 24 | (uint32_t)p[1] << 16 | (uint32_t)p[2] << 8 | p[3];
}

static uint32_t GLBig24(const uint8_t *p) {
    return (uint32_t)p[0] << 16 | (uint32_t)p[1] << 8 | p[2];
}

static uint32_t GLSyncSafe(const uint8_t *p) {
    return (uint32_t)(p[0] & 0x7f) << 21 | (uint32_t)(p[1] & 0x7f) << 14 | (uint32_t)(p[2] & 0x7f) << 7 | (p[3] & 0x7f);
}

#pragma mark Values

// The first number of "3/12" or "3".
static NSInteger GLLeadingNumber(NSString *text) {
    NSScanner *scanner = [NSScanner scannerWithString:text ?: @""];
    NSInteger value = 0;
    return [scanner scanInteger:&value] && value > 0 ? value : 0;
}

// The year of "2009", "2009-05-01", or "2009-05-01T12:00".
static NSInteger GLYear(NSString *text) {
    if (text.length < 4) return 0;
    NSInteger year = [[text substringToIndex:4] integerValue];
    return year > 0 ? year : 0;
}

// The number in "-6.54 dB" or "0.98".
static double GLDecibels(NSString *text) {
    NSScanner *scanner = [NSScanner scannerWithString:text ?: @""];
    double value = 0;
    return [scanner scanDouble:&value] ? value : NAN;
}

static NSString *GLClean(NSString *text) {
    NSString *trimmed = [text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return trimmed.length ? trimmed : nil;
}

// Stores the value of a field with a common name. ID3, MP4, Vorbis, and APE
// use different names for the same field. Each reader changes its names into
// these names first. A field that has a value keeps its first value.
static void GLSetField(GLTags *tags, NSString *name, NSString *value) {
    value = GLClean(value);
    if (!value) return;
    name = name.lowercaseString;
    if ([name isEqualToString:@"title"]) {
        if (!tags.title) tags.title = value;
    } else if ([name isEqualToString:@"artist"]) {
        if (!tags.artist) tags.artist = value;
    } else if ([name isEqualToString:@"album"]) {
        if (!tags.album) tags.album = value;
    } else if ([name isEqualToString:@"albumartist"] || [name isEqualToString:@"album artist"] ||
               [name isEqualToString:@"album_artist"]) {
        if (!tags.albumArtist) tags.albumArtist = value;
    } else if ([name isEqualToString:@"genre"]) {
        if (!tags.genre) tags.genre = value;
    } else if ([name isEqualToString:@"titlesort"]) {
        if (!tags.sortTitle) tags.sortTitle = value;
    } else if ([name isEqualToString:@"artistsort"]) {
        if (!tags.sortArtist) tags.sortArtist = value;
    } else if ([name isEqualToString:@"albumsort"]) {
        if (!tags.sortAlbum) tags.sortAlbum = value;
    } else if ([name isEqualToString:@"albumartistsort"]) {
        if (!tags.sortAlbumArtist) tags.sortAlbumArtist = value;
    } else if ([name isEqualToString:@"date"] || [name isEqualToString:@"year"]) {
        if (!tags.year) tags.year = GLYear(value);
    } else if ([name isEqualToString:@"tracknumber"] || [name isEqualToString:@"track"]) {
        if (!tags.trackNumber) tags.trackNumber = GLLeadingNumber(value);
    } else if ([name isEqualToString:@"discnumber"] || [name isEqualToString:@"disc"]) {
        if (!tags.discNumber) tags.discNumber = GLLeadingNumber(value);
    } else if ([name isEqualToString:@"compilation"]) {
        tags.compilation = tags.compilation || [value integerValue] != 0;
    } else if ([name isEqualToString:@"replaygain_track_gain"]) {
        if (isnan(tags.trackGain)) tags.trackGain = GLDecibels(value);
    } else if ([name isEqualToString:@"replaygain_track_peak"]) {
        if (isnan(tags.trackPeak)) tags.trackPeak = GLDecibels(value);
    } else if ([name isEqualToString:@"replaygain_album_gain"]) {
        if (isnan(tags.albumGain)) tags.albumGain = GLDecibels(value);
    } else if ([name isEqualToString:@"replaygain_album_peak"]) {
        if (isnan(tags.albumPeak)) tags.albumPeak = GLDecibels(value);
    }
}

#pragma mark ID3v2

// The text of an ID3 text with its encoding byte. Only the first value of a
// list of values separated by zero is kept. `end` gets the length that the
// first value and its terminator use.
static NSString *GLID3Text(const uint8_t *bytes, NSUInteger length, uint8_t encoding, NSUInteger *end) {
    BOOL wide = encoding == 1 || encoding == 2;
    NSUInteger n = 0;
    if (wide) {
        while (n + 1 < length && !(bytes[n] == 0 && bytes[n + 1] == 0)) n += 2;
    } else {
        while (n < length && bytes[n] != 0) n++;
    }
    if (end) *end = MIN(length, n + (wide ? 2 : 1));
    NSStringEncoding stringEncoding = NSISOLatin1StringEncoding;
    if (encoding == 1) stringEncoding = NSUTF16StringEncoding;  // It has a byte order mark.
    if (encoding == 2) stringEncoding = NSUTF16BigEndianStringEncoding;
    if (encoding == 3) stringEncoding = NSUTF8StringEncoding;
    if (encoding == 1 && n >= 2 && !((bytes[0] == 0xff && bytes[1] == 0xfe) || (bytes[0] == 0xfe && bytes[1] == 0xff))) {
        stringEncoding = NSUTF16LittleEndianStringEncoding;
    }
    NSString *text = [[NSString alloc] initWithBytes:bytes length:n encoding:stringEncoding];
    if (!text && encoding == 3) text = [[NSString alloc] initWithBytes:bytes length:n encoding:NSISOLatin1StringEncoding];
    // A byte order mark can stay at the start of the text.
    if ([text hasPrefix:@"﻿"]) text = [text substringFromIndex:1];
    return text;
}

// Removes the unsynchronisation of ID3: each 0xFF 0x00 becomes 0xFF.
static NSData *GLID3Resync(NSData *data) {
    const uint8_t *in = data.bytes;
    NSMutableData *out = [NSMutableData dataWithLength:data.length];
    uint8_t *o = out.mutableBytes;
    NSUInteger n = 0;
    for (NSUInteger i = 0; i < data.length; i++) {
        o[n++] = in[i];
        if (in[i] == 0xff && i + 1 < data.length && in[i + 1] == 0) i++;
    }
    out.length = n;
    return out;
}

// The genre of ID3 can be "(17)" or "(17)Rock". The number alone is dropped.
static NSString *GLID3Genre(NSString *text) {
    if ([text hasPrefix:@"("]) {
        NSRange close = [text rangeOfString:@")"];
        if (close.location != NSNotFound) {
            NSString *rest = [text substringFromIndex:close.location + 1];
            return rest.length ? rest : nil;
        }
    }
    return text;
}

static void GLID3Frame(GLTags *tags, NSString *frameID, NSData *body, BOOL wantPicture) {
    const uint8_t *b = body.bytes;
    NSUInteger length = body.length;
    if (length < 2) return;
    NSDictionary *names = @{
        @"TIT2": @"title", @"TT2": @"title", @"TPE1": @"artist", @"TP1": @"artist", @"TALB": @"album",
        @"TAL": @"album", @"TPE2": @"albumartist", @"TP2": @"albumartist", @"TRCK": @"tracknumber",
        @"TRK": @"tracknumber", @"TPOS": @"discnumber", @"TPA": @"discnumber", @"TYER": @"year", @"TYE": @"year",
        @"TDRC": @"date", @"TCMP": @"compilation", @"TCP": @"compilation", @"TSOT": @"titlesort",
        @"TSOP": @"artistsort", @"TSOA": @"albumsort", @"TSO2": @"albumartistsort",
    };
    NSString *name = names[frameID];
    if (name) {
        GLSetField(tags, name, GLID3Text(b + 1, length - 1, b[0], NULL));
    } else if ([frameID isEqualToString:@"TCON"] || [frameID isEqualToString:@"TCO"]) {
        GLSetField(tags, @"genre", GLID3Genre(GLID3Text(b + 1, length - 1, b[0], NULL)));
    } else if ([frameID isEqualToString:@"TXXX"] || [frameID isEqualToString:@"TXX"]) {
        NSUInteger end = 0;
        NSString *description = GLID3Text(b + 1, length - 1, b[0], &end);
        NSString *value = GLID3Text(b + 1 + end, length - 1 - end, b[0], NULL);
        NSString *key = description.lowercaseString;
        if ([key isEqualToString:@"album artist"]) key = @"albumartist";
        GLSetField(tags, key, value);
    } else if ([frameID isEqualToString:@"APIC"] || [frameID isEqualToString:@"PIC"]) {
        tags.hasPicture = YES;
        if (!wantPicture) return;
        // APIC: encoding, MIME type, 0, picture type, description, data.
        // PIC: encoding, 3 letters of the format, picture type, description, data.
        uint8_t encoding = b[0];
        NSUInteger p = 1;
        if ([frameID isEqualToString:@"APIC"]) {
            while (p < length && b[p] != 0) p++;
            p++;
        } else {
            p += 3;
        }
        if (p >= length) return;
        uint8_t type = b[p++];
        NSUInteger end = 0;
        GLID3Text(b + p, length - p, encoding, &end);
        p += end;
        if (p >= length) return;
        // The front cover wins over the other pictures.
        if (!tags.picture || type == 3) tags.picture = [body subdataWithRange:NSMakeRange(p, length - p)];
    }
}

// Reads an ID3v2 tag at `offset`. Returns the length of the tag, or 0.
static unsigned long long GLReadID3v2(GLTagFile *file, unsigned long long offset, GLTags *tags, BOOL wantPicture) {
    NSData *header = [file read:offset length:10];
    const uint8_t *h = header.bytes;
    if (!header || memcmp(h, "ID3", 3) != 0 || h[3] < 2 || h[3] > 4) return 0;
    uint8_t version = h[3];
    uint8_t flags = h[5];
    unsigned long long size = GLSyncSafe(h + 6);
    unsigned long long total = 10 + size + ((flags & 0x10) ? 10 : 0);
    unsigned long long start = offset + 10;
    unsigned long long end = MIN(start + size, file.size);
    // A tag with unsynchronisation of the whole tag is read at once.
    BOOL wholeUnsync = version < 4 && (flags & 0x80);
    NSData *whole = nil;
    if (wholeUnsync) {
        whole = [file read:start length:(NSUInteger)(end - start)];
        if (!whole) return total;
        whole = GLID3Resync(whole);
    }
    unsigned long long p = 0;
    unsigned long long limit = whole ? whole.length : end - start;
    // The extended header.
    if (flags & 0x40) {
        NSData *ext = whole ? [whole subdataWithRange:NSMakeRange(0, MIN((NSUInteger)4, whole.length))]
                            : [file read:start length:4];
        if (ext.length < 4) return total;
        p = version == 4 ? GLSyncSafe(ext.bytes) : GLBig32(ext.bytes) + 4;
    }
    NSUInteger headerLength = version == 2 ? 6 : 10;
    while (p + headerLength <= limit) {
        NSData *frameHeader = whole ? [whole subdataWithRange:NSMakeRange((NSUInteger)p, headerLength)]
                                    : [file read:start + p length:headerLength];
        const uint8_t *f = frameHeader.bytes;
        if (!frameHeader || f[0] == 0) break;  // The padding starts here.
        NSString *frameID = [[NSString alloc] initWithBytes:f length:version == 2 ? 3 : 4
                                                   encoding:NSISOLatin1StringEncoding];
        unsigned long long frameSize = version == 2 ? GLBig24(f + 3) : version == 4 ? GLSyncSafe(f + 4) : GLBig32(f + 4);
        uint8_t frameFlags = version == 2 ? 0 : f[9];
        unsigned long long bodyStart = p + headerLength;
        p = bodyStart + frameSize;
        if (p > limit) break;
        BOOL picture = [frameID isEqualToString:@"APIC"] || [frameID isEqualToString:@"PIC"];
        BOOL wanted = [frameID hasPrefix:@"T"] || picture;
        if (!wanted) continue;
        if (picture && !wantPicture) {
            tags.hasPicture = YES;
            continue;
        }
        // Compressed or encrypted frames are skipped.
        if (version == 3 && (frameFlags & 0xc0)) continue;
        if (version == 4 && (frameFlags & 0x0c)) continue;
        if (frameSize > 32 * 1024 * 1024) continue;
        NSData *body = whole ? [whole subdataWithRange:NSMakeRange((NSUInteger)bodyStart, (NSUInteger)frameSize)]
                             : [file read:start + bodyStart length:(NSUInteger)frameSize];
        if (!body) break;
        if (version == 4 && (frameFlags & 0x02)) body = GLID3Resync(body);
        if (version == 4 && (frameFlags & 0x01) && body.length >= 4) {
            body = [body subdataWithRange:NSMakeRange(4, body.length - 4)];
        }
        GLID3Frame(tags, frameID, body, wantPicture);
    }
    return total;
}

#pragma mark The reader

GLTags *GLReadTags(NSString *path, BOOL wantPicture) {
    GLTagFile *file = [GLTagFile fileWithPath:path];
    if (!file) return nil;
    GLTags *tags = [GLTags new];
    GLReadID3v2(file, 0, tags, wantPicture);
    return tags;
}
