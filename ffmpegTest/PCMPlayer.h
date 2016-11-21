//
//  PCMPlayer.h
//  ffmpegTest
//
//  Created by mac_w on 2016/11/18.
//  Copyright © 2016年 伍陶陶. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioUnit/AudioUnit.h>
//4096   341
//640   48000

#define QUEUE_BUFFER_SIZE 4   //队列缓冲个数
#define AUDIO_BUFFER_SIZE 4096 //数据区大小
#define MAX_BUFFER_SIZE 4096*4 //

@interface PCMPlayer : NSObject

-(BOOL)start;
-(void)play:(NSData *)data;
-(void)stop;


@end
