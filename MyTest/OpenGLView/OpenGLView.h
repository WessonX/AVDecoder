//
//  OpenGLView.h
//  MyTest
//
//  Created by 谢文灏 on 2023/1/11.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <OpenGLES/EAGL.h>

@interface OpenGLView : UIView

#pragma mark - 接口
- (void)displayYUV420pData:(void *)data width:(int)w height:(int)h;
- (void)setVideoSize:(GLuint)width height:(GLuint)height;

@end
