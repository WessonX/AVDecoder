//
//  OpenGLView.m
//  MyTest
//
//  Created by 谢文灏 on 2023/1/11.
//

#import "OpenGLView.h"
#import <OpenGLES/ES2/gl.h>


@interface OpenGLView()

@property(nonatomic, strong)CAEAGLLayer *eaglLayer;
@property(nonatomic, strong)EAGLContext *eaglContenxt;
@property(nonatomic, assign)GLuint       colorRenderBuffer;
@property(nonatomic, assign)GLuint       colorFrameBuffer;
@property(nonatomic, assign)GLuint       programe;

/// 创建用于openGL绘制的图层
-(void)setupLayer;

/// 创建openGL上下文
-(void)setupContext;

/// 清空缓存区
-(void)deleteRenderAndFrameBuffer;
-(void)setupRenderBuffer;
-(void)setupFrameBuffer;
-(void)renderLayer;

@end

@implementation OpenGLView

- (void)layoutSubviews {
    // 1. 创建图层
    [self setupLayer];
    
    // 2. 创建上下文
    [self setupContext];
    
    // 3. 清空缓存区
    [self deleteRenderAndFrameBuffer];
    
    // 4. 设置renderBuffer
    [self setupRenderBuffer];
    
    // 5. 设置frameBuffer
    [self setupFrameBuffer];
    
    // 6. 开始绘制
    [self renderLayer];
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
    glDeleteBuffers(1, &_colorRenderBuffer);
    self.colorRenderBuffer = 0;
    
    // 清空帧缓存区
    glDeleteBuffers(1, &_colorFrameBuffer);
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
    // 1. 设置清屏颜色
    glClearColor(0.3f, 0.45f, 0.5f, 1.0f);
    
    // 2. 指定所要清屏的buffer。这里指定的是color_buffer
    glClear(GL_COLOR_BUFFER_BIT);
    
    // 3. 设置窗口的大小
    CGFloat scale = [UIScreen mainScreen].scale;
    glViewport(self.frame.origin.x * scale, self.frame.origin.y * scale, self.frame.size.width * scale, self.frame.size.height * scale);
    
    [self.eaglContenxt presentRenderbuffer:GL_RENDERBUFFER];
}
@end
