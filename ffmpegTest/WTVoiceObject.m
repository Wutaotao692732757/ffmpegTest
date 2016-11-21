#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define __STDC_CONSTANT_MACROS

#import "WTVoiceObject.h"
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswresample/swresample.h>
#include "SDL.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#define QUEUE_BUFFER_SIZE 4 //队列缓冲个数
#define EVERY_READ_LENGTH 1000 //每次从文件读取的长度
#define MIN_SIZE_PER_FRAME 2000 //每侦最小数据长度
//#include "SDL_main.h"

#ifdef __cplusplus

#endif
#define sanbox  NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES)[0]
#define MAX_AUDIO_FRAME_SIZE 1024*4 // 1 second of 48khz 32bit audio  192000

//#define Output PCM
//#define OUTPUT_PCM 1
//Use SDL
//#define USE_SDL 1

//Buffer:
//|-----------|-------------|
//chunk-------pos---len-----|
static  Uint8  *audio_chunk;
static  Uint32  audio_len;
static  Uint8  *audio_pos;

@interface WTVoiceObject (){
    //Out Audio Param
    uint64_t out_channel_layout;
    //nb_samples: AAC-1024 MP3-1152
    int out_nb_samples;
    enum AVSampleFormat out_sample_fmt;
    int out_sample_rate;
    int out_channels;
    //Out Buffer Size
    int out_buffer_size;
    AVFormatContext *pFormatCtx;
    int             i, audioStream;
    AVCodecContext  *pCodecCtx;
    AVCodec         *pCodec;
    AVPacket        *packet;
    uint8_t         *out_buffer;
    AVFrame         *pFrame;
    SDL_AudioSpec wanted_spec;
    int ret;
    
    int got_picture;
    
    int64_t in_channel_layout;
    struct SwrContext *au_convert_ctx;
    FILE *pFile;
    
}

@end

@implementation WTVoiceObject


-(int )playerVideo{
    
    int index = 0;
    uint32_t len = 0;
    
  BOOL abc=[[NSFileManager defaultManager] createFileAtPath:[NSString stringWithFormat:@"%@/output.raw",sanbox] contents:[NSMutableData data] attributes:nil];
       NSLog(@"%zd",abc);
       NSString *filepath = [NSString stringWithFormat:@"%@/output.pcm",sanbox];
    
    
        const  char *pathurl=[_videoPath UTF8String];
//        char url[]="Background.mp3";
    
        av_register_all();
        avformat_network_init();
        pFormatCtx = avformat_alloc_context();
        //Open
        if(avformat_open_input(&pFormatCtx,pathurl,NULL,NULL)!=0){
            printf("Couldn't open input stream.\n");
            return -1;
        }
        // Retrieve stream information
        if(avformat_find_stream_info(pFormatCtx,NULL)<0){
            printf("Couldn't find stream information.\n");
            return -1;
        }
        // Dump valid information onto standard error
        av_dump_format(pFormatCtx, 0, pathurl, false);
    
        // Find the first audio stream
        audioStream=-1;
        for(i=0; i < pFormatCtx->nb_streams; i++)
            if(pFormatCtx->streams[i]->codec->codec_type==AVMEDIA_TYPE_AUDIO){
                audioStream=i;
                break;
            }
    
        if(audioStream==-1){
            printf("Didn't find a audio stream.\n");
            return -1;
        }
    
        // Get a pointer to the codec context for the audio stream
        pCodecCtx=pFormatCtx->streams[audioStream]->codec;
    
        // Find the decoder for the audio stream
        pCodec=avcodec_find_decoder(pCodecCtx->codec_id);
        if(pCodec==NULL){
            printf("Codec not found.\n");
            return -1;
        }
    
        // Open codec
        if(avcodec_open2(pCodecCtx, pCodec,NULL)<0){
            printf("Could not open codec.\n");
            return -1;
        }
    
    
    #if OUTPUT_PCM
        pFile=fopen([filepath UTF8String], "wb");
    #endif
    
        packet=(AVPacket *)av_malloc(sizeof(AVPacket));
        av_init_packet(packet);
    
        //Out Audio Param  AV_CH_LAYOUT_STEREO     AV_CH_LAYOUT_2POINT1
        out_channel_layout = AV_CH_LAYOUT_STEREO;
        //nb_samples: AAC-1024 MP3-1152
        out_nb_samples=pCodecCtx->frame_size;
    
//  AV_SAMPLE_FMT_S16   AV_SAMPLE_FMT_U8
        out_sample_fmt= AV_SAMPLE_FMT_S16;
        out_sample_rate=48000;
        out_channels=av_get_channel_layout_nb_channels(out_channel_layout);
        //Out Buffer Size
        out_buffer_size=av_samples_get_buffer_size(NULL,out_channels ,out_nb_samples,out_sample_fmt, 1);
    
        out_buffer=(uint8_t *)av_malloc(MAX_AUDIO_FRAME_SIZE*2);
        pFrame=av_frame_alloc();
    
    
    
    
    
    NSLog(@"%lf--%zd---%d---%zd---",&out_channel_layout,&out_nb_samples,&out_sample_fmt,&out_channels);
    
    
        //SDL------------------
    #if USE_SDL
        //Init
        if(SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_TIMER)) {
            printf( "Could not initialize SDL - %s\n", SDL_GetError());
            return -1;
        }
        //SDL_AudioSpec
        wanted_spec.freq = out_sample_rate;
        wanted_spec.format = AUDIO_S16SYS;
        wanted_spec.channels = out_channels;
        wanted_spec.silence = 10;
        wanted_spec.samples = out_nb_samples;
        wanted_spec.callback = fill_audio;
        wanted_spec.userdata = pCodecCtx;
    
        if (SDL_OpenAudio(&wanted_spec, NULL)<0){
            printf("can't open audio.\n");
            return -1;
        }
    #endif
    
        //FIX:Some Codec's Context Information is missing
        in_channel_layout=av_get_default_channel_layout(pCodecCtx->channels);
        //Swr
  
 
        au_convert_ctx = swr_alloc();
        au_convert_ctx=swr_alloc_set_opts(au_convert_ctx,out_channel_layout, out_sample_fmt, out_sample_rate,
                                          in_channel_layout,pCodecCtx->sample_fmt , pCodecCtx->sample_rate,0, NULL);
        swr_init(au_convert_ctx);
    
        //Play
//        SDL_PauseAudio(0);
    
//        while(av_read_frame(pFormatCtx, packet)>=0){
//           
//        }
    
    _pcmplayer=[[PCMPlayer alloc]init];
    [_pcmplayer start];
    
    _timer = [NSTimer scheduledTimerWithTimeInterval:0.01 target:self selector:@selector(playVideoStreem) userInfo:nil repeats:YES];
    
        return 0;  

  
    
}


-(void)playVideoStreem{
    
    if (av_read_frame(pFormatCtx, packet)>=0) {
        if(packet->stream_index==audioStream){
            
            
            ret = avcodec_decode_audio4( pCodecCtx, pFrame,&got_picture, packet);
           
            NSLog(@"----sssd---%zd",pCodecCtx->frame_size);
            
            if ( ret < 0 ) {
                printf("Error in decoding audio frame.\n");
                
            }
            if ( got_picture > 0 ){
                swr_convert(au_convert_ctx,&out_buffer, MAX_AUDIO_FRAME_SIZE,(const uint8_t **)pFrame->data , pFrame->nb_samples);
                
#if 1
                printf("index:%d\t pts:%lld\t packet size:%d\n",_index,packet->pts,packet->size);
#endif
                
#if OUTPUT_PCM
                //Write PCM
                fwrite(out_buffer, 1, out_buffer_size, pFile);
#endif
                _index++;
            }
#if USE_SDL
            
            //Set audio buffer (PCM data)
            audio_chunk = (Uint8 *) out_buffer;
            //Audio buffer length
            audio_len =out_buffer_size;
            audio_pos = audio_chunk;
            
            //                while(audio_len>0)//Wait until finish
            //                    SDL_Delay(1);
#endif
        }
        
        fclose(pFile);
     
        audio_chunk = (Uint8 *) out_buffer;
        NSData *avdata=[NSData dataWithBytes:audio_chunk length:out_buffer_size];
//        MyPropertyListenerProc((__bridge void *)(avdata), audioStream, au_convert_ctx, out_buffer);
        NSLog(@"222shengyingshengying-%zd",avdata.length);
        CFDataRef data = CFDataCreate(kCFAllocatorDefault,
                                      out_buffer,
                                      out_buffer_size);
        CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
     
        [_pcmplayer play:avdata];
    
        av_free_packet(packet);
    }
}

-(void)reciveData:(NSData *)data{
    
    
    
    
    
    
}



-(void)stopTheVideo{
        
        [_timer setFireDate:[NSDate distantFuture]];
        swr_free(&au_convert_ctx);
        
#if USE_SDL
        SDL_CloseAudio();//Close SDL
        SDL_Quit();
#endif
        
#if OUTPUT_PCM
        fclose(pFile);
#endif
        av_free(out_buffer);
        avcodec_close(pCodecCtx);
        avformat_close_input(&pFormatCtx);
        
    }
    


void  fill_audio(void *udata,Uint8 *stream,int len){
    //SDL 2.0
    SDL_memset(stream, 0, len);
    if(audio_len==0)
        return;

    len=(len>audio_len?audio_len:len);   /*  Mix  as  much  data  as  possible  */

    SDL_MixAudio(stream,audio_pos,len,SDL_MIX_MAXVOLUME);
    audio_pos += len;
    audio_len -= len;
}

@end


/* The audio function callback takes the following parameters:
 * stream: A pointer to the audio buffer to be filled
 * len: The length (in bytes) of the audio buffer
 */

//-----------------

//
//int main(int argc, char* argv[])
//{
//    AVFormatContext *pFormatCtx;
//    int             i, audioStream;
//    AVCodecContext  *pCodecCtx;
//    AVCodec         *pCodec;
//    AVPacket        *packet;
//    uint8_t         *out_buffer;
//    AVFrame         *pFrame;
//    SDL_AudioSpec wanted_spec;
//    int ret;
//    uint32_t len = 0;
//    int got_picture;
//    int index = 0;
//    int64_t in_channel_layout;
//    struct SwrContext *au_convert_ctx;
//    
//    FILE *pFile=NULL;
//    char url[]="09 Background for talking but don't.mp3";
//    
//    av_register_all();
//    avformat_network_init();
//    pFormatCtx = avformat_alloc_context();
//    //Open
//    if(avformat_open_input(&pFormatCtx,url,NULL,NULL)!=0){
//        printf("Couldn't open input stream.\n");
//        return -1;
//    }
//    // Retrieve stream information
//    if(avformat_find_stream_info(pFormatCtx,NULL)<0){
//        printf("Couldn't find stream information.\n");
//        return -1;
//    }
//    // Dump valid information onto standard error
//    av_dump_format(pFormatCtx, 0, url, false);
//    
//    // Find the first audio stream
//    audioStream=-1;
//    for(i=0; i < pFormatCtx->nb_streams; i++)
//        if(pFormatCtx->streams[i]->codec->codec_type==AVMEDIA_TYPE_AUDIO){
//            audioStream=i;
//            break;
//        }
//    
//    if(audioStream==-1){
//        printf("Didn't find a audio stream.\n");
//        return -1;
//    }
//    
//    // Get a pointer to the codec context for the audio stream
//    pCodecCtx=pFormatCtx->streams[audioStream]->codec;
//    
//    // Find the decoder for the audio stream
//    pCodec=avcodec_find_decoder(pCodecCtx->codec_id);
//    if(pCodec==NULL){
//        printf("Codec not found.\n");
//        return -1;
//    }
//    
//    // Open codec
//    if(avcodec_open2(pCodecCtx, pCodec,NULL)<0){
//        printf("Could not open codec.\n");
//        return -1;
//    }
//    
//    
//#if OUTPUT_PCM
//    pFile=fopen("output.pcm", "wb");
//#endif
//    
//    packet=(AVPacket *)av_malloc(sizeof(AVPacket));
//    av_init_packet(packet);
//    
//    //Out Audio Param
//    uint64_t out_channel_layout=AV_CH_LAYOUT_STEREO;
//    //nb_samples: AAC-1024 MP3-1152
//    int out_nb_samples=pCodecCtx->frame_size;
//    enum AVSampleFormat out_sample_fmt=AV_SAMPLE_FMT_S16;
//    int out_sample_rate=44100;
//    int out_channels=av_get_channel_layout_nb_channels(out_channel_layout);
//    //Out Buffer Size
//    int out_buffer_size=av_samples_get_buffer_size(NULL,out_channels ,out_nb_samples,out_sample_fmt, 1);
//    
//    out_buffer=(uint8_t *)av_malloc(MAX_AUDIO_FRAME_SIZE*2);
//    pFrame=av_frame_alloc();
//    //SDL------------------
//#if USE_SDL
//    //Init
//    if(SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_TIMER)) {
//        printf( "Could not initialize SDL - %s\n", SDL_GetError());
//        return -1;
//    }
//    //SDL_AudioSpec
//    wanted_spec.freq = out_sample_rate;
//    wanted_spec.format = AUDIO_S16SYS;
//    wanted_spec.channels = out_channels;
//    wanted_spec.silence = 0;
//    wanted_spec.samples = out_nb_samples;
//    wanted_spec.callback = fill_audio;
//    wanted_spec.userdata = pCodecCtx;
//    
//    if (SDL_OpenAudio(&wanted_spec, NULL)<0){
//        printf("can't open audio.\n");
//        return -1;
//    }
//#endif
//    
//    //FIX:Some Codec's Context Information is missing
//    in_channel_layout=av_get_default_channel_layout(pCodecCtx->channels);
//    //Swr
//    
//    au_convert_ctx = swr_alloc();
//    au_convert_ctx=swr_alloc_set_opts(au_convert_ctx,out_channel_layout, out_sample_fmt, out_sample_rate,
//                                      in_channel_layout,pCodecCtx->sample_fmt , pCodecCtx->sample_rate,0, NULL);
//    swr_init(au_convert_ctx);
//    
//    //Play
//    SDL_PauseAudio(0);
//    
//    while(av_read_frame(pFormatCtx, packet)>=0){
//        if(packet->stream_index==audioStream){
//            ret = avcodec_decode_audio4( pCodecCtx, pFrame,&got_picture, packet);
//            if ( ret < 0 ) {
//                printf("Error in decoding audio frame.\n");
//                return -1;
//            }
//            if ( got_picture > 0 ){
//                swr_convert(au_convert_ctx,&out_buffer, MAX_AUDIO_FRAME_SIZE,(const uint8_t **)pFrame->data , pFrame->nb_samples);
//#if 1
//                printf("index:%5d\t pts:%lld\t packet size:%d\n",index,packet->pts,packet->size);
//#endif
//                
//                
//#if OUTPUT_PCM
//                //Write PCM
//                fwrite(out_buffer, 1, out_buffer_size, pFile);
//#endif
//                index++;
//            }
//            
//#if USE_SDL
//            while(audio_len>0)//Wait until finish
//                SDL_Delay(1);
//            
//            //Set audio buffer (PCM data)
//            audio_chunk = (Uint8 *) out_buffer;
//            //Audio buffer length
//            audio_len =out_buffer_size;
//            audio_pos = audio_chunk;
//            
//#endif
//        }
//        av_free_packet(packet);
//    }
//    
//    swr_free(&au_convert_ctx);
//    
//#if USE_SDL
//    SDL_CloseAudio();//Close SDL
//    SDL_Quit();
//#endif
//    
//#if OUTPUT_PCM
//    fclose(pFile);
//#endif
//    av_free(out_buffer);
//    avcodec_close(pCodecCtx);  
//    avformat_close_input(&pFormatCtx);  
//    
//    return 0;  
//}
