//
//  AudioPlayer.h
//  MyTest
//
//  Created by 谢文灏 on 2022/12/31.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AudioPlayer : NSObject

/// 采样率
@property (nonatomic,assign) double graphSampleRate;

/// ioBuffer的处理时长
@property (nonatomic,assign) double ioBufferDuration;

- (instancetype)initWithFilePath:(NSString *)filePath;

- (BOOL)play;

- (void)stop;

@end

NS_ASSUME_NONNULL_END
