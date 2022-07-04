//
//  ViewController.m
//  IYZMainApp
//
//  Created by YB007 on 2022/7/2.
//

#import "ViewController.h"

#import <RKKeepAlive/RKKeepAlive.h>

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    [self keepAlive];
    
}

#pragma mark - 保活测试

-(void)keepAlive {
    
    NSNotificationCenter *notiCenter = [NSNotificationCenter defaultCenter];
    [notiCenter addObserver:self selector:@selector(appActive) name:UIApplicationDidBecomeActiveNotification object:nil];

    [[RKKeepAlive sharedKeepInstance] showLog:YES];
    [[RKKeepAlive sharedKeepInstance] startAppLifeCycleMonitor];

}

-(void)appActive {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[RKKeepAlive sharedKeepInstance] showRunTime];
    });
}



@end
