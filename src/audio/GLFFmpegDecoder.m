#import "GLFFmpegDecoder.h"
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/channel_layout.h>
#include <libavutil/opt.h>
#include <libswresample/swresample.h>

@interface GLFFmpegDecoder () {
    AVFormatContext *_format;
    AVCodecContext *_codec;
    SwrContext *_resampler;
    AVPacket *_packet;
    AVFrame *_frame;
    int _stream;
    // Converted frames that the last read did not take.
    int16_t *_pending;
    int _pendingCapacity;
    int _pendingStart;
    int _pendingCount;
    // After a seek: the frames of the output to drop before the target.
    int64_t _dropFrames;
    BOOL _inputEnded;
}
@property (nonatomic) double duration;
@end

static NSError *GLFFmpegError(int code) {
    char text[128];
    av_strerror(code, text, sizeof(text));
    return [NSError errorWithDomain:@"FFmpeg" code:code userInfo:@{ NSLocalizedDescriptionKey: @(text) }];
}

@implementation GLFFmpegDecoder

+ (instancetype)decoderWithPath:(NSString *)path error:(NSError **)error {
    GLFFmpegDecoder *decoder = [GLFFmpegDecoder new];
    int result = [decoder openPath:path];
    if (result < 0) {
        if (error) *error = GLFFmpegError(result);
        return nil;
    }
    return decoder;
}

- (int)openPath:(NSString *)path {
    int result = avformat_open_input(&_format, path.fileSystemRepresentation, NULL, NULL);
    if (result < 0) return result;
    result = avformat_find_stream_info(_format, NULL);
    if (result < 0) return result;
    const AVCodec *codec = NULL;
    _stream = av_find_best_stream(_format, AVMEDIA_TYPE_AUDIO, -1, -1, &codec, 0);
    if (_stream < 0) return _stream;
    AVStream *stream = _format->streams[_stream];
    for (unsigned i = 0; i < _format->nb_streams; i++) {
        if ((int)i != _stream) _format->streams[i]->discard = AVDISCARD_ALL;
    }
    _codec = avcodec_alloc_context3(codec);
    if (!_codec) return AVERROR(ENOMEM);
    result = avcodec_parameters_to_context(_codec, stream->codecpar);
    if (result < 0) return result;
    result = avcodec_open2(_codec, codec, NULL);
    if (result < 0) return result;
    if (_codec->ch_layout.order == AV_CHANNEL_ORDER_UNSPEC) {
        av_channel_layout_default(&_codec->ch_layout, _codec->ch_layout.nb_channels);
    }
    AVChannelLayout stereo = AV_CHANNEL_LAYOUT_STEREO;
    result = swr_alloc_set_opts2(&_resampler, &stereo, AV_SAMPLE_FMT_S16, GLOutputRate, &_codec->ch_layout,
                                 _codec->sample_fmt, _codec->sample_rate, 0, NULL);
    if (result < 0) return result;
    result = swr_init(_resampler);
    if (result < 0) return result;
    _packet = av_packet_alloc();
    _frame = av_frame_alloc();
    if (!_packet || !_frame) return AVERROR(ENOMEM);
    if (stream->duration != AV_NOPTS_VALUE) {
        _duration = stream->duration * av_q2d(stream->time_base);
    } else if (_format->duration != AV_NOPTS_VALUE) {
        _duration = (double)_format->duration / AV_TIME_BASE;
    }
    return 0;
}

- (void)dealloc {
    av_frame_free(&_frame);
    av_packet_free(&_packet);
    swr_free(&_resampler);
    avcodec_free_context(&_codec);
    avformat_close_input(&_format);
    av_free(_pending);
}

// Converts one decoded frame into the pending buffer.
- (BOOL)convertFrame:(AVFrame *)frame {
    int room = swr_get_out_samples(_resampler, frame ? frame->nb_samples : 0);
    if (room <= 0) return YES;
    if (room > _pendingCapacity) {
        av_free(_pending);
        _pending = av_malloc((size_t)room * GLOutputChannels * sizeof(int16_t));
        if (!_pending) return NO;
        _pendingCapacity = room;
    }
    uint8_t *out = (uint8_t *)_pending;
    int n = swr_convert(_resampler, &out, room, frame ? (const uint8_t **)frame->extended_data : NULL,
                        frame ? frame->nb_samples : 0);
    if (n < 0) return NO;
    _pendingStart = 0;
    _pendingCount = n;
    // After a seek, drop the frames before the target.
    if (_dropFrames > 0) {
        int drop = (int)MIN(_dropFrames, (int64_t)n);
        _pendingStart = drop;
        _pendingCount -= drop;
        _dropFrames -= drop;
    }
    return YES;
}

// Decodes until the pending buffer holds frames. Returns NO at the end or
// for an error.
- (BOOL)fillPending:(BOOL *)failed {
    while (_pendingCount == 0) {
        int result = avcodec_receive_frame(_codec, _frame);
        if (result == 0) {
            BOOL converted = [self convertFrame:_frame];
            av_frame_unref(_frame);
            if (!converted) {
                *failed = YES;
                return NO;
            }
            continue;
        }
        if (result == AVERROR_EOF) {
            // Take the last frames out of the resampler.
            if (![self convertFrame:NULL]) *failed = YES;
            return _pendingCount > 0;
        }
        if (result != AVERROR(EAGAIN)) {
            *failed = YES;
            return NO;
        }
        if (_inputEnded) {
            avcodec_send_packet(_codec, NULL);
            continue;
        }
        result = av_read_frame(_format, _packet);
        if (result < 0) {
            _inputEnded = YES;
            avcodec_send_packet(_codec, NULL);
            continue;
        }
        if (_packet->stream_index == _stream) {
            // A damaged packet is skipped. The next packet can decode.
            avcodec_send_packet(_codec, _packet);
        }
        av_packet_unref(_packet);
    }
    return YES;
}

- (NSInteger)readFrames:(int16_t *)buffer count:(NSUInteger)frames {
    NSUInteger done = 0;
    while (done < frames) {
        BOOL failed = NO;
        if (![self fillPending:&failed]) {
            if (failed && done == 0) return -1;
            break;
        }
        int n = (int)MIN((NSUInteger)_pendingCount, frames - done);
        memcpy(buffer + done * GLOutputChannels, _pending + _pendingStart * GLOutputChannels,
               (size_t)n * GLOutputChannels * sizeof(int16_t));
        _pendingStart += n;
        _pendingCount -= n;
        done += (NSUInteger)n;
    }
    return (NSInteger)done;
}

- (BOOL)seekToTime:(double)seconds {
    AVStream *stream = _format->streams[_stream];
    seconds = MAX(0, seconds);
    int64_t target = (int64_t)(seconds / av_q2d(stream->time_base));
    if (stream->start_time != AV_NOPTS_VALUE) target += stream->start_time;
    if (av_seek_frame(_format, _stream, target, AVSEEK_FLAG_BACKWARD) < 0) return NO;
    avcodec_flush_buffers(_codec);
    swr_close(_resampler);
    swr_init(_resampler);
    _pendingCount = 0;
    _inputEnded = NO;
    // The demuxer lands on a packet at or before the target. Decode from
    // there and drop the frames before the target, so that the seek is exact.
    _dropFrames = 0;
    BOOL failed = NO;
    while (YES) {
        int result = av_read_frame(_format, _packet);
        if (result < 0) {
            _inputEnded = YES;
            return YES;
        }
        if (_packet->stream_index != _stream) {
            av_packet_unref(_packet);
            continue;
        }
        int64_t pts = _packet->pts != AV_NOPTS_VALUE ? _packet->pts : _packet->dts;
        if (pts != AV_NOPTS_VALUE) {
            if (stream->start_time != AV_NOPTS_VALUE) pts -= stream->start_time;
            double start = pts * av_q2d(stream->time_base);
            _dropFrames = (int64_t)llround(MAX(0, seconds - start) * GLOutputRate);
        }
        avcodec_send_packet(_codec, _packet);
        av_packet_unref(_packet);
        break;
    }
    (void)failed;
    return YES;
}

@end
