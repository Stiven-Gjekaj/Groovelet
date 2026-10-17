#import "GLLink.h"

@implementation GLLink
@end

static NSDictionary *GLQueryValues(NSURL *url) {
    NSMutableDictionary *values = [NSMutableDictionary dictionary];
    for (NSString *pair in [url.query componentsSeparatedByString:@"&"]) {
        NSRange equals = [pair rangeOfString:@"="];
        if (equals.location == NSNotFound) continue;
        NSString *key = [pair substringToIndex:equals.location];
        NSString *value = [[[pair substringFromIndex:equals.location + 1] stringByReplacingOccurrencesOfString:@"+"
                                                                                                    withString:@" "]
            stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        if (value) values[key] = value;
    }
    return values;
}

GLLink *GLParseLink(NSURL *url) {
    if (![url.scheme.lowercaseString isEqualToString:@"groovelet"]) return nil;
    NSDictionary *kinds = @{
        @"play": @(GLLinkPlay), @"pause": @(GLLinkPause), @"resume": @(GLLinkResume), @"next": @(GLLinkNext),
        @"previous": @(GLLinkPrevious), @"seek": @(GLLinkSeek), @"open": @(GLLinkOpen),
        @"sleep": @(GLLinkSleep),
    };
    NSNumber *kind = kinds[url.host.lowercaseString ?: @""];
    if (!kind) return nil;
    NSDictionary *values = GLQueryValues(url);
    GLLink *link = [GLLink new];
    link.kind = kind.integerValue;
    link.path = values[@"path"];
    link.name = values[@"name"];
    link.time = [values[@"t"] doubleValue];
    if (link.kind == GLLinkPlay && !link.path.length) return nil;
    if (link.kind == GLLinkOpen && !link.name.length) return nil;
    return link;
}
