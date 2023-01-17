//
//  VideoPlayer.m
//  MyTest
//
//  Created by 谢文灏 on 2023/1/16.
//

#import "VideoPlayer.h"

@interface VideoPlayer ()

@end

@implementation VideoPlayer
- (instancetype)init {
    if(self = [super init]) {
        int width  = [UIScreen mainScreen].bounds.size.width;
        int height = [UIScreen mainScreen].bounds.size.height;
        
        self.videoView = [[OpenGLView alloc] initWithFrame:CGRectMake(0, 0, width, height)];
        
        // 注册监听视频是否播放结束
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(videoDidPlayToEnd) name:@"videoDidPlayToEnd" object:nil];
    }
    return self;
}

- (void)play {
    self.shouldPullData = YES;
    NSLog(@"开始播放");
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        if (self.dataDelegate && [self.dataDelegate respondsToSelector:@selector(fillVideoDataWithBuffer:width:height:)]) {
            [[NSThread currentThread] setName:@"videoThread"];
            while (self.shouldPullData) {
                uint8_t *data = NULL;
                int width = 0, height = 0;
                
                // 通过代理，获得视频帧以及宽高信息
                [self.dataDelegate fillVideoDataWithBuffer:(void **)&data width:&width height:&height];
                if (data) {
                    self.isPlaying = YES;
                    [self.videoView displayYUV420pData:data width:width height:height];
                    delete []data;
                }
                
                // 35ms渲染一次，计算为28帧，考虑到其他的一些计算消耗，实际刚好是24帧。
                [NSThread sleepForTimeInterval:0.035];
            }
        }
    });
}

- (void)stop {
    NSLog(@"播放暂停");
    self.shouldPullData = NO;
    self.isPlaying      = NO;
}

- (void)videoDidPlayToEnd {
    NSLog(@"视频播放结束");
    self.shouldPullData = false;
}
@end
