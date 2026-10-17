#import "GLLibrary.h"
#import "GLPaths.h"
#import "GLSort.h"
#include <sqlite3.h>

NSString *const GLLibraryDidChangeNotification = @"GLLibraryDidChange";

@implementation GLArtist
@end

@implementation GLAlbum
@end

@implementation GLFolderContent
@end

// The version of the schema. A newer app changes an older database.
static const int GLSchemaVersion = 1;

static NSString *const GLTrackColumns =
    @"id, path, size, modified, added, title, artist, album, album_artist, genre, sort_title, sort_artist, "
    @"sort_album, sort_album_artist, year, track_number, disc_number, compilation, duration, track_gain, "
    @"track_peak, album_gain, album_peak, has_picture, play_count, last_played";

@interface GLLibrary ()
@property (nonatomic) sqlite3 *db;
@property (nonatomic, strong) dispatch_queue_t queue;
@end

@implementation GLLibrary

+ (instancetype)shared {
    static GLLibrary *shared;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[GLLibrary alloc] initWithPath:[GLSupportDirectory() stringByAppendingPathComponent:@"library.sqlite"]];
    });
    return shared;
}

- (instancetype)initWithPath:(NSString *)path {
    if ((self = [super init])) {
        _queue = dispatch_queue_create("GLLibrary", DISPATCH_QUEUE_SERIAL);
        _ignoreArticles = YES;
        if (sqlite3_open(path.fileSystemRepresentation, &_db) != SQLITE_OK || ![self migrate]) {
            sqlite3_close(_db);
            return nil;
        }
    }
    return self;
}

- (void)dealloc {
    sqlite3_close(_db);
}

#pragma mark SQL

- (BOOL)execute:(NSString *)sql {
    return sqlite3_exec(self.db, sql.UTF8String, NULL, NULL, NULL) == SQLITE_OK;
}

- (sqlite3_stmt *)prepare:(NSString *)sql {
    sqlite3_stmt *statement = NULL;
    if (sqlite3_prepare_v2(self.db, sql.UTF8String, -1, &statement, NULL) != SQLITE_OK) return NULL;
    return statement;
}

static void GLBindText(sqlite3_stmt *statement, int index, NSString *text) {
    if (text) sqlite3_bind_text(statement, index, text.UTF8String, -1, SQLITE_TRANSIENT);
    else sqlite3_bind_null(statement, index);
}

static void GLBindDouble(sqlite3_stmt *statement, int index, double value) {
    if (isnan(value)) sqlite3_bind_null(statement, index);
    else sqlite3_bind_double(statement, index, value);
}

static NSString *GLColumnText(sqlite3_stmt *statement, int index) {
    const unsigned char *text = sqlite3_column_text(statement, index);
    return text ? [NSString stringWithUTF8String:(const char *)text] : nil;
}

static double GLColumnDouble(sqlite3_stmt *statement, int index) {
    return sqlite3_column_type(statement, index) == SQLITE_NULL ? NAN : sqlite3_column_double(statement, index);
}

- (BOOL)migrate {
    sqlite3_stmt *statement = [self prepare:@"PRAGMA user_version"];
    int version = statement && sqlite3_step(statement) == SQLITE_ROW ? sqlite3_column_int(statement, 0) : 0;
    sqlite3_finalize(statement);
    [self execute:@"PRAGMA journal_mode = WAL"];
    if (version >= GLSchemaVersion) return YES;
    BOOL ok = [self execute:@"BEGIN"];
    if (version < 1) {
        ok = ok && [self execute:@"CREATE TABLE tracks ("
                                 @"id INTEGER PRIMARY KEY, path TEXT NOT NULL UNIQUE, size INTEGER, modified REAL, "
                                 @"added REAL, title TEXT, artist TEXT, album TEXT, album_artist TEXT, genre TEXT, "
                                 @"sort_title TEXT, sort_artist TEXT, sort_album TEXT, sort_album_artist TEXT, "
                                 @"year INTEGER, track_number INTEGER, disc_number INTEGER, compilation INTEGER, "
                                 @"duration REAL, track_gain REAL, track_peak REAL, album_gain REAL, album_peak REAL, "
                                 @"has_picture INTEGER, play_count INTEGER NOT NULL DEFAULT 0, "
                                 @"last_played REAL NOT NULL DEFAULT 0, "
                                 // The names and the keys that the lists group and sort by. The
                                 // key with "_the" keeps a leading article.
                                 @"album_key TEXT, artist_name TEXT, album_name TEXT, "
                                 @"title_key TEXT, title_key_the TEXT, artist_key TEXT, artist_key_the TEXT, "
                                 @"album_sort TEXT, album_sort_the TEXT)"];
        ok = ok && [self execute:@"CREATE INDEX tracks_album ON tracks (album_key)"];
        ok = ok && [self execute:@"CREATE INDEX tracks_artist ON tracks (artist_name)"];
    }
    ok = ok && [self execute:[NSString stringWithFormat:@"PRAGMA user_version = %d", GLSchemaVersion]];
    return [self execute:ok ? @"COMMIT" : @"ROLLBACK"] && ok;
}

- (GLTrack *)trackFromRow:(sqlite3_stmt *)s {
    GLTrack *track = [GLTrack new];
    track.trackID = sqlite3_column_int64(s, 0);
    track.path = GLColumnText(s, 1);
    track.fileSize = sqlite3_column_int64(s, 2);
    track.modified = sqlite3_column_double(s, 3);
    track.added = sqlite3_column_double(s, 4);
    track.title = GLColumnText(s, 5);
    track.artist = GLColumnText(s, 6);
    track.album = GLColumnText(s, 7);
    track.albumArtist = GLColumnText(s, 8);
    track.genre = GLColumnText(s, 9);
    track.sortTitle = GLColumnText(s, 10);
    track.sortArtist = GLColumnText(s, 11);
    track.sortAlbum = GLColumnText(s, 12);
    track.sortAlbumArtist = GLColumnText(s, 13);
    track.year = sqlite3_column_int(s, 14);
    track.trackNumber = sqlite3_column_int(s, 15);
    track.discNumber = sqlite3_column_int(s, 16);
    track.compilation = sqlite3_column_int(s, 17) != 0;
    track.duration = sqlite3_column_double(s, 18);
    track.trackGain = GLColumnDouble(s, 19);
    track.trackPeak = GLColumnDouble(s, 20);
    track.albumGain = GLColumnDouble(s, 21);
    track.albumPeak = GLColumnDouble(s, 22);
    track.hasPicture = sqlite3_column_int(s, 23) != 0;
    track.playCount = sqlite3_column_int(s, 24);
    track.lastPlayed = sqlite3_column_double(s, 25);
    return track;
}

- (NSArray *)tracksWhere:(NSString *)clause bind:(void (^)(sqlite3_stmt *statement))bind {
    NSString *sql = [NSString stringWithFormat:@"SELECT %@ FROM tracks %@", GLTrackColumns, clause];
    sqlite3_stmt *statement = [self prepare:sql];
    NSMutableArray *tracks = [NSMutableArray array];
    if (!statement) return tracks;
    if (bind) bind(statement);
    while (sqlite3_step(statement) == SQLITE_ROW) [tracks addObject:[self trackFromRow:statement]];
    sqlite3_finalize(statement);
    return tracks;
}

- (NSString *)suffix {
    return self.ignoreArticles ? @"" : @"_the";
}

// Puts the suffix of the sort keys in the place of each "{S}".
- (NSString *)withSuffix:(NSString *)sql {
    return [sql stringByReplacingOccurrencesOfString:@"{S}" withString:self.suffix];
}

#pragma mark For the scan

- (NSDictionary *)fileStamps {
    __block NSMutableDictionary *stamps = [NSMutableDictionary dictionary];
    dispatch_sync(self.queue, ^{
        sqlite3_stmt *statement = [self prepare:@"SELECT path, size, modified FROM tracks"];
        while (statement && sqlite3_step(statement) == SQLITE_ROW) {
            stamps[GLColumnText(statement, 0)] =
                @[ @(sqlite3_column_int64(statement, 1)), @(sqlite3_column_double(statement, 2)) ];
        }
        sqlite3_finalize(statement);
    });
    return stamps;
}

// The values of the columns of a track, from "path" on, without the counts.
static void GLBindTrack(sqlite3_stmt *s, GLTrack *t) {
    GLBindText(s, 1, t.path);
    sqlite3_bind_int64(s, 2, t.fileSize);
    sqlite3_bind_double(s, 3, t.modified);
    GLBindText(s, 4, t.title);
    GLBindText(s, 5, t.artist);
    GLBindText(s, 6, t.album);
    GLBindText(s, 7, t.albumArtist);
    GLBindText(s, 8, t.genre);
    GLBindText(s, 9, t.sortTitle);
    GLBindText(s, 10, t.sortArtist);
    GLBindText(s, 11, t.sortAlbum);
    GLBindText(s, 12, t.sortAlbumArtist);
    sqlite3_bind_int(s, 13, (int)t.year);
    sqlite3_bind_int(s, 14, (int)t.trackNumber);
    sqlite3_bind_int(s, 15, (int)t.discNumber);
    sqlite3_bind_int(s, 16, t.compilation);
    sqlite3_bind_double(s, 17, t.duration);
    GLBindDouble(s, 18, t.trackGain);
    GLBindDouble(s, 19, t.trackPeak);
    GLBindDouble(s, 20, t.albumGain);
    GLBindDouble(s, 21, t.albumPeak);
    sqlite3_bind_int(s, 22, t.hasPicture);
    GLBindText(s, 23, t.albumKey);
    GLBindText(s, 24, t.displayAlbumArtist);
    GLBindText(s, 25, t.displayAlbum);
    NSString *title = t.sortTitle ?: t.title;
    NSString *artist = t.sortAlbumArtist ?: t.displayAlbumArtist;
    NSString *album = t.sortAlbum ?: t.displayAlbum;
    GLBindText(s, 26, GLSortKey(title, YES));
    GLBindText(s, 27, GLSortKey(title, NO));
    GLBindText(s, 28, GLSortKey(artist, YES));
    GLBindText(s, 29, GLSortKey(artist, NO));
    GLBindText(s, 30, GLSortKey(album, YES));
    GLBindText(s, 31, GLSortKey(album, NO));
}

- (void)saveTracks:(NSArray *)tracks {
    if (!tracks.count) return;
    dispatch_sync(self.queue, ^{
        [self execute:@"BEGIN"];
        NSString *names = @"path = ?1, size = ?2, modified = ?3, title = ?4, artist = ?5, album = ?6, "
                          @"album_artist = ?7, genre = ?8, sort_title = ?9, sort_artist = ?10, sort_album = ?11, "
                          @"sort_album_artist = ?12, year = ?13, track_number = ?14, disc_number = ?15, "
                          @"compilation = ?16, duration = ?17, track_gain = ?18, track_peak = ?19, "
                          @"album_gain = ?20, album_peak = ?21, has_picture = ?22, album_key = ?23, "
                          @"artist_name = ?24, album_name = ?25, title_key = ?26, title_key_the = ?27, "
                          @"artist_key = ?28, artist_key_the = ?29, album_sort = ?30, album_sort_the = ?31";
        // SQLite 3.7 of iOS 6 has no upsert. Change the row, and add it when
        // no row changed.
        sqlite3_stmt *update = [self prepare:[NSString stringWithFormat:@"UPDATE tracks SET %@ WHERE path = ?1", names]];
        sqlite3_stmt *insert = [self prepare:
            @"INSERT INTO tracks (path, size, modified, title, artist, album, album_artist, genre, sort_title, "
            @"sort_artist, sort_album, sort_album_artist, year, track_number, disc_number, compilation, duration, "
            @"track_gain, track_peak, album_gain, album_peak, has_picture, album_key, artist_name, album_name, "
            @"title_key, title_key_the, artist_key, artist_key_the, album_sort, album_sort_the, added) VALUES "
            @"(?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, ?15, ?16, ?17, ?18, ?19, ?20, ?21, "
            @"?22, ?23, ?24, ?25, ?26, ?27, ?28, ?29, ?30, ?31, ?32)"];
        for (GLTrack *track in tracks) {
            GLBindTrack(update, track);
            sqlite3_step(update);
            sqlite3_reset(update);
            if (sqlite3_changes(self.db) == 0) {
                GLBindTrack(insert, track);
                sqlite3_bind_double(insert, 32, track.added ?: [NSDate date].timeIntervalSince1970);
                sqlite3_step(insert);
                sqlite3_reset(insert);
            }
        }
        sqlite3_finalize(update);
        sqlite3_finalize(insert);
        [self execute:@"COMMIT"];
    });
}

- (void)removePaths:(NSArray *)paths {
    if (!paths.count) return;
    dispatch_sync(self.queue, ^{
        [self execute:@"BEGIN"];
        sqlite3_stmt *statement = [self prepare:@"DELETE FROM tracks WHERE path = ?"];
        for (NSString *path in paths) {
            GLBindText(statement, 1, path);
            sqlite3_step(statement);
            sqlite3_reset(statement);
        }
        sqlite3_finalize(statement);
        [self execute:@"COMMIT"];
    });
}

#pragma mark For the screens

- (NSUInteger)trackCount {
    __block NSUInteger count = 0;
    dispatch_sync(self.queue, ^{
        sqlite3_stmt *statement = [self prepare:@"SELECT COUNT(*) FROM tracks"];
        if (statement && sqlite3_step(statement) == SQLITE_ROW) count = (NSUInteger)sqlite3_column_int64(statement, 0);
        sqlite3_finalize(statement);
    });
    return count;
}

- (NSArray *)allTracks {
    __block NSArray *tracks = nil;
    dispatch_sync(self.queue, ^{
        tracks = [self tracksWhere:[self withSuffix:@"ORDER BY title_key{S}, path"] bind:nil];
    });
    return tracks;
}

- (NSArray *)artists {
    __block NSMutableArray *artists = [NSMutableArray array];
    dispatch_sync(self.queue, ^{
        NSString *sql = [self withSuffix:
            @"SELECT artist_name, MIN(artist_key{S}), COUNT(DISTINCT album_key), COUNT(*) FROM tracks "
            @"GROUP BY artist_name ORDER BY MIN(artist_key{S}), artist_name"];
        sqlite3_stmt *statement = [self prepare:sql];
        while (statement && sqlite3_step(statement) == SQLITE_ROW) {
            GLArtist *artist = [GLArtist new];
            artist.name = GLColumnText(statement, 0);
            artist.sortKey = GLColumnText(statement, 1);
            artist.albumCount = sqlite3_column_int(statement, 2);
            artist.trackCount = sqlite3_column_int(statement, 3);
            [artists addObject:artist];
        }
        sqlite3_finalize(statement);
    });
    return artists;
}

- (NSArray *)albumsOfArtist:(NSString *)name {
    __block NSMutableArray *albums = [NSMutableArray array];
    dispatch_sync(self.queue, ^{
        NSString *where = name ? @"WHERE t.artist_name = ?1" : @"";
        NSString *order = name ? @"MAX(t.year), MIN(t.album_sort{S})" : @"MIN(t.album_sort{S}), MIN(t.artist_name)";
        NSString *sql = [self withSuffix:[NSString stringWithFormat:
            @"SELECT t.album_key, MIN(t.album_name), MIN(t.artist_name), MIN(t.album_sort{S}), MAX(t.year), "
            @"COUNT(*), SUM(t.duration), (SELECT a.path FROM tracks a WHERE a.album_key = t.album_key "
            @"ORDER BY a.has_picture DESC, a.disc_number, a.track_number, a.path LIMIT 1) "
            @"FROM tracks t %@ GROUP BY t.album_key ORDER BY %@", where, order]];
        sqlite3_stmt *statement = [self prepare:sql];
        if (statement && name) GLBindText(statement, 1, name);
        while (statement && sqlite3_step(statement) == SQLITE_ROW) {
            GLAlbum *album = [GLAlbum new];
            album.key = GLColumnText(statement, 0);
            album.title = GLColumnText(statement, 1);
            album.artist = GLColumnText(statement, 2);
            album.sortKey = GLColumnText(statement, 3);
            album.year = sqlite3_column_int(statement, 4);
            album.trackCount = sqlite3_column_int(statement, 5);
            album.duration = sqlite3_column_double(statement, 6);
            album.artPath = GLColumnText(statement, 7);
            [albums addObject:album];
        }
        sqlite3_finalize(statement);
    });
    return albums;
}

- (NSArray *)tracksOfAlbum:(NSString *)key {
    __block NSArray *tracks = nil;
    dispatch_sync(self.queue, ^{
        tracks = [self tracksWhere:@"WHERE album_key = ?1 ORDER BY disc_number, track_number, title_key_the, path"
                              bind:^(sqlite3_stmt *statement) { GLBindText(statement, 1, key); }];
    });
    return tracks;
}

- (GLFolderContent *)contentOfFolder:(NSString *)folder {
    NSString *prefix = folder.length ? [folder stringByAppendingString:@"/"] : @"";
    __block NSArray *rows = nil;
    dispatch_sync(self.queue, ^{
        // All paths that start with the prefix. The byte after "/" is "0".
        NSString *end = folder.length ? [folder stringByAppendingString:@"0"] : nil;
        NSString *clause = end ? @"WHERE path >= ?1 AND path < ?2 ORDER BY path" : @"ORDER BY path";
        rows = [self tracksWhere:clause bind:^(sqlite3_stmt *statement) {
            if (end) {
                GLBindText(statement, 1, prefix);
                GLBindText(statement, 2, end);
            }
        }];
    });
    NSMutableOrderedSet *folders = [NSMutableOrderedSet orderedSet];
    NSMutableArray *tracks = [NSMutableArray array];
    for (GLTrack *track in rows) {
        NSString *rest = [track.path substringFromIndex:prefix.length];
        NSRange slash = [rest rangeOfString:@"/"];
        if (slash.location == NSNotFound) [tracks addObject:track];
        else [folders addObject:[rest substringToIndex:slash.location]];
    }
    GLFolderContent *content = [GLFolderContent new];
    content.folders = [folders.array sortedArrayUsingSelector:@selector(localizedStandardCompare:)];
    content.tracks = [tracks sortedArrayUsingComparator:^NSComparisonResult(GLTrack *a, GLTrack *b) {
        return [a.path localizedStandardCompare:b.path];
    }];
    return content;
}

- (GLTrack *)trackWithPath:(NSString *)path {
    __block GLTrack *track = nil;
    dispatch_sync(self.queue, ^{
        track = [self tracksWhere:@"WHERE path = ?1" bind:^(sqlite3_stmt *statement) {
            GLBindText(statement, 1, path);
        }].firstObject;
    });
    return track;
}

- (void)postChange {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:GLLibraryDidChangeNotification object:self];
    });
}

@end
