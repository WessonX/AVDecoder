//
//  AppDelegate.m
//  MyTest
//
//  Created by 谢文灏 on 2022/10/9.
//

#import "AppDelegate.h"
#import "ViewController.h"
#import "WHPlayerViewController.h"
#import "CommonUtil.h"
@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    self.window = [UIWindow new];
    NSString *filePath =  [CommonUtil bundlePath:@"big_buck_bunny.mp4"];
    WHPlayerViewController *rootVC = [[WHPlayerViewController alloc] initWithFilePath:filePath];
    [self.window setRootViewController:rootVC];
    [self.window makeKeyAndVisible];
    return YES;
}

+ (void)initialize{
    
}

@end
