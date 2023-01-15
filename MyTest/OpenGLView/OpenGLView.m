//
//  OpenGLView.m
//  MyTest
//
//  Created by 谢文灏 on 2023/1/11.
//

#import "OpenGLView.h"
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>

#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)

enum AttribEnum
{
    ATTRIB_VERTEX,
    ATTRIB_TEXTURE,
    ATTRIB_COLOR,
};

enum TextureType{
    TEXY = 0,
    TEXU,
    TEXV,
};

NSString *const vertexShaderString = SHADER_STRING(
     // 顶点坐标
     attribute vec4 vPosition;
     // 输入的纹理坐标
     attribute vec2 TexCoordIn;
     // 输出到fragmentShader的纹理坐标
     varying   vec2 TexCoordOut;
                                                   
     void main(void)
     {
        gl_Position = vPosition;
        TexCoordOut = TexCoordIn;
     }
);

NSString *const fragmentShaderString = SHADER_STRING(
                                                     
     // 纹理坐标
     varying lowp vec2 TexCoordOut;
     // 纹理采样器
     uniform sampler2D SamplerY;
     uniform sampler2D SamplerU;
     uniform sampler2D SamplerV;

     void main()
     {
        mediump vec3 yuv;
        lowp vec3 rgb;
        yuv.x = texture2D(SamplerY,TexCoordOut).r;
        yuv.y = texture2D(SamplerU,TexCoordOut).r - 0.5;
        yuv.z = texture2D(SamplerV,TexCoordOut).r - 0.5;
        
        rgb = mat3(
        1,             1,      1,
        0,      -0.39465,2.03211,
        1.13983,-0.58060,      0
                   ) * yuv;
        gl_FragColor = vec4(rgb,1);
     }
);

@interface OpenGLView()

@property(nonatomic, strong)CAEAGLLayer *eaglLayer;
@property(nonatomic, strong)EAGLContext *eaglContenxt;
@property(nonatomic, assign)GLuint       colorRenderBuffer;
@property(nonatomic, assign)GLuint       colorFrameBuffer;
@property(nonatomic, assign)GLuint       programe;
@property(nonatomic, assign)GLuint       positionSlot;
@property(nonatomic, assign)GLuint       texCoordInSlot;
@property(nonatomic, assign)int          width;
@property(nonatomic, assign)int          height;

/// 创建用于openGL绘制的图层
-(void)setupLayer;

/// 创建openGL上下文
-(void)setupContext;

/// 清空缓存区
-(void)deleteRenderAndFrameBuffer;

/// 设置渲染缓冲区
-(void)setupRenderBuffer;

/// 设置帧缓冲区
-(void)setupFrameBuffer;

///  绘制
-(void)renderLayer;

/// 编译shader
-(GLuint)compileShader:(NSString *)shaderString ShaderType:(GLenum)shaderType;

/// 创建program
-(void)setupProgram;

/// 创建纹理
-(void)setupYUVTexture;

@end

@implementation OpenGLView
{
    /// YUV纹理数组
    GLuint _textureYUV[3];
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        // 1. 创建图层
        [self setupLayer];
        
        // 2. 创建上下文
        [self setupContext];
        
        // 3. 创建YUV纹理对象
        [self setupYUVTexture];
        
        // 4. 创建、编译、链接程序
        [self setupProgram];
    }
    return self;
}
- (void)layoutSubviews {
    
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        @synchronized (self) {
            // 1. 设置上下文
            [EAGLContext setCurrentContext:self->_eaglContenxt];
            
            // 2. 清空缓存区
            [self deleteRenderAndFrameBuffer];
            
            // 3. 设置renderBuffer
            [self setupRenderBuffer];
            
            // 4. 设置frameBuffer
            [self setupFrameBuffer];
        }
        CGFloat scale = [UIScreen mainScreen].scale;
        glViewport(0, 0, self.bounds.size.width * scale, self.bounds.size.height * scale);
    });
}

+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (void)setupLayer {
    // 1. 将自带的layer转换为CAEAGLLayer
    self.eaglLayer = (CAEAGLLayer *)self.layer;
    
    self.eaglLayer.opaque = YES;
    
    // 2. 设置scale
    [self setContentScaleFactor:[[UIScreen mainScreen] scale]];
    
    // 3. 设置描述属性
    self.eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                @false,kEAGLDrawablePropertyRetainedBacking,
                                kEAGLColorFormatRGBA8,kEAGLDrawablePropertyColorFormat, nil];
}

- (void)setupContext {
    // 1. 指定所用的openGL es的版本
    EAGLRenderingAPI api = kEAGLRenderingAPIOpenGLES2;
    
    // 2. 创建图形上下文
    EAGLContext *context =  [[EAGLContext alloc]initWithAPI:api];
    
    // 3. 判断是否创建成功
    if (!context) {
        NSLog(@"fail to generate EAGLContext!");
        return;
    }
    
    // 4. 将刚创建的图形上下文，设置为openGL的当前上下文
    BOOL ret = [EAGLContext setCurrentContext:context];
    
    if (!ret) {
        NSLog(@"fail to setCurrentContext!");
        return;
    }
    
    // 5. 将图形上下文赋值给全局的context属性
    self.eaglContenxt = context;
}

- (void)deleteRenderAndFrameBuffer {
    // 清空渲染缓存区
    if (_colorRenderBuffer) {
        glDeleteBuffers(1, &_colorRenderBuffer);
    }
    self.colorRenderBuffer = 0;
    
    // 清空帧缓存区
    if (_colorFrameBuffer) {
        glDeleteBuffers(1, &_colorFrameBuffer);
    }
    self.colorFrameBuffer = 0;
}

- (void)setupRenderBuffer {
    //1. 定义1个缓存区ID
    GLuint buffer;
    
    //2. 申请一个缓存区标识符
    glGenRenderbuffers(1, &buffer);
    
    //3. 将标识符赋值给全局变量
    self.colorRenderBuffer = buffer;
    
    //4. 将标识符绑定到GL_RENDERBUFFER
    glBindRenderbuffer(GL_RENDERBUFFER, self.colorRenderBuffer);
    
    //5. 将layer的存储绑定到renderBuffer对象
    [self.eaglContenxt renderbufferStorage:GL_RENDERBUFFER fromDrawable:self.eaglLayer];
}

- (void)setupFrameBuffer {
    // 1. 申请缓冲区标识符
    glGenBuffers(1, &_colorFrameBuffer);
    
    // 2. 将标识符绑定到gl_framebuffer
    glBindFramebuffer(GL_FRAMEBUFFER, _colorFrameBuffer);
    
    // 3. 将renderBuffer和frameBuffer进行绑定
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, self.colorRenderBuffer);
}

- (void)renderLayer {
//     1. 设置清屏颜色
    glClearColor(0.3f, 0.45f, 0.5f, 1.0f);

//     2. 指定所要清屏的buffer。这里指定的是color_buffer
    glClear(GL_COLOR_BUFFER_BIT);
    
    // 3. 设置窗口的大小
    CGFloat scale = [UIScreen mainScreen].scale;
    glViewport(0, 0, self.bounds.size.width * scale, self.bounds.size.height * scale);
    
    // 4. 矩形窗口的顶点坐标
    GLfloat vertices[] = {
        -1.0f, -1.0f,
         1.0f, -1.0f,
        -1.0f,  1.0f,
         1.0f,  1.0f,
    };
    
    // 5. 顶点的纹理坐标
    GLfloat coordVertices[] = {
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 0.0f,
    };
    
    // 指定顶点数据和纹理坐标
    glVertexAttribPointer(_positionSlot, 2, GL_FLOAT, GL_FALSE, 0, vertices);
    
    // 启用_positionSlot对应的attribute，在shader中才能读取到vertices的数据
    glEnableVertexAttribArray(_positionSlot);
    
    glVertexAttribPointer(_texCoordInSlot, 2, GL_FLOAT, GL_FALSE, 0, coordVertices);
    glEnableVertexAttribArray(_texCoordInSlot);
    
    // 绘制矩形窗口
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    
    [self.eaglContenxt presentRenderbuffer:GL_RENDERBUFFER];
}

- (GLuint)compileShader:(NSString *)shaderString ShaderType:(GLenum)shaderType {
    // 1. 创建shader对象
    GLuint shaderHandle = glCreateShader(shaderType);
    
    // 2. 获取shader的c字符串和长度
    const char *shaderStringUTF8 = [shaderString UTF8String];
    GLint len = (GLint)[shaderString length];
    
    // 3. 将shader内容传递给opengl
    glShaderSource(shaderHandle, 1, &shaderStringUTF8, &len);
    
    // 4. 编译shader
    glCompileShader(shaderHandle);
    
    // 5. 判断是否编译成功
    GLint compileSuccess;
    glGetShaderiv(shaderHandle, GL_COMPILE_STATUS, &compileSuccess);
    if (compileSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetShaderInfoLog(shaderHandle, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"%@", messageString);
        exit(1);
    }
    
    return shaderHandle;
    
}
- (void)setupProgram{
    // 1.创建并编译shader
    GLuint vertexShader   = [self compileShader:vertexShaderString ShaderType:GL_VERTEX_SHADER];
    GLuint fragmentShader = [self compileShader:fragmentShaderString ShaderType:GL_FRAGMENT_SHADER];
    
    // 2. 创建程序对象
    _programe = glCreateProgram();
    
    // 3. 将shader绑定到程序对象
    glAttachShader(_programe, vertexShader);
    glAttachShader(_programe, fragmentShader);
    
    // 4. 链接两个shader
    glLinkProgram(_programe);
    
    // 判断是否链接成功
    GLint linkSuccess;
    glGetProgramiv(_programe, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(_programe, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"<<<<着色器连接失败 %@>>>", messageString);
        //exit(1);
    }
    
    // 5. 将创建的program设置为当前opengl 使用的program
    glUseProgram(_programe);
    
    // 6. 获取对shader中，传入变量的引用.这里就是将shader中的vPosition和_positionSlot联系起来。
    //    通过设置postionSlot的值，作为vPosition的输入
    _positionSlot = glGetAttribLocation(_programe, "vPosition");
//
//    //
    _texCoordInSlot = glGetAttribLocation(_programe, "TexCoordIn");
    
    // 7. 由于shader已经链接到程序当中，所以这里将shader删除，释放内存
    if (vertexShader) {
        glDeleteShader(vertexShader);
    }
    if (fragmentShader) {
        glDeleteShader(fragmentShader);
    }
    
    // 8. 获取shader中的sampler的索引，将它们和0，1，2分别绑定在一起
    GLuint textureUniformY = glGetUniformLocation(_programe, "SamplerY");
    GLuint textureUniformU = glGetUniformLocation(_programe, "SamplerU");
    GLuint textureUniformV = glGetUniformLocation(_programe, "SamplerV");
    
    // 给textureUniformY赋值0，也就是将textureUniformY和0绑定在一起
    glUniform1i(textureUniformY, TEXY);
    glUniform1i(textureUniformU, TEXU);
    glUniform1i(textureUniformV, TEXV);
    
}

- (void)setupYUVTexture {
    // 如果已经存在纹理对象，就删除
    if (_textureYUV[TEXY]) {
        glDeleteTextures(3, _textureYUV);
    }
    
    // 创建纹理对象
    glGenTextures(3, _textureYUV);
    if(!_textureYUV[TEXY] || !_textureYUV[TEXU] || !_textureYUV[TEXV]) {
        NSLog(@"纹理创建失败");
        return;
    }
    
    // 激活3个纹理对象
    for(int i = 0 ; i < 3; ++i) {
        // 激活纹理单元。则后续的纹理操作都是在这个纹理单元上进行
        glActiveTexture(GL_TEXTURE0 + i);
        
        // 将_textureYUV[i]对应的纹理对象，作为2D纹理的纹理目标。也就是对_textureYUV[i]的操作，都是对GL_TEXTURE_2D这个纹理目标展开的。ps：一个纹理单元，有多个纹理目标，如GL_TEXTURE_2D、GL_TEXTURE_3D
        glBindTexture(GL_TEXTURE_2D, _textureYUV[i]);
        // 设置纹理对象的属性。该函数确定如何把纹理象素映射成像素.
//        glTexParameteri(GLenum target, GLenum pname, GLint param)
        // 放大过滤时，使用GL_LINEAR线性过滤方式
        glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_LINEAR);
        // 缩小过滤时，使用GL_LINEAR线性过滤方式
        glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_LINEAR);
        // S方向上的贴图方式，将纹理坐标限制在0.0,1.0的范围之内.如果超出了会如何呢.不会错误,只是会边缘拉伸填充.
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        // T方向上的贴图方式，同上
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    }
}

- (void)displayYUV420pData:(void *)data width:(int)w height:(int)h {
    
    @synchronized (self) {
        
        // 设置视频的宽高
        if (w != self.width || h != self.height) {
            [self setVideoSize:w height:h];
        }
        
        // 设置上下文
        [EAGLContext setCurrentContext:_eaglContenxt];
        
        // 绑定纹理对象到纹理目标，表明接下来的操作都是对这个纹理对象展开的，直到出现下一次bind
        glBindTexture(GL_TEXTURE_2D, _textureYUV[TEXY]);
        
        /**
                 glTexSubImage2D 是在原有纹理的基础上进行修改，而glTexImage2D是创建一个纹理。
                 修改一个纹理的开销要远远小于创建纹理的，所以一开始就通过setVideoSize方法，创建一个纹理，后续渲染的时候，都通过glTexSubImage2D来修改纹理图像。
         
         */
        // 给这个纹理对象输入纹理数据Y
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, w, h, GL_RED_EXT, GL_UNSIGNED_BYTE, data);
        
        // 给纹理对象输入纹理数据U
        
        glBindTexture(GL_TEXTURE_2D, _textureYUV[TEXU]);
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, w / 2, h / 2, GL_RED_EXT, GL_UNSIGNED_BYTE, data + w * h);
        
        // 给纹理对象输入纹理数据V
        glBindTexture(GL_TEXTURE_2D, _textureYUV[TEXV]);
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, w / 2, h / 2, GL_RED_EXT, GL_UNSIGNED_BYTE, data + w * h * 5 / 4);
        
        [self renderLayer];
    }
    
#ifdef DEBUG
    GLenum err = glGetError();
    if (err != GL_NO_ERROR) {
        NSLog(@"GL_ERROR:%d",err);
    }
#endif
}

- (void)setVideoSize:(int)width height:(int)height {
    self.width  = width;
    self.height = height;
    
    void *tempData = malloc(width * height * 1.5);
    if (tempData) {
        memset(tempData, 0x0, width * height * 1.5);
    }
    
    [EAGLContext setCurrentContext:_eaglContenxt];
    
    glBindTexture(GL_TEXTURE_2D, _textureYUV[TEXY]);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RED_EXT, width, height, 0, GL_RED_EXT, GL_UNSIGNED_BYTE, tempData);
    
    glBindTexture(GL_TEXTURE_2D, _textureYUV[TEXU]);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RED_EXT, width / 2, height / 2, 0, GL_RED_EXT, GL_UNSIGNED_BYTE, tempData + width * height);
    
    glBindTexture(GL_TEXTURE_2D, _textureYUV[TEXV]);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RED_EXT, width / 2, height / 2, 0, GL_RED_EXT, GL_UNSIGNED_BYTE, tempData + width * height * 5 / 4);
    free(tempData);
}

@end
