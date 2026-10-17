// Reads the tags of an audio file: the names, the numbers, the ReplayGain
// values, and the picture. It reads ID3v2, ID3v1, MP4 atoms, Vorbis comments
// in FLAC and Ogg files, and APEv2.
//
// The reader reads only the parts of the file that it needs. It does not
// read the bytes of a picture unless the caller asks for the picture, so a
// scan of the library stays fast.

#import <Foundation/Foundation.h>

@interface GLTags : NSObject

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *artist;
@property (nonatomic, copy) NSString *album;
@property (nonatomic, copy) NSString *albumArtist;
@property (nonatomic, copy) NSString *genre;
@property (nonatomic, copy) NSString *sortTitle;
@property (nonatomic, copy) NSString *sortArtist;
@property (nonatomic, copy) NSString *sortAlbum;
@property (nonatomic, copy) NSString *sortAlbumArtist;
@property (nonatomic) NSInteger year;         // 0 when unknown
@property (nonatomic) NSInteger trackNumber;  // 0 when unknown
@property (nonatomic) NSInteger discNumber;   // 0 when unknown
@property (nonatomic) BOOL compilation;

// ReplayGain. A gain is in dB. A peak is 1.0 at full scale. NAN when unknown.
@property (nonatomic) double trackGain;
@property (nonatomic) double trackPeak;
@property (nonatomic) double albumGain;
@property (nonatomic) double albumPeak;

// YES when the file holds a picture. The bytes are in `picture` only when the
// caller asked for them.
@property (nonatomic) BOOL hasPicture;
@property (nonatomic, strong) NSData *picture;

@end

// Reads the tags of the file at `path`. Returns an empty GLTags object for a
// file with no tags, and nil for a file that does not open.
GLTags *GLReadTags(NSString *path, BOOL wantPicture);
