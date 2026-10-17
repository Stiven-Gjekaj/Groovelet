#import "GLRenderer.h"

@interface GLRendererPosition ()
@property (nonatomic, strong) id item;
@property (nonatomic) double time;
@property (nonatomic) int64_t startFrame;
@end

@implementation GLRendererPosition
@end

// One track in the stream: the item, the frame of the stream where it
// starts, and its time at that frame.
@interface GLRendererSpan : NSObject
@property (nonatomic, strong) id item;
@property (nonatomic) int64_t startFrame;
@property (nonatomic) double startTime;
@end

@implementation GLRendererSpan
@end

@interface GLRenderer ()
@property (nonatomic, strong) id currentItem;
@property (nonatomic, strong) id<GLDecoder> currentDecoder;
@property (nonatomic, strong) id nextItem;
@property (nonatomic, strong) id<GLDecoder> nextDecoder;
@property (nonatomic, strong) NSMutableArray *spans;
@property (nonatomic) int64_t renderedFrames;
@property (nonatomic) int64_t endFrame;
@end

@implementation GLRenderer

- (instancetype)init {
    if ((self = [super init])) {
        _spans = [NSMutableArray array];
        _endFrame = 0;
    }
    return self;
}

- (void)startItem:(id)item decoder:(id<GLDecoder>)decoder atTime:(double)seconds {
    @synchronized (self) {
        self.currentItem = item;
        self.currentDecoder = decoder;
        if (seconds > 0) [decoder seekToTime:seconds];
        [self resetTimelineAtTime:seconds];
    }
}

- (void)resetTimelineAtTime:(double)seconds {
    [self.spans removeAllObjects];
    self.renderedFrames = 0;
    self.endFrame = -1;
    [self addSpanForItem:self.currentItem time:seconds];
}

- (BOOL)restartAtTime:(double)seconds {
    @synchronized (self) {
        if (!self.currentDecoder) return NO;
        [self.currentDecoder seekToTime:seconds];
        [self resetTimelineAtTime:seconds];
        return YES;
    }
}

- (void)setNextItem:(id)item decoder:(id<GLDecoder>)decoder {
    @synchronized (self) {
        self.nextItem = item;
        self.nextDecoder = item ? decoder : nil;
    }
}

- (void)clear {
    @synchronized (self) {
        self.currentItem = nil;
        self.currentDecoder = nil;
        self.nextItem = nil;
        self.nextDecoder = nil;
        [self.spans removeAllObjects];
        self.renderedFrames = 0;
        self.endFrame = 0;
    }
}

- (void)addSpanForItem:(id)item time:(double)seconds {
    GLRendererSpan *span = [GLRendererSpan new];
    span.item = item;
    span.startFrame = self.renderedFrames;
    span.startTime = seconds;
    [self.spans addObject:span];
    // The output plays a few buffers behind the renderer. Keep the spans that
    // it can still ask for, and drop the older ones.
    while (self.spans.count > 8) [self.spans removeObjectAtIndex:0];
}

- (NSUInteger)renderInto:(int16_t *)buffer frames:(NSUInteger)frames {
    @synchronized (self) {
        NSUInteger done = 0;
        // A next track that came after the end continues the stream.
        if (!self.currentDecoder && self.nextDecoder && self.endFrame >= 0) {
            self.currentItem = self.nextItem;
            self.currentDecoder = self.nextDecoder;
            self.nextItem = nil;
            self.nextDecoder = nil;
            self.endFrame = -1;
            [self.spans removeLastObject];  // The span of the end.
            [self addSpanForItem:self.currentItem time:0];
        }
        while (done < frames && self.currentDecoder) {
            NSInteger n = [self.currentDecoder readFrames:buffer + done * GLOutputChannels count:frames - done];
            if (n > 0) {
                done += (NSUInteger)n;
                self.renderedFrames += n;
                continue;
            }
            // The track ended, or it failed. The next track starts here.
            self.currentItem = self.nextItem;
            self.currentDecoder = self.nextDecoder;
            self.nextItem = nil;
            self.nextDecoder = nil;
            if (self.currentDecoder) {
                [self addSpanForItem:self.currentItem time:0];
            } else {
                self.endFrame = self.renderedFrames;
                [self addSpanForItem:nil time:0];
            }
        }
        return done;
    }
}

- (GLRendererPosition *)positionAtFrame:(int64_t)frame {
    @synchronized (self) {
        GLRendererPosition *position = [GLRendererPosition new];
        for (GLRendererSpan *span in self.spans.reverseObjectEnumerator) {
            if (span.startFrame <= frame) {
                position.item = span.item;
                position.startFrame = span.startFrame;
                position.time = span.item ? span.startTime + (double)(frame - span.startFrame) / GLOutputRate : 0;
                break;
            }
        }
        return position;
    }
}

@end
