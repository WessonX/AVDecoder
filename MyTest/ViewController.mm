//
//  ViewController.m
//  MyTest
//
//  Created by 谢文灏 on 2022/10/9.
//

#import "ViewController.h"
#import "CommonUtil.h"
#include "AVDecoder.hpp"

@interface ViewController ()

@end


@implementation ViewController

- (void)viewDidLoad {
    NSLog(@"view did load");
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor greenColor];

    const char *inputFilePath = [[CommonUtil bundlePath:@"131.aac"] cStringUsingEncoding:NSUTF8StringEncoding];
    const char *outputFilePath = [[CommonUtil documentPath:@"132.pcm"] cStringUsingEncoding:NSUTF8StringEncoding];
    
    AVDecoder *decoder = new AVDecoder(inputFilePath,outputFilePath);
    decoder->Decode();
    delete decoder;
}


@end
