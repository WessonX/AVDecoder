//
//  Synchronizer.h
//  MyTest
//
//  Created by 谢文灏 on 2023/1/20.
//

#import <Foundation/Foundation.h>
#import "AVDecoder.hpp"

NS_ASSUME_NONNULL_BEGIN

@interface Synchronizer : NSObject


@property(nonatomic,assign)BOOL isPlaying;

- (instancetype)initWithFilePath:(NSString *)filePath;

- (int)fillAudioData:(uint8_t *)sampleBuffer numFrames:(int)frameNum numChannels:(int)channels;

- (VideoFrame *)getCorrectVideoFrame;

@end

NS_ASSUME_NONNULL_END
