//
//  AudioPlayer.h
//  MyTest
//
//  Created by 谢文灏 on 2022/12/31.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol fillAudioDataDelegate <NSObject>

- (int)fillAudioDataWithBuffer:(uint8_t *)buffer numFrames:(int)numFrames numChannels:(int) channels;

@end

@interface AudioPlayer : NSObject

/// 采样率
@property (nonatomic,assign) double graphSampleRate;

/// ioBuffer的处理时长
@property (nonatomic,assign) double ioBufferDuration;

/// 拉取音频数据的代理
@property(nonatomic, weak) id<fillAudioDataDelegate> fillAudioDataDelegate;

//- (instancetype)initWithFilePath:(NSString *)filePath;

- (void)play;

- (void)stop;

- (bool)isPlaying;

- (void)destroyPlayer;
@end

NS_ASSUME_NONNULL_END
