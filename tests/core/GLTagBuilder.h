// Builds the bytes of tags for the tests of GLTags, so that the repository
// holds no media files. Each test builds the file that it reads.

#import <Foundation/Foundation.h>

// An ID3v2 text frame. Encoding 3 is UTF-8, 1 is UTF-16 with a byte order
// mark, and 0 is ISO-8859-1. `version` is 3 or 4.
NSData *GLID3TextFrame(NSString *frameID, NSString *text, uint8_t encoding, int version);
// An ID3v2 frame with any body.
NSData *GLID3Frame(NSString *frameID, NSData *body, int version);
// An ID3v2 tag with the frames, and `padding` zero bytes at the end.
NSData *GLID3Tag(NSArray *frames, int version, NSUInteger padding);
// The body of an APIC frame with a picture of `type`.
NSData *GLID3PictureBody(uint8_t type, NSData *picture);

// Writes the parts one after the other into a new file and returns its path.
NSString *GLWriteFile(NSString *name, NSArray *parts);

// Some bytes that look like audio, to put after a tag.
NSData *GLFakeAudio(NSUInteger length);

// The bytes of a string with no terminator.
NSData *GLBytes(NSString *text);
// Four bytes, big-endian or little-endian.
NSData *GLBig32Data(uint32_t value);
NSData *GLLittle32Data(uint32_t value);

// An MP4 atom with a 4-letter type. The type can start with the byte 0xA9,
// given as "©".
NSData *GLMP4Atom(NSString *type, NSArray *children);
// An item of ilst with a data atom of `dataType` (1 is text, 0 is a number,
// 13 is JPEG).
NSData *GLMP4Item(NSString *type, uint32_t dataType, NSData *payload);
// A text item.
NSData *GLMP4TextItem(NSString *type, NSString *text);
// A freeform item "----" with a name, as iTunes writes for ReplayGain.
NSData *GLMP4FreeformItem(NSString *name, NSString *text);
// A whole M4A file with the items in moov/udta/meta/ilst.
NSData *GLMP4File(NSArray *items);
