#import "GLM3U.h"

// Removes "." and "..". Returns nil for a path that goes above its root.
static NSString *GLNormalPath(NSArray *parts) {
    NSMutableArray *result = [NSMutableArray array];
    for (NSString *part in parts) {
        if (!part.length || [part isEqualToString:@"."]) continue;
        if ([part isEqualToString:@".."]) {
            if (!result.count) return nil;
            [result removeLastObject];
            continue;
        }
        [result addObject:part];
    }
    return result.count ? [result componentsJoinedByString:@"/"] : nil;
}

NSArray *GLReadM3U(NSData *data, NSString *playlistPath, NSString *musicDirectory) {
    // M3U8 is UTF-8. An old M3U can be Latin-1.
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?:
        [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
    if ([text hasPrefix:@"﻿"]) text = [text substringFromIndex:1];
    NSString *folder = playlistPath.stringByDeletingLastPathComponent;
    NSString *root = [musicDirectory.stringByStandardizingPath stringByAppendingString:@"/"];
    NSMutableArray *paths = [NSMutableArray array];
    for (NSString *raw in [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
        NSString *line = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (!line.length || [line hasPrefix:@"#"]) continue;
        if ([line.lowercaseString hasPrefix:@"file://"]) {
            line = [[NSURL URLWithString:line] path] ?: [line substringFromIndex:7];
        } else if ([line rangeOfString:@"://"].location != NSNotFound) {
            continue;  // A web stream.
        }
        line = [line stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
        NSString *path = nil;
        if ([line hasPrefix:@"/"]) {
            // An absolute path counts only inside the music directory.
            NSString *standard = line.stringByStandardizingPath;
            if (![standard hasPrefix:root]) continue;
            path = GLNormalPath([[standard substringFromIndex:root.length] componentsSeparatedByString:@"/"]);
        } else {
            NSArray *parts = [[folder componentsSeparatedByString:@"/"]
                arrayByAddingObjectsFromArray:[line componentsSeparatedByString:@"/"]];
            path = GLNormalPath(parts);
        }
        if (path) [paths addObject:path];
    }
    return paths;
}
