// Tests of GLUploadServer on 127.0.0.1, with a small HTTP client.

#import "GLTest.h"
#import "GLUploadServer.h"
#include <arpa/inet.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

// Sends `request` and returns the whole answer.
static NSString *GLSend(uint16_t port, NSData *request) {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_len = sizeof(address);
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    address.sin_port = htons(port);
    if (connect(fd, (struct sockaddr *)&address, sizeof(address)) != 0) {
        close(fd);
        return nil;
    }
    write(fd, request.bytes, request.length);
    // The client sends nothing more. A server that waits for more bytes sees
    // the end now.
    shutdown(fd, SHUT_WR);
    NSMutableData *answer = [NSMutableData data];
    uint8_t buffer[4096];
    ssize_t n;
    while ((n = read(fd, buffer, sizeof(buffer))) > 0) [answer appendBytes:buffer length:(size_t)n];
    close(fd);
    return [[NSString alloc] initWithData:answer encoding:NSUTF8StringEncoding];
}

static NSData *GLPut(NSString *path, NSData *body) {
    NSString *head = [NSString stringWithFormat:@"PUT /upload?path=%@ HTTP/1.1\r\nHost: x\r\nContent-Length: %lu\r\n\r\n",
                                                path, (unsigned long)body.length];
    NSMutableData *request = [[head dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
    [request appendData:body];
    return request;
}

static GLUploadServer *GLStartServer(NSString *directory) {
    GLUploadServer *server = [[GLUploadServer alloc] initWithDirectory:directory];
    [server startOnPort:0 loopbackOnly:YES error:NULL];
    return server;
}

GL_TEST(test_upload_server_writes_a_file_into_a_folder) {
    NSString *music = GLTestTemporaryDirectory();
    GLUploadServer *server = GLStartServer(music);
    GL_EXPECT(server.running);
    __block NSString *reported = nil;
    server.onFile = ^(NSString *path) { reported = path; };
    NSMutableData *body = [NSMutableData dataWithLength:200000];
    ((uint8_t *)body.mutableBytes)[199999] = 7;
    NSString *answer = GLSend(server.port, GLPut(@"New%20Album/01%20Song.flac", body));
    GL_EXPECT([answer hasPrefix:@"HTTP/1.1 200"]);
    NSData *written = [NSData dataWithContentsOfFile:[music stringByAppendingPathComponent:@"New Album/01 Song.flac"]];
    GL_EQUAL(written, body);
    NSDate *until = [NSDate dateWithTimeIntervalSinceNow:2];
    while (!reported && [until timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    GL_EQUAL(reported, @"New Album/01 Song.flac");
    [server stop];
}

GL_TEST(test_upload_server_refuses_a_path_out_of_the_directory) {
    NSString *music = GLTestTemporaryDirectory();
    GLUploadServer *server = GLStartServer(music);
    NSString *answer = GLSend(server.port, GLPut(@"..%2Fescape.mp3", [@"x" dataUsingEncoding:NSUTF8StringEncoding]));
    GL_EXPECT([answer hasPrefix:@"HTTP/1.1 403"]);
    GL_EXPECT(![[NSFileManager defaultManager] fileExistsAtPath:
        [music.stringByDeletingLastPathComponent stringByAppendingPathComponent:@"escape.mp3"]]);
    [server stop];
}

GL_TEST(test_upload_server_refuses_a_file_that_is_not_music) {
    NSString *music = GLTestTemporaryDirectory();
    GLUploadServer *server = GLStartServer(music);
    NSString *answer = GLSend(server.port, GLPut(@"run.sh", [@"rm -rf" dataUsingEncoding:NSUTF8StringEncoding]));
    GL_EXPECT([answer hasPrefix:@"HTTP/1.1 403"]);
    GL_EQUAL_INT([[NSFileManager defaultManager] contentsOfDirectoryAtPath:music error:NULL].count, 0);
    [server stop];
}

GL_TEST(test_upload_server_gives_the_page) {
    GLUploadServer *server = GLStartServer(GLTestTemporaryDirectory());
    NSString *answer = GLSend(server.port, [@"GET / HTTP/1.1\r\nHost: x\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]);
    GL_EXPECT([answer hasPrefix:@"HTTP/1.1 200"]);
    GL_EXPECT([answer rangeOfString:@"Drop files or folders here"].location != NSNotFound);
    answer = GLSend(server.port, [@"GET /etc/passwd HTTP/1.1\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]);
    GL_EXPECT([answer hasPrefix:@"HTTP/1.1 404"]);
    [server stop];
}

GL_TEST(test_upload_server_keeps_no_part_of_a_broken_upload) {
    NSString *music = GLTestTemporaryDirectory();
    GLUploadServer *server = GLStartServer(music);
    // The head says 1000 bytes, but only 10 come.
    NSString *head = @"PUT /upload?path=cut.mp3 HTTP/1.1\r\nContent-Length: 1000\r\n\r\n0123456789";
    GLSend(server.port, [head dataUsingEncoding:NSUTF8StringEncoding]);
    [NSThread sleepForTimeInterval:0.2];
    GL_EQUAL_INT([[NSFileManager defaultManager] contentsOfDirectoryAtPath:music error:NULL].count, 0);
    [server stop];
}

GL_TEST(test_upload_paths_stay_inside_and_keep_the_folders) {
    GL_EQUAL([GLUploadServer safePathForUploadPath:@"A/B/c.MP3"], @"A/B/c.MP3");
    GL_EQUAL([GLUploadServer safePathForUploadPath:@"/A//./c.flac"], @"A/c.flac");
    GL_EXPECT([GLUploadServer safePathForUploadPath:@"A/../../c.mp3"] == nil);
    GL_EXPECT([GLUploadServer safePathForUploadPath:@".hidden/c.mp3"] == nil);
    GL_EXPECT([GLUploadServer safePathForUploadPath:@"A\\..\\c.mp3"] == nil);
    GL_EXPECT([GLUploadServer safePathForUploadPath:@"cover.jpg"] != nil);
    GL_EXPECT([GLUploadServer safePathForUploadPath:@"list.m3u8"] != nil);
    GL_EXPECT([GLUploadServer safePathForUploadPath:@""] == nil);
}
