// The index of the music: one SQLite database with a row for each audio file.
// The scan writes the rows. The screens read the artists, the albums, the
// tracks, and the folders. All methods are safe to call from any thread.
// They run one at a time on the queue of the library.

#import <Foundation/Foundation.h>
#import "GLTrack.h"

// Posted on the main thread when the rows change.
extern NSString *const GLLibraryDidChangeNotification;

@interface GLArtist : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *sortKey;
@property (nonatomic) NSInteger albumCount;
@property (nonatomic) NSInteger trackCount;
@end

@interface GLAlbum : NSObject
@property (nonatomic, copy) NSString *key;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *artist;
@property (nonatomic, copy) NSString *sortKey;
@property (nonatomic) NSInteger year;
@property (nonatomic) NSInteger trackCount;
@property (nonatomic) double duration;
// The path of a track that holds the picture of the album, or the first
// track. The art cache reads the picture from it or from its folder.
@property (nonatomic, copy) NSString *artPath;
@end

// The direct content of a folder of the music directory.
@interface GLFolderContent : NSObject
@property (nonatomic, copy) NSArray *folders;  // Names, sorted
@property (nonatomic, copy) NSArray *tracks;   // GLTrack, sorted by path
@end

@interface GLLibrary : NSObject

// The library of the app, in the support directory.
+ (instancetype)shared;

// Opens or makes the database at `path`. Returns nil if it cannot.
- (instancetype)initWithPath:(NSString *)path;

// With YES, the lists sort "The Beatles" under B.
@property (nonatomic) BOOL ignoreArticles;

#pragma mark For the scan

// The size and the time of change of each file in the index: path to
// @[ size, modified ].
- (NSDictionary *)fileStamps;
// Adds or changes the rows of the tracks, by path. A row that changes keeps
// its ID, its play count, and its date of addition.
- (void)saveTracks:(NSArray *)tracks;
- (void)removePaths:(NSArray *)paths;

#pragma mark For the screens

- (NSUInteger)trackCount;
// All tracks, by title. To load fast, each track has only the facts that a
// list shows: the ID, the path, the names, the duration, the picture flag,
// and the sort key. trackWithPath: gives all facts.
- (NSArray *)allTracks;
- (NSArray *)artists;
// The albums of the album artist `name`, by year. With nil, all albums by name.
- (NSArray *)albumsOfArtist:(NSString *)name;
- (NSArray *)tracksOfAlbum:(NSString *)key;
// `folder` is relative to the music directory. "" is the top.
- (GLFolderContent *)contentOfFolder:(NSString *)folder;
- (GLTrack *)trackWithPath:(NSString *)path;

// Posts GLLibraryDidChangeNotification on the main thread.
- (void)postChange;

@end
