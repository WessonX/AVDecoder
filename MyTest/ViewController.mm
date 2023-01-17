//
//  ViewController.m
//  MyTest
//
//  Created by 谢文灏 on 2022/10/9.
//

#import "ViewController.h"
#import "CommonUtil.h"
#import "AudioPlayer.h"
#import <Masonry/Masonry.h>
#include "AVDecoder.hpp"
#include "avformat.h"
#include "OpenGLView.h"

@interface ViewController ()

@property(nonatomic, strong)AudioPlayer *player;
@property(nonatomic, strong)UIButton    *playBtn;
@property(nonatomic, strong)OpenGLView  *openglView;

-(void)play;


-(void)playDidEnd;
@end


@implementation ViewController
{
    AVDecoder *decoder;
    dispatch_queue_t myQueue;
}

- (void)viewDidLoad {
    NSLog(@"view did load");
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    
//    self.playBtn = [[UIButton alloc]initWithFrame:CGRectMake(50, 50, 100, 100)];
    [self.view layoutIfNeeded];
    self.playBtn = [[UIButton alloc]init];
    self.playBtn.backgroundColor = [UIColor greenColor];
    [self.playBtn setTitle:@"播放" forState:UIControlStateNormal];
    [self.playBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [self.playBtn addTarget:self action:@selector(play) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.playBtn];
    
    [self.playBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.width.height.equalTo(@(50));
        make.center.equalTo(self.view);
        
    }];
    
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(playDidEnd) name:@"endPlayNotification" object:nil];

    NSString *filePath =  [CommonUtil bundlePath:@"big_buck_bunny.mp4"];
    
//    self.player = [[AudioPlayer alloc]initWithFilePath:@"https://media.w3.org/2010/05/sintel/trailer.mp4"];
//    self.player = [[AudioPlayer alloc] initWithFilePath:filePath];
    
    self.openglView = [[OpenGLView alloc]initWithFrame:self.view.bounds];
    [self.view addSubview:_openglView];
    decoder = new AVDecoder([filePath UTF8String]);
//    decoder->outputPath = [filePath UTF8String];
    myQueue = dispatch_queue_create("queue", DISPATCH_QUEUE_CONCURRENT);
    dispatch_async(myQueue, ^{
        self->decoder->decode();
    });
    
}

- (void)viewDidAppear:(BOOL)animated {
     //需要在viewDidAppear，将view添加进view体系中，才能使用openGL进行渲染。
    dispatch_async(myQueue, ^{
        // 只要decoder还在解码，或者帧队列还没空，就不断尝试从queue中获取数据
        while(self->decoder->isDecoding || !self->decoder->videoQueue.empty()) {
            if (!self->decoder->videoQueue.empty()) {
                VideoFrame &frame = self->decoder->videoQueue.front();
                
                [self->_openglView displayYUV420pData:frame.data width:frame.width height:frame.height];
                self->decoder->videoQueue.pop();
                delete []frame.data;
            }
        }
    });
    
}
- (void)play {
    if (self.player) {
        if ([self.player isPlaying]) {
            [self.player stop];
            [self.playBtn setTitle:@"播放" forState:UIControlStateNormal];
            NSLog(@"点击了暂停按钮");
        } else {
            [self.player play];
            [self.playBtn setTitle:@"暂停" forState:UIControlStateNormal];
            NSLog(@"点击了播放按钮");
            
        }
    }
}


- (void)playDidEnd {
    //回到主线程上更新UI
    [[NSOperationQueue mainQueue]addOperationWithBlock:^{
        [self.playBtn setTitle:@"播放" forState:UIControlStateNormal];
    }];
}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter]removeObserver:self];
}
@end
