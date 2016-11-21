//
//  AACDecode.m
//  FC_FFmpeg_test
//
//  Created by szfcios on 2016/11/7.
//  Copyright © 2016年 fencun. All rights reserved.
//

#import "AACDecode.h"
#import "avcodec.h"
#import "swscale.h"
#import "avformat.h"
#import "swresample.h"

@interface AACDecode ()
@property (assign, nonatomic) AVFrame *aacFrame;
@property (assign, nonatomic) AVCodec *aacCodec;
@property (assign, nonatomic) AVCodecContext *aacCodecCtx;
@property (assign, nonatomic) AVPacket aacPacket;
@property (nonatomic, assign) int sampleRate;
@property (nonatomic, assign) int channel;
@property (nonatomic, assign) int64_t bit;
@end
@implementation AACDecode

/**
 *  初始化音频解码器
 *
 *  @param sampleRate 采样率
 *  @param channel    通道数
 *  @param bit        位数
 *
 *  @return YES:解码成功
 */
- (BOOL)initAACDecoderWithSampleRate:(int)sampleRate channel:(int)channel bit:(int)bit {
    av_register_all();
    avformat_network_init();
    self.aacCodec = avcodec_find_decoder(AV_CODEC_ID_AAC);
    av_init_packet(&_aacPacket);
    
    if (self.aacCodec != nil) {
        self.aacCodecCtx = avcodec_alloc_context3(self.aacCodec);
        
        // 初始化codecCtx
        self.aacCodecCtx->codec_type = AVMEDIA_TYPE_AUDIO;
        self.aacCodecCtx->sample_rate = sampleRate;
        self.aacCodecCtx->channels = channel;
        self.aacCodecCtx->bit_rate = bit;
        self.aacCodecCtx->channel_layout = AV_CH_LAYOUT_STEREO;
        
        self.sampleRate = sampleRate;
        self.channel = channel;
        self.bit = bit;
        
        // 打开codec
        if (avcodec_open2(self.aacCodecCtx, self.aacCodec, NULL) >= 0) {
            self.aacFrame = av_frame_alloc();
            
        }
    }
    return (BOOL)self.aacFrame;
}

/**
 *  音频解码
 *
 *  @param mediaData  被解码音频数据
 *  @param sampleRate 采样率
 *  @param completion block：返回解码后的数据及长度
 */
- (void)AACDecoderWithMediaData:(NSData *)mediaData sampleRate:(int)sampleRate completion:(void (^)(uint8_t *, size_t))completion {
    _aacPacket.data = (uint8_t *)mediaData.bytes;
    _aacPacket.size = (int)mediaData.length;
    
    if (&_aacPacket) {
        avcodec_send_packet(self.aacCodecCtx, &_aacPacket);
        int result = avcodec_receive_frame(self.aacCodecCtx, self.aacFrame);
        
        if (result == 0) {
            struct SwrContext *au_convert_ctx = swr_alloc();
            au_convert_ctx = swr_alloc_set_opts(au_convert_ctx,
                                                AV_CH_LAYOUT_STEREO, AV_SAMPLE_FMT_S16, sampleRate,
                                                self.aacCodecCtx->channel_layout, self.aacCodecCtx->sample_fmt, self.aacCodecCtx->sample_rate,
                                                0, NULL);
            swr_init(au_convert_ctx);
            
            int out_linesize;
            int out_buffer_size=av_samples_get_buffer_size(&out_linesize, self.aacCodecCtx->channels,self.aacCodecCtx->frame_size,self.aacCodecCtx->sample_fmt, 1);
            uint8_t *out_buffer=(uint8_t *)av_malloc(out_buffer_size);
            swr_convert(au_convert_ctx, &out_buffer, out_linesize, (const uint8_t **)self.aacFrame->data , self.aacFrame->nb_samples);
            
            swr_free(&au_convert_ctx);
            au_convert_ctx = NULL;
            if (completion) {
                completion(out_buffer, out_linesize);
            }
            // 释放
            av_free(out_buffer);
        }
    }
}
/**
 *  释放AAC解码器 
 */
- (void)releaseAACDecoder {
    if(self.aacCodecCtx) {
        avcodec_close(self.aacCodecCtx);
        avcodec_free_context(&_aacCodecCtx);
        self.aacCodecCtx = NULL;
    }
    
    if(self.aacFrame) {
        av_frame_free(&_aacFrame);
        self.aacFrame = NULL;
    }
}

@end
