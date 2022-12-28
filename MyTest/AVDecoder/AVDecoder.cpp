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
    
    init();
    
    output = fopen(outputFilePath, "wb+");
    cout<<"AVDecoder initialize with filepath"<<endl;
}

void AVDecoder::init(){
    avformat_network_init();
    
    // 解码相关变量
    frame = nullptr;
    packet = nullptr;
    fmtCtx = nullptr;
    codecContext = nullptr;
    
    // 重采样参数
    swrContext = nullptr;
    out_ch_layout = av_get_default_channel_layout(OUT_CHANNELS);
    out_sample_rate = OUT_SAMPLE_RATE;
    out_sample_fmt = OUT_SAMPLE_FMT;
        
    outdata = nullptr;

}

int AVDecoder::decode(){
    // 构造avformatContext
    fmtCtx = avformat_alloc_context();
    
    // 打开文件，获取流
    int result = avformat_open_input(&fmtCtx, inputFilePath, NULL, NULL);
    if (result == 0) {
        cout<<"open file succeed！"<<endl;
    } else {
        cout<<"fail to open file！"<<endl;
        destroy();
        return -1;
    }
    
    // 获取流信息
    int res = avformat_find_stream_info(fmtCtx, NULL);
    if (res >=0){
        cout<<"successed to get stream info！"<<endl;
    } else {
        cout<<"fail to get stream info！"<<endl;
        destroy();
        return -1;
    }
    
    // 获取音频流
    int audioStreamNb = av_find_best_stream(fmtCtx, AVMEDIA_TYPE_AUDIO, -1, -1, NULL, 0);
    if (audioStreamNb == -1){
        cout<<"fail to find audio Stream"<<endl;
        destroy();
        return -1;
    }
    AVStream *audioStream = fmtCtx->streams[audioStreamNb];
    
    // 获取音频流的解码器信息
    AVCodecParameters *codecParms = audioStream->codecpar;
    
    // 根据解码器信息创建对应的解码器
    AVCodec *codec = avcodec_find_decoder(codecParms->codec_id);
    if (!codec) {
        cout<<"fail to find decoder！"<<endl;
        destroy();
        return -1;
    }
    
    // 构建解码器上下文
    codecContext = avcodec_alloc_context3(codec);
    int code = avcodec_parameters_to_context(codecContext, codecParms);
    if (code < 0) {
        cout<<"fail at [avcodec_parameters_to_context] "<<endl;
        destroy();
        return -1;
    }
    
    code = avcodec_open2(codecContext, codec, NULL);
    if (code < 0) {
        cout<<"fail at [avcodec_open2]"<<endl;
        destroy();
        return -1;
    }
    
    cout<<"解码器名称:"<<codec->name<<endl;
    cout<<"采样格式:"<<codec->sample_fmts<<endl;
    cout<<"通道数:"<<codecContext->channels<<endl;
    cout<<"通道布局:"<<av_get_default_channel_layout(codecContext->channels)<<endl;
    cout<<"采样率:"<<codecContext->sample_rate<<endl;
    
    // 读取音频帧
    packet = av_packet_alloc();
    frame = av_frame_alloc();

    while(true){
        
        // 循环从流中读取数据包
        av_read_frame(fmtCtx, packet);
        
        // 将数据包输入到解码器
        int ret = avcodec_send_packet(codecContext, packet);
        
        // 切记要解除packet对于其内部缓冲区的引用。 因为每次调用read_frame，都会新malloc一块缓冲区。所以数据用完就要及时释放掉！
        // 对于frame的内部缓冲区的解引用同理！
        av_packet_unref(packet);
        if (ret == AVERROR(EINVAL) || ret == AVERROR(ENOMEM)) {
            cout<<"fail to send packet into decoder"<<endl;
            destroy();
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
                destroy();
                return -1;
            }
            // 采样深度
            int numBytes = av_get_bytes_per_sample(out_sample_fmt);
            
            // 目标格式的每帧采样数目
            int nb_samples = 0;
            // 如果格式不符，则进行重采样
            if (needResample(codecContext)) {
                nb_samples = resample(codecContext, frame);
                if (nb_samples < 0) {
                    cout<<"fail to resample"<<endl;
                    destroy();
                    return -1;
                }
            } else {
                nb_samples = frame->nb_samples;
            }
            // AVFrame采用的是LLLLRRRRR的planar格式，左右声道数据分开排列。
            // pcm采用的是packed格式，即LRLRLR形，左右声道数据交叉排列。
            for (int i = 0; i < nb_samples; ++i) {
                for (int channel = 0; channel< OUT_CHANNELS; ++channel) {
                    if(needResample(codecContext)) {
                        fwrite(outdata[channel] + numBytes * i, numBytes, 1, output);
                    } else {
                        fwrite(frame->data[channel] + numBytes * i, numBytes, 1, output);
                    }
                }
            }
            av_frame_unref(frame);
        }
    }
    return 1;
}

int AVDecoder::resample(AVCodecContext *codecContext, AVFrame *frame){
    if (!swrContext) {
        // 设置重采样上下文的参数
        swrContext = swr_alloc_set_opts(NULL, out_ch_layout, out_sample_fmt, out_sample_rate, av_get_default_channel_layout(codecContext->channels), codecContext->sample_fmt, codecContext->sample_rate, 0, 0);
        
        // 初始化重采样上下文
        int code = swr_init(swrContext);
        if (code < 0) {
            destroy();
            cout<<"fail to resample.."<<endl;
            return -1;
        }
    }
    // 计算重新采样后，每个frame的sample数目
    int dst_nb_samples = (int)av_rescale_rnd(frame->nb_samples, out_sample_rate,codecContext->sample_rate, AV_ROUND_UP);
        
    // 为输出缓冲区分配空间
    if (!outdata) {
        outdata = new uint8_t*[OUT_CHANNELS];
        int size = av_samples_get_buffer_size(NULL, OUT_CHANNELS, dst_nb_samples,out_sample_fmt, 0);
        for (int i = 0; i < OUT_CHANNELS; ++i) {
            outdata[i] = (uint8_t *)av_malloc(size);
        }
    }
    
    // 将frame进行格式转换
    int code = swr_convert(swrContext, outdata, dst_nb_samples,(const uint8_t **)frame->data, frame->nb_samples);
    
    av_frame_unref(frame);
    if (code < 0) {
        destroy();
    }
    
    return code;
}

void AVDecoder::destroy(){
    cout<<"AVDecoder destroy"<<endl;
    // 释放数据包和数据帧
    if (frame) {
        av_frame_unref(frame);
        av_frame_free(&frame);
        frame = nullptr;
    }
    if (packet) {
        av_packet_unref(packet);
        av_packet_free(&packet);
        packet = nullptr;
    }
    
    // 释放codecCOntext
    if (codecContext) {
        avcodec_free_context(&codecContext);
        codecContext = nullptr;
    }
    
    // 释放avformatContext
    if (fmtCtx) {
        avformat_close_input(&fmtCtx);
        avformat_free_context(fmtCtx);
        fmtCtx = nullptr;
    }
    
    // 释放swrContext
    if (swrContext) {
        swr_free(&swrContext);
    }
    
    // 关闭文件
    fclose(output);
    
    // 释放缓冲区
    for (int i = 0; i < OUT_CHANNELS; ++i) {
        if (outdata[i]) {
            free(outdata[i]);
            outdata[i] = nullptr;
        }
    }
    delete []outdata;
}


/// 判断是否需要重新采样
/// - Parameter codecContext: 待判断数据的编码格式
bool AVDecoder::needResample(AVCodecContext *codecContext) {
    if (codecContext->sample_fmt == out_sample_fmt && codecContext->sample_rate == out_sample_rate) {
        return false;
    }
    return true;
}
AVDecoder::~AVDecoder(){
    destroy();
}
