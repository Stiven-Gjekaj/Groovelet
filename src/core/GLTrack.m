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

- (instancetype)initWithCoder:(NSCoder *)coder {
    if ((self = [self init])) {
        _trackID = [coder decodeInt64ForKey:@"id"];
        _path = [coder decodeObjectForKey:@"path"];
        _title = [coder decodeObjectForKey:@"title"];
        _artist = [coder decodeObjectForKey:@"artist"];
        _album = [coder decodeObjectForKey:@"album"];
        _albumArtist = [coder decodeObjectForKey:@"albumArtist"];
        _compilation = [coder decodeBoolForKey:@"compilation"];
        _duration = [coder decodeDoubleForKey:@"duration"];
        _hasPicture = [coder decodeBoolForKey:@"hasPicture"];
        if ([coder containsValueForKey:@"trackGain"]) _trackGain = [coder decodeDoubleForKey:@"trackGain"];
        if ([coder containsValueForKey:@"trackPeak"]) _trackPeak = [coder decodeDoubleForKey:@"trackPeak"];
        if ([coder containsValueForKey:@"albumGain"]) _albumGain = [coder decodeDoubleForKey:@"albumGain"];
        if ([coder containsValueForKey:@"albumPeak"]) _albumPeak = [coder decodeDoubleForKey:@"albumPeak"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInt64:self.trackID forKey:@"id"];
    [coder encodeObject:self.path forKey:@"path"];
    [coder encodeObject:self.title forKey:@"title"];
    [coder encodeObject:self.artist forKey:@"artist"];
    [coder encodeObject:self.album forKey:@"album"];
    [coder encodeObject:self.albumArtist forKey:@"albumArtist"];
    [coder encodeBool:self.compilation forKey:@"compilation"];
    [coder encodeDouble:self.duration forKey:@"duration"];
    [coder encodeBool:self.hasPicture forKey:@"hasPicture"];
    if (!isnan(self.trackGain)) [coder encodeDouble:self.trackGain forKey:@"trackGain"];
    if (!isnan(self.trackPeak)) [coder encodeDouble:self.trackPeak forKey:@"trackPeak"];
    if (!isnan(self.albumGain)) [coder encodeDouble:self.albumGain forKey:@"albumGain"];
    if (!isnan(self.albumPeak)) [coder encodeDouble:self.albumPeak forKey:@"albumPeak"];
}

@end
