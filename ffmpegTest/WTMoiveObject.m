//
//  WTMoiveObject.m
//  ffmpegTest
//
//  Created by 伍陶陶 on 2016/10/28.
//  Copyright © 2016年 伍陶陶. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "WTMoiveObject.h"
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswscale/swscale.h>

@interface WTMoiveObject ()
    
    @property (nonatomic, copy) NSString *currtenPath;
    
    
    
    
    @end

@implementation WTMoiveObject{
    
    //输入视频的格式信息
    AVFormatContext     *SJFormatCtx;
    //输入视频的编码信息
    AVCodecContext      *SJCodecCtx;
    AVFrame             *SJFrame;
    //保存数据帧的数据结构
    AVStream            *stream;
    //解析文件读到的位置
    AVPacket            packet;
    AVPicture           picture;
    int                 videoStream;
    double              fps;
    BOOL                isReleaseResources;
}
    
    -(instancetype)initWithVideo:(NSString *)moviePath
    {
        if (!(self=[super init])) return nil;
        
        if ([self initializeResource:[moviePath UTF8String]]) {
            
            self.currtenPath=[moviePath copy];
            
            return self;
        }else{
            
            return nil;
        }
        
    }
    
    -(BOOL)initializeResource:(const char *)filePath{
        
        isReleaseResources = NO;
        AVCodec *pCodec;
        //注册所有解码器
        avcodec_register_all();
        av_register_all();
        avformat_network_init();
        //打开视频文件
        
        if (avformat_open_input(&SJFormatCtx, filePath, NULL, NULL) != 0) {
            
            UIAlertView *showView=[[UIAlertView alloc]initWithTitle:@"打开失败" message:@"打开失败了" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:nil, nil];
            [showView show];
            goto initError;
        }
        
        if (avformat_find_stream_info(SJFormatCtx, NULL) <0 ) {
            
            UIAlertView *showView=[[UIAlertView alloc]initWithTitle:@"检查数据流失败" message:@"打开失败了" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:nil, nil];
            [showView show];
            goto initError;
            
        }
        
        if ((videoStream = av_find_best_stream(SJFormatCtx, AVMEDIA_TYPE_VIDEO, -1, -1, &pCodec, 0))<0) {
            UIAlertView *showView=[[UIAlertView alloc]initWithTitle:@"没有找到第一个视频流" message:@"打开失败了" delegate:self cancelButtonTitle:@"取消" otherButtonTitles:nil, nil];
            [showView show];
            goto initError;
            
        }
        
        
        //获取视频流的编解码上下文的指针
        
        stream = SJFormatCtx->streams[videoStream];
        SJCodecCtx = stream->codec;
        
        //打印视频流的详细信息
        av_dump_format(SJFormatCtx, videoStream, filePath, 0);
        
        if (stream->avg_frame_rate.den && stream->avg_frame_rate.num) {
            fps = av_q2d(stream->avg_frame_rate);
        } else {
            fps = 30;
        }
        //查找解码器
        pCodec = avcodec_find_decoder(SJCodecCtx->codec_id);
        
        if (pCodec==NULL) {
            NSLog(@"没有找到解码器");
            goto initError;
        }
        // 打开解码器
        if (avcodec_open2(SJCodecCtx, pCodec, NULL) <0) {
            NSLog(@"打开解码器失败");
            goto initError;
        }
        
        //分配视频帧
        SJFrame = av_frame_alloc();
        _outputWidth = SJCodecCtx->width;
        _outputHeight = SJCodecCtx->height;
        
        return YES;
        
    initError:
        return NO;
        
    }
    
    
-(void)seekTime:(double)seconds
    {
        AVRational timeBase = SJFormatCtx->streams[videoStream]->time_base;
        int64_t targetFrame = (int64_t) ((double)timeBase.den / timeBase.num *seconds);
        avformat_seek_file(SJFormatCtx, videoStream, 0, targetFrame, targetFrame, AVSEEK_FLAG_FRAME);
        
        avcodec_flush_buffers(SJCodecCtx);
        
    }
    
-(BOOL)stepFrame {
    
    int frameFinished =0;
    while (!frameFinished && av_read_frame(SJFormatCtx, &packet) >=0) {
        if (packet.stream_index==videoStream) {
            
            avcodec_decode_video2(SJCodecCtx, SJFrame, &frameFinished, &packet);
            
        }
    }
    
    
    if (frameFinished==0&&isReleaseResources==NO) {
        
        [self releaseResources];
    }
    
    return frameFinished !=0;
    
}
    
    
    - (void)replaceTheResources:(NSString *)moviePath {
        if (!isReleaseResources) {
            [self releaseResources];
        }
        self.currtenPath = [moviePath copy];
        [self initializeResource:[moviePath UTF8String]];
    }
    
    
    - (void)redialPaly {
        [self initializeResource:[self.currtenPath UTF8String]];
    }
    
    
    -(void)setOutputWidth:(int)newValue {
        if (_outputWidth == newValue) return;
        _outputWidth = newValue;
    }
-(void)setOutputHeight:(int)newValue {
    if (_outputHeight == newValue) return;
    _outputHeight = newValue;
}
-(UIImage *)currentImage {
    if (!SJFrame->data[0]) return nil;
    return [self imageFromAVPicture];
}
-(double)duration {
    return (double)SJFormatCtx->duration / AV_TIME_BASE;
}
- (double)currentTime {
    AVRational timeBase = SJFormatCtx->streams[videoStream]->time_base;
    return packet.pts * (double)timeBase.num / timeBase.den;
}
- (int)sourceWidth {
    return SJCodecCtx->width;
}
- (int)sourceHeight {
    return SJCodecCtx->height;
}
- (double)fps {
    return fps;
}
    
 
    - (UIImage *)imageFromAVPicture
    {
        avpicture_free(&picture);
        avpicture_alloc(&picture, AV_PIX_FMT_RGB24, _outputWidth, _outputHeight);
        struct SwsContext * imgConvertCtx = sws_getContext(SJFrame->width,
                                                           SJFrame->height,
                                                           AV_PIX_FMT_YUV420P,
                                                           _outputWidth,
                                                           _outputHeight,
                                                           AV_PIX_FMT_RGB24,
                                                           SWS_FAST_BILINEAR,
                                                           NULL,
                                                           NULL,
                                                           NULL);
        if(imgConvertCtx == nil) return nil;
        sws_scale(imgConvertCtx,
                  SJFrame->data,
                  SJFrame->linesize,
                  0,
                  SJFrame->height,
                  picture.data,
                  picture.linesize);
        sws_freeContext(imgConvertCtx);
        
        CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
        CFDataRef data = CFDataCreate(kCFAllocatorDefault,
                                      picture.data[0],
                                      picture.linesize[0] * _outputHeight);
        
        CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGImageRef cgImage = CGImageCreate(_outputWidth,
                                           _outputHeight,
                                           8,
                                           24,
                                           picture.linesize[0],
                                           colorSpace,
                                           bitmapInfo,
                                           provider,
                                           NULL,
                                           NO,
                                           kCGRenderingIntentDefault);
        UIImage *image = [UIImage imageWithCGImage:cgImage];
        CGImageRelease(cgImage);
        CGColorSpaceRelease(colorSpace);
        CGDataProviderRelease(provider);
        CFRelease(data);
        
        return image;
    }
    
#pragma mark --------------------------
#pragma mark - 释放资源
- (void)releaseResources {
    //    SJLog(@"释放资源");
    //    SJLogFunc
    isReleaseResources = YES;
    // 释放RGB
    avpicture_free(&picture);
    // 释放frame
    av_packet_unref(&packet);
    // 释放YUV frame
    av_free(SJFrame);
    // 关闭解码器
    if (SJCodecCtx) avcodec_close(SJCodecCtx);
    // 关闭文件
    if (SJFormatCtx) avformat_close_input(&SJFormatCtx);
    avformat_network_deinit();
}
    
    
@end



















