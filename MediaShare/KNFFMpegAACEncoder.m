//
//  KNFFMpegAACEncoder.m
//  RtspTest
//
//  Created by ken on 13. 5. 13..
//  Copyright (c) 2013년 SH. All rights reserved.
//

#import "KNFFMpegAACEncoder.h"
#import "KNFFmpegFrameReader.h"


static int check_sample_fmt(AVCodec *codec, enum AVSampleFormat sample_fmt)
{
    const enum AVSampleFormat *p = codec->sample_fmts;
    
    while (*p != AV_SAMPLE_FMT_NONE) {
        if (*p == sample_fmt)
            return 1;
        p++;
    }
    return 0;
}

/* just pick the highest supported samplerate */
static int select_sample_rate(AVCodec *codec)
{
    const int *p;
    int best_samplerate = 0;
    
    if (!codec->supported_samplerates)
        return 44100;
    
    p = codec->supported_samplerates;
    while (*p) {
        best_samplerate = FFMAX(*p, best_samplerate);
        p++;
    }
    return best_samplerate;
}

/* select layout with the highest channel count */
static int select_channel_layout(AVCodec *codec)
{
    const uint64_t *p;
    uint64_t best_ch_layout = 0;
    int best_nb_channels   = 0;
    
    if (!codec->channel_layouts)
        return AV_CH_LAYOUT_STEREO;
    
    p = codec->channel_layouts;
    while (*p) {
        int nb_channels = av_get_channel_layout_nb_channels(*p);
        
        if (nb_channels > best_nb_channels) {
            best_ch_layout    = *p;
            best_nb_channels = nb_channels;
        }
        p++;
    }
    return best_ch_layout;
}


@implementation KNFFMpegAACEncoder

@synthesize codecCtx = _codecCtx;
@synthesize codec = _codec;

- (void)dealloc {
    
    avcodec_close(_codecCtx);
    _codecCtx = NULL;
    
    [super dealloc];
}

- (id)initWithReader:(KNFFmpegFrameReader *)reader {
    self = [super init];
    if (self) {
        
        if (reader.audioStreamIndex == -1){
            NSLog(@"audio stream index error.");
            [self release];
            return nil;
        }
            

        _codec = avcodec_find_encoder(AV_CODEC_ID_AAC);
        if (_codec == NULL) {
            NSLog(@"avcodec_find_encoder error.");
            [self release];
            return nil;
        }
        
        _codecCtx                   = avcodec_alloc_context3(_codec);
        _codecCtx->bit_rate         = reader.audioCodecCtx->bit_rate;
        _codecCtx->sample_rate      = reader.audioCodecCtx->sample_rate;
        _codecCtx->sample_fmt       = AV_SAMPLE_FMT_S16;
        _codecCtx->channels         = reader.audioCodecCtx->channels;
        _codecCtx->channel_layout   = reader.audioCodecCtx->channel_layout;
        _codecCtx->profile          = FF_PROFILE_AAC_MAIN;
        _codecCtx->time_base.num    = 1;//reader.audioCodecCtx->time_base.num;
        _codecCtx->time_base.den    = 48000;//reader.audioCodecCtx->time_base.den;
        _codecCtx->codec_type       = AVMEDIA_TYPE_AUDIO;
        _codecCtx->flags            |= CODEC_FLAG_GLOBAL_HEADER;
        
//        NSLog(@"AAC Enc Info : bitrate : %d, sample rate : %d", _codecCtx->bit_rate, _codecCtx->sample_rate);
        
//        _codecCtx                   = avcodec_alloc_context3(_codec);
//        _codecCtx->bit_rate = 12800;;
//        _codecCtx->sample_rate = select_sample_rate(_codec);
//        _codecCtx->channel_layout = reader.audioCodecCtx->channel_layout;
//        _codecCtx->channels = reader.audioCodecCtx->channels;
//        _codecCtx->sample_fmt       = AV_SAMPLE_FMT_S16;
//        _codecCtx->profile          = FF_PROFILE_AAC_MAIN;
//                _codecCtx->codec_type       = AVMEDIA_TYPE_AUDIO;
//        _codecCtx->flags            |= CODEC_FLAG_GLOBAL_HEADER;
//        _codecCtx->time_base.num    = reader.audioCodecCtx->time_base.num;
//        _codecCtx->time_base.den    = reader.audioCodecCtx->time_base.den;


        if (avcodec_open2(_codecCtx, _codec, NULL) < 0) {
            NSLog(@"avcodec_open2 error.");
            [self release];
            return nil;
        }
    }
    return self;
}

- (void)encode:(uint8_t*) buff size:(int)size completion:(void(^)(AVPacket* pkt))completion {
    
    AVPacket packet;
    av_init_packet(&packet);
    packet.data = NULL;
    packet.size = 0;
    
    AVFrame* pcmFrame = avcodec_alloc_frame();
    pcmFrame->nb_samples = _codecCtx->frame_size;
    pcmFrame->format = _codecCtx->sample_fmt;
    pcmFrame->channel_layout = _codecCtx->channel_layout;
    pcmFrame->channels = av_get_channel_layout_nb_channels(_codecCtx->channel_layout);
    
//    int buffer_size = av_samples_get_buffer_size(NULL, _codecCtx->channels, _codecCtx->frame_size,
//                                             _codecCtx->sample_fmt, 0);
//    uint8_t* samples = av_malloc(buffer_size);
//    memset(samples, 0, buffer_size);
//    memcpy(samples, buff, size);
//    int ret = avcodec_fill_audio_frame(pcmFrame, _codecCtx->channels, _codecCtx->sample_fmt, (const uint8_t *)samples, buffer_size, 0);
    
    int buffer_size = size;
    uint8_t* samples = av_malloc(buffer_size);
    memset(samples, 0, buffer_size);
    memcpy(samples, buff, size);
    int ret = avcodec_fill_audio_frame(pcmFrame, _codecCtx->channels, _codecCtx->sample_fmt, (const uint8_t *)samples, buffer_size, 0);

    int got_packet_ptr = 0;
    ret = avcodec_encode_audio2(_codecCtx, &packet, pcmFrame, &got_packet_ptr);
    
    if (!got_packet_ptr) {
        NSLog(@"avcodec_encode_audio2 error : %d", ret);
        
        av_freep(&samples);
        samples = NULL;
        avcodec_free_frame(&pcmFrame);

        if (completion)
            completion(nil);
        
        return;
    }
        
    if (completion)
        completion(&packet);
    
    av_free_packet(&packet);
    
    av_freep(&samples);
    samples = NULL;
    avcodec_free_frame(&pcmFrame);
}
@end
