//
//  WHPlayerViewController.h
//  MyTest
//
//  Created by 谢文灏 on 2023/1/17.
//

#import <UIKit/UIKit.h>
#import "VideoPlayer.h"
#import "AudioPlayer.h"

NS_ASSUME_NONNULL_BEGIN

@interface WHPlayerViewController : UIViewController<fillVideoFrameDelegate,fillAudioDataDelegate>

/// 视频播放器
@property(nonatomic, strong)VideoPlayer *videoPlayer;
/// 音频播放器
@property(nonatomic, strong)AudioPlayer *audioPlayer;

/// 播放内容的路径
@property(nonatomic, assign)NSString    *filePath;

- (instancetype)initWithFilePath:(NSString *)filePath;


@end

NS_ASSUME_NONNULL_END
