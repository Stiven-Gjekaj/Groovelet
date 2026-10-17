// One audio file and the facts that the app knows about it.
// The path is relative to the music directory, so that the index stays
// correct when the directory moves.

#import <Foundation/Foundation.h>

@class GLTags;

// The name of the album artist of a compilation with no album artist.
extern NSString *const GLVariousArtists;
// The name of an artist that the tags do not give.
extern NSString *const GLUnknownArtist;

@interface GLTrack : NSObject

@property (nonatomic) int64_t trackID;      // The row in the library, or 0
@property (nonatomic, copy) NSString *path;  // Relative to the music directory
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *artist;
@property (nonatomic, copy) NSString *album;
@property (nonatomic, copy) NSString *albumArtist;
@property (nonatomic, copy) NSString *genre;
@property (nonatomic, copy) NSString *sortTitle;
@property (nonatomic, copy) NSString *sortArtist;
@property (nonatomic, copy) NSString *sortAlbum;
@property (nonatomic, copy) NSString *sortAlbumArtist;
@property (nonatomic) NSInteger year;
@property (nonatomic) NSInteger trackNumber;
@property (nonatomic) NSInteger discNumber;
@property (nonatomic) BOOL compilation;
@property (nonatomic) double duration;
@property (nonatomic) double trackGain;  // NAN when unknown
@property (nonatomic) double trackPeak;
@property (nonatomic) double albumGain;
@property (nonatomic) double albumPeak;
@property (nonatomic) BOOL hasPicture;
@property (nonatomic) long long fileSize;
@property (nonatomic) double modified;   // Seconds since 1970
@property (nonatomic) double added;      // Seconds since 1970
@property (nonatomic) NSInteger playCount;
@property (nonatomic) double lastPlayed;  // Seconds since 1970, or 0
// The key that the list of songs sorts by. The library sets it.
@property (nonatomic, copy) NSString *sortKey;

// A track with only a path. The title is the file name with no extension.
+ (instancetype)trackWithPath:(NSString *)path;

// A track with the facts of its tags. An empty field takes a value from the
// path: the title from the file name, and the album from the folder.
+ (instancetype)trackWithPath:(NSString *)path tags:(GLTags *)tags;

// The artist to show: the artist, or the unknown artist.
@property (nonatomic, readonly) NSString *displayArtist;
// The artist of the album: the album artist, the various artists for a
// compilation, or the artist.
@property (nonatomic, readonly) NSString *displayAlbumArtist;
// The album, or the name of the folder.
@property (nonatomic, readonly) NSString *displayAlbum;
// The tracks of one album have the same key: the album artist and the album.
@property (nonatomic, readonly) NSString *albumKey;

@end
