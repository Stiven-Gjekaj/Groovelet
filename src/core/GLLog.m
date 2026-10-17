#import "GLLog.h"
#import "GLPaths.h"

// The log starts again from its second half when it is larger than this.
static const unsigned long long GLLogLimit = 256 * 1024;

static NSString *GLLogPath(void) {
    return [GLCacheDirectory() stringByAppendingPathComponent:@"log.txt"];
}

static dispatch_queue_t GLLogQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ queue = dispatch_queue_create("GLLog", DISPATCH_QUEUE_SERIAL); });
    return queue;
}

void GLLog(NSString *format, ...) {
    va_list arguments;
    va_start(arguments, format);
    NSString *text = [[NSString alloc] initWithFormat:format arguments:arguments];
    va_end(arguments);
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateFormat = @"HH:mm:ss.SSS";
    NSString *line = [NSString stringWithFormat:@"%@ %@\n", [formatter stringFromDate:[NSDate date]], text];
    dispatch_async(GLLogQueue(), ^{
        NSString *path = GLLogPath();
        NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:path];
        if (!file) {
            [[NSData data] writeToFile:path atomically:NO];
            file = [NSFileHandle fileHandleForWritingAtPath:path];
        }
        unsigned long long size = [file seekToEndOfFile];
        if (size > GLLogLimit) {
            [file closeFile];
            NSData *old = [NSData dataWithContentsOfFile:path];
            [[old subdataWithRange:NSMakeRange(old.length / 2, old.length - old.length / 2)] writeToFile:path atomically:YES];
            file = [NSFileHandle fileHandleForWritingAtPath:path];
            [file seekToEndOfFile];
        }
        [file writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [file closeFile];
    });
}

NSString *GLLogText(void) {
    __block NSString *text = nil;
    dispatch_sync(GLLogQueue(), ^{
        text = [NSString stringWithContentsOfFile:GLLogPath() encoding:NSUTF8StringEncoding error:NULL];
    });
    return text ?: @"";
}
