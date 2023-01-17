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
        _decoder = new AVDecoder([filePath UTF8String]);
        
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            self->_decoder->decode();
        });
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _videoPlayer = [[VideoPlayer alloc] init];
    _audioPlayer = [[AudioPlayer alloc] init];
    [self.view addSubview:_videoPlayer.videoView];
    self.videoPlayer.dataDelegate = self;
}

- (void)viewDidAppear:(BOOL)animated {
    [self.videoPlayer play];
}

- (void)fillDataWithBuffer:(void **)buffer width:(int *)width height:(int *)height {
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

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (self.videoPlayer.isPlaying) {
        [self.videoPlayer stop];
    } else {
        [self.videoPlayer play];
    }
}
@end
