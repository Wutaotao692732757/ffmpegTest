//
//  ViewController.m
//  ffmpegTest
//
//  Created by 伍陶陶 on 2016/10/26.
//  Copyright © 2016年 伍陶陶. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import "WTMoiveObject.h"

#define  LERP(A,B,C) ((A)*(1.0-C)+(B)*C)


@interface ViewController ()

    @property (weak, nonatomic) IBOutlet UIButton *playBtn;
   
    @property (weak, nonatomic) IBOutlet UIButton *timerBtn;
    
    @property (weak, nonatomic) IBOutlet UILabel *flpLabel;
    @property (weak, nonatomic) IBOutlet UILabel *timeLabel;
    @property (weak, nonatomic) IBOutlet UIImageView *VideoImageView;
    
    @property(nonatomic,strong) WTMoiveObject *video;
    
    
    @property(nonatomic,assign) float lastFrameTime;
    
    
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    av_register_all();
    self.video = [[WTMoiveObject alloc] initWithVideo:@"rtsp://184.72.239.149/vod/mp4://BigBuckBunny_175k.mov"];
    
//    1、rtsp://184.72.239.149/vod/mp4://BigBuckBunny_175k.mov
//    一段动画片
//    2、rtsp://218.204.223.237:554/live/1/66251FC11353191F/e7ooqwcfbqjoo80j.sdp
//    拱北口岸珠海过澳门大厅
//    3、rtsp://218.204.223.237:554/live/1/0547424F573B085C/gsfp90ef4k0a6iap.sdp
//    好像是个车站吧
//    以下是从网上搜集的一些有效的rtsp流媒体测试地址：
//
//    1.      rtsp://218.204.223.237:554/live/1/0547424F573B085C/gsfp90ef4k0a6iap.sdp
//    
//    2.      rtsp://218.204.223.237:554/live/1/66251FC11353191F/e7ooqwcfbqjoo80j.sdp
//    
//    3.      rtsp://211.139.194.251:554/live/2/13E6330A31193128/5iLd2iNl5nQ2s8r8.sdp
//    
//    4.      rtsp://218.204.223.237:554/live/1/67A7572844E51A64/f68g2mj7wjua3la7.sdp
//    
//    5.      rtsp://46.249.213.87:554/playlists/brit-asia_hvga.hpl.3gp
//    
//    6.      rtsp://46.249.213.87:554/playlists/ftv_hvga.hpl.3gp
//    
//    7.      rtsp://217.146.95.166:554/live/ch11yqvga.3gp
//    
//    8.      rtsp://217.146.95.166:554/live/ch12bqvga.3gp
//    
//    9.      rtsp://217.146.95.166:554/live/ch14bqvga.3gp
    NSLog(@"视频总时长>>>video duration: %f",_video.duration);
    NSLog(@"源尺寸>>>video size: %d x %d", _video.sourceWidth, _video.sourceHeight);
    NSLog(@"输出尺寸>>>video size: %d x %d", _video.outputWidth, _video.outputHeight);
    NSLog(@"帧率----%.2f",_video.fps);
    // Do any additional setup after loading the view, typically from a nib.
}


    
- (IBAction)playButtonDidClicked:(id)sender {
    
    [_playBtn setEnabled:NO];
    _lastFrameTime = -1;
    
    // seek to 0.0 seconds
    [_video seekTime:0.0];
    
    
    [NSTimer scheduledTimerWithTimeInterval: 1 / _video.fps
                                     target:self
                                   selector:@selector(displayNextFrame:)
                                   userInfo:nil
                                    repeats:YES];
    
}
 
    
    -(void)displayNextFrame:(NSTimer *)timer {
        NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
        //    self.TimerLabel.text = [NSString stringWithFormat:@"%f s",video.currentTime];
        self.timeLabel.text  = [self dealTime:_video.currentTime];
        if (![_video stepFrame]) {
            [timer invalidate];
            [_playBtn setEnabled:YES];
            return;
        }
        
        UIImage *currentImage=_video.currentImage;
        UIGraphicsBeginImageContextWithOptions(currentImage.size, NO, 0);
        [currentImage drawAtPoint:CGPointZero];
        NSString *string=@"斗鱼TV";
        [string drawAtPoint:CGPointMake(10, 20) withAttributes:nil];
        UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        
        _VideoImageView.image = newImage;
        float frameTime = 1.0 / ([NSDate timeIntervalSinceReferenceDate] - startTime);
        if (_lastFrameTime < 0) {
            _lastFrameTime = frameTime;
        } else {
            _lastFrameTime = LERP(frameTime, _lastFrameTime, 0.8);
        }
        [_flpLabel setText:[NSString stringWithFormat:@"fps %.0f",_lastFrameTime]];
    }
    
 
    
    - (NSString *)dealTime:(double)time {
        
        int tns, thh, tmm, tss;
        tns = time;
        thh = tns / 3600;
        tmm = (tns % 3600) / 60;
        tss = tns % 60;
        
        
        // [ImageView setTransform:CGAffineTransformMakeRotation(M_PI)];
        return [NSString stringWithFormat:@"%02d:%02d:%02d",thh,tmm,tss];
    }
    
- (IBAction)TimerCilicked:(id)sender {
    
    
    if (_playBtn.enabled) {
        [_video redialPaly];
        [self playButtonDidClicked:_playBtn];
    }
    
    
}
    
    
    
    
    
    
    
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
