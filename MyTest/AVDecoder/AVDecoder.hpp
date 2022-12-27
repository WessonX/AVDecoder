//
//  AVDecoder.hpp
//  MyTest
//
//  Created by 谢文灏 on 2022/12/25.
//

#ifndef AVDecoder_hpp
#define AVDecoder_hpp

#include <stdio.h>
#include <iostream>
#include <string>
using namespace std;

#define OUT_CHANNELS 2
#define OUT_SAMPLE_RATE 44100
#define OUT_SAMPLE_FMT AV_SAMPLE_FMT_S16P
extern "C" {
    #include "libavcodec/avcodec.h"
    #include "libavformat/avformat.h"
    #include "libavutil/avutil.h"
    #include "libavutil/samplefmt.h"
    #include "libavutil/common.h"
    #include "libavutil/channel_layout.h"
    #include "libavutil/opt.h"
    #include "libavutil/imgutils.h"
    #include "libavutil/mathematics.h"
    #include "libswscale/swscale.h"
    #include "libswresample/swresample.h"
};

class AVDecoder{
private:
    // 输入文件的路径
    const char *inputFilePath;
    
    // 输出文件的保存路径
    const char *outputFilePath;
    
    // 输出文件的句柄
    FILE *output;
    
    // 存储流信息的上下文
    AVFormatContext *fmtCtx;
    
    // 存储编解码信息的上下文
    AVCodecContext *codecContext;
    
    // 数据包
    AVPacket *packet;
    
    // 数据帧
    AVFrame *frame;
    
    /// 初始化函数
    void init();
    
    /// 重采样
    int resample(AVCodecContext *, AVFrame *);
    
    // 重采样上下文
    SwrContext *swrContext;
    
    // 目标采样率
    int out_sample_rate;
    
    // 目标采样格式
    AVSampleFormat out_sample_fmt;
    
    // 目标采样通道布局
    int64_t out_ch_layout;
    
    // 存储重采样后的数据
    uint8_t *outdata[2] = {0};
    
    // 判断是否需要重新采样
    bool needResample(AVCodecContext *);
    
public:
    ~AVDecoder();
    AVDecoder(const char *, const char *);
    int decode();
    void destroy();
    
};
#endif /* AVDecoder_hpp */
