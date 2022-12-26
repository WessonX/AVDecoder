//
//  CommonUtil.m
//  MyTest
//
//  Created by 谢文灏 on 2022/12/26.
//

#import "CommonUtil.h"

@implementation CommonUtil

+ (NSString *)bundlePath:(NSString *)fileName{
    return [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:fileName];
}

+ (NSString *)documentPath:(NSString *)fileName{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    return [documentsDirectory stringByAppendingPathComponent:fileName];
}
@end
