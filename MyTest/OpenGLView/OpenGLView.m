//
//  OpenGLView.m
//  MyTest
//
//  Created by 谢文灏 on 2023/1/11.
//

#import "OpenGLView.h"

#define STRINGIZE(x) #x
#define STRINGIZE2(x) STRINGIZE(x)
#define SHADER_STRING(text) @ STRINGIZE2(text)
enum AttribEnum
{
    ATTRIB_VERTEX,
    ATTRIB_TEXTURE,
    ATTRIB_COLOR,
};

enum TextureType
{
    TEXY = 0,
    TEXU,
    TEXV,
    TEXC
};


static NSString *const vertexShaderString = SHADER_STRING(
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

static NSString *const fragmentShaderString = SHADER_STRING(

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
{
    // OpenGL绘图上下文
    EAGLContext             *_glContext;
    
    // 帧缓冲区
    GLuint                  _framebuffer;
    
    // 渲染缓冲区
    GLuint                  _renderBuffer;
    
    // OpenGL程序
    GLuint                  _program;
    
    // YUV纹理数组
    GLuint                  _textureYUV[3];
    
    // 视频宽度
    GLuint                  _videoW;
    
    // 视频高度
    GLuint                  _videoH;
    
    // 视图的伸缩比
    GLsizei                 _viewScale;
      
}

/// 初始化YUV纹理
- (void)setupYUVTexture;


/// 创建缓冲区
- (BOOL)createFrameAndRenderBuffer;


/// 销毁缓冲区
- (void)destoryFrameAndRenderBuffer;


/// 加载着色器
- (void)loadShader;


/// 编译shader
/// - Parameters:
///   - shaderCode: shader 的代码
///   - shaderType: shader 的类型
- (GLuint)compileShader:(NSString*)shaderCode withType:(GLenum)shaderType;

/// 渲染
- (void)render;
@end

@implementation OpenGLView

- (BOOL)doInit
{
    // 1. 将自带的layer转换为CAEAGLLayer
    CAEAGLLayer *eaglLayer = (CAEAGLLayer*) self.layer;
    
    eaglLayer.opaque = YES;
    
    // 2. 设置描述属性
    eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                    @false, kEAGLDrawablePropertyRetainedBacking,
                                    kEAGLColorFormatRGB565, kEAGLDrawablePropertyColorFormat,
                                    //[NSNumber numberWithBool:YES], kEAGLDrawablePropertyRetainedBacking,
                                    nil];
    // 3. 设置scale
    self.contentScaleFactor = [UIScreen mainScreen].scale;
    _viewScale = [UIScreen mainScreen].scale;
    
    // 4. 创建图形上下文
    _glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    // 5. 判断是否创建成功,并将刚创建的图形上下文，设置为openGL的当前上下文
    if(!_glContext || ![EAGLContext setCurrentContext:_glContext])
    {
        return NO;
    }
    
    // 6. 初始化YUV纹理对象
    [self setupYUVTexture];
    [self loadShader];
    
    // 7. 将创建的program设置为当前opengl 使用的program
    glUseProgram(_program);
    
    // 8. 获取shader中的sampler的索引，将它们和0，1，2分别绑定在一起
    GLuint textureUniformY = glGetUniformLocation(_program, "SamplerY");
    GLuint textureUniformU = glGetUniformLocation(_program, "SamplerU");
    GLuint textureUniformV = glGetUniformLocation(_program, "SamplerV");
    
    // 给textureUniformY赋值0，也就是将textureUniformY和0绑定在一起
    glUniform1i(textureUniformY, 0);
    glUniform1i(textureUniformU, 1);
    glUniform1i(textureUniformV, 2);
    
    return YES;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self)
    {
        if (![self doInit])
        {
            self = nil;
        }
    }
    return self;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        if (![self doInit])
        {
            self = nil;
        }
    }
    return self;
}

- (void)layoutSubviews
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        @synchronized(self)
        {
            // 1. 设置上下文
            [EAGLContext setCurrentContext:self->_glContext];
            
            // 2. 清空缓存区
            [self destoryFrameAndRenderBuffer];
            
            // 3. 设置renderBuffer和frameBuffer
            [self createFrameAndRenderBuffer];
        }
        
        glViewport(0, 0, self.bounds.size.width * _viewScale, self.bounds.size.height * self->_viewScale);
    });
}

- (void)setupYUVTexture
{
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

- (void)render
{
    // 1. 设置上下文
    [EAGLContext setCurrentContext:_glContext];
    CGSize size = self.bounds.size;
    
    // 2. 设置绘制窗口大小和位置
    glViewport(0, 0, size.width * _viewScale, size.height * _viewScale);
    
    // 3. 矩形窗口的顶点坐标
    static const GLfloat squareVertices[] = {
        -1.0f, -1.0f,
        1.0f, -1.0f,
        -1.0f,  1.0f,
        1.0f,  1.0f,
    };

    // 4. 顶点的纹理坐标
    static const GLfloat coordVertices[] = {
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f,  0.0f,
        1.0f,  0.0f,
    };
    
    
    // 5.指定顶点数据和纹理坐标
    glVertexAttribPointer(ATTRIB_VERTEX, 2, GL_FLOAT, 0, 0, squareVertices);
    
    // 启用ATTRIB_VERTEX对应的attribute，在shader中才能读取到vertices的数据
    glEnableVertexAttribArray(ATTRIB_VERTEX);
    
    
    glVertexAttribPointer(ATTRIB_TEXTURE, 2, GL_FLOAT, 0, 0, coordVertices);
    glEnableVertexAttribArray(ATTRIB_TEXTURE);
    
    
    // 绘制矩形窗口
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    [_glContext presentRenderbuffer:GL_RENDERBUFFER];
}

#pragma mark - 设置openGL
+ (Class)layerClass
{
    return [CAEAGLLayer class];
}

- (BOOL)createFrameAndRenderBuffer
{
    // 1. 申请一个缓存区标识符，并赋值给_framebuffer和_renderBuffer
    glGenFramebuffers(1, &_framebuffer);
    glGenRenderbuffers(1, &_renderBuffer);
    
    // 2. 将标识符绑定到GL_FRAMEBUFFER和GL_RENDERBUFFER
    glBindFramebuffer(GL_FRAMEBUFFER, _framebuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
    
    // 3. 将layer的存储绑定到renderBuffer对象
    if (![_glContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:(CAEAGLLayer *)self.layer])
    {
        NSLog(@"attach渲染缓冲区失败");
    }
    
    // 4. 将renderBuffer和frameBuffer进行绑定
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderBuffer);
    if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
    {
        NSLog(@"创建缓冲区错误 0x%x", glCheckFramebufferStatus(GL_FRAMEBUFFER));
        return NO;
    }
    return YES;
}

- (void)destoryFrameAndRenderBuffer
{
    // 清空帧缓存区
    if (_framebuffer)
    {
        glDeleteFramebuffers(1, &_framebuffer);
    }
    // 清空渲染缓存区
    if (_renderBuffer)
    {
        glDeleteRenderbuffers(1, &_renderBuffer);
    }
    
    _framebuffer = 0;
    _renderBuffer = 0;
}

/**
 加载着色器
 */
- (void)loadShader
{
    // 1.创建并编译shader
    GLuint vertexShader = [self compileShader:vertexShaderString withType:GL_VERTEX_SHADER];
    GLuint fragmentShader = [self compileShader:fragmentShaderString withType:GL_FRAGMENT_SHADER];
    
    // 2. 创建程序对象
    _program = glCreateProgram();
    
    // 3. 将shader绑定到程序对象
    glAttachShader(_program, vertexShader);
    glAttachShader(_program, fragmentShader);
    
    // 4. 将shader中的变量，和一个常数索引绑定，这里就是将shader中的position，和ATTRIB_VERTEX = 0 绑定起来。通过设置ATTRIB_VERTEX的值，作为position的输入
    glBindAttribLocation(_program, ATTRIB_VERTEX, "position");
    glBindAttribLocation(_program, ATTRIB_TEXTURE, "TexCoordIn");
    
    // 5. 链接两个shader
    glLinkProgram(_program);
    
    // 6. 判断是否链接成功
    GLint linkSuccess;
    glGetProgramiv(_program, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(_program, sizeof(messages), 0, &messages[0]);
        NSString *messageString = [NSString stringWithUTF8String:messages];
        NSLog(@"<<<<着色器连接失败 %@>>>", messageString);
    }
    
    // 7. 由于shader已经链接到程序当中，所以这里将shader删除，释放内存
    if (vertexShader)
        glDeleteShader(vertexShader);
    if (fragmentShader)
        glDeleteShader(fragmentShader);
}

- (GLuint)compileShader:(NSString*)shaderString withType:(GLenum)shaderType
{
    
    NSError *error = nil;
    if (!shaderString) {
        NSLog(@"Error loading shader: %@", error.localizedDescription);
        exit(1);
    }
    
    // 1. 创建shader对象
    GLuint shaderHandle = glCreateShader(shaderType);
    
    // 2. 获取shader的c字符串和长度
    const char * shaderStringUTF8 = [shaderString UTF8String];
    int shaderStringLength = (int)[shaderString length];
    
    // 3. 将shader内容传递给opengl
    glShaderSource(shaderHandle, 1, &shaderStringUTF8, &shaderStringLength);
    
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

#pragma mark - 接口
- (void)displayYUV420pData:(void *)data width:(int)w height:(int)h
{
    @synchronized(self)
    {
        // 设置视频的宽高
        if (w != _videoW || h != _videoH)
        {
            [self setVideoSize:w height:h];
        }
        
        // 设置上下文
        [EAGLContext setCurrentContext:_glContext];
        
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
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, w/2, h/2, GL_RED_EXT, GL_UNSIGNED_BYTE, data + w * h);
        
        // 给纹理对象输入纹理数据V
        glBindTexture(GL_TEXTURE_2D, _textureYUV[TEXV]);
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, w/2, h/2, GL_RED_EXT, GL_UNSIGNED_BYTE, data + w * h * 5 / 4);
        
        [self render];
    }
#ifdef DEBUG
    GLenum err = glGetError();
    if (err != GL_NO_ERROR) {
        NSLog(@"GL_ERROR:%d",err);
    }
#endif
}

- (void)setVideoSize:(GLuint)width height:(GLuint)height
{
    _videoW = width;
    _videoH = height;
    
    void *blackData = malloc(width * height * 1.5);
    if(blackData){
        memset(blackData, 0x0, width * height * 1.5);
    }
    
    [EAGLContext setCurrentContext:_glContext];
    glBindTexture(GL_TEXTURE_2D, _textureYUV[TEXY]);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RED_EXT, width, height, 0, GL_RED_EXT, GL_UNSIGNED_BYTE, blackData);
    
    glBindTexture(GL_TEXTURE_2D, _textureYUV[TEXU]);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RED_EXT, width / 2, height / 2, 0, GL_RED_EXT, GL_UNSIGNED_BYTE, blackData + width * height);
    
    glBindTexture(GL_TEXTURE_2D, _textureYUV[TEXV]);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RED_EXT, width / 2, height / 2, 0, GL_RED_EXT, GL_UNSIGNED_BYTE, blackData + width * height * 5 / 4);
    free(blackData);
}

@end
