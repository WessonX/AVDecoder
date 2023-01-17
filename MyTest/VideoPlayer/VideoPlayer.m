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
        self.shouldPullData = true;
        
        // 注册监听视频是否播放结束
        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(videoDidPlayToEnd) name:@"videoDidPlayToEnd" object:nil];
    }
    return self;
}

- (void)play {
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        if (self.dataDelegate && [self.dataDelegate respondsToSelector:@selector(fillDataWithBuffer:width:height:)]) {
            
            while (self.shouldPullData) {
                void *data = NULL;
                int width = 0, height = 0;
                
                // 通过代理，获得视频帧以及宽高信息
                [self.dataDelegate fillDataWithBuffer:&data width:&width height:&height];
                if (data) {
                    [self.videoView displayYUV420pData:data width:width height:height];
                    free(data);
                }
                
            }
        }
    });
}

- (void)stop {
    
}

- (void)videoDidPlayToEnd {
    NSLog(@"视频播放结束");
    self.shouldPullData = false;
}
@end
