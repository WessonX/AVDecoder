//
//  CommonUtil.h
//  MyTest
//
//  Created by 谢文灏 on 2022/12/26.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface CommonUtil : NSObject

+ (NSString *)bundlePath:(NSString *)fileName;

+ (NSString *)documentPath:(NSString *)fileName;

@end

NS_ASSUME_NONNULL_END
