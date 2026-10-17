// Tests of GLRenderer with decoders that the tests make.

#import "GLRenderer.h"
#import "GLTest.h"

// A decoder that gives `length` frames. Each sample holds `mark`, so a test
// can see which track a frame came from. It gives at most `chunk` frames for
// each read, as a real decoder does.
@interface GLFakeDecoder : NSObject <GLDecoder>
@property (nonatomic) NSUInteger length;
@property (nonatomic) NSUInteger position;
@property (nonatomic) int16_t mark;
@property (nonatomic) NSUInteger chunk;
@property (nonatomic) BOOL fails;
@end

@implementation GLFakeDecoder

+ (instancetype)decoderWithLength:(NSUInteger)length mark:(int16_t)mark {
    GLFakeDecoder *decoder = [GLFakeDecoder new];
    decoder.length = length;
    decoder.mark = mark;
    decoder.chunk = 1000;
    return decoder;
}

- (double)duration {
    return (double)self.length / GLOutputRate;
}

- (NSInteger)readFrames:(int16_t *)buffer count:(NSUInteger)frames {
    if (self.fails) return -1;
    NSUInteger n = MIN(MIN(frames, self.chunk), self.length - self.position);
    for (NSUInteger i = 0; i < n * GLOutputChannels; i++) buffer[i] = self.mark;
    self.position += n;
    return (NSInteger)n;
}

- (BOOL)seekToTime:(double)seconds {
    self.position = MIN(self.length, (NSUInteger)(seconds * GLOutputRate));
    return YES;
}

@end

GL_TEST(test_renderer_joins_two_tracks_with_no_gap) {
    GLRenderer *renderer = [GLRenderer new];
    [renderer startItem:@"a" decoder:[GLFakeDecoder decoderWithLength:1500 mark:1] atTime:0];
    [renderer setNextItem:@"b" decoder:[GLFakeDecoder decoderWithLength:3000 mark:2]];
    int16_t buffer[4096 * 2];
    NSUInteger n = [renderer renderInto:buffer frames:4096];
    GL_EQUAL_INT(n, 4096);
    GL_EQUAL_INT(buffer[1499 * 2 + 1], 1);
    GL_EQUAL_INT(buffer[1500 * 2], 2);
    GL_EQUAL_INT(buffer[4095 * 2 + 1], 2);
    GL_EQUAL_INT(renderer.endFrame, -1);
}

GL_TEST(test_renderer_tells_the_track_and_the_time_of_a_frame) {
    GLRenderer *renderer = [GLRenderer new];
    [renderer startItem:@"a" decoder:[GLFakeDecoder decoderWithLength:GLOutputRate mark:1] atTime:0];
    [renderer setNextItem:@"b" decoder:[GLFakeDecoder decoderWithLength:GLOutputRate mark:2]];
    int16_t buffer[8192 * 2];
    for (int i = 0; i < 8; i++) [renderer renderInto:buffer frames:8192];
    GLRendererPosition *position = [renderer positionAtFrame:GLOutputRate / 2];
    GL_EQUAL(position.item, @"a");
    GL_EXPECT(fabs(position.time - 0.5) < 1e-9);
    position = [renderer positionAtFrame:GLOutputRate + GLOutputRate / 4];
    GL_EQUAL(position.item, @"b");
    GL_EXPECT(fabs(position.time - 0.25) < 1e-9);
}

GL_TEST(test_renderer_ends_when_no_track_is_left) {
    GLRenderer *renderer = [GLRenderer new];
    [renderer startItem:@"a" decoder:[GLFakeDecoder decoderWithLength:1000 mark:1] atTime:0];
    int16_t buffer[4096 * 2];
    GL_EQUAL_INT([renderer renderInto:buffer frames:4096], 1000);
    GL_EQUAL_INT(renderer.endFrame, 1000);
    GL_EQUAL_INT([renderer renderInto:buffer frames:4096], 0);
    GL_EXPECT([renderer positionAtFrame:1200].item == nil);
}

GL_TEST(test_renderer_starts_the_timeline_again_at_a_seek) {
    GLRenderer *renderer = [GLRenderer new];
    GLFakeDecoder *decoder = [GLFakeDecoder decoderWithLength:GLOutputRate * 10 mark:1];
    [renderer startItem:@"a" decoder:decoder atTime:0];
    int16_t buffer[4096 * 2];
    [renderer renderInto:buffer frames:4096];
    GL_EXPECT([renderer restartAtTime:6]);
    GL_EQUAL_INT(decoder.position, GLOutputRate * 6);
    [renderer renderInto:buffer frames:4096];
    GLRendererPosition *position = [renderer positionAtFrame:GLOutputRate];
    GL_EQUAL(position.item, @"a");
    GL_EXPECT(fabs(position.time - 7) < 1e-9);
}

GL_TEST(test_renderer_skips_a_track_that_fails) {
    GLRenderer *renderer = [GLRenderer new];
    GLFakeDecoder *broken = [GLFakeDecoder decoderWithLength:1000 mark:1];
    broken.fails = YES;
    [renderer startItem:@"a" decoder:broken atTime:0];
    [renderer setNextItem:@"b" decoder:[GLFakeDecoder decoderWithLength:1000 mark:2]];
    int16_t buffer[512 * 2];
    GL_EQUAL_INT([renderer renderInto:buffer frames:512], 512);
    GL_EQUAL_INT(buffer[0], 2);
    GL_EQUAL([renderer positionAtFrame:0].item, @"b");
}

GL_TEST(test_renderer_forgets_the_next_track_when_it_is_removed) {
    GLRenderer *renderer = [GLRenderer new];
    [renderer startItem:@"a" decoder:[GLFakeDecoder decoderWithLength:100 mark:1] atTime:0];
    [renderer setNextItem:@"b" decoder:[GLFakeDecoder decoderWithLength:100 mark:2]];
    [renderer setNextItem:nil decoder:nil];
    GL_EXPECT(renderer.nextItem == nil);
    int16_t buffer[512 * 2];
    GL_EQUAL_INT([renderer renderInto:buffer frames:512], 100);
}

GL_TEST(test_renderer_keeps_the_next_track_at_a_seek) {
    GLRenderer *renderer = [GLRenderer new];
    [renderer startItem:@"a" decoder:[GLFakeDecoder decoderWithLength:GLOutputRate * 2 mark:1] atTime:0];
    [renderer setNextItem:@"b" decoder:[GLFakeDecoder decoderWithLength:1000 mark:2]];
    GL_EXPECT([renderer restartAtTime:1.5]);
    GL_EQUAL(renderer.nextItem, @"b");
    int16_t buffer[32768 * 2];
    GL_EQUAL_INT([renderer renderInto:buffer frames:32768], GLOutputRate / 2 + 1000);
}

GL_TEST(test_renderer_cannot_restart_with_no_track) {
    GL_EXPECT(![[GLRenderer new] restartAtTime:1]);
}
