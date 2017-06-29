//
//  WTVoiceObject.h
//  ffmpegTest
//
//  Created by mac_w on 2016/11/17.
//  Copyright © 2016年 伍陶陶. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PCMPlayer.h"

@interface WTVoiceObject : NSObject

@property(nonatomic,copy) NSString *videoPath;

@property(nonatomic,strong) NSTimer *timer;
@property(nonatomic,assign) NSInteger index;
@property(nonatomic,strong)NSMutableData *mutableData;

@property (nonatomic,strong) PCMPlayer *pcmplayer;

-(int )playerVideo;

-(void)playVideoFromFile;

-(void)stopTheVideo;

@end
