采用了新方法avcodec_parameters_to_context(WTCodecCtx, stream->codecpar) 
替代 WTCodecCtx=stream->codec;

用avcodec_send_packet(WTCodecCtx, &packet); 和avcodec_receive_frame(WTCodecCtx, WTFrame);
替换了之前的avcodec_decode_video2(WTCodecCtx, WTFrame, &frameFinished, &packet);
需要删除有关 SDL的项目,才能编译通过.
