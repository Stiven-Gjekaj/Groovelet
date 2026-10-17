#import "GLTrack.h"

@implementation GLTrack

+ (instancetype)trackWithPath:(NSString *)path {
    GLTrack *track = [GLTrack new];
    track.path = path;
    track.title = path.lastPathComponent.stringByDeletingPathExtension;
    return track;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if ((self = [super init])) {
        _trackID = [coder decodeInt64ForKey:@"id"];
        _path = [coder decodeObjectForKey:@"path"];
        _title = [coder decodeObjectForKey:@"title"];
        _artist = [coder decodeObjectForKey:@"artist"];
        _album = [coder decodeObjectForKey:@"album"];
        _duration = [coder decodeDoubleForKey:@"duration"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInt64:self.trackID forKey:@"id"];
    [coder encodeObject:self.path forKey:@"path"];
    [coder encodeObject:self.title forKey:@"title"];
    [coder encodeObject:self.artist forKey:@"artist"];
    [coder encodeObject:self.album forKey:@"album"];
    [coder encodeDouble:self.duration forKey:@"duration"];
}

@end
