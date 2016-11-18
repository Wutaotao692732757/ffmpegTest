//
//  WTVoiceObject.h
//  ffmpegTest
//
//  Created by mac_w on 2016/11/17.
//  Copyright © 2016年 伍陶陶. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WTVoiceObject : NSObject

@property(nonatomic,copy) NSString *videoPath;

@property(nonatomic,strong) NSTimer *timer;

-(int )playerVideo;

-(void)playVideoFromFile;

-(void)stopTheVideo;

@end
