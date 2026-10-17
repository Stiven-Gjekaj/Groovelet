// Tests of GLAudioPlayer on the phone. The volume is 0, so they make no sound.

#import "GLAudioPlayer.h"
#import "GLAudioTestSupport.h"
#import "GLTest.h"

@interface GLPlayerRecorder : NSObject <GLAudioPlayerDelegate>
@property (nonatomic, strong) NSMutableArray *started;
@property (nonatomic) BOOL finished;
@property (nonatomic, copy) void (^onStart)(id item);
@end

@implementation GLPlayerRecorder

- (instancetype)init {
    if ((self = [super init])) _started = [NSMutableArray array];
    return self;
}

- (void)audioPlayer:(GLAudioPlayer *)player didStartItem:(id)item {
    [self.started addObject:item];
    if (self.onStart) self.onStart(item);
}

- (void)audioPlayerDidFinish:(GLAudioPlayer *)player {
    self.finished = YES;
}

- (void)audioPlayerDidChangeState:(GLAudioPlayer *)player {
}

@end

static NSString *GLWave(NSString *directory, NSString *name, double seconds) {
    return GLWriteSineFile(directory, name, kAudioFileWAVEType, kAudioFormatLinearPCM, 44100, 2, seconds);
}

GL_TEST(test_player_plays_the_next_item_and_then_finishes) {
    NSString *directory = GLTestTemporaryDirectory();
    NSDictionary *paths = @{ @"a": GLWave(directory, @"a.wav", 1), @"b": GLWave(directory, @"b.wav", 1) };
    GLAudioPlayer *player = [GLAudioPlayer new];
    player.volume = 0;
    GLPlayerRecorder *recorder = [GLPlayerRecorder new];
    __weak GLAudioPlayer *weakPlayer = player;
    recorder.onStart = ^(id item) {
        if ([item isEqual:@"a"]) [weakPlayer setNextItem:@"b" path:paths[@"b"]];
    };
    player.delegate = recorder;
    NSDate *start = [NSDate date];
    GL_EXPECT([player playItem:@"a" path:paths[@"a"] atTime:0 paused:NO]);
    GL_EXPECT(player.playing);
    while (!recorder.finished && [start timeIntervalSinceNow] > -5) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    double elapsed = -[start timeIntervalSinceNow];
    GL_EXPECT(recorder.finished);
    GL_EQUAL(recorder.started, (@[ @"a", @"b" ]));
    // Two tracks of 1 second play in 2 seconds, plus the tick of the clock.
    GL_EXPECT(elapsed > 1.9 && elapsed < 2.6);
}

GL_TEST(test_player_seeks_near_the_end) {
    NSString *path = GLWave(GLTestTemporaryDirectory(), @"a.wav", 4);
    GLAudioPlayer *player = [GLAudioPlayer new];
    player.volume = 0;
    GLPlayerRecorder *recorder = [GLPlayerRecorder new];
    player.delegate = recorder;
    GL_EXPECT([player playItem:@"a" path:path atTime:0 paused:NO]);
    [player seekToTime:3.5];
    NSDate *start = [NSDate date];
    while (!recorder.finished && [start timeIntervalSinceNow] > -5) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    GL_EXPECT(recorder.finished);
    GL_EXPECT(-[start timeIntervalSinceNow] < 1.2);
}

GL_TEST(test_player_keeps_its_place_while_paused) {
    NSString *path = GLWave(GLTestTemporaryDirectory(), @"a.wav", 4);
    GLAudioPlayer *player = [GLAudioPlayer new];
    player.volume = 0;
    GL_EXPECT([player playItem:@"a" path:path atTime:1 paused:NO]);
    NSDate *until = [NSDate dateWithTimeIntervalSinceNow:0.6];
    while ([until timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    [player pause];
    double paused = player.currentTime;
    GL_EXPECT(paused > 1.3 && paused < 1.8);
    until = [NSDate dateWithTimeIntervalSinceNow:0.5];
    while ([until timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    GL_EXPECT(fabs(player.currentTime - paused) < 0.01);
    GL_EXPECT(!player.playing);
    [player stop];
}

GL_TEST(test_player_starts_an_item_again_for_repeat_one) {
    NSString *path = GLWave(GLTestTemporaryDirectory(), @"a.wav", 0.6);
    GLAudioPlayer *player = [GLAudioPlayer new];
    player.volume = 0;
    GLPlayerRecorder *recorder = [GLPlayerRecorder new];
    __weak GLAudioPlayer *weakPlayer = player;
    __block int plays = 0;
    recorder.onStart = ^(id item) {
        if (++plays < 3) [weakPlayer setNextItem:item path:path];
    };
    player.delegate = recorder;
    GL_EXPECT([player playItem:@"a" path:path atTime:0 paused:NO]);
    NSDate *start = [NSDate date];
    while (!recorder.finished && [start timeIntervalSinceNow] > -5) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
    GL_EXPECT(recorder.finished);
    GL_EQUAL(recorder.started, (@[ @"a", @"a", @"a" ]));
}
