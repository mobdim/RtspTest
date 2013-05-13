//
//  KNFFMpegAACEncoder.m
//  RtspTest
//
//  Created by ken on 13. 5. 13..
//  Copyright (c) 2013년 SH. All rights reserved.
//

#import "KNFFMpegAACEncoder.h"
#import "KNFFmpegFrameReader.h"


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
            

        _codec = avcodec_find_encoder(CODEC_ID_AAC);
        if (_codec == NULL) {
            NSLog(@"avcodec_find_encoder error.");
            [self release];
            return nil;
        }
        
        _codecCtx = avcodec_alloc_context3(_codec);
        _codecCtx->bit_rate = reader.audioCodecCtx->bit_rate;
        _codecCtx->sample_rate = reader.audioCodecCtx->sample_rate;
        _codecCtx->sample_fmt = AV_SAMPLE_FMT_S16;
        _codecCtx->channels = reader.audioCodecCtx->channels;
        _codecCtx->profile = FF_PROFILE_AAC_MAIN;
        _codecCtx->time_base.num = reader.audioCodecCtx->time_base.num;
        _codecCtx->time_base.den = reader.audioCodecCtx->time_base.den;
        _codecCtx->codec_type = AVMEDIA_TYPE_AUDIO;
        
        if (avcodec_open2(_codecCtx, _codec, NULL) < 0) {
            NSLog(@"avcodec_open2 error.");
            [self release];
            return nil;
        }
    }
    return self;
}

- (void)encode:(AVFrame *)rawFrame completion:(void(^)(AVPacket* pkt))completion {
    
    AVPacket packet;
    av_init_packet(&packet);

    int got_packet_ptr = 0;
    avcodec_encode_audio2(_codecCtx, &packet, rawFrame, &got_packet_ptr);
    
    if (!got_packet_ptr) {
        NSLog(@"avcodec_encode_audio2 error");
        av_free_packet(&packet);
    }
    
    if (completion)
        completion(&packet);
    
    av_free_packet(&packet);
}
@end
