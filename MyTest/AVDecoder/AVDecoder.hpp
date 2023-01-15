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
#include <queue>
#include "ConcurrentQueue.h"


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
/**
    用于音频
 */
// 将AVFrame进行可能的格式转换后，并从plannar转换成packed形式后的frame。 一个decodedFrame包含若干个sample
struct DecodedFrame {
    // 存储数据
    uint8_t *data;
    
    // 已经被读取的sample帧数目
    int readCnt = 0;
    
    // 总共的sample帧数目
    int frameCnt = 0;
};

/**
    用于视频
 */
struct VideoFrame {
    // yuv数据
    uint8_t *data;
    
    // 视频的宽
    int width;
    
    // 视频的高
    int height;
};

class AVDecoder{
private:
    // 输入文件的路径
    const char *inputFilePath;
    
    // 存储decodedFrame的队列
//    std::queue<DecodedFrame> audioQueue;
    ConcurrenceQueue<DecodedFrame> audioQueue;
    
//    // 存储VideoFrame的队列
//    ConcurrenceQueue<VideoFrame> videoQueue;
    
    
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
    AVFormatContext *fmtCtx = nullptr;
    
    // 存储音频编解码信息的上下文
    AVCodecContext *audioCodecCtx = nullptr;
    
    // 存储视频编解码信息的上下文
    AVCodecContext *videoCodecCtx = nullptr;
    
    // 数据包
    AVPacket *packet = nullptr;
    
    // 数据帧
    AVFrame *frame = nullptr;
    
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
    
    
    // 对数据包进行解析
    int decodePacket(AVCodecContext *, AVPacket *);
    
    /**重采样相关参数**/
    /// 重采样
    int resample(AVCodecContext *, AVFrame *);
    
    // 重采样上下文
    SwrContext *swrContext = nullptr;
    
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
    SwsContext *swsContext = nullptr;
    
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
    AVDecoder(const char *);
    
    /// 解码数据，并将数据以decodedFrame的形式存储。
    int decode();
    
    /// 从decodedFrame队列中读取指定数目的样本，返回给audioUnit渲染
    int assembleRenderData(uint8_t *, int);
    
    void destroy();
    
    // 是否正在解码数据
    bool isDecoding = false;
    
    // 存储VideoFrame的队列
    ConcurrenceQueue<VideoFrame> videoQueue;
    
    const char *outputPath;
    
    FILE *output;
    
};
#endif /* AVDecoder_hpp */
