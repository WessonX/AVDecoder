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

@interface ViewController ()

@property(nonatomic, strong)AudioPlayer *player;
@property(nonatomic, strong)UIButton    *playBtn;

-(void)play;


-(void)playDidEnd;
@end


@implementation ViewController

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

    NSString *filePath =  [CommonUtil bundlePath:@"131.aac"];
    
    self.player = [[AudioPlayer alloc]initWithFilePath:@"https://media.w3.org/2010/05/sintel/trailer.mp4"];
//    self.player = [[AudioPlayer alloc] initWithFilePath:filePath];
}

- (void)play {
    if (self.player) {
        if ([self.player isPlaying]) {
            [self.player stop];
            [self.playBtn setTitle:@"播放" forState:UIControlStateNormal];
            NSLog(@"点击了暂停按钮");
        } else {
            [self.player start];
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
