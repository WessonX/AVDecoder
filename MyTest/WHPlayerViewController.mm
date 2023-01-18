//
//  WHPlayerViewController.m
//  MyTest
//
//  Created by 谢文灏 on 2023/1/17.
//

#import "WHPlayerViewController.h"

#import "AVDecoder.hpp"

@interface WHPlayerViewController ()

@end

@implementation WHPlayerViewController
{
    AVDecoder *_decoder;
    
}

- (instancetype)initWithFilePath:(NSString *)filePath {
    if (self = [super init]) {
        self.filePath = filePath;
        NSLog(@"currentThread:%@",[NSThread currentThread]);
        _decoder = new AVDecoder([filePath UTF8String]);
        
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [[NSThread currentThread] setName:@"decodeThread"];
            self->_decoder->decode();
        });
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playDidEnd) name:@"videoDidPlayToEnd" object:nil];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _videoPlayer = [[VideoPlayer alloc] init];
    _audioPlayer = [[AudioPlayer alloc] init];
    [self.view addSubview:_videoPlayer.videoView];
    self.videoPlayer.dataDelegate = self;
    self.audioPlayer.fillAudioDataDelegate = self;
}

- (void)fillVideoDataWithBuffer:(void **)buffer width:(int *)width height:(int *)height {
    if(_decoder->isDecoding || !_decoder->videoQueue.empty()) {
        if (!self->_decoder->videoQueue.empty()) {
            VideoFrame &frame = _decoder->videoQueue.front();
            *buffer  = frame.data;
            *width   = frame.width;
            *height  = frame.height;
            _decoder->videoQueue.pop();
        }
    } else {
        // 发送播放结束的通知
        NSNotification *endVideoNotification = [[NSNotification alloc] initWithName:@"videoDidPlayToEnd" object:nil userInfo:nil];
        [[NSNotificationCenter defaultCenter]postNotification:endVideoNotification];
    }
}

- (int)fillAudioDataWithBuffer:(uint8_t *)buffer numFrames:(int)numFrames numChannels:(int)channels {
    int ret = _decoder->assembleRenderData(buffer, numFrames);
    return ret;
}


- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (self.videoPlayer.isPlaying) {
        [self.videoPlayer stop];
        [self.audioPlayer stop];
    } else {
        [self.videoPlayer play];
        [self.audioPlayer play];
    }
}

- (void)playDidEnd{

}
- (void)viewDidDisappear:(BOOL)animated{
    delete _decoder;
    _decoder = nullptr;
}
@end
