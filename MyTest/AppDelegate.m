//
//  AppDelegate.m
//  MyTest
//
//  Created by 谢文灏 on 2022/10/9.
//

#import "AppDelegate.h"
#import "ViewController.h"
@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    self.window = [UIWindow new];
    ViewController *rootVC = [ViewController new];
    [self.window setRootViewController:rootVC];
    [self.window makeKeyAndVisible];
    return YES;
}

+ (void)initialize{
    
}

@end
