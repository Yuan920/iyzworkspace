//
//  RKKeepAlive.h
//  RKKeepAlive
//
//  Created by RK on 2022/7/1.
//  Copyright © 2022 cat. All rights reserved.
//

#import "RKKeepAlive.h"
#import <AVFoundation/AVFoundation.h>

static NSString *const kBgTaskName = @"com.rk.root777.KeepAlive";
static RKKeepAlive *_keepInstance = nil;

@interface RKKeepAlive(){
    int _runningTime;
    NSTimer *_testTimer;
    BOOL _showConsoleLog;
    BOOL _showVerboseLog;
}
@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundTaskIdentifier;
@property(nonatomic,assign)BOOL needKeepAliveInBackground;
@property(nonatomic,strong)AVAudioPlayer *player;

@end

@implementation RKKeepAlive

+(instancetype)sharedKeepInstance{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _keepInstance = [[super allocWithZone:NULL]init];
    });
    return _keepInstance;
}
+ (instancetype)allocWithZone:(struct _NSZone *)zone{
    return [self sharedKeepInstance];
}

#pragma mark -
- (void)initPlayer {
    [self.player prepareToPlay];
}
- (AVAudioPlayer *)player {
    if (!_player) {
        NSError *error = nil;
        
        // m-1 需要将.mp3导入主工程
        /*
         NSURL *fileURL = [[NSBundle mainBundle] URLForResource:@"mute-mp3" withExtension:@"mp3"];
         */
        
        // m-2 需要将.bundle导入主工程
        /*
         NSString *rkBundle = [[NSBundle mainBundle] pathForResource:@"KAResource" ofType:@"bundle"];
         NSString *rkResource = [rkBundle stringByAppendingPathComponent:@"image"];
         NSString *mp3File = [rkResource stringByAppendingPathComponent:@"mute-mp3.mp3"];
         */
        
        // m-3 直接加载framework的资源【得是动态库】
        NSBundle *rkBundle = [NSBundle bundleForClass:[RKKeepAlive class]];
        NSString *rkResource = [rkBundle pathForResource:@"KAResource" ofType:@"bundle"];
        NSString *mp3File = [rkResource stringByAppendingPathComponent:@"image/mute-mp3.mp3"];
        if (!mp3File && _showConsoleLog) {
            //NSString *des = [NSString stringWithFormat:@"%s File path cannot be empty!",__FUNCTION__];
            NSAssert(mp3File,@"File path cannot be empty!");
        }
        NSURL *fileURL = [NSURL fileURLWithPath:mp3File];
        //NSLog(@"bundle:%@\nfile:%@\nUrl:%@",rkBundle,mp3File,fileURL);
        AVAudioPlayer *audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:fileURL error:&error];
        audioPlayer.numberOfLoops = NSUIntegerMax;
        _player = audioPlayer;
        AVAudioSession *session = [AVAudioSession sharedInstance];
        [[AVAudioSession sharedInstance] setMode:AVAudioSessionModeDefault error:nil];
        NSString* route = [[[[[AVAudioSession sharedInstance] currentRoute] outputs] objectAtIndex:0] portType];
        if ([route isEqualToString:AVAudioSessionPortHeadphones] ||
            [route isEqualToString:AVAudioSessionPortBluetoothA2DP] ||
            [route isEqualToString:AVAudioSessionPortBluetoothLE] ||
            [route isEqualToString:AVAudioSessionPortBluetoothHFP]) {
            if (@available(iOS 10.0, *)) {
                [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord
                                                 withOptions:(AVAudioSessionCategoryOptionMixWithOthers | AVAudioSessionCategoryOptionAllowBluetooth | AVAudioSessionCategoryOptionAllowBluetoothA2DP)
                                                       error:nil];
            } else {
                // Fallback on earlier versions
            }
        }else{
            [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord
                                             withOptions:(AVAudioSessionCategoryOptionMixWithOthers | AVAudioSessionCategoryOptionDefaultToSpeaker)
                                                   error:nil];
        }
        [session setActive:YES error:nil];
        if (_showConsoleLog) {
            NSLog(@"%s 初始化==:%@",__FUNCTION__,error?[NSString stringWithFormat:@"失败:%@",error]:@"成功");
        }
    }
    return _player;
}

-(void)startAppLifeCycleMonitor{
    self.needKeepAliveInBackground = YES;
    [self addNoti];
}
-(void)addNoti {
    NSNotificationCenter *notiCenter = [NSNotificationCenter defaultCenter];
    [notiCenter addObserver:self selector:@selector(appEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
    [notiCenter addObserver:self selector:@selector(appEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
}
- (void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
-(void)appEnterForeground {
    if (_showConsoleLog) {
        NSLog(@"%s：应用将进入前台WillEnterForeground", __FUNCTION__);
        [self appActive];
    }
    if (self.needKeepAliveInBackground && _player) {
        [self.player pause];
    }
    if (_backgroundTaskIdentifier) {
        [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
    }
}
-(void)appEnterBackground {
    if (_showConsoleLog) {
        NSLog(@"%s：应用进入后台DidEnterBackground", __FUNCTION__);
        [self backGround];
    }
    self.backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithName:kBgTaskName expirationHandler:^{
        if (self.needKeepAliveInBackground) {
            [self.player play];
        }
        if (self.backgroundTaskIdentifier != UIBackgroundTaskInvalid) {
            [[UIApplication sharedApplication] endBackgroundTask:self.backgroundTaskIdentifier];
            self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
        }
    }];
}

#pragma mark - 保活测试
-(void)backGround {
    [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:@"rk_keep_alive_back"];
    [self setupTimer];
}
-(void)appActive {
    [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:@"rk_keep_alive_foreground"];
    if (_testTimer) {
        [_testTimer invalidate];
        _testTimer = nil;
        _runningTime = 0;
    }
}
/// 定时器
- (void)setupTimer {
    _runningTime = 0;
    _testTimer = [NSTimer timerWithTimeInterval:1.0 target:self selector:@selector(timerEvent:) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:_testTimer forMode:NSRunLoopCommonModes];
    [_testTimer fire];
}

- (void)timerEvent:(id)sender {
    _runningTime ++;
    if (_showConsoleLog) {
        NSLog(@"后台运行中:%d",_runningTime);
    }
    if (_runningTime%60 == 0) {
        [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithFormat:@"%d",_runningTime] forKey:@"rk_keep_alive_time"];
    }
}
/// 控制台日志
-(void)showLog:(BOOL)showLog;{
    _showConsoleLog = showLog;
}
- (void)showVerboseLog:(BOOL)verboseLog {
    _showVerboseLog = verboseLog;
}
/// 弹窗
-(void)showRunTime{
    if (_showConsoleLog == NO) {
        return;
    }
    NSString * runTime = [[NSUserDefaults standardUserDefaults] objectForKey:@"rk_keep_alive_time"];
    
    NSDate *backDate = [[NSUserDefaults standardUserDefaults] objectForKey:@"rk_keep_alive_back"];
    NSDate *foregroundDate = [[NSUserDefaults standardUserDefaults] objectForKey:@"rk_keep_alive_foreground"];
    if (backDate && foregroundDate) {
        double intervalTime = [foregroundDate timeIntervalSinceReferenceDate] - [backDate timeIntervalSinceReferenceDate];
        runTime = [NSString stringWithFormat:@"%.0f",intervalTime];
    }
    NSString *msgStr = [NSString stringWithFormat:@"开始时间:\n%@\n结束时间:\n%@\n运行时间: %@ s",backDate,foregroundDate,runTime];
    UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:@"App运行测试" message:msgStr preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *sureAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"rk_keep_alive_time"];
        
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"rk_keep_alive_back"];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"rk_keep_alive_foreground"];
        
    }];
    [alertVC addAction:sureAction];
    if (_showConsoleLog) {
        NSLog(@"%s:当前控制器:%@",__FUNCTION__,[self topViewController]);
        if (_showVerboseLog && ![self topViewController]) {
            NSLog(@"%s:请检查当前控制器是否有navigation",__FUNCTION__);
        }
    }
    [[self topViewController] presentViewController:alertVC animated:YES completion:nil];
    
}

- (UIViewController *)topViewController {
    UINavigationController *nav = [self navigationViewController];
    if (!nav) {
        if (_showVerboseLog) {
            NSLog(@"\n[iyz==>nav 不存在:\n<==iyz]");
        }
        return nil;
    }
    return nav.topViewController;
}
- (UINavigationController *)navigationViewController{
    UIWindow *window = [self getRootWindow];
    if ([window.rootViewController isKindOfClass:[UINavigationController class]]) {
        return (UINavigationController *)window.rootViewController;
    }else if ([window.rootViewController isKindOfClass:[UITabBarController class]]) {
        UIViewController *selectVc = [((UITabBarController *)window.rootViewController) selectedViewController];
        if ([selectVc isKindOfClass:[UINavigationController class]]){
            return (UINavigationController *)selectVc;
        }
    }
    return nil;
}
-(UIWindow *)getRootWindow {
    if (@available(iOS 13.0,*)) {
        for (UIWindowScene* windowScene in [UIApplication sharedApplication].connectedScenes) {
            if (windowScene.activationState == UISceneActivationStateForegroundActive) {
                if (_showVerboseLog) {
                    NSLog(@"\n[iyz==>:get active ==:%@\n<==iyz]",windowScene.windows);
                }
                for (UIView *view in windowScene.windows) {
                    if ([view isKindOfClass:[UIWindow class]]) {
                        UIWindow *window = (UIWindow *)view;
                        if (_showVerboseLog) {
                            NSLog(@"\n[iyz==>:find ==>\n<==iyz]");
                        }
                        return window;
                    }
                }
            }else if (windowScene.activationState == UISceneActivationStateForegroundInactive) {
                if (_showVerboseLog) {
                    NSLog(@"\n[iyz==>:get inactive ==:%@\n<==iyz]",windowScene.windows);
                }
                for (UIView *view in windowScene.windows) {
                    if ([view isKindOfClass:[UIWindow class]]) {
                        UIWindow *window = (UIWindow *)view;
                        if (_showVerboseLog) {
                            NSLog(@"\n[iyz==>:find ==>\n<==iyz]");
                        }
                        return window;
                    }
                }
            }
        }
        return [UIApplication sharedApplication].delegate.window;
    }else {
        return [UIApplication sharedApplication].delegate.window;
    }
}
@end
