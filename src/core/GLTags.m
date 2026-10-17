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

#pragma mark MP4

// Calls `block` for each atom between `start` and `end`. `block` returns NO
// to stop.
static void GLMP4Atoms(GLTagFile *file, unsigned long long start, unsigned long long end,
                       BOOL (^block)(NSString *type, unsigned long long body, unsigned long long length)) {
    unsigned long long p = start;
    while (p + 8 <= end) {
        NSData *header = [file read:p length:8];
        if (!header) return;
        const uint8_t *h = header.bytes;
        unsigned long long size = GLBig32(h);
        unsigned long long headerLength = 8;
        if (size == 1) {
            NSData *large = [file read:p + 8 length:8];
            if (!large) return;
            const uint8_t *l = large.bytes;
            size = (unsigned long long)GLBig32(l) << 32 | GLBig32(l + 4);
            headerLength = 16;
        } else if (size == 0) {
            size = end - p;
        }
        if (size < headerLength || p + size > end) return;
        NSString *type = [[NSString alloc] initWithBytes:h + 4 length:4 encoding:NSISOLatin1StringEncoding];
        if (!block(type, p + headerLength, size - headerLength)) return;
        p += size;
    }
}

// Finds the first atom with the path of types, for example moov/udta/meta.
static BOOL GLMP4Find(GLTagFile *file, unsigned long long start, unsigned long long end, NSArray *path,
                      unsigned long long *bodyOut, unsigned long long *lengthOut) {
    __block BOOL found = NO;
    GLMP4Atoms(file, start, end, ^BOOL(NSString *type, unsigned long long body, unsigned long long length) {
        if (![type isEqualToString:path[0]]) return YES;
        unsigned long long childStart = body;
        // The meta atom has 4 bytes of version and flags before its children,
        // unless the next 4 bytes after them are a handler atom.
        if ([type isEqualToString:@"meta"]) {
            NSData *peek = [file read:body + 4 length:4];
            if (!(peek && memcmp(peek.bytes, "hdlr", 4) == 0)) childStart += 4;
        }
        if (path.count == 1) {
            *bodyOut = childStart;
            *lengthOut = length - (childStart - body);
            found = YES;
        } else {
            found = GLMP4Find(file, childStart, body + length, [path subarrayWithRange:NSMakeRange(1, path.count - 1)],
                              bodyOut, lengthOut);
        }
        return NO;
    });
    return found;
}

// The payload of the "data" atom inside an item of ilst, and its type.
static NSData *GLMP4ItemData(GLTagFile *file, unsigned long long body, unsigned long long length, uint32_t *typeOut,
                             NSString **freeformName) {
    __block NSData *payload = nil;
    __block NSString *name = nil;
    GLMP4Atoms(file, body, body + length, ^BOOL(NSString *type, unsigned long long atomBody, unsigned long long atomLength) {
        if ([type isEqualToString:@"name"] && atomLength > 4 && atomLength < 1024) {
            NSData *bytes = [file read:atomBody + 4 length:(NSUInteger)(atomLength - 4)];
            name = [[NSString alloc] initWithData:bytes encoding:NSUTF8StringEncoding];
        } else if ([type isEqualToString:@"data"] && atomLength >= 8) {
            NSData *head = [file read:atomBody length:8];
            if (typeOut && head) *typeOut = GLBig32(head.bytes) & 0xffffff;
            if (atomLength - 8 <= 32 * 1024 * 1024) payload = [file read:atomBody + 8 length:(NSUInteger)(atomLength - 8)];
            return NO;
        }
        return YES;
    });
    if (freeformName) *freeformName = name;
    return payload;
}

static void GLReadMP4(GLTagFile *file, GLTags *tags, BOOL wantPicture) {
    unsigned long long body = 0, length = 0;
    if (!GLMP4Find(file, 0, file.size, @[ @"moov", @"udta", @"meta", @"ilst" ], &body, &length)) return;
    NSDictionary *names = @{
        @"\u00a9nam": @"title", @"\u00a9ART": @"artist", @"\u00a9alb": @"album", @"aART": @"albumartist",
        @"\u00a9day": @"date", @"\u00a9gen": @"genre", @"sonm": @"titlesort", @"soar": @"artistsort",
        @"soal": @"albumsort", @"soaa": @"albumartistsort",
    };
    GLMP4Atoms(file, body, body + length, ^BOOL(NSString *type, unsigned long long item, unsigned long long itemLength) {
        if ([type isEqualToString:@"covr"]) {
            tags.hasPicture = YES;
            if (wantPicture && !tags.picture) tags.picture = GLMP4ItemData(file, item, itemLength, NULL, NULL);
            return YES;
        }
        uint32_t dataType = 0;
        NSString *freeform = nil;
        NSData *data = GLMP4ItemData(file, item, itemLength, &dataType, &freeform);
        if (!data) return YES;
        const uint8_t *d = data.bytes;
        if ([type isEqualToString:@"trkn"] || [type isEqualToString:@"disk"]) {
            if (data.length >= 4) {
                NSInteger number = (NSInteger)(d[2] << 8 | d[3]);
                if ([type isEqualToString:@"trkn"] && !tags.trackNumber) tags.trackNumber = number;
                if ([type isEqualToString:@"disk"] && !tags.discNumber) tags.discNumber = number;
            }
        } else if ([type isEqualToString:@"cpil"]) {
            tags.compilation = data.length >= 1 && d[0] != 0;
        } else if ([type isEqualToString:@"----"]) {
            GLSetField(tags, freeform, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
        } else {
            NSString *name = names[type];
            if (name) GLSetField(tags, name, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
        }
        return YES;
    });
}

#pragma mark Vorbis comments

static uint32_t GLLittle32(const uint8_t *p) {
    return (uint32_t)p[3] << 24 | (uint32_t)p[2] << 16 | (uint32_t)p[1] << 8 | p[0];
}

// Reads a FLAC picture block: type, MIME, description, size, and data.
static NSData *GLFLACPicture(NSData *block, uint32_t *typeOut) {
    const uint8_t *b = block.bytes;
    NSUInteger length = block.length, p = 0;
    if (length < 32) return nil;
    uint32_t type = GLBig32(b);
    p = 4;
    uint32_t mime = GLBig32(b + p);
    p += 4 + mime;
    if (p + 4 > length) return nil;
    uint32_t description = GLBig32(b + p);
    p += 4 + description + 16;
    if (p + 4 > length) return nil;
    uint32_t size = GLBig32(b + p);
    p += 4;
    if (size > length - p) return nil;
    if (typeOut) *typeOut = type;
    return [block subdataWithRange:NSMakeRange(p, size)];
}

// Decodes base64. The method of NSData for this is new in iOS 7, and the
// old method is deprecated on the Mac. Characters outside the alphabet are
// skipped.
static NSData *GLBase64Decode(NSString *text) {
    static int8_t table[256];
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        memset(table, -1, sizeof(table));
        const char *alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
        for (int i = 0; i < 64; i++) table[(uint8_t)alphabet[i]] = (int8_t)i;
    });
    NSData *input = [text dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
    const uint8_t *in = input.bytes;
    NSMutableData *out = [NSMutableData dataWithCapacity:input.length * 3 / 4];
    uint32_t bits = 0;
    int count = 0;
    for (NSUInteger i = 0; i < input.length; i++) {
        int8_t value = table[in[i]];
        if (value < 0) continue;
        bits = bits << 6 | (uint32_t)value;
        if (++count == 4) {
            uint8_t bytes[3] = { (uint8_t)(bits >> 16), (uint8_t)(bits >> 8), (uint8_t)bits };
            [out appendBytes:bytes length:3];
            bits = 0;
            count = 0;
        }
    }
    if (count == 2) {
        uint8_t byte = (uint8_t)(bits >> 4);
        [out appendBytes:&byte length:1];
    } else if (count == 3) {
        uint8_t bytes[2] = { (uint8_t)(bits >> 10), (uint8_t)(bits >> 2) };
        [out appendBytes:bytes length:2];
    }
    return out;
}

static void GLVorbisComments(GLTags *tags, NSData *data, BOOL wantPicture) {
    const uint8_t *b = data.bytes;
    NSUInteger length = data.length;
    if (length < 8) return;
    NSUInteger p = 4 + GLLittle32(b);
    if (p + 4 > length) return;
    uint32_t count = GLLittle32(b + p);
    p += 4;
    for (uint32_t i = 0; i < count && p + 4 <= length; i++) {
        uint32_t size = GLLittle32(b + p);
        p += 4;
        if (size > length - p) return;
        NSString *comment = [[NSString alloc] initWithBytes:b + p length:size encoding:NSUTF8StringEncoding];
        p += size;
        NSRange equals = [comment rangeOfString:@"="];
        if (equals.location == NSNotFound) continue;
        NSString *key = [comment substringToIndex:equals.location].lowercaseString;
        NSString *value = [comment substringFromIndex:equals.location + 1];
        if ([key isEqualToString:@"metadata_block_picture"] || [key isEqualToString:@"coverart"]) {
            tags.hasPicture = YES;
            if (!wantPicture) continue;
            NSData *decoded = GLBase64Decode(value);
            uint32_t type = 3;
            NSData *picture = [key isEqualToString:@"coverart"] ? decoded : GLFLACPicture(decoded, &type);
            if (picture && (!tags.picture || type == 3)) tags.picture = picture;
            continue;
        }
        if ([key isEqualToString:@"tracktotal"] || [key isEqualToString:@"totaltracks"]) continue;
        GLSetField(tags, key, value);
    }
}

static void GLReadFLAC(GLTagFile *file, unsigned long long start, GLTags *tags, BOOL wantPicture) {
    unsigned long long p = start + 4;
    while (p + 4 <= file.size) {
        NSData *header = [file read:p length:4];
        if (!header) return;
        const uint8_t *h = header.bytes;
        BOOL last = (h[0] & 0x80) != 0;
        uint8_t type = h[0] & 0x7f;
        uint32_t length = GLBig24(h + 1);
        p += 4;
        if (type == 4) {
            NSData *block = [file read:p length:length];
            if (block) GLVorbisComments(tags, block, wantPicture);
        } else if (type == 6) {
            tags.hasPicture = YES;
            if (wantPicture) {
                NSData *block = [file read:p length:length];
                uint32_t pictureType = 0;
                NSData *picture = block ? GLFLACPicture(block, &pictureType) : nil;
                if (picture && (!tags.picture || pictureType == 3)) tags.picture = picture;
            }
        }
        p += length;
        if (last) return;
    }
}

// Reads the second packet of the first stream of an Ogg file. It holds the
// comments of Vorbis and Opus. The reader stops after 16 MB.
static NSData *GLOggCommentPacket(GLTagFile *file) {
    NSMutableData *packet = [NSMutableData data];
    unsigned long long p = 0;
    int packetIndex = 0;
    uint32_t serial = 0;
    BOOL first = YES;
    while (p + 27 <= file.size && packet.length < 16 * 1024 * 1024) {
        NSData *header = [file read:p length:27];
        const uint8_t *h = header.bytes;
        if (!header || memcmp(h, "OggS", 4) != 0) return nil;
        uint32_t pageSerial = GLLittle32(h + 14);
        if (first) serial = pageSerial;
        first = NO;
        uint8_t segments = h[26];
        NSData *table = [file read:p + 27 length:segments];
        if (!table) return nil;
        const uint8_t *t = table.bytes;
        unsigned long long data = p + 27 + segments;
        unsigned long long size = 0;
        for (int i = 0; i < segments; i++) size += t[i];
        if (pageSerial == serial) {
            unsigned long long offset = data;
            for (int i = 0; i < segments; i++) {
                if (packetIndex == 1 && t[i] > 0) {
                    NSData *piece = [file read:offset length:t[i]];
                    if (!piece) return nil;
                    [packet appendData:piece];
                }
                offset += t[i];
                // A segment of less than 255 bytes ends a packet.
                if (t[i] < 255) {
                    if (packetIndex == 1) return packet;
                    packetIndex++;
                }
            }
        }
        p = data + size;
    }
    return nil;
}

static void GLReadOgg(GLTagFile *file, GLTags *tags, BOOL wantPicture) {
    NSData *packet = GLOggCommentPacket(file);
    if (packet.length > 8 && memcmp(packet.bytes, "OpusTags", 8) == 0) {
        GLVorbisComments(tags, [packet subdataWithRange:NSMakeRange(8, packet.length - 8)], wantPicture);
    } else if (packet.length > 7 && memcmp(packet.bytes, "\x03vorbis", 7) == 0) {
        GLVorbisComments(tags, [packet subdataWithRange:NSMakeRange(7, packet.length - 7)], wantPicture);
    }
}

#pragma mark APEv2 and ID3v1

// Reads an APEv2 tag at the end of the file, before an ID3v1 tag.
static void GLReadAPE(GLTagFile *file, GLTags *tags, BOOL wantPicture) {
    unsigned long long end = file.size;
    NSData *v1 = end >= 128 ? [file read:end - 128 length:3] : nil;
    if (v1 && memcmp(v1.bytes, "TAG", 3) == 0) end -= 128;
    if (end < 32) return;
    NSData *footer = [file read:end - 32 length:32];
    const uint8_t *f = footer.bytes;
    if (!footer || memcmp(f, "APETAGEX", 8) != 0) return;
    uint32_t size = GLLittle32(f + 12);
    uint32_t count = GLLittle32(f + 16);
    if (size < 32 || size > end || size > 64 * 1024 * 1024) return;
    unsigned long long start = end - size;
    unsigned long long p = start;
    unsigned long long itemsEnd = end - 32;
    for (uint32_t i = 0; i < count && p + 8 < itemsEnd; i++) {
        NSData *head = [file read:p length:8];
        if (!head) return;
        uint32_t valueSize = GLLittle32(head.bytes);
        uint32_t flags = GLLittle32((const uint8_t *)head.bytes + 4);
        p += 8;
        // The key ends with a zero byte. A key has at most 255 bytes.
        NSData *keyArea = [file read:p length:(NSUInteger)MIN((unsigned long long)256, itemsEnd - p)];
        const uint8_t *k = keyArea.bytes;
        NSUInteger keyLength = 0;
        while (keyLength < keyArea.length && k[keyLength] != 0) keyLength++;
        if (keyLength == keyArea.length) return;
        NSString *key = [[NSString alloc] initWithBytes:k length:keyLength encoding:NSASCIIStringEncoding].lowercaseString;
        p += keyLength + 1;
        if (valueSize > itemsEnd - p) return;
        BOOL binary = ((flags >> 1) & 3) == 1;
        if ([key hasPrefix:@"cover art"]) {
            tags.hasPicture = YES;
            if (wantPicture && binary && (!tags.picture || [key isEqualToString:@"cover art (front)"])) {
                // The value is a file name, a zero byte, and the picture.
                NSData *value = [file read:p length:valueSize];
                const uint8_t *v = value.bytes;
                NSUInteger name = 0;
                while (name < value.length && v[name] != 0) name++;
                if (name + 1 < value.length) {
                    tags.picture = [value subdataWithRange:NSMakeRange(name + 1, value.length - name - 1)];
                }
            }
        } else if (!binary && valueSize < 64 * 1024) {
            NSData *value = [file read:p length:valueSize];
            NSString *text = value ? [[NSString alloc] initWithData:value encoding:NSUTF8StringEncoding] : nil;
            // A list of values is separated by zero bytes. Keep the first.
            text = [text componentsSeparatedByString:[NSString stringWithFormat:@"%C", (unichar)0]].firstObject;
            GLSetField(tags, key, text);
        }
        p += valueSize;
    }
}

// Reads the old ID3v1 tag in the last 128 bytes. Its fields fill only the
// fields that are still empty.
static void GLReadID3v1(GLTagFile *file, GLTags *tags) {
    if (file.size < 128) return;
    NSData *tag = [file read:file.size - 128 length:128];
    const uint8_t *t = tag.bytes;
    if (!tag || memcmp(t, "TAG", 3) != 0) return;
    NSString *(^field)(NSUInteger, NSUInteger) = ^NSString *(NSUInteger offset, NSUInteger length) {
        NSUInteger n = 0;
        while (n < length && t[offset + n] != 0) n++;
        return [[NSString alloc] initWithBytes:t + offset length:n encoding:NSISOLatin1StringEncoding];
    };
    GLSetField(tags, @"title", field(3, 30));
    GLSetField(tags, @"artist", field(33, 30));
    GLSetField(tags, @"album", field(63, 30));
    GLSetField(tags, @"year", field(93, 4));
    // ID3v1.1 keeps the track in the last byte of the comment.
    if (t[125] == 0 && t[126] != 0 && !tags.trackNumber) tags.trackNumber = t[126];
}

#pragma mark WAV and AIFF

// Reads the chunks of a RIFF (WAV) or FORM (AIFF) file. Both can hold an
// ID3v2 tag in an "id3 " chunk. WAV can hold a LIST INFO chunk, and AIFF can
// hold NAME and AUTH chunks.
static void GLReadChunks(GLTagFile *file, GLTags *tags, BOOL wantPicture, BOOL bigEndian) {
    unsigned long long p = 12;
    while (p + 8 <= file.size) {
        NSData *header = [file read:p length:8];
        if (!header) return;
        const uint8_t *h = header.bytes;
        uint32_t size = bigEndian ? GLBig32(h + 4) : GLLittle32(h + 4);
        NSString *type = [[NSString alloc] initWithBytes:h length:4 encoding:NSISOLatin1StringEncoding].lowercaseString;
        unsigned long long body = p + 8;
        if ([type isEqualToString:@"id3 "]) {
            GLReadID3v2(file, body, tags, wantPicture);
        } else if ([type isEqualToString:@"list"] && size >= 4 && size < 1024 * 1024) {
            NSData *list = [file read:body length:size];
            const uint8_t *l = list.bytes;
            if (list && memcmp(l, "INFO", 4) == 0) {
                NSDictionary *names = @{ @"INAM": @"title", @"IART": @"artist", @"IPRD": @"album", @"ICRD": @"date",
                                         @"IPRT": @"tracknumber", @"ITRK": @"tracknumber", @"IGNR": @"genre" };
                NSUInteger q = 4;
                while (q + 8 <= list.length) {
                    uint32_t itemSize = GLLittle32(l + q + 4);
                    if (itemSize > list.length - q - 8) break;
                    NSString *key = [[NSString alloc] initWithBytes:l + q length:4 encoding:NSISOLatin1StringEncoding];
                    NSUInteger n = 0;
                    while (n < itemSize && l[q + 8 + n] != 0) n++;
                    NSString *value = [[NSString alloc] initWithBytes:l + q + 8 length:n encoding:NSUTF8StringEncoding] ?:
                        [[NSString alloc] initWithBytes:l + q + 8 length:n encoding:NSISOLatin1StringEncoding];
                    if (names[key]) GLSetField(tags, names[key], value);
                    q += 8 + itemSize + (itemSize & 1);
                }
            }
        } else if (bigEndian && ([type isEqualToString:@"name"] || [type isEqualToString:@"auth"]) && size < 4096) {
            NSData *text = [file read:body length:size];
            NSString *value = [[NSString alloc] initWithData:text encoding:NSISOLatin1StringEncoding];
            GLSetField(tags, [type isEqualToString:@"name"] ? @"title" : @"artist", value);
        }
        // Each chunk has an even length.
        p = body + size + (size & 1);
    }
}

#pragma mark The reader

GLTags *GLReadTags(NSString *path, BOOL wantPicture) {
    GLTagFile *file = [GLTagFile fileWithPath:path];
    if (!file) return nil;
    GLTags *tags = [GLTags new];
    NSData *head = [file read:0 length:12];
    if (head && memcmp((const uint8_t *)head.bytes + 4, "ftyp", 4) == 0) {
        GLReadMP4(file, tags, wantPicture);
        return tags;
    }
    if (head && memcmp(head.bytes, "OggS", 4) == 0) {
        GLReadOgg(file, tags, wantPicture);
        return tags;
    }
    if (head && memcmp(head.bytes, "RIFF", 4) == 0) {
        GLReadChunks(file, tags, wantPicture, NO);
        return tags;
    }
    if (head && memcmp(head.bytes, "FORM", 4) == 0) {
        GLReadChunks(file, tags, wantPicture, YES);
        return tags;
    }
    // Some FLAC files start with an ID3v2 tag.
    unsigned long long id3 = GLReadID3v2(file, 0, tags, wantPicture);
    NSData *flac = [file read:id3 length:4];
    if (flac && memcmp(flac.bytes, "fLaC", 4) == 0) GLReadFLAC(file, id3, tags, wantPicture);
    // MP3, APE, and WavPack files can have tags at the end.
    GLReadAPE(file, tags, wantPicture);
    GLReadID3v1(file, tags);
    return tags;
}
