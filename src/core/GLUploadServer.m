#import "GLUploadServer.h"
#include <arpa/inet.h>
#include <ifaddrs.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

// The longest request head that the server reads.
static const size_t GLMaxHead = 16 * 1024;
// The largest file that the server takes: 2 GB.
static const long long GLMaxBody = 2LL * 1024 * 1024 * 1024;

static NSString *GLUploadPage(void);

@interface GLUploadServer ()
@property (nonatomic, copy) NSString *directory;
@property (nonatomic) uint16_t port;
@property (nonatomic) int listenSocket;
@property (nonatomic, strong) dispatch_source_t acceptSource;
@property (nonatomic, strong) dispatch_queue_t queue;
@end

@implementation GLUploadServer

- (instancetype)initWithDirectory:(NSString *)directory {
    if ((self = [super init])) {
        _directory = [directory copy];
        _listenSocket = -1;
        _queue = dispatch_queue_create("GLUploadServer", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)dealloc {
    [self stop];
}

- (BOOL)running {
    return self.listenSocket >= 0;
}

static int GLListen(uint16_t port, BOOL loopbackOnly, uint16_t *boundPort) {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) return -1;
    int yes = 1;
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));
    setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, sizeof(yes));
    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_len = sizeof(address);
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(loopbackOnly ? INADDR_LOOPBACK : INADDR_ANY);
    address.sin_port = htons(port);
    socklen_t length = sizeof(address);
    if (bind(fd, (struct sockaddr *)&address, sizeof(address)) != 0 || listen(fd, 8) != 0 ||
        getsockname(fd, (struct sockaddr *)&address, &length) != 0) {
        close(fd);
        return -1;
    }
    *boundPort = ntohs(address.sin_port);
    return fd;
}

- (BOOL)startOnPort:(uint16_t)port loopbackOnly:(BOOL)loopbackOnly error:(NSError **)error {
    if (self.running) return YES;
    uint16_t bound = 0;
    int fd = GLListen(port, loopbackOnly, &bound);
    if (fd < 0) fd = GLListen(0, loopbackOnly, &bound);  // The port is in use. Take a free port.
    if (fd < 0) {
        if (error) *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil];
        return NO;
    }
    self.listenSocket = fd;
    self.port = bound;
    dispatch_source_t source = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, (uintptr_t)fd, 0, self.queue);
    __weak GLUploadServer *weakSelf = self;
    dispatch_source_set_event_handler(source, ^{
        int client = accept(fd, NULL, NULL);
        if (client < 0) return;
        int on = 1;
        setsockopt(client, SOL_SOCKET, SO_NOSIGPIPE, &on, sizeof(on));
        // A client that stops sending frees its thread after 30 seconds.
        struct timeval timeout = { 30, 0 };
        setsockopt(client, SOL_SOCKET, SO_RCVTIMEO, &timeout, sizeof(timeout));
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [weakSelf serve:client];
        });
    });
    dispatch_source_set_cancel_handler(source, ^{ close(fd); });
    self.acceptSource = source;
    dispatch_resume(source);
    return YES;
}

- (void)stop {
    if (self.acceptSource) dispatch_source_cancel(self.acceptSource);
    self.acceptSource = nil;
    self.listenSocket = -1;
}

#pragma mark Paths

+ (NSString *)safePathForUploadPath:(NSString *)path {
    NSMutableArray *parts = [NSMutableArray array];
    for (NSString *part in [path componentsSeparatedByString:@"/"]) {
        if (!part.length || [part isEqualToString:@"."]) continue;
        // A part that goes up, or a hidden name, is refused.
        if ([part isEqualToString:@".."] || [part hasPrefix:@"."]) return nil;
        if ([part rangeOfString:@"\\"].location != NSNotFound) return nil;
        [parts addObject:part];
    }
    if (!parts.count) return nil;
    NSSet *allowed = [NSSet setWithObjects:@"mp3", @"m4a", @"m4b", @"aac", @"mp4", @"wav", @"aif", @"aiff", @"aifc",
                                           @"caf", @"flac", @"opus", @"ogg", @"oga", @"ape", @"wv", @"mka", @"jpg",
                                           @"jpeg", @"png", @"m3u", @"m3u8", nil];
    if (![allowed containsObject:[parts.lastObject pathExtension].lowercaseString]) return nil;
    return [parts componentsJoinedByString:@"/"];
}

+ (NSString *)wifiAddress {
    struct ifaddrs *list = NULL;
    if (getifaddrs(&list) != 0) return nil;
    NSString *found = nil;
    for (struct ifaddrs *item = list; item; item = item->ifa_next) {
        if (!item->ifa_addr || item->ifa_addr->sa_family != AF_INET) continue;
        if (strcmp(item->ifa_name, "en0") != 0) continue;
        char text[INET_ADDRSTRLEN];
        struct sockaddr_in *address = (struct sockaddr_in *)item->ifa_addr;
        if (inet_ntop(AF_INET, &address->sin_addr, text, sizeof(text))) found = @(text);
    }
    freeifaddrs(list);
    return found;
}

#pragma mark HTTP

static BOOL GLWriteAll(int fd, const void *bytes, size_t length) {
    const uint8_t *p = bytes;
    while (length > 0) {
        ssize_t n = write(fd, p, length);
        if (n <= 0) return NO;
        p += n;
        length -= (size_t)n;
    }
    return YES;
}

static void GLRespond(int fd, int status, NSString *reason, NSString *type, NSData *body) {
    NSString *head = [NSString stringWithFormat:@"HTTP/1.1 %d %@\r\nContent-Type: %@\r\nContent-Length: %lu\r\n"
                                                @"Cache-Control: no-cache\r\nConnection: close\r\n\r\n",
                                                status, reason, type, (unsigned long)body.length];
    NSData *headData = [head dataUsingEncoding:NSASCIIStringEncoding];
    if (GLWriteAll(fd, headData.bytes, headData.length)) GLWriteAll(fd, body.bytes, body.length);
}

static void GLRespondText(int fd, int status, NSString *reason, NSString *text) {
    GLRespond(fd, status, reason, @"text/plain; charset=utf-8", [text dataUsingEncoding:NSUTF8StringEncoding]);
}

static NSString *GLQueryValue(NSString *target, NSString *name) {
    NSRange question = [target rangeOfString:@"?"];
    if (question.location == NSNotFound) return nil;
    for (NSString *pair in [[target substringFromIndex:question.location + 1] componentsSeparatedByString:@"&"]) {
        NSRange equals = [pair rangeOfString:@"="];
        if (equals.location == NSNotFound || ![[pair substringToIndex:equals.location] isEqualToString:name]) continue;
        return [[pair substringFromIndex:equals.location + 1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    }
    return nil;
}

- (void)serve:(int)fd {
    @autoreleasepool {
        // Read the head. The bytes after it are the start of the body.
        NSMutableData *request = [NSMutableData data];
        uint8_t buffer[64 * 1024];
        NSRange end = NSMakeRange(NSNotFound, 0);
        NSData *separator = [NSData dataWithBytes:"\r\n\r\n" length:4];
        while (request.length < GLMaxHead) {
            ssize_t n = read(fd, buffer, sizeof(buffer));
            if (n <= 0) break;
            [request appendBytes:buffer length:(size_t)n];
            end = [request rangeOfData:separator options:0 range:NSMakeRange(0, request.length)];
            if (end.location != NSNotFound) break;
        }
        if (end.location == NSNotFound) {
            close(fd);
            return;
        }
        NSString *head = [[NSString alloc] initWithData:[request subdataWithRange:NSMakeRange(0, end.location)]
                                               encoding:NSUTF8StringEncoding];
        NSArray *lines = [head componentsSeparatedByString:@"\r\n"];
        NSArray *words = [lines.firstObject componentsSeparatedByString:@" "];
        NSString *method = words.count >= 2 ? words[0] : @"";
        NSString *target = words.count >= 2 ? words[1] : @"";
        long long length = -1;
        for (NSString *line in lines) {
            if ([line.lowercaseString hasPrefix:@"content-length:"]) length = [[line substringFromIndex:15] longLongValue];
        }
        NSData *start = [request subdataWithRange:NSMakeRange(NSMaxRange(end), request.length - NSMaxRange(end))];
        if ([method isEqualToString:@"GET"] && ([target isEqualToString:@"/"] || [target hasPrefix:@"/?"])) {
            GLRespond(fd, 200, @"OK", @"text/html; charset=utf-8", [GLUploadPage() dataUsingEncoding:NSUTF8StringEncoding]);
        } else if ([method isEqualToString:@"PUT"] && [target hasPrefix:@"/upload?"]) {
            [self receive:fd path:GLQueryValue(target, @"path") length:length start:start];
        } else {
            GLRespondText(fd, 404, @"Not Found", @"not found");
        }
        close(fd);
    }
}

- (void)receive:(int)fd path:(NSString *)uploadPath length:(long long)length start:(NSData *)start {
    NSString *path = [GLUploadServer safePathForUploadPath:uploadPath ?: @""];
    if (!path) {
        GLRespondText(fd, 403, @"Forbidden", @"This file type or path is not allowed.");
        return;
    }
    if (length < 0 || length > GLMaxBody || (long long)start.length > length) {
        GLRespondText(fd, 411, @"Length Required", @"The request needs a correct Content-Length.");
        return;
    }
    NSString *full = [self.directory stringByAppendingPathComponent:path];
    NSString *partial = [full stringByAppendingString:@".part"];
    NSFileManager *files = [NSFileManager defaultManager];
    [files createDirectoryAtPath:full.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil
                           error:NULL];
    // Write to a temporary name. The scan does not see a file that is not
    // complete, because ".part" is not an audio extension.
    if (![files createFileAtPath:partial contents:nil attributes:nil]) {
        GLRespondText(fd, 500, @"Internal Server Error", @"The phone cannot write the file.");
        return;
    }
    NSFileHandle *file = [NSFileHandle fileHandleForWritingAtPath:partial];
    long long received = 0;
    BOOL ok = YES;
    @try {
        [file writeData:start];
        received = (long long)start.length;
        uint8_t buffer[64 * 1024];
        while (received < length) {
            ssize_t n = read(fd, buffer, (size_t)MIN((long long)sizeof(buffer), length - received));
            if (n <= 0) {
                ok = NO;
                break;
            }
            [file writeData:[NSData dataWithBytesNoCopy:buffer length:(NSUInteger)n freeWhenDone:NO]];
            received += n;
        }
    } @catch (NSException *exception) {
        ok = NO;
    }
    [file closeFile];
    if (!ok) {
        [files removeItemAtPath:partial error:NULL];
        return;
    }
    [files removeItemAtPath:full error:NULL];
    if (![files moveItemAtPath:partial toPath:full error:NULL]) {
        GLRespondText(fd, 500, @"Internal Server Error", @"The phone cannot write the file.");
        return;
    }
    GLRespondText(fd, 200, @"OK", @"ok");
    void (^onFile)(NSString *) = self.onFile;
    if (onFile) dispatch_async(dispatch_get_main_queue(), ^{ onFile(path); });
}

@end

// The page. It sends one file at a time, so that the phone writes at full
// speed and the page shows the progress of each file.
static NSString *GLUploadPage(void) {
    return @"<!doctype html><html><head><meta charset=\"utf-8\">"
           @"<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><title>Groovelet</title><style>"
           @"body{margin:0;background:#111;color:#f5f1ec;font:15px -apple-system,system-ui,sans-serif}"
           @"main{max-width:640px;margin:0 auto;padding:32px 16px}h1{font-size:24px;margin:0 0 4px}"
           @"h1 b{color:#ff6b4a}p{color:#8e8a86;margin:0 0 24px}"
           @"#drop{border:2px dashed #3a3a3a;border-radius:12px;padding:40px 16px;text-align:center}"
           @"#drop.over{border-color:#ff6b4a;background:#1c1c1c}"
           @"label{display:inline-block;margin:12px 6px 0;padding:10px 18px;border-radius:20px;background:#ff6b4a;"
           @"color:#111;font-weight:600;cursor:pointer}label.second{background:#2a2a2a;color:#f5f1ec}"
           @"input{display:none}ul{list-style:none;padding:0;margin:24px 0}li{padding:8px 0;border-bottom:1px solid #262626}"
           @"li span{float:right;color:#8e8a86}li.done span{color:#7bd88f}li.fail span{color:#ff6b4a}"
           @"progress{width:100%;height:4px;accent-color:#ff6b4a}</style></head><body><main>"
           @"<h1><b>Groove</b>let</h1><p>Drop music here. It goes into Media/Groovelet on the phone.</p>"
           @"<div id=\"drop\">Drop files or folders here<br>"
           @"<label>Choose files<input id=\"files\" type=\"file\" multiple></label>"
           @"<label class=\"second\">Choose a folder<input id=\"folder\" type=\"file\" webkitdirectory multiple></label>"
           @"</div><ul id=\"list\"></ul></main><script>"
           @"const list=document.getElementById('list'),drop=document.getElementById('drop');let queue=[],busy=false;"
           @"function add(file,path){const li=document.createElement('li');li.textContent=path;"
           @"const s=document.createElement('span');s.textContent='waiting';li.appendChild(s);"
           @"const bar=document.createElement('progress');bar.max=1;bar.value=0;li.appendChild(bar);list.appendChild(li);"
           @"queue.push({file,path,li,s,bar});next();}"
           @"function next(){if(busy||!queue.length)return;busy=true;const job=queue.shift();"
           @"const x=new XMLHttpRequest();x.open('PUT','/upload?path='+encodeURIComponent(job.path));"
           @"x.upload.onprogress=e=>{if(e.lengthComputable){job.bar.value=e.loaded/e.total;"
           @"job.s.textContent=Math.round(100*e.loaded/e.total)+'%';}};"
           @"x.onload=()=>{const ok=x.status==200;job.li.className=ok?'done':'fail';"
           @"job.s.textContent=ok?'done':x.responseText;job.bar.remove();busy=false;next();};"
           @"x.onerror=()=>{job.li.className='fail';job.s.textContent='failed';busy=false;next();};x.send(job.file);}"
           @"function walk(entry,prefix){if(entry.isFile){entry.file(f=>add(f,prefix+f.name));}"
           @"else if(entry.isDirectory){const r=entry.createReader();const read=()=>r.readEntries(es=>{"
           @"if(!es.length)return;es.forEach(e=>walk(e,prefix+entry.name+'/'));read();});read();}}"
           @"drop.ondragover=e=>{e.preventDefault();drop.className='over';};drop.ondragleave=()=>drop.className='';"
           @"drop.ondrop=e=>{e.preventDefault();drop.className='';for(const item of e.dataTransfer.items){"
           @"const entry=item.webkitGetAsEntry&&item.webkitGetAsEntry();if(entry)walk(entry,'');"
           @"else{const f=item.getAsFile();if(f)add(f,f.name);}}};"
           @"document.getElementById('files').onchange=e=>{for(const f of e.target.files)add(f,f.name);e.target.value='';};"
           @"document.getElementById('folder').onchange=e=>{for(const f of e.target.files)add(f,f.webkitRelativePath||f.name);"
           @"e.target.value='';};</script></body></html>";
}
