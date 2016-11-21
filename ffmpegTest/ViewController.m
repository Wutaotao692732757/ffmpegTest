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
#import "WTVoiceObject.h"


@interface ViewController ()

@property (weak, nonatomic) IBOutlet UIImageView *VideoImageView;

@property(nonatomic,strong) WTMoiveObject *videoPlayer;

@property(nonatomic,strong) WTVoiceObject *voicePlayer;

@property(nonatomic,assign) float lastFrameTime;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
//    AudioStreamEngine *stream = [AudioStreamEngine sharedInstance];
//    [stream setupStream];
//    [stream startWithURL:@"rtsp://192.168.42.1/live"];
    
    
    
    self.videoPlayer = [[WTMoiveObject alloc] initWithVideo:@"rtsp://192.168.42.1/live"];
    
    _voicePlayer=[[WTVoiceObject alloc]init];
    _voicePlayer.videoPath=@"rtsp://192.168.42.1/live";
    [_voicePlayer playerVideo];
//    [_voicePlayer playerVideo];
    

    
    
    [_videoPlayer playWithImageView:_VideoImageView];
   
    //    1、rtsp://184.72.239.149/vod/mp4://BigBuckBunny_175k.mov
    //    一段动画片
    //    2、rtsp://218.204.223.237:554/live/1/66251FC11353191F/e7ooqwcfbqjoo80j.sdp
    //    拱北口岸珠海过澳门大厅
    //    3、rtsp://218.204.223.237:554/live/1/0547424F573B085C/gsfp90ef4k0a6iap.sdp
    //    好像是个车站吧
    //    以下是从网上搜集的一些有效的rtsp流媒体测试地址：
   
    // Do any additional setup after loading the view, typically from a nib.
//    NSLog(@"视频总时长>>>video duration: %f",_videoPlayer.duration);
//    NSLog(@"源尺寸>>>video size: %d x %d", _videoPlayer.sourceWidth, _video.sourceHeight);
//    NSLog(@"输出尺寸>>>video size: %d x %d", _videoPlayer.outputWidth, _videoPlayer.outputHeight);
//    NSLog(@"帧率----%.2f",_video.fps);
   
}


- (IBAction)stopbtnDidClicked:(id)sender {
   
    [_videoPlayer StopPlay];
    
    [_voicePlayer stopTheVideo];
}

- (IBAction)continueBtnDidClicked:(id)sender {
    
    
//    [_voicePlayer playVideoFromFile];
      [_videoPlayer PlayerContinue];
    
}





- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];

}


@end
