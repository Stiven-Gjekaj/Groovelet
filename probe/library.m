// library: measure the queries of the library on the phone, with the
// database of the app. Usage: library [PATH_OF_DATABASE]

#import "GLLibrary.h"
#import "GLPlayQueue.h"

static double GLTime(void (^block)(void)) {
    NSDate *start = [NSDate date];
    block();
    return -[start timeIntervalSinceNow];
}

int main(int argc, char **argv) {
    @autoreleasepool {
        NSString *path = argc > 1 ? @(argv[1])
                                  : @"/var/mobile/Library/Application Support/Groovelet/library.sqlite";
        GLLibrary *library = [[GLLibrary alloc] initWithPath:path];
        __block NSUInteger count = 0;
        for (int i = 0; i < 2; i++) {
            printf("allTracks: %.3f s\n", GLTime(^{ count = [library allTracks].count; }));
        }
        printf("tracks: %lu\n", (unsigned long)count);
        printf("artists: %.3f s\n", GLTime(^{ count = [library artists].count; }));
        printf("albums: %.3f s (%lu)\n", GLTime(^{ count = [library albumsOfArtist:nil].count; }), (unsigned long)count);
        printf("fileStamps: %.3f s\n", GLTime(^{ count = [library fileStamps].count; }));
        printf("folder: %.3f s\n", GLTime(^{ count = [library contentOfFolder:@""].folders.count; }));
        // The save and the restore of a queue of all tracks.
        NSArray *tracks = [library allTracks];
        GLPlayQueue *queue = [GLPlayQueue new];
        printf("queue of all: %.3f s\n", GLTime(^{ [queue setTracks:tracks currentIndex:5]; }));
        __block NSData *data = nil;
        printf("queue save: %.3f s\n", GLTime(^{
            data = [NSPropertyListSerialization dataWithPropertyList:queue.state format:NSPropertyListBinaryFormat_v1_0
                                                             options:0 error:NULL];
        }));
        printf("queue restore: %.3f s (%lu bytes)\n", GLTime(^{
            NSDictionary *state = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:NULL];
            NSMutableDictionary *map = [NSMutableDictionary dictionary];
            for (GLTrack *track in [library allTracks]) map[track.path] = track;
            count = [GLPlayQueue queueWithState:state lookup:^GLTrack *(NSString *path) { return map[path]; }].entries.count;
        }), (unsigned long)data.length);
    }
    return 0;
}
