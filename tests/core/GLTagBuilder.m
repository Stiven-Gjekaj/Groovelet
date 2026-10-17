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

static NSData *GLMP4Type(NSString *type) {
    return [type dataUsingEncoding:NSISOLatin1StringEncoding];
}

NSData *GLMP4Atom(NSString *type, NSArray *children) {
    NSMutableData *body = [NSMutableData data];
    for (NSData *child in children) [body appendData:child];
    NSMutableData *atom = [NSMutableData dataWithData:GLBig32Data((uint32_t)body.length + 8)];
    [atom appendData:GLMP4Type(type)];
    [atom appendData:body];
    return atom;
}

NSData *GLMP4Item(NSString *type, uint32_t dataType, NSData *payload) {
    NSMutableData *data = [NSMutableData dataWithData:GLBig32Data(dataType)];
    [data appendData:GLBig32Data(0)];  // The locale.
    [data appendData:payload];
    return GLMP4Atom(type, @[ GLMP4Atom(@"data", @[ data ]) ]);
}

NSData *GLMP4TextItem(NSString *type, NSString *text) {
    return GLMP4Item(type, 1, GLBytes(text));
}

NSData *GLMP4FreeformItem(NSString *name, NSString *text) {
    NSMutableData *mean = [NSMutableData dataWithData:GLBig32Data(0)];
    [mean appendData:GLBytes(@"com.apple.iTunes")];
    NSMutableData *nameBody = [NSMutableData dataWithData:GLBig32Data(0)];
    [nameBody appendData:GLBytes(name)];
    NSMutableData *data = [NSMutableData dataWithData:GLBig32Data(1)];
    [data appendData:GLBig32Data(0)];
    [data appendData:GLBytes(text)];
    return GLMP4Atom(@"----", @[ GLMP4Atom(@"mean", @[ mean ]), GLMP4Atom(@"name", @[ nameBody ]),
                                 GLMP4Atom(@"data", @[ data ]) ]);
}

NSData *GLMP4File(NSArray *items) {
    NSMutableData *ftyp = [NSMutableData dataWithData:GLBytes(@"M4A ")];
    [ftyp appendData:GLBig32Data(0)];
    [ftyp appendData:GLBytes(@"M4A mp42isom")];
    NSMutableData *hdlr = [NSMutableData dataWithData:GLBig32Data(0)];
    [hdlr appendData:GLBig32Data(0)];
    [hdlr appendData:GLBytes(@"mdirappl")];
    [hdlr increaseLengthBy:9];
    NSData *meta = GLMP4Atom(@"meta", @[ GLBig32Data(0), GLMP4Atom(@"hdlr", @[ hdlr ]), GLMP4Atom(@"ilst", items) ]);
    NSData *moov = GLMP4Atom(@"moov", @[ GLMP4Atom(@"mvhd", @[ [NSMutableData dataWithLength:100] ]),
                                         GLMP4Atom(@"udta", @[ meta ]) ]);
    NSMutableData *file = [NSMutableData dataWithData:GLMP4Atom(@"ftyp", @[ ftyp ])];
    [file appendData:moov];
    [file appendData:GLMP4Atom(@"mdat", @[ GLFakeAudio(2000) ])];
    return file;
}

NSData *GLVorbisCommentBody(NSArray *comments) {
    NSData *vendor = GLBytes(@"test vendor");
    NSMutableData *body = [NSMutableData dataWithData:GLLittle32Data((uint32_t)vendor.length)];
    [body appendData:vendor];
    [body appendData:GLLittle32Data((uint32_t)comments.count)];
    for (NSString *comment in comments) {
        NSData *bytes = GLBytes(comment);
        [body appendData:GLLittle32Data((uint32_t)bytes.length)];
        [body appendData:bytes];
    }
    return body;
}

NSData *GLFLACPictureBody(uint32_t type, NSData *picture) {
    NSMutableData *body = [NSMutableData dataWithData:GLBig32Data(type)];
    NSData *mime = GLBytes(@"image/png");
    [body appendData:GLBig32Data((uint32_t)mime.length)];
    [body appendData:mime];
    [body appendData:GLBig32Data(0)];  // No description.
    [body increaseLengthBy:16];         // Width, height, depth, colors.
    [body appendData:GLBig32Data((uint32_t)picture.length)];
    [body appendData:picture];
    return body;
}

NSData *GLFLACFile(NSArray *blocks) {
    NSMutableData *file = [NSMutableData dataWithData:GLBytes(@"fLaC")];
    NSMutableArray *all = [NSMutableArray arrayWithObject:@[ @0, [NSMutableData dataWithLength:34] ]];
    [all addObjectsFromArray:blocks];
    for (NSUInteger i = 0; i < all.count; i++) {
        uint8_t type = [all[i][0] unsignedCharValue];
        NSData *body = all[i][1];
        uint8_t header[4] = { (uint8_t)(type | (i + 1 == all.count ? 0x80 : 0)), (uint8_t)(body.length >> 16),
                              (uint8_t)(body.length >> 8), (uint8_t)body.length };
        [file appendBytes:header length:4];
        [file appendData:body];
    }
    [file appendData:GLFakeAudio(500)];
    return file;
}

NSData *GLOggFile(NSArray *packets) {
    NSMutableData *file = [NSMutableData data];
    uint32_t sequence = 0;
    for (NSData *packet in packets) {
        NSUInteger offset = 0;
        BOOL continued = NO;
        // Up to 255 segments of 255 bytes go in one page. The last segment of
        // a packet has less than 255 bytes, also 0 bytes.
        while (YES) {
            NSUInteger left = packet.length - offset;
            NSMutableData *table = [NSMutableData data];
            NSUInteger inPage = 0;
            BOOL ends = NO;
            while (table.length < 255) {
                uint8_t lace = (uint8_t)MIN((NSUInteger)255, left - inPage);
                [table appendBytes:&lace length:1];
                inPage += lace;
                if (lace < 255) {
                    ends = YES;
                    break;
                }
            }
            NSMutableData *page = [NSMutableData dataWithData:GLBytes(@"OggS")];
            uint8_t head[2] = { 0, (uint8_t)(continued ? 1 : 0) };
            [page appendBytes:head length:2];
            [page increaseLengthBy:8];                // The granule position.
            [page appendData:GLLittle32Data(77)];     // The serial number.
            [page appendData:GLLittle32Data(sequence++)];
            [page increaseLengthBy:4];                // The CRC.
            uint8_t count = (uint8_t)table.length;
            [page appendBytes:&count length:1];
            [page appendData:table];
            [page appendData:[packet subdataWithRange:NSMakeRange(offset, inPage)]];
            [file appendData:page];
            offset += inPage;
            continued = YES;
            if (ends) break;
        }
    }
    return file;
}

NSString *GLBase64Encode(NSData *data) {
    const char *alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    const uint8_t *b = data.bytes;
    NSMutableString *text = [NSMutableString string];
    for (NSUInteger i = 0; i < data.length; i += 3) {
        uint32_t bits = (uint32_t)b[i] << 16;
        if (i + 1 < data.length) bits |= (uint32_t)b[i + 1] << 8;
        if (i + 2 < data.length) bits |= b[i + 2];
        [text appendFormat:@"%c%c%c%c", alphabet[(bits >> 18) & 63], alphabet[(bits >> 12) & 63],
                           i + 1 < data.length ? alphabet[(bits >> 6) & 63] : '=',
                           i + 2 < data.length ? alphabet[bits & 63] : '='];
    }
    return text;
}

NSData *GLAPETag(NSArray *items) {
    NSMutableData *body = [NSMutableData data];
    for (NSArray *item in items) {
        BOOL binary = [item[1] isKindOfClass:[NSData class]];
        NSData *value = binary ? item[1] : GLBytes(item[1]);
        [body appendData:GLLittle32Data((uint32_t)value.length)];
        [body appendData:GLLittle32Data(binary ? 2 : 0)];
        [body appendData:GLBytes(item[0])];
        [body appendBytes:"\0" length:1];
        [body appendData:value];
    }
    NSMutableData *footer = [NSMutableData dataWithData:GLBytes(@"APETAGEX")];
    [footer appendData:GLLittle32Data(2000)];
    [footer appendData:GLLittle32Data((uint32_t)body.length + 32)];
    [footer appendData:GLLittle32Data((uint32_t)items.count)];
    [footer appendData:GLLittle32Data(0)];
    [footer increaseLengthBy:8];
    [body appendData:footer];
    return body;
}

NSData *GLID3v1Tag(NSString *title, NSString *artist, NSString *album, NSString *year, uint8_t track) {
    NSMutableData *tag = [NSMutableData dataWithLength:128];
    uint8_t *t = tag.mutableBytes;
    memcpy(t, "TAG", 3);
    NSArray *fields = @[ @[ title, @3, @30 ], @[ artist, @33, @30 ], @[ album, @63, @30 ], @[ year, @93, @4 ] ];
    for (NSArray *field in fields) {
        NSData *bytes = [field[0] dataUsingEncoding:NSISOLatin1StringEncoding];
        memcpy(t + [field[1] intValue], bytes.bytes, MIN(bytes.length, (NSUInteger)[field[2] intValue]));
    }
    t[126] = track;
    t[127] = 255;
    return tag;
}
