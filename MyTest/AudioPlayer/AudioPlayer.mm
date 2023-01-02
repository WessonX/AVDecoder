//
//  AudioPlayer.m
//  MyTest
//
//  Created by 谢文灏 on 2022/12/31.
//

#import "AudioPlayer.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import "CommonUtil.h"
#include "AVDecoder.hpp"

// 默认的采样率
static const double sample_rate = 44100;
// 默认的ioBuffer处理时间
static const double ioBufferDuration = 0.023;

static void CheckStatus(OSStatus status, NSString *message, BOOL fatal);
static OSStatus InputRenderCallback(void *inRefCon,
                                    AudioUnitRenderActionFlags *ioActionFlags,
                                    const AudioTimeStamp *inTimeStamp,
                                    UInt32 inBusNumber,
                                    UInt32 inNumberFrames,
                                    AudioBufferList *ioData);

@interface AudioPlayer ()

@property(nonatomic, strong) AVAudioSession     *audioSession;
@property(nonatomic, assign) AUGraph            graph;
@property(nonatomic, assign) AUNode             ioNode;
@property(nonatomic, assign) AudioUnit          ioUnit;

@end
@implementation AudioPlayer
{
//    AVDecoder *_avDecoder;
    std::queue<SampleFrame>_audioQueue;
}

- (instancetype)initWithFilePath:(NSString *)filePath {
    self = [super init];
    if (self) {
        // 进行解码
        dispatch_queue_t queue = dispatch_queue_create("decodeQueue", DISPATCH_QUEUE_CONCURRENT);
        __weak typeof(self) weakSelf = self;
        dispatch_async(queue, ^{
            // 初始化解码器
            __strong typeof(self) strongSelf = weakSelf;
            AVDecoder *_avDecoder = new AVDecoder([filePath UTF8String],&strongSelf->_audioQueue);
            int ret = _avDecoder->decode();
            if (ret < 0) {
                NSLog(@"解码失败");
            } else {
                NSLog(@"解码成功");
            }
            delete _avDecoder;
        });
        // 设置默认参数
        self.graphSampleRate = sample_rate;
        self.ioBufferDuration = ioBufferDuration;
        // 设置audioSession
        self.audioSession = [AVAudioSession sharedInstance];
        NSError *audioSessionError = nil;
        [self.audioSession setPreferredSampleRate:sample_rate error:&audioSessionError];
        [self.audioSession setCategory:AVAudioSessionCategoryPlayback error:&audioSessionError];
        [self.audioSession setActive:YES error:&audioSessionError];
        [self.audioSession setPreferredIOBufferDuration:_ioBufferDuration error:&audioSessionError];
        /* 前面虽然设置了audioSession的sampleRate，但是实际系统可能不并会接受，因为可能设备上有其他的app正在占用资源，所以系统会自己为audiosession决定一个sampleRate。因此这里需要更新一下sampleRate
         */
        self.graphSampleRate = [self.audioSession preferredSampleRate];

        // 配置AUgraph和node
        [self initialize];
    }
    return self;
}

- (void)initialize{
    OSStatus status = noErr;
    
    // 构造AUgraph
    status = NewAUGraph(&_graph);
    CheckStatus(status, @"fail to create graph", YES);
    
    // 添加IO node
    AudioComponentDescription ioDescription;
    bzero(&ioDescription, sizeof(ioDescription));
    ioDescription.componentType         = kAudioUnitType_Output;
    ioDescription.componentSubType      = kAudioUnitSubType_RemoteIO;
    ioDescription.componentManufacturer = kAudioUnitManufacturer_Apple;
    ioDescription.componentFlags        = 0;
    ioDescription.componentFlagsMask    = 0;
    status = AUGraphAddNode(_graph, &ioDescription, &_ioNode);
    CheckStatus(status, @"fail to add ioNode to graph", YES);
    
    
    // 打开graph
    status = AUGraphOpen(_graph);
    CheckStatus(status, @"fail to open graph", YES);
    
    // 获取AudioUnit实例
    status = AUGraphNodeInfo(_graph, _ioNode, NULL, &_ioUnit);
    CheckStatus(status, @"fail to get Audio unit from node", YES);
    
    // 给AudioUnit设置参数
    UInt32 bytesPerSample  = sizeof(SInt16);
    AudioStreamBasicDescription asbd;
    bzero(&asbd, sizeof(asbd));
    asbd.mFormatID         = kAudioFormatLinearPCM;
    asbd.mFormatFlags      = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    asbd.mBitsPerChannel   = 8 * bytesPerSample;
    asbd.mChannelsPerFrame = 2;
    asbd.mBytesPerFrame    = bytesPerSample * 2;
    asbd.mBytesPerPacket   = bytesPerSample * 2;
    asbd.mSampleRate       = self.graphSampleRate;
    asbd.mFramesPerPacket  = 1;
    
    status = AudioUnitSetProperty(_ioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &asbd, sizeof(asbd));
    CheckStatus(status, @"fail to setStreamFmt", YES);
    
    // 设置数据源
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = &InputRenderCallback;
    callbackStruct.inputProcRefCon = (__bridge void *)(self);
    
    status = AudioUnitSetProperty(_ioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &callbackStruct, sizeof(callbackStruct));
    CheckStatus(status,@"fail to set renderCallBack", YES);
    
    
    // 初始化graph
    status = AUGraphInitialize(_graph);
    CheckStatus(status, @"fail to initialize the graph", YES);
    
    CAShow(_graph);
    
    [self printASBD:asbd];
    // 开启graph
    
    status = AUGraphStart(_graph);
    CheckStatus(status, @"fail to start the graph", YES);
    
    
}

- (BOOL)play {
    return YES;
}

- (void)stop{
    
}

- (OSStatus)renderData:(AudioBufferList *)ioData
           atTimeStamp:(const AudioTimeStamp *)timeStamp
            forElement:(UInt32)element
          numberFrames:(UInt32)numFrames
                 flags:(AudioUnitRenderActionFlags *)flags {

    for (int i = 0; i < ioData->mNumberBuffers; ++i) {
        memset(ioData->mBuffers[i].mData, 0, ioData->mBuffers[i].mDataByteSize);
        if (!_audioQueue.empty()) {
            // 注意，queue.front（），返回的“Reference”并不是指针意义上的引用,而是一个拷贝。所以这里的frame要加&，转换为真正的引用
            SampleFrame &frame = _audioQueue.front();
            
            // 将frame中的数据拷贝到ioData中
            memcpy(ioData->mBuffers[i].mData, frame.data, frame.frameCnt * 4);
            
            // 将frame的数据清除掉
            delete frame.data;
            
            // 将frame从队列移除
            _audioQueue.pop();
            
        }
        
    }
    
    return noErr;
}

static OSStatus InputRenderCallback(void *inRefCon,
                                    AudioUnitRenderActionFlags *ioActionFlags,
                                    const AudioTimeStamp *inTimeStamp,
                                    UInt32 inBusNumber,
                                    UInt32 inNumberFrames,
                                    AudioBufferList *ioData) {
    AudioPlayer *player = (__bridge id)inRefCon;
    return [player renderData:ioData atTimeStamp:inTimeStamp forElement:inBusNumber numberFrames:inNumberFrames flags:ioActionFlags];
}

- (void) printASBD: (AudioStreamBasicDescription) asbd {
 
    char formatIDString[5];
    UInt32 formatID = CFSwapInt32HostToBig (asbd.mFormatID);
    bcopy (&formatID, formatIDString, 4);
    formatIDString[4] = '\0';
 
    NSLog (@"  Sample Rate:         %10.0f",  asbd.mSampleRate);
    NSLog (@"  Format ID:           %10s",    formatIDString);
    NSLog (@"  Format Flags:        %10X",    asbd.mFormatFlags);
    NSLog (@"  Bytes per Packet:    %10d",    asbd.mBytesPerPacket);
    NSLog (@"  Frames per Packet:   %10d",    asbd.mFramesPerPacket);
    NSLog (@"  Bytes per Frame:     %10d",    asbd.mBytesPerFrame);
    NSLog (@"  Channels per Frame:  %10d",    asbd.mChannelsPerFrame);
    NSLog (@"  Bits per Channel:    %10d",    asbd.mBitsPerChannel);
}

- (void)dealloc{
    [self destroyPlayer];
}

- (void)destroyPlayer {
    AUGraphStop(_graph);
    AUGraphUninitialize(_graph);
    AUGraphClose(_graph);
    AUGraphRemoveNode(_graph, _ioNode);
    DisposeAUGraph(_graph);
    _graph  = NULL;
    _ioNode = NULL;
    _ioUnit = NULL;
}

@end

static void CheckStatus(OSStatus status, NSString *message, BOOL fatal)
{
    if(status != noErr)
    {
        char fourCC[16];
        *(UInt32 *)fourCC = CFSwapInt32HostToBig(status);
        fourCC[4] = '\0';
        
        if(isprint(fourCC[0]) && isprint(fourCC[1]) && isprint(fourCC[2]) && isprint(fourCC[3]))
            NSLog(@"%@: %s", message, fourCC);
        else
            NSLog(@"%@: %d", message, (int)status);
        
        if(fatal)
            exit(-1);
    }
}


