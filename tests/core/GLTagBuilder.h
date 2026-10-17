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
