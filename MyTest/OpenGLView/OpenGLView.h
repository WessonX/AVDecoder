//
//  OpenGLView.h
//  MyTest
//
//  Created by 谢文灏 on 2023/1/11.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface OpenGLView : UIView
- (void)displayYUV420pData:(void *)data width:(int)w height:(int)h;
@end

NS_ASSUME_NONNULL_END
