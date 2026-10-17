#import "GLTrack.h"
#import "GLTags.h"

NSString *const GLVariousArtists = @"Various Artists";
NSString *const GLUnknownArtist = @"Unknown Artist";

@implementation GLTrack

- (instancetype)init {
    if ((self = [super init])) {
        _trackGain = NAN;
        _trackPeak = NAN;
        _albumGain = NAN;
        _albumPeak = NAN;
    }
    return self;
}

+ (instancetype)trackWithPath:(NSString *)path {
    GLTrack *track = [GLTrack new];
    track.path = path;
    track.title = path.lastPathComponent.stringByDeletingPathExtension;
    return track;
}

+ (instancetype)trackWithPath:(NSString *)path tags:(GLTags *)tags {
    GLTrack *track = [GLTrack trackWithPath:path];
    if (tags.title) track.title = tags.title;
    track.artist = tags.artist;
    track.album = tags.album;
    track.albumArtist = tags.albumArtist;
    track.genre = tags.genre;
    track.sortTitle = tags.sortTitle;
    track.sortArtist = tags.sortArtist;
    track.sortAlbum = tags.sortAlbum;
    track.sortAlbumArtist = tags.sortAlbumArtist;
    track.year = tags.year;
    track.trackNumber = tags.trackNumber;
    track.discNumber = tags.discNumber;
    track.compilation = tags.compilation;
    track.trackGain = tags ? tags.trackGain : NAN;
    track.trackPeak = tags ? tags.trackPeak : NAN;
    track.albumGain = tags ? tags.albumGain : NAN;
    track.albumPeak = tags ? tags.albumPeak : NAN;
    track.hasPicture = tags.hasPicture;
    return track;
}

- (NSString *)displayArtist {
    return self.artist ?: self.albumArtist ?: GLUnknownArtist;
}

- (NSString *)displayAlbumArtist {
    if (self.albumArtist) return self.albumArtist;
    if (self.compilation) return GLVariousArtists;
    return self.displayArtist;
}

- (NSString *)displayAlbum {
    if (self.album) return self.album;
    NSString *folder = self.path.stringByDeletingLastPathComponent.lastPathComponent;
    return folder.length ? folder : @"Unknown Album";
}

- (NSString *)albumKey {
    return [NSString stringWithFormat:@"%@\x1f%@", self.displayAlbumArtist.lowercaseString,
                                      self.displayAlbum.lowercaseString];
}

@end
