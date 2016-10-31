//
//  WTVideoPlayer.h
//  ffmpegTest
//
//  Created by 伍陶陶 on 2016/10/28.
//  Copyright © 2016年 伍陶陶. All rights reserved.
//

#include <stdio.h>
extern "C"{
#include "libavformat/avformat.h"
#include "libavcodec/avcodec.h"
#include "libavutil/avstring.h"
#include "libavutil/time.h"
#include "libswresample/swresample.h"
#include "libswscale/swscale.h"
#include "SDL.h"
#include "SDL_thread.h"
};
#include <math.h>
#define AVCODEC_MAX_AUDIO_FRAME_SIZE 19200
#define VIDEO_PICTURE_QUEUE_SIZE 1

#define SDL_AUDIO_BUFFER_SIZE 1024

#define MAX_AUDIOQ_SIZE (5 * 16 * 1024)
#define MAX_VIDEOQ_SIZE (5 * 256 * 1024)

#define AV_SYNC_THRESHOLD 0.01
#define AV_NOSYNC_THRESHOLD 10.0


#define FF_ALLOC_EVENT   (SDL_USEREVENT)
#define FF_REFRESH_EVENT (SDL_USEREVENT + 1)
#define FF_QUIT_EVENT (SDL_USEREVENT + 2)
uint64_t global_video_pkt_pts = AV_NOPTS_VALUE;
typedef struct PacketQueue{
    AVPacketList *first_pkt, *last_pkt;
    int nb_packets;
    int size;
    SDL_mutex *mutex;
    SDL_cond *cond;
}PacketQueue;

typedef struct VideoPicture{
    SDL_Overlay *bmp;
    int width, height;
    int allocated;
    double pts;
}VideoPicture;

typedef struct VideoState{
    AVFormatContext *pFormatCtx;
    int videoStream, audioStream;
    
    //用于保存音视频各自播放了多久
    double audio_clock;
    double video_clock;
    
    AVStream *audio_st;
    PacketQueue audioq;
    uint8_t audio_buf[(AVCODEC_MAX_AUDIO_FRAME_SIZE * 3) / 2];
    unsigned int audio_buf_size;
    unsigned int audio_buf_index;
    AVPacket audio_pkt;
    uint8_t *audio_pkt_data;
    int audio_pkt_size;
    
    int audio_hw_buf_size;
    double frame_timer;
    double frame_last_pts;
    double frame_last_delay;
    
    AVStream *video_st;
    PacketQueue videoq;
    
    VideoPicture pictq[VIDEO_PICTURE_QUEUE_SIZE];
    int pictq_size, pictq_rindex, pictq_windex;
    SDL_mutex *pictq_mutex;
    SDL_cond *pictq_cond;
    
    SDL_Thread *parse_tid;
    SDL_Thread *video_tid;
    
    char filename[1024];
    int quit;
};

SDL_Surface *screen;

VideoState *global_video_state;
