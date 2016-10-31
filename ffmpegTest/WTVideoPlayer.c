//
//  WTVideoPlayer.c
//  ffmpegTest
//
//  Created by 伍陶陶 on 2016/10/28.
//  Copyright © 2016年 伍陶陶. All rights reserved.
//

#include "WTVideoPlayer.h"

void packet_queue_init(PacketQueue *q) {
    memset(q, 0, sizeof(PacketQueue));
    q->mutex = SDL_CreateMutex();
    q->cond = SDL_CreateCond();
}

int packet_queue_put(PacketQueue *q, AVPacket *pkt) {
    
    AVPacketList *pkt1;
    if(av_dup_packet(pkt) < 0) {
        return -1;
    }
    pkt1 = (AVPacketList *)av_malloc(sizeof(AVPacketList));
    if (!pkt1)
    return -1;
    pkt1->pkt = *pkt;
    pkt1->next = NULL;
    
    SDL_LockMutex(q->mutex);
    
    if (!q->last_pkt)
    q->first_pkt = pkt1;
    else
    q->last_pkt->next = pkt1;
    q->last_pkt = pkt1;
    q->nb_packets++;
    q->size += pkt1->pkt.size;
    SDL_CondSignal(q->cond);
    
    SDL_UnlockMutex(q->mutex);
    return 0;
}

static int packet_queue_get(PacketQueue *q, AVPacket *pkt, int block)
{
    AVPacketList *pkt1;
    int ret;
    
    SDL_LockMutex(q->mutex);
    
    for(;;) {
        
        if(global_video_state->quit) {
            ret = -1;
            break;
        }
        
        pkt1 = q->first_pkt;
        if (pkt1) {
            q->first_pkt = pkt1->next;
            if (!q->first_pkt)
            q->last_pkt = NULL;
            q->nb_packets--;
            q->size -= pkt1->pkt.size;
            *pkt = pkt1->pkt;
            av_free(pkt1);
            ret = 1;
            break;
        } else if (!block) {
            ret = 0;
            break;
        } else {
            SDL_CondWait(q->cond, q->mutex);
        }
    }
    SDL_UnlockMutex(q->mutex);
    return ret;
}

int audio_decode_frame(VideoState *is, uint8_t *audio_buf, int buf_size, double *pts_ptr) {
    static AVPacket pkt;
    static AVPacket pkt1;
    AVCodecContext *aCodecCtx = is->audio_st->codec;
    uint8_t *out[] = { audio_buf };
    int len1, data_size, n;
    int got_frame = 0;
    AVFrame *pAudioFrame = av_frame_alloc();
    
    int wanted_nb_samples;
    av_frame_unref(pAudioFrame);
    double pts;
    for(;;)
    {
        while(pkt1.size > 0)
        {
            data_size = buf_size;
            len1 = avcodec_decode_audio4(is->audio_st->codec, pAudioFrame, &got_frame,
                                         &pkt1);
            if(len1 < 0)
            {
                /* if error, skip frame */
                pkt1.size = 0;
                break;
            }
            pkt1.data += len1;
            pkt1.size -= len1;
            if(got_frame == 0)
            {
                /* No data yet, get more frames */
                continue;
            }
            else
            {
                SwrContext *swrContext = swr_alloc();
                swrContext = swr_alloc_set_opts(swrContext, AV_CH_LAYOUT_STEREO,//is->audio_st->codec->channel_layout,
                                                AV_SAMPLE_FMT_S16,
                                                44100,//is->audio_st->codec->sample_rate,
                                                //is->audio_st->codec->channel_layout,
                                                av_get_default_channel_layout(is->audio_st->codec->channels),
                                                is->audio_st->codec->sample_fmt,
                                                is->audio_st->codec->sample_rate, 0, NULL);
                swr_init(swrContext);
                swr_convert(swrContext, out, AVCODEC_MAX_AUDIO_FRAME_SIZE,//buf_size/aCodecCtx->channels / av_get_bytes_per_sample(AV_SAMPLE_FMT_S16),
                            (const uint8_t **)pAudioFrame->data, pAudioFrame->nb_samples);
                //pAudioFrame->linesize[0] / aCodecCtx->channels / av_get_bytes_per_sample((AVSampleFormat)pAudioFrame->format));
                
                data_size = av_samples_get_buffer_size(NULL, aCodecCtx->channels, pAudioFrame->nb_samples,
                                                       AV_SAMPLE_FMT_S16, 0);
                //if(wanted_spec.samples != pAudioFrame->nb_samples)
                av_free(pAudioFrame);
                av_free_packet(&pkt);
                swr_free(&swrContext);
            }
            /* We have data, return it and come back for more later */
            pts = is->audio_clock;
            *pts_ptr = pts;
            n = 2 * is->audio_st->codec->channels;
            is->audio_clock += (double)data_size /
            (double)(n * is->audio_st->codec->sample_rate);
            return data_size;
        }
        if(pkt.data)
        {
            av_free_packet(&pkt);
        }
        
        if(is->quit)
        {
            return -1;
        }
        
        if(packet_queue_get(&is->audioq, &pkt, 1) < 0)
        {
            return -1;
        }
        pkt1.data = pkt.data;
        pkt1.size = pkt.size;
        if(pkt.pts != AV_NOPTS_VALUE){
            is->audio_clock = av_q2d(is->audio_st->time_base)*(pkt.pts);
        }
    }
}

void audio_callback(void *userdata, Uint8 *stream, int len) {
    //memset(stream, 0, len);
    SDL_memset(stream, 0, len);
    VideoState *is = (VideoState *)userdata;
    int len1, audio_size;
    double pts;
    while(len > 0) {
        if(is->audio_buf_index >= is->audio_buf_size) {
            /* We have already sent all our data; get more */
            audio_size = audio_decode_frame(is, is->audio_buf, sizeof(is->audio_buf), &pts);
            if(audio_size < 0) {
                /* If error, output silence */
                is->audio_buf_size = 1024;
                memset(is->audio_buf, 0, is->audio_buf_size);
            } else {
                is->audio_buf_size = audio_size;
            }
            is->audio_buf_index = 0;
        }
        len1 = is->audio_buf_size - is->audio_buf_index;
        if(len1 > len)
        len1 = len;
        memcpy(stream, (uint8_t *)is->audio_buf + is->audio_buf_index, len1);
        len -= len1;
        stream += len1;
        is->audio_buf_index += len1;
    }
}

static Uint32 sdl_refresh_timer_cb(Uint32 interval, void *opaque) {
    SDL_Event event;
    event.type = FF_REFRESH_EVENT;
    event.user.data1 = opaque;
    SDL_PushEvent(&event);
    return 0; /* 0 means stop timer */
}

static void schedule_refresh(VideoState *is, int delay) {
    SDL_AddTimer(delay, sdl_refresh_timer_cb, is);
}

static int decode_interrupt_cb(void *ctx)
{
    return global_video_state && global_video_state->quit;
}
const AVIOInterruptCB int_cb = { decode_interrupt_cb, NULL };

int queue_picture(VideoState *is, AVFrame *pFrame, double pts) {
    
    VideoPicture *vp;
    int dst_pix_fmt;
    AVPicture pict;
    struct SwsContext *img_convert_ctx;
    AVCodecContext *pCodecCtx = is->video_st->codec;
    
    /* wait until we have space for a new pic */
    SDL_LockMutex(is->pictq_mutex);
    while(is->pictq_size >= VIDEO_PICTURE_QUEUE_SIZE &&
          !is->quit) {
        SDL_CondWait(is->pictq_cond, is->pictq_mutex);
    }
    SDL_UnlockMutex(is->pictq_mutex);
    
    if(is->quit)
    return -1;
    
    // windex is set to 0 initially
    vp = &is->pictq[is->pictq_windex];
    
    /* allocate or resize the buffer! */
    if(!vp->bmp ||
       vp->width != is->video_st->codec->width ||
       vp->height != is->video_st->codec->height) {
        SDL_Event event;
        
        vp->allocated = 0;
        /* we have to do it in the main thread */
        event.type = FF_ALLOC_EVENT;
        event.user.data1 = is;
        SDL_PushEvent(&event);
        
        /* wait until we have a picture allocated */
        SDL_LockMutex(is->pictq_mutex);
        while(!vp->allocated && !is->quit) {
            SDL_CondWait(is->pictq_cond, is->pictq_mutex);
        }
        SDL_UnlockMutex(is->pictq_mutex);
        if(is->quit) {
            return -1;
        }
    }
    /* We have a place to put our picture on the queue */
    
    img_convert_ctx = sws_getContext(pCodecCtx->width, pCodecCtx->height, pCodecCtx->pix_fmt,
                                     pCodecCtx->width, pCodecCtx->height, PIX_FMT_YUV420P, SWS_BICUBIC, NULL, NULL, NULL);
    if(vp->bmp) {
        
        SDL_LockYUVOverlay(vp->bmp);
        
        dst_pix_fmt = PIX_FMT_YUV420P;
        
        pict.data[0] = vp->bmp->pixels[0];
        pict.data[1] = vp->bmp->pixels[2];
        pict.data[2] = vp->bmp->pixels[1];
        
        pict.linesize[0] = vp->bmp->pitches[0];
        pict.linesize[1] = vp->bmp->pitches[2];
        pict.linesize[2] = vp->bmp->pitches[1];
        
        // Convert the image into YUV format that SDL uses
        sws_scale(img_convert_ctx, (const uint8_t* const*)pFrame->data, pFrame->linesize, 0,
                  pCodecCtx->height,pict.data, pict.linesize);
        
        SDL_UnlockYUVOverlay(vp->bmp);
        vp->pts = pts;
        /* now we inform our display thread that we have a pic ready */
        if(++is->pictq_windex == VIDEO_PICTURE_QUEUE_SIZE) {
            is->pictq_windex = 0;
        }
        SDL_LockMutex(is->pictq_mutex);
        is->pictq_size++;
        SDL_UnlockMutex(is->pictq_mutex);
    }
    return 0;
}

double synchronize_video(VideoState *is, AVFrame *src_frame, double pts) {
    
    double frame_delay;
    
    if(pts != 0) {
        /* if we have pts, set video clock to it */
        is->video_clock = pts;
    } else {
        /* if we aren't given a pts, set it to the clock */
        pts = is->video_clock;
    }
    /* update the video clock */
    frame_delay = av_q2d(is->video_st->codec->time_base);
    /* if we are repeating a frame, adjust clock accordingly */
    frame_delay += src_frame->repeat_pict * (frame_delay * 0.5);
    is->video_clock += frame_delay;
    return pts;
}

int video_thread(void *arg)
{
    VideoState *is = (VideoState*)arg;
    AVPacket pkt1, *packet = &pkt1;
    int len1, frameFinished;
    AVFrame *pFrame = av_frame_alloc();
    double pts;
    
    for(;;){
        if(packet_queue_get(&is->videoq, packet, 1) < 0){
            break;
        }
        
        pts = 0;
        global_video_pkt_pts = packet->pts;
        len1 = avcodec_decode_video2(is->video_st->codec, pFrame, &frameFinished, packet);
        if(packet->dts == AV_NOPTS_VALUE && pFrame->opaque
           && *(uint64_t*)pFrame->opaque != AV_NOPTS_VALUE)
        {
            pts = *(uint64_t*)pFrame->opaque;
        }else if(packet->dts != AV_NOPTS_VALUE){
            pts = packet->dts;
        }else{
            pts = 0;
        }
        
        pts *= av_q2d(is->video_st->time_base);
        if(frameFinished){
            //获取第一帧，就调用。作用是：维护video_clock的值，让其始终保存视频播放了多长时间
            pts = synchronize_video(is, pFrame, pts);
            if(queue_picture(is, pFrame, pts) < 0)
            break;
        }
        av_free_packet(packet);
    }
    av_free(pFrame);
    return 0;
}
int our_get_buffer(struct AVCodecContext* c, AVFrame *pic)
{
    int ret = avcodec_default_get_buffer2(c, pic, NULL);
    uint64_t *pts = (uint64_t*)av_malloc(sizeof(uint64_t));
    *pts = global_video_pkt_pts;
    pic->opaque = pts;//将第一个包的时间磋保存到pFrame
    return ret;
}

void our_release_buffer(struct AVCodecContext* c, AVFrame *pic)
{
    if(pic)
    av_freep(&pic->opaque);
    avcodec_default_release_buffer(c, pic);
}

int stream_component_open(VideoState *is, int stream_index)
{
    AVFormatContext *pFormatCtx = is->pFormatCtx;
    AVCodecContext *codecCtx;
    AVCodec *codec;
    SDL_AudioSpec wanted_spec, spec;
    
    if(stream_index < 0 || stream_index >= pFormatCtx->nb_streams){
        return -1;
    }
    
    codecCtx = pFormatCtx->streams[stream_index]->codec;
    
    if(codecCtx->codec_type == AVMEDIA_TYPE_AUDIO){
        wanted_spec.freq = codecCtx->sample_rate;
        wanted_spec.format = AUDIO_S16SYS;
        wanted_spec.channels = codecCtx->channels;
        wanted_spec.silence = 0;
        wanted_spec.samples = SDL_AUDIO_BUFFER_SIZE;
        wanted_spec.callback = audio_callback;
        wanted_spec.userdata = is;
        
        if(SDL_OpenAudio(&wanted_spec, &spec)  < 0){
            fprintf(stderr, "SDL_OpenAudio: %s\n", SDL_GetError());
            return -1;
        }
    }
    //open decoder
    codec = avcodec_find_decoder(codecCtx->codec_id);
    if(!codec || (avcodec_open2(codecCtx, codec, NULL) < 0)){
        fprintf(stderr, "Unsupported codec!\n");
        return -1;
    }
    
    switch(codecCtx->codec_type){
        
        case AVMEDIA_TYPE_AUDIO:
        is->audioStream = stream_index;
        is->audio_st = pFormatCtx->streams[stream_index];
        is->audio_buf_size = 0;
        is->audio_buf_index = 0;
        memset(&is->audio_pkt, 0, sizeof(is->audio_pkt));
        packet_queue_init(&is->audioq);
        SDL_PauseAudio(0);
        break;
        
        case AVMEDIA_TYPE_VIDEO:
        is->videoStream = stream_index;
        is->video_st = pFormatCtx->streams[stream_index];
        
        is->frame_timer = (double)av_gettime() / 1000000.0;
        is->frame_last_delay = 40e-3;
        
        packet_queue_init(&is->videoq);
        is->video_tid = SDL_CreateThread(video_thread, is);
        
        codecCtx->get_buffer = our_get_buffer;
        codecCtx->release_buffer = our_release_buffer;
        break;
        
        default:
        break;
    }
    
    return 0;
}
int decode_thread(void *arg)
{
    VideoState *is = (VideoState*)arg;
    
    AVFormatContext *pFormatCtx;
    AVPacket pkt1, *packet = &pkt1;
    
    int video_index = -1;
    int audio_index = -1;
    int i;
    
    is->videoStream = -1;
    is->audioStream = -1;
    
    global_video_state = is;
    
    pFormatCtx = avformat_alloc_context();
    //will interrupt blocking function if we quit
    pFormatCtx->interrupt_callback = int_cb;
    
    //open video file
    if(avformat_open_input(&pFormatCtx, is->filename, NULL, 0) != 0)
    {
        fprintf(stderr, "%s", "Couldn't open file\n");
        return -1;
    }
    
    is->pFormatCtx = pFormatCtx;
    
    if(avformat_find_stream_info(pFormatCtx, NULL) < 0)
    {
        fprintf(stderr, "%s\n", "Couldn't find stream info");
        return -1;
    }
    
    av_dump_format(pFormatCtx, 0, is->filename, 0);
    
    for(i = 0; i < pFormatCtx->nb_streams; ++i){
        if(pFormatCtx->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO && video_index < 0)
        video_index = i;
        if(pFormatCtx->streams[i]->codec->codec_type == AVMEDIA_TYPE_AUDIO && audio_index < 0)
        audio_index = i;
    }
    
    if(audio_index >= 0)
    stream_component_open(is, audio_index);
    if(video_index >= 0)
    stream_component_open(is, video_index);
    
    if(is->videoStream < 0 || is->audioStream < 0)
    {
        fprintf(stderr, "%s: could not open codecs\n", is->filename);
        goto fail;
    }
    
    for(;;){
        if(is->quit){
            break;
        }
        if(is->audioq.size > MAX_AUDIOQ_SIZE || is->videoq.size > MAX_VIDEOQ_SIZE){
            SDL_Delay(10);
            continue;
        }
        if(av_read_frame(is->pFormatCtx, packet) < 0){
            if(pFormatCtx->pb && pFormatCtx->pb->error) {
                SDL_Delay(100); /* no error; wait for user input */
                continue;
            } else {
                break;
            }
        }
        if(packet->stream_index == is->videoStream){
            packet_queue_put(&is->videoq, packet);
        }else if(packet->stream_index == is->audioStream){
            packet_queue_put(&is->audioq, packet);
        }else
        av_free_packet(packet);
    }
    while(!is->quit)
    SDL_Delay(100);
    
fail:
    {
        SDL_Event event;
        event.type = FF_QUIT_EVENT;
        event.user.data1 = is;
        SDL_PushEvent(&event);
    }
    return 0;
}

int rint(double x)
{
    if(x >= 0)
    return (int)(x + 0.5);
    else
    return (int)(x - 0.5);
}

void video_display(VideoState *is) {
    
    SDL_Rect rect;
    VideoPicture *vp;
    AVPicture pict;
    float aspect_ratio;
    int w, h, x, y;
    int i;
    
    vp = &is->pictq[is->pictq_rindex];
    if(vp->bmp) {
        if(is->video_st->codec->sample_aspect_ratio.num == 0) {
            aspect_ratio = 0;
        } else {
            aspect_ratio = av_q2d(is->video_st->codec->sample_aspect_ratio) *
            is->video_st->codec->width / is->video_st->codec->height;
        }
        if(aspect_ratio <= 0.0) {
            aspect_ratio = (float)is->video_st->codec->width /
            (float)is->video_st->codec->height;
        }
        h = screen->h;
        w = ((int)rint(h * aspect_ratio)) & -3;
        if(w > screen->w) {
            w = screen->w;
            h = ((int)rint(w / aspect_ratio)) & -3;
        }
        x = (screen->w - w) / 2;
        y = (screen->h - h) / 2;
        
        rect.x = x;
        rect.y = y;
        rect.w = w;
        rect.h = h;
        SDL_DisplayYUVOverlay(vp->bmp, &rect);
    }
}
//获取音频帧的时间磋
double get_audio_clock(VideoState *is) {
    double pts;
    int hw_buf_size, bytes_per_sec, n;
    
    pts = is->audio_clock; /* maintained in the audio thread */
    hw_buf_size = is->audio_buf_size - is->audio_buf_index;
    bytes_per_sec = 0;
    n = is->audio_st->codec->channels * 2;
    if(is->audio_st) {
        bytes_per_sec = is->audio_st->codec->sample_rate * n;
    }
    if(bytes_per_sec) {
        pts -= (double)hw_buf_size / bytes_per_sec;
    }
    return pts;
}
void video_refresh_timer(void *userdata)
{
    VideoState *is = (VideoState *)userdata;
    VideoPicture *vp;
    double actual_delay, delay, sync_threshold, ref_clock, diff;
    
    if(is->video_st)
    {
        if(is->pictq_size == 0)
        {
            schedule_refresh(is, 1);
        }
        else
        {
            vp = &is->pictq[is->pictq_rindex];
            
            delay = vp->pts - is->frame_last_pts; /* the pts from last time */
            if(delay <= 0 || delay >= 1.0)
            {
                /* if incorrect delay, use previous one */
                delay = is->frame_last_delay;
            }
            /* save for next time */
            is->frame_last_delay = delay;
            is->frame_last_pts = vp->pts;
            
            /* update delay to sync to audio */
            ref_clock = get_audio_clock(is);
            diff = vp->pts - ref_clock;
            
            /* Skip or repeat the frame. Take delay into account
             FFPlay still doesn't "know if this is the best guess." */
            sync_threshold = (delay > AV_SYNC_THRESHOLD) ? delay : AV_SYNC_THRESHOLD;
            if(fabs(diff) < AV_NOSYNC_THRESHOLD)
            {
                if(diff <= -sync_threshold)
                {
                    delay = 0;
                }
                else if(diff >= sync_threshold)
                {
                    delay = 2 * delay;
                }
            }
            is->frame_timer += delay;
            /* computer the REAL delay */
            actual_delay = is->frame_timer - (av_gettime() / 1000000.0);
            if(actual_delay < 0.010)
            {
                /* Really it should skip the picture instead */
                actual_delay = 0.010;
            }
            schedule_refresh(is, (int)(actual_delay * 1000 + 0.5));
            /* show the picture! */
            video_display(is);
            
            /* update queue for next picture! */
            if(++is->pictq_rindex == VIDEO_PICTURE_QUEUE_SIZE)
            {
                is->pictq_rindex = 0;
            }
            SDL_LockMutex(is->pictq_mutex);
            is->pictq_size--;
            SDL_CondSignal(is->pictq_cond);
            SDL_UnlockMutex(is->pictq_mutex);
        }
    }
    else
    {
        schedule_refresh(is, 100);
    }
}

void alloc_picture(void *userdata) {
    
    VideoState *is = (VideoState *)userdata;
    VideoPicture *vp;
    
    vp = &is->pictq[is->pictq_windex];
    if(vp->bmp) {
        // we already have one make another, bigger/smaller
        SDL_FreeYUVOverlay(vp->bmp);
    }
    // Allocate a place to put our YUV image on that screen
    vp->bmp = SDL_CreateYUVOverlay(is->video_st->codec->width,
                                   is->video_st->codec->height,
                                   SDL_YV12_OVERLAY,
                                   screen);
    vp->width = is->video_st->codec->width;
    vp->height = is->video_st->codec->height;
    
    SDL_LockMutex(is->pictq_mutex);
    vp->allocated = 1;
    SDL_CondSignal(is->pictq_cond);
    SDL_UnlockMutex(is->pictq_mutex);
}

int main(int argc, char** argv)
{
    SDL_Event  event;
    VideoState *is = (VideoState *)av_mallocz(sizeof(VideoState));
    
    //char filename[] = "rtp://10.0.67.153:5004";
    //char filename[] = "E:\\Video\\menglong.mkv";
    char filename[] = "C:\\school.ts";
    av_register_all();
    avformat_network_init();
    
    if(SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_TIMER)) {
        fprintf(stderr, "Could not initialize SDL - %s\n", SDL_GetError());
        exit(1);
    }
    screen = SDL_SetVideoMode(640, 480, 0, 0);
    if(!screen) {
        fprintf(stderr, "SDL: could not set video mode - exiting\n");
        exit(1);
    }
    av_strlcpy(is->filename, filename, sizeof(filename));
    
    is->pictq_mutex = SDL_CreateMutex();
    is->pictq_cond = SDL_CreateCond();
    
    schedule_refresh(is, 40);
    
    is->parse_tid = SDL_CreateThread(decode_thread, is);
    
    if(!is->parse_tid){
        av_free(is);
        return -1;
    }
    for(;;){
        SDL_WaitEvent(&event);
        switch(event.type){
            case FF_QUIT_EVENT:
            case SDL_QUIT:  
            is->quit = 1;  
            SDL_Quit();  
            return 0;  
            break;  
            
            case FF_ALLOC_EVENT:  
            alloc_picture(event.user.data1);  
            break;  
            
            case FF_REFRESH_EVENT:  
            video_refresh_timer(event.user.data1);  
            break;  
            
            default:  
            break;  
        }  
    }  
    return 0;  
}
