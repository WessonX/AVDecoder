//
//  AVDecoder.cpp
//  MyTest
//
//  Created by 谢文灏 on 2022/12/25.
//

#include "AVDecoder.hpp"
#include "avformat.h"

AVDecoder::AVDecoder(const char *inputFilePath, const char *outputFilePath){
    this->inputFilePath = inputFilePath;
    this->outputFilePath = outputFilePath;
    
    Init();
    
    output = fopen(outputFilePath, "wb+");
    cout<<"AVDecoder initialize with filepath"<<endl;
}

void AVDecoder::Init(){
    avformat_network_init();
}

int AVDecoder::Decode(){
    // 构造avformatContext
    fmtCtx = avformat_alloc_context();
    
    // 打开文件，获取流
    int result = avformat_open_input(&fmtCtx, inputFilePath, NULL, NULL);
    if (result == 0) {
        cout<<"open file succeed！"<<endl;
    } else {
        cout<<"fail to open file！"<<endl;
        return -1;
    }
    
    // 获取流信息
    int res = avformat_find_stream_info(fmtCtx, NULL);
    if (res >=0){
        cout<<"successed to get stream info！"<<endl;
    } else {
        cout<<"fail to get stream info！"<<endl;
        return -1;
    }
    
    // 获取音频流
    int audioStreamNb = av_find_best_stream(fmtCtx, AVMEDIA_TYPE_AUDIO, -1, -1, NULL, 0);
    if (audioStreamNb == -1){
        cout<<"fail to find audio Stream"<<endl;
        return -1;
    }
    AVStream *audioStream = fmtCtx->streams[audioStreamNb];
    
    // 获取音频流的解码器信息
    AVCodecParameters *codecParms = audioStream->codecpar;
    
    // 根据解码器信息创建对应的解码器
    AVCodec *codec = avcodec_find_decoder(codecParms->codec_id);
    if (!codec) {
        cout<<"fail to find decoder！"<<endl;
        return -1;
    }
    
    // 构建解码器上下文
    codecContext = avcodec_alloc_context3(codec);
    int code = avcodec_parameters_to_context(codecContext, codecParms);
    if (code < 0) {
        cout<<"fail at [avcodec_parameters_to_context] "<<endl;
        return -1;
    }
    
    code = avcodec_open2(codecContext, codec, NULL);
    if (code < 0) {
        cout<<"fail at [avcodec_open2]"<<endl;
        return -1;
    }
    
    cout<<"解码器名称:"<<codec->name<<endl;
    cout<<"采样格式:"<<codec->sample_fmts<<endl;
    cout<<"通道数:"<<codecContext->channels<<endl;
    cout<<"采样率:"<<codecContext->sample_rate<<endl;
    
    
    // 读取音频帧
    packet = av_packet_alloc();
    frame = av_frame_alloc();

    while(true){
        
        // 循环从流中读取数据包
        av_read_frame(fmtCtx, packet);
        
        // 将数据包输入到解码器
        int ret = avcodec_send_packet(codecContext, packet);
        if (ret == AVERROR(EINVAL) || ret == AVERROR(ENOMEM)) {
            cout<<"fail to send packet into decoder"<<endl;
            return -1;
        } else if (ret == AVERROR_EOF) { //解码器已经读空
            return 1;
        }
        
        // 从解码器中循环获取数据帧
        while(true) {
            ret =  avcodec_receive_frame(codecContext, frame);
            // 需要继续输入packet
            if (ret == AVERROR(EAGAIN)){
                break;
            } else if (ret == AVERROR_EOF) { // 解码器已经读空
                return 1;
            } else if (ret == AVERROR(EINVAL) || ret == AVERROR(ENOMEM)) { // 出现异常
                cout<<"error accured"<<endl;
                return -1;
            }
            // 采样格式
            int numBytes = av_get_bytes_per_sample(codecContext->sample_fmt);
            
            // AVFrame采用的是LLLLRRRRR的planar格式，左右声道数据分开排列。
            // pcm采用的是packed格式，即LRLRLR形，左右声道数据交叉排列。
            for (int i = 0; i < frame->nb_samples; ++i) {
                for (int channel = 0; channel< codecContext->channels; ++channel) {
                    fwrite(frame->data[channel] + numBytes * i, numBytes, 1, output);
                }
            }
        }
    }
    return 1;
}

AVDecoder::~AVDecoder(){
    cout<<"AVDecoder destroy"<<endl;
    // 释放avformatContext
    avformat_close_input(&fmtCtx);
    avformat_free_context(fmtCtx);
    // 关闭文件
    fclose(output);
    
    // 释放codecCOntext
    avcodec_free_context(&codecContext);
    
    // 释放数据包和数据帧
    av_frame_free(&frame);
    av_packet_free(&packet);
    
}
