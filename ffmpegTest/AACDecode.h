//
//  AACDecode.h
//  FC_FFmpeg_test
//
//  Created by szfcios on 2016/11/7.
//  Copyright © 2016年 fencun. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AACDecode : NSObject
/**
 *  初始化音频解码器
 *
 *  @param sampleRate 采样率
 *  @param channel    通道数
 *  @param bit        位数
 *
 *  @return YES:初始化成功
 */
- (BOOL)initAACDecoderWithSampleRate:(int)sampleRate channel:(int)channel bit:(int)bit ;

/**
 *  音频解码
 *
 *  @param mediaData  被解码音频数据
 *  @param sampleRate 采样率
 *  @param completion block：返回解码后的数据及长度
 */
- (void)AACDecoderWithMediaData:(NSData *)mediaData sampleRate:(int)sampleRate completion:(void(^)(uint8_t *out_buffer, size_t out_buffer_size))completion;

/* 释放AAC解码器 */
- (void)releaseAACDecoder;
@end
