//
//  ViewController.m
//  MyTest
//
//  Created by 谢文灏 on 2022/10/9.
//

#import "ViewController.h"
#import "CommonUtil.h"
#import "AudioPlayer.h"
#include "AVDecoder.hpp"

@interface ViewController ()

@property(nonatomic, strong)AudioPlayer *player;
@end


@implementation ViewController

- (void)viewDidLoad {
    NSLog(@"view did load");
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor greenColor];

    const char *inputFilePath = [[CommonUtil bundlePath:@"big_buck_bunny.mp4"] cStringUsingEncoding:NSUTF8StringEncoding];
    
    const char *outputAudioFilePath = [[CommonUtil documentPath:@"132.pcm"] cStringUsingEncoding:NSUTF8StringEncoding];
    
    const char *outputVideoFilePath = [[CommonUtil documentPath:@"132.h264"] cStringUsingEncoding:NSUTF8StringEncoding];
    
    dispatch_queue_t queue = dispatch_queue_create("myqueue",DISPATCH_QUEUE_CONCURRENT);
    dispatch_async(queue, ^{
//        AVDecoder *decoder = new AVDecoder("https://media.w3.org/2010/05/sintel/trailer.mp4",outputAudioFilePath,outputVideoFilePath);
//        int ret = decoder->decode();
//        if (ret == 0) {
//            cout<<"解码成功！"<<endl;
//        } else {
//            cout<<"解码失败！"<<endl;
//        }
//        delete decoder;
        self.player = [[AudioPlayer alloc]initWithFilePath:@"https://media.w3.org/2010/05/sintel/trailer.mp4"];
    });

}


@end
