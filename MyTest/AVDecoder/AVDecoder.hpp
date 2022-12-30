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

// 目标音频的参数
#define OUT_CHANNELS 2
#define OUT_SAMPLE_RATE 44100
#define OUT_SAMPLE_FMT AV_SAMPLE_FMT_S16P

// 目标视频的参数
#define DST_WIDTH 400
#define DST_HEIGHT 400
#define DST_PIX_FMT AV_PIX_FMT_YUV420P

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
    
    // 输出音频文件的保存路径
    const char *outputAudioFilePath;
    
    // 输出视频文件的保存路径
    const char *outputVideoFilePath;
    
    // 输出音频文件的句柄
    FILE *audioOutput;
    
    // 输出视频文件的句柄
    FILE *videoOutput;
    
    // 视频帧的高度
    int height;
    
    // 视频帧的宽度
    int width;
    
    // 视频输出缓冲区 data[0][1][2]分别存储y,u,v分量 （当然也可能是rgb分量，取决于具体的格式）
    uint8_t *video_dst_data[4] = {NULL};
    
    // 输出缓冲区的大小
    int video_dst_bufsize;
    
    // 视频输出的行大小 linesize[0][1][2]分别存储y,u,v分量的行大小
    int video_dst_linesize[4];
    
    // 视频帧的格式
    AVPixelFormat pix_fmt;
    
    // 存储流信息的上下文
    AVFormatContext *fmtCtx;
    
    // 存储音频编解码信息的上下文
    AVCodecContext *audioCodecCtx;
    
    // 存储视频编解码信息的上下文
    AVCodecContext *videoCodecCtx;
    
    // 数据包
    AVPacket *packet;
    
    // 数据帧
    AVFrame *frame;
    
    // 音频流的索引
    int audioIndex = -1;
    
    // 视频流的索引
    int videoIndex = -1;
    
    // 创建解码器上下文
    int createCodecCtx(AVStream *);
    
    // 输出视频帧
    int out_video_frame(AVFrame *);
    
    // 输出音频帧
    int out_audio_frame(AVFrame *);
    
    /// 初始化函数
    void init();
    
    // 对数据包进行解析
    int decodePacket(AVCodecContext *, AVPacket *);
    
    /**重采样相关参数**/
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
    uint8_t **outdata;
    
    // 判断是否需要重新采样
    bool needResample(AVCodecContext *);
    
    /**视频格式转换相关参数**/
    
    // 图像格式转换上下文
    SwsContext *swsContext;
    
    // 目标高度
    int dst_height;
    
    // 目标宽度
    int dst_width;
    
    // 格式转换后的数据
    uint8_t *scaled_data[4] = {NULL};
    
    // 格式转换后数据的字节数
    int scaled_buffer_size;
    
    // 格式转换后的数据的行大小
    int scaled_linesize[4];
    
    // 目标像素格式
    AVPixelFormat dst_pix_fmt;
    
    // 判断是否需要格式转换
    bool needScale(AVCodecContext *);
    
    // 图像格式转换
    int rescale(uint8_t *[]);
    
    
public:
    ~AVDecoder();
    AVDecoder(const char *, const char *, const char *);
    int decode();
    void destroy();
    
};
#endif /* AVDecoder_hpp */
