## FFmpeg

![image.png](https://s2.loli.net/2022/12/28/5SnkQpg6bafI7sj.png)

ffmpeg是一套可以用来记录、处理数字音频、视频、并将其转换为流的开源框架，提供了录制、转换、以及流化音视频的完整解决方案。

编译后会生成四个可执行文件和八个静态库。

可执行文件：

+ ffmpeg：用于转码、推流、dump媒体文件
+ ffplay：用于播放媒体文件
+ ffprobe：用于获取媒体信息
+ ffserver：简单流媒体服务器

静态库：

+ AVUtil：核心工具库
+ AVFormat：文件格式和协议库
+ AVCodec：编解码库
+ AVFilter：音视频滤镜库
+ AVDevice：输入输出设备
+ SwrRessample：用于音频重采样
+ SWScale：将图像进行格式转换
+ Postproc：用于进行后期处理

## 音画同步的实现方式

ffplay中音画同步有三种实现方式：

+ 以音频为主时间轴
+ 以视频为主时间轴
+ 以外部时钟为主时间轴

默认是以音频为主时间轴，对齐策略如下：

> 播放器接收到的视频帧或音频帧，内部都会有一个PTS时间戳，来标识它实际应该在什么时刻展示。首先会比较视频当前的播放时间和音频的当前播放时间。如果视频播放过快，则通过加大延迟或者重复播放来降低视频播放速度；如果视频播放慢了，则通过减少延迟或者丢帧来追赶音频播放的时间点。关键就在于音视频时间的比较以及延迟的计算，当然在比较的过程中会设置一个阈值，若超过预设的阈值，就应该做调整。

## FFmpeg API的使用

### 一些术语

+ 容器/文件：特定格式的多媒体文件，比如MP4、flv、mov等   ——**对应着AVFormatContext**

+ 媒体流：表示时间轴上的一段连续数据，如一段声音数据、一段视频数据、一段字幕数据，可以是压缩的也可以是非压缩的，压缩的数据要关联特定的编解码器。           ——**对应着AVStream**

+ 数据帧/数据包：一个媒体流是由大量的数据帧组成的。对于压缩数据，帧对应着编解码器的最小处理单元，分属于不同媒体流的数据帧交错存储于容器中。       ——**对应着AVFrame和AVPacket**

+ 编解码器：编解码器是以帧为单位实现压缩数据和原始数据之间的相互转换的。  —— **编解码格式对应着AVCodecContext，编解码器对应着AVCodec**


### 注册协议、格式与编解码器

使用ffmpeg的API，首先要调用FFmpeg的注册协议、格式与编解码器的方法，确保所有的格式与编解码器都被注册到了FFmpeg框架中，当然如果需要用到网络的操作，那么也应该将网络协议部分注册到FFmpeg框架，以便后续再去查找对应的格式。

```
avformat_network_init();
av_regist_all();
```

在新版的ffmpeg中，av_regist_all()方法已经被弃用。

av_regist_all()函数，最初的作用就是将注册的编解码器组织在一个链表中。

但是在新版本中，不再需要将编解码器串成链表，而是直接使用通过configure生成的编解码器数组。 [更详细看这篇文章](https://cloud.tencent.com/developer/article/1910867)

### 打开媒体文件源，并设置超时回调

```
AVFormatContext *formatCtx = avformat_alloc_context(); 
AVIOInterruptCB int_cb = {interrupt_callback, (__bridge void *)(self)}; formatCtx->interrupt_callback = int_cb; 
avformat_open_input(formatCtx, path, NULL, NULL); avformat_find_stream_info(formatCtx, NULL);
```

### 寻找各个流，并且打开对应的解码器

对于视频来说，音频流和视频流是封装在一个容器中的。所以我们需要将音频和视频流分离出来，然后分别使用对应的解码器

```
    AVCodecContext *codeContext = avcodec_alloc_context3(codec);
    int code = avcodec_parameters_to_context(codeContext, codecParms);
    if (code < 0) {
        cout<<"将parm 复制到context失败"<<endl;
        return -1;
    }
    
    code = avcodec_open2(codeContext, codec, NULL);
    if (code < 0) {
        cout<<"初始化context失败"<<endl;
        return -1;
    }
    
    //avcodec_alloc_context3(codec) 根据编解码器的信息，建立一个context上下文，并给一些field赋默认值
    // avcodec_parameters_to_context(codeContext, codecParms); 将编码器的信息复制到context
    // avcodec_open2(codeContext, codec, NULL); 将编码器与context进行一些绑定操作，线程相关的操作。
```



### 初始化解码后数据的结构体

知道了音视频解码器的信息之后，下面需要分配出解码之后的数据所存放的内存空间，以及进行格式转换需要用到的对象。

### 读取流内容并且解码

打开了解码器之后，就可以读取一部分流中的数据（压缩数据），然后将压缩数据作为解码器的输入，解码器将其解码为原始数据（裸数据），之后就可以将原始数据写入文件了。

```
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
```

+ 通过**int** av_read_frame(AVFormatContext *s, AVPacket *pkt);从流中读取数据到packet中

+ 通过**int** avcodec_send_packet(AVCodecContext *avctx, **const** AVPacket *avpkt); 将packet中的数据送入解码器

+ 通过**int** avcodec_receive_frame(AVCodecContext *avctx, AVFrame *frame); 从解码器中读取解码好的frame

  这里我们进行了细致的差错控制。是因为，解码器内部其实存在一个缓冲区，送入的packet到一定数目，才会开始解码；产生的frame到一定数目，通过avcodec_receive_frame才能收取到frame。 [参考这篇文章](https://zhuanlan.zhihu.com/p/345530242)

### 处理解码后的裸数据

解码之后会得到裸数据，音频就是PCM数据，视频就是YUV数据。下面将其处理成我们所需要的格式并且进行写文件。

### 关闭所有资源