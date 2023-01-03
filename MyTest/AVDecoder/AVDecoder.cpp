//
//  AVDecoder.cpp
//  MyTest
//
//  Created by 谢文灏 on 2022/12/25.
//

#include "AVDecoder.hpp"
#include "avformat.h"
using namespace std;



AVDecoder::AVDecoder(const char *src_path) {
    avformat_network_init();
    
    
    // 音频重采样参数
    out_ch_layout = av_get_default_channel_layout(OUT_CHANNELS);
    out_sample_rate = OUT_SAMPLE_RATE;
    out_sample_fmt = OUT_SAMPLE_FMT;
        
    outdata = nullptr;
    
    // 图像格式转换参数
    dst_width = DST_WIDTH;
    dst_height = DST_HEIGHT;
    dst_pix_fmt = DST_PIX_FMT;
    
    this->inputFilePath = src_path;
    
}

int AVDecoder::decode(){
    int ret = 0;
    // 构造avformatContext
    fmtCtx = avformat_alloc_context();
    
    // 打开文件，获取流
    ret = avformat_open_input(&fmtCtx, inputFilePath, NULL, NULL);
    if (ret == 0) {
        cout<<"open file succeed！"<<endl;
    } else {
        cout<<"fail to open file！"<<av_err2str(ret)<<endl;
        destroy();
        return ret;
    }
    
    // 获取流信息
    ret = avformat_find_stream_info(fmtCtx, NULL);
    if (ret >= 0){
        cout<<"successed to get stream info！"<<endl;
    } else {
        cout<<"fail to get stream info！"<<av_err2str(ret)<<endl;
        destroy();
        return ret;
    }
    
    
    // 分解音频流和视频流
    AVStream *audioStream = nullptr;
    AVStream *videoStream = nullptr;
    
    for (int i = 0; i < fmtCtx->nb_streams; ++i) {
        AVCodecParameters *codecParms = fmtCtx->streams[i]->codecpar;
        switch (codecParms->codec_type) {
            case AVMEDIA_TYPE_AUDIO:
                audioStream = fmtCtx->streams[i];
                audioIndex = i;
                break;
            case AVMEDIA_TYPE_VIDEO:
                videoStream = fmtCtx->streams[i];
                videoIndex = i;
                break;
            case AVMEDIA_TYPE_DATA:
                cout<<"AVMEDIA_TYPE_DATA:"<<i<<endl;
                break;
            case AVMEDIA_TYPE_NB:
                cout<<"AVMEDIA_TYPE_NB:"<<i<<endl;
                break;
            case AVMEDIA_TYPE_UNKNOWN:
                cout<<"AVMEDIA_TYPE_UNKNOWN:"<<i<<endl;
                break;
            case AVMEDIA_TYPE_SUBTITLE:
                cout<<"AVMEDIA_TYPE_SUBTITLE:"<<i<<endl;
                break;
            case AVMEDIA_TYPE_ATTACHMENT:
                cout<<"AVMEDIA_TYPE_ATTACHMENT:"<<i<<endl;
                break;
            default:
                break;
        }
    }
    
    if (!audioStream && !videoStream) {
        cout<<"fail to find correspond streams"<<endl;
        destroy();
        return -1;
    }
    
    // 创建解码器上下文
    if (audioStream) {
        ret = createCodecCtx(audioStream);
        if (ret < 0)  {
            destroy();
            return ret;
        }
        cout<<"audioCodecName:"<<audioCodecCtx->codec->name<<endl;
        cout<<"bit-rate:"<<audioCodecCtx->bit_rate<<endl;
        cout<<"sample_rate:"<<audioCodecCtx->sample_rate<<endl;
        cout<<"sample_fmt:"<< av_get_sample_fmt_name(audioCodecCtx->sample_fmt)<<endl;
        cout<<"channels:"<<audioCodecCtx->channels<<endl;
    }
    if (videoStream) {
        ret = createCodecCtx(videoStream);
        if (ret < 0) {
            destroy();
            return ret;
        }
        width = videoCodecCtx->width;
        height = videoCodecCtx->height;
        pix_fmt = videoCodecCtx->pix_fmt;
        ret = av_image_alloc(video_dst_data, video_dst_linesize, width, height, pix_fmt, 1);
        if(ret < 0) {
            cout<<"could not allocate raw video buffer"<<endl;
            destroy();
            return ret;
        }
        video_dst_bufsize = ret;
        
        cout<<"videoCodecName:"<<videoCodecCtx->codec->name<<endl;
        cout<<"width:"<<width<<endl;
        cout<<"height:"<<height<<endl;
        cout<<"pixel_fmt:"<<av_get_pix_fmt_name(pix_fmt)<<endl;
    }
    
    // 创建packet和frame
    if (!packet) {
        packet = av_packet_alloc();
    }
    if (!frame) {
        frame = av_frame_alloc();
    }

    // 循环从流中读取数据包
    while(av_read_frame(fmtCtx, packet) >= 0){
        
        if (packet->stream_index == audioIndex) {
            ret = decodePacket(audioCodecCtx, packet);
        } else if (packet->stream_index == videoIndex) {
            ret = decodePacket(videoCodecCtx, packet);
        }
        // 数据包用完要及时减少引用计数
        av_packet_unref(packet);
        if (ret < 0) break;
    }
    
    // 冲刷解码器的缓冲区
    if (videoCodecCtx) {
        decodePacket(videoCodecCtx, NULL);

    }
    if(audioCodecCtx) {
        decodePacket(audioCodecCtx, NULL);
        
    }
    return ret;
}
int AVDecoder::decodePacket(AVCodecContext *codecContext, AVPacket *packet) {
    int ret = 0;
    
    // 将数据输入到解码器
    ret = avcodec_send_packet(codecContext, packet);

    if (ret < 0) {
        cout<<"Error submitting a packet for decoding: "<<av_err2str(ret)<<endl;
        return ret;
    }
    
    // 从解码器中循环获取帧
    while (ret >= 0) {
        ret = avcodec_receive_frame(codecContext, frame);
        if (ret < 0) {
            if (ret == AVERROR_EOF || ret == AVERROR(EAGAIN)) {
                return 0;
            }
            cout<<"Error during decoing: "<<av_err2str(ret)<<endl;
            return ret;
        }
        
        // 将获取到的帧按照类型分别输出处理
        if (codecContext->codec_type == AVMEDIA_TYPE_VIDEO) {
            ret = out_video_frame(frame);
        } else {
            ret = out_audio_frame(frame);
        }
        
        // frame用完要及时减少引用计数
        av_frame_unref(frame);
        if (ret < 0) return ret;
    }
    return 0;
}

int AVDecoder::out_audio_frame(AVFrame *frame){
    // 采样深度
    int numBytes = av_get_bytes_per_sample(out_sample_fmt);
    
    // 目标格式的每帧采样数目
    int nb_samples = 0;
    // 如果格式不符，则进行重采样
    if (needResample(audioCodecCtx)) {
        nb_samples = resample(audioCodecCtx, frame);
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
    DecodedFrame decodedFrame;
    decodedFrame.data = new uint8_t[nb_samples * OUT_CHANNELS * numBytes];
    decodedFrame.frameCnt = nb_samples;
    
    for (int i = 0; i < nb_samples; ++i) {
        for (int channel = 0; channel < OUT_CHANNELS; ++channel) {
            if(needResample(audioCodecCtx)) {
                memcpy(decodedFrame.data + i * numBytes * OUT_CHANNELS + channel * numBytes, outdata[channel] + numBytes * i, numBytes);
            } else {
                memcpy(decodedFrame.data + i * numBytes * OUT_CHANNELS + channel * numBytes, frame->data[channel] + numBytes * i, numBytes);
            }
        }
    }
    
    this->audioQueue.push(decodedFrame);
    return 0;
}

int AVDecoder::out_video_frame(AVFrame *frame){
    
    // video_dst_data 经过av_image_copy 之后，将可能存在的填充数据都去除掉了，video_dst_data[0] 存储y分量， video_dst_data[1]存储u分量，video_dst_data[2]存储v分量。
    av_image_copy(video_dst_data, video_dst_linesize, (const uint8_t **)(frame->data), frame->linesize, pix_fmt, width, height);
    
    // 判断图像格式是否需要转换
    if (needScale(videoCodecCtx)) {
        int ret = rescale(video_dst_data);
        if (ret < 0) {
            cout<<"fail to scale"<<endl;
            return ret;
        }
//        fwrite(scaled_data[0], 1, scaled_buffer_size, videoOutput);
    } else {
        
        //下面直接read了整个frame大小的数据，是因为，yuv分量的三个数组是连续存储的，从video_dst_data[0]的起始地址开始，读video_dst_bufsize，实际就把整个帧都读完了，就不需要再分别的读data[0],data[1],data[2].
//        fwrite(video_dst_data[0], 1, video_dst_bufsize, videoOutput);
    }
    return 0;
}

int AVDecoder::assembleRenderData(uint8_t *buffer, int numFrames) {
    // 采样深度
    int numBytes = av_get_bytes_per_sample(out_sample_fmt);
    
    if (this->audioQueue.empty()) {
        buffer = 0;
        return 0;
    }
    
    // 已读的样本帧数目（样本帧，一个样本就是一帧）
    int readFrames = 0;
    while(numFrames > 0) {
        
        if(this->audioQueue.empty()) {
            break;
        }
        DecodedFrame &decodedFrame = this->audioQueue.front();
        
        // decodedFrame剩余的未被读取过的帧数目
        int frameLeftCnt = decodedFrame.frameCnt - decodedFrame.readCnt;
        
        // 如果整个decodedFrame都被读取
        if(frameLeftCnt < numFrames) {
            memcpy(buffer + readFrames * OUT_CHANNELS * numBytes, decodedFrame.data + decodedFrame.readCnt * OUT_CHANNELS * numBytes, frameLeftCnt * OUT_CHANNELS * numBytes);
            
            // 更新需要的数据量
            numFrames  = numFrames - frameLeftCnt;
            
            // 更新已读的数据量
            readFrames = readFrames + frameLeftCnt;
            
            // 更新这个decodedFrame的已读数据量
            decodedFrame.readCnt = decodedFrame.frameCnt;
            
            
        } else {  // 如果只读取一部分
            memcpy(buffer + readFrames * OUT_CHANNELS * numBytes, decodedFrame.data + decodedFrame.readCnt * OUT_CHANNELS * numBytes , numFrames * OUT_CHANNELS * numBytes);
            
            readFrames =  readFrames + numFrames;
            
            decodedFrame.readCnt = decodedFrame.readCnt + numFrames;
            
            numFrames = 0;
        }
        
        // 因为整个decodedFrame都已经被读过，所以将decodedFrame.data释放（分配在堆上，要手动释放);同时出队列
        if (decodedFrame.frameCnt == decodedFrame.readCnt) {
            this->audioQueue.pop();
            delete []decodedFrame.data;
        }
    }
    
    // 返回总共读取的字节数
    return readFrames * numBytes * OUT_CHANNELS;
}

int AVDecoder::createCodecCtx(AVStream *stream){
    // 获取音频流的解码器信息
    AVCodecParameters *codecParms = stream->codecpar;
    
    // 根据解码器信息创建对应的解码器
    AVCodec *codec = avcodec_find_decoder(codecParms->codec_id);
    if (!codec) {
        cout<<"fail to find audio decoder！"<<endl;
        return -1;
    }
    
    // 构建解码器上下文
    
    AVCodecContext *codecContext = nullptr;
    // 如果是视频流
    if (codecParms->codec_type == AVMEDIA_TYPE_VIDEO) {
        videoCodecCtx = avcodec_alloc_context3(codec);
        codecContext = videoCodecCtx;
    } else {
        // 如果是音频流
        audioCodecCtx = avcodec_alloc_context3(codec);
        codecContext = audioCodecCtx;
    }
    
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
  
    return 0;
 
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
    
//    av_frame_unref(frame);
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
    
    // 释放codecContext
    if (audioCodecCtx) {
        avcodec_free_context(&audioCodecCtx);
        audioCodecCtx = nullptr;
    }
    
    if (videoCodecCtx) {
        avcodec_free_context(&videoCodecCtx);
        videoCodecCtx = nullptr;
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
    
    // 释放swsContext
    if (swsContext) {
        sws_freeContext(swsContext);
    }
    
    // 释放缓冲区
    if (outdata) {
        for (int i = 0; i < OUT_CHANNELS; ++i) {
            if (outdata[i]) {
                free(outdata[i]);
                outdata[i] = nullptr;
            }
        }
        delete []outdata;
    }
    
    if (video_dst_data[0]) {
        av_free(video_dst_data[0]);
    }
    
    if (scaled_data[0]){
        av_free(scaled_data[0]);
    }
}

bool AVDecoder::needResample(AVCodecContext *codecContext) {
    if (codecContext->sample_fmt == out_sample_fmt && codecContext->sample_rate == out_sample_rate) {
        return false;
    }
    return true;
}

AVDecoder::~AVDecoder(){
    destroy();
}

bool AVDecoder::needScale(AVCodecContext *codecContext) {
    if (width == dst_width && height == dst_height && pix_fmt == dst_pix_fmt) {
        return false;
    }
    return true ;
}

int AVDecoder::rescale(uint8_t *buffer[]) {
    int ret = 0;
    if(!swsContext) {
        swsContext = sws_getContext(width, height, pix_fmt,
                                    dst_width, dst_height, dst_pix_fmt,
                                    SWS_BILINEAR, NULL, NULL, NULL);
        if (!swsContext) {
            cout<<"impossible to create scale context for the conversion"<<endl;
            ret = AVERROR(EINVAL);
            destroy();
            return ret;
        }
        
    }
    
    // 为scaled_data 分配空间
    if (!scaled_data[0]) {
        ret = av_image_alloc(scaled_data, scaled_linesize, dst_width, dst_height, dst_pix_fmt, 1);
        if(ret < 0) {
            cout<<"could not allocate raw video buffer"<<endl;
            destroy();
            return ret;
        }
        scaled_buffer_size = ret;
    }
    
    // 将输入的buffer数据，格式转换，存储到scaled_data中
    ret = sws_scale(swsContext, buffer, video_dst_linesize, 0, height, scaled_data, scaled_linesize);
    return 0;
}
