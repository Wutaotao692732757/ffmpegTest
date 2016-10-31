//
//  WTMoiveObject.h
//  ffmpegTest
//
//  Created by 伍陶陶 on 2016/10/28.
//  Copyright © 2016年 伍陶陶. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WTMoiveObject : NSObject
    
    @property(nonatomic,strong,readonly)UIImage *currentImage;
    @property(nonatomic,assign,readonly)int sourceWidth, sourceHeight;
    /* 输出图像大小。默认设置为源大小。 */
    @property (nonatomic,assign) int outputWidth, outputHeight;
    
    /* 视频的长度，秒为单位 */
    @property (nonatomic, assign, readonly) double duration;
    
    /* 视频的当前秒数 */
    @property (nonatomic, assign, readonly) double currentTime;
    
    /* 视频的帧率 */
    @property (nonatomic, assign, readonly) double fps;
    
    /* 视频路径。 */
- (instancetype)initWithVideo:(NSString *)moviePath;
    /* 切换资源 */
- (void)replaceTheResources:(NSString *)moviePath;
    /* 重拨 */
- (void)redialPaly;
    /* 从视频流中读取下一帧。返回假，如果没有帧读取（视频）。 */
- (BOOL)stepFrame;
    
    /* 寻求最近的关键帧在指定的时间 */
- (void)seekTime:(double)seconds;
    
    
    @end
