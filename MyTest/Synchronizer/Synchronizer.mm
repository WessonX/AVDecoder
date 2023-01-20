//
//  Synchronizer.m
//  MyTest
//
//  Created by 谢文灏 on 2023/1/20.
//

#import "Synchronizer.h"


#define LOCAL_AV_SYNC_MAX_TIME_DIFF                     0.05      // 音视频时钟差允许的最大阈值

@interface Synchronizer ()

/// 当前音频帧的时间戳
@property(nonatomic,assign)CGFloat audioPosition;

/// 当前视频帧的时间戳
@property(nonatomic,assign)CGFloat videoPosition;

/// 音视频时钟差值的阈值
@property(nonatomic,assign)CGFloat sync_threshold;

@end


@implementation Synchronizer
{
    AVDecoder *_decoder;
}

- (instancetype)initWithFilePath:(NSString *)filePath {
    if (self = [super init]) {
        _decoder = new AVDecoder([filePath UTF8String]);
        _sync_threshold = LOCAL_AV_SYNC_MAX_TIME_DIFF;
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [[NSThread currentThread] setName:@"decodeThread"];
            self->_decoder->decode();
        });
    }
    return self;
}

- (int)fillAudioData:(uint8_t *)sampleBuffer numFrames:(int)frameNum numChannels:(int)channels {
    int ret = _decoder->assembleRenderData(sampleBuffer, frameNum, &_audioPosition);
    return ret;
}

/**
 相较于笔记中记录的ffplay的音视频同步方式，这里忽略了上一帧的duartion,delay那些参数，直接将当前的视频帧和当前的音频帧做对比，决定当前音频帧的取舍，更加简洁。
 */
- (VideoFrame *)getCorrectVideoFrame {
    while(!_decoder->videoQueue.empty()) {
        VideoFrame &frame = _decoder->videoQueue.front();
        
        // 音频时钟和视频时钟的差值
        const CGFloat diff = frame.position - _audioPosition;
        
        // 视频比音频快，超过了阈值。则还是渲染上一帧
        if (diff > _sync_threshold) {
            return NULL;
        }
        
        _decoder->videoQueue.pop();
        // 视频比音频慢，超过了阈值。继续从队列中拿到合适的帧
        if (diff < 0 - _sync_threshold) {
            continue;
        } else { // 视频和音频时钟的差值在阈值内，认为同步，直接返回当前帧
            return &frame;
        }
    }
    return  NULL;
}
@end
