//
//  WHPlayerViewController.m
//  MyTest
//
//  Created by 谢文灏 on 2023/1/17.
//

#import "WHPlayerViewController.h"
#import "Synchronizer.h"
#import "AVDecoder.hpp"

@interface WHPlayerViewController ()

@property(nonatomic, strong)Synchronizer *synchronizer;

@end

@implementation WHPlayerViewController
{
    AVDecoder *_decoder;
    
}

#pragma mark Life cycle
- (instancetype)initWithFilePath:(NSString *)filePath {
    if (self = [super init]) {
        self.filePath = filePath;
        _synchronizer = [[Synchronizer alloc] initWithFilePath:filePath];
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(playDidEnd) name:@"endPlayNotification" object:nil];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _videoPlayer = [[VideoPlayer alloc] init];
    _audioPlayer = [[AudioPlayer alloc] init];
    [self.view addSubview:_videoPlayer.videoView];
    self.audioPlayer.fillAudioDataDelegate = self;
}

- (void)viewDidDisappear:(BOOL)animated{
    delete _decoder;
    _decoder = nullptr;
}

#pragma mark 获取音频数据的代理方法，并驱动视频数据的获取
- (int)fillAudioDataWithBuffer:(uint8_t *)buffer numFrames:(int)numFrames numChannels:(int)channels {
    if (_synchronizer) {
        int ret = [_synchronizer fillAudioData:buffer numFrames:numFrames numChannels:channels];
        
        // 基于前面获取的音频数据，获取对应时间的视频帧
        VideoFrame *frame = [_synchronizer getCorrectVideoFrame];
        if (frame) {
            [self.videoPlayer playWithData:frame->data width:frame->width height:frame->height];
            delete []frame->data;
        }
        return ret;
    }
    return 0;
}


- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (self.audioPlayer.isPlaying) {
        [self.audioPlayer stop];
    } else {
        [self.audioPlayer play];
    }
}

#pragma mark Notification
- (void)playDidEnd{
    NSLog(@"播放结束");
}


@end
