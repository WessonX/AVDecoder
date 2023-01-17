//
//  VideoPlayer.h
//  MyTest
//
//  Created by 谢文灏 on 2023/1/16.
//

#import <Foundation/Foundation.h>
#import "OpenGLView.h"

NS_ASSUME_NONNULL_BEGIN

//获取视频帧的协议
@protocol fillVideoFrameDelegate <NSObject>

/// 获取视频帧数据
/// - Parameters:
///   - buffer: 视频帧
///   - width:  视频的宽度
///   - height: 视频的高度
-(void)fillDataWithBuffer:(void **)buffer width:(int *)width height:(int *)height;

@end

@interface VideoPlayer : NSObject

/// 实际播放的视图
@property(nonatomic, strong)OpenGLView                     *videoView;
/// 获取数据源的代理
@property(nonatomic, weak) id<fillVideoFrameDelegate>      dataDelegate;

/// 判断是否需要拉取数据
@property(nonatomic, assign)BOOL                           shouldPullData;

/// 判断是否正在播放
@property(nonatomic, assign)BOOL                           isPlaying;
- (void)play;

- (void)stop;

@end

NS_ASSUME_NONNULL_END
