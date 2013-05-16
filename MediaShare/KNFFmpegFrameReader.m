//
//  KNFFmpegFileReader.m
//  GLKDrawTest
//
//  Created by Choi Yeong Hyeon on 12. 11. 25..
//  Copyright (c) 2012년 Choi Yeong Hyeon. All rights reserved.
//

#import "KNFFmpegFrameReader.h"

@interface KNFFmpegFrameReader() {
    BOOL isCancelReadFrame_;
    KNNetOption netOption_;

    BOOL isCancelForSeek_;
    int64_t seekTime_;
    void(^seekBlock_)(void);
    
    
    void(^readFrameBlock_)(AVPacket*, int);
    void(^completionBlock_)(BOOL);
}

@property (copy, nonatomic) NSString* inputURL;
@property (assign) int videoStreamIndex;
@property (assign) int audioStreamIndex;

@end

@implementation KNFFmpegFrameReader
@synthesize videoCodecCtx       = _videoCodecCtx;
@synthesize audioCodecCtx       = _audioCodecCtx;
@synthesize formatCtx           = _formatCtx;
@synthesize inputURL            = _inputURL;
@synthesize videoStreamIndex    = _videoStreamIndex;
@synthesize audioStreamIndex    = _audioStreamIndex;


- (void)dealloc {
    [_inputURL release];
    
    if (_formatCtx) {
        avformat_close_input(&_formatCtx);
        _formatCtx = NULL;
    }
    [super dealloc];
}

- (id)initWithURL:(NSString *)url withOption:(KNNetOption)opt {

    self = [super init];
    if (self) {
        
        av_register_all();
        avcodec_register_all();

        _videoStreamIndex = _audioStreamIndex = -1;
        
        self.inputURL   = url;
        netOption_      = opt;
        seekTime_       = -1;
        if ([self initInput] == NO) {
            return nil;
            [self release];
        }
    }
    return self;
}

- (BOOL)initInput {
    
    AVDictionary *opts = 0;
    if (netOption_ == kNetTCP)
        av_dict_set(&opts, "rtsp_transport", "tcp", 0);
    if (netOption_ == kNetUDP)
        av_dict_set(&opts, "rtsp_transport", "udp", 0);
        
    if (avformat_open_input(&_formatCtx, [_inputURL UTF8String], 0, opts ? &opts : 0) != 0) {
        NSLog(@"avformat_open_input failed.");
        av_dict_free(&opts);
        return NO;
    }
    av_dict_free(&opts);
    
    if (avformat_find_stream_info(_formatCtx, 0) < 0) {
        NSLog(@"avformat_find_stream_info failed.");
        return NO;
    }
    
    for (int i = 0; i < _formatCtx->nb_streams; i++) {
        if (_formatCtx->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO) {
            _videoStreamIndex = i;
            break;
        }
    }
    
    for (int i = 0; i < _formatCtx->nb_streams; i++) {
        if (_formatCtx->streams[i]->codec->codec_type == AVMEDIA_TYPE_AUDIO) {
            _audioStreamIndex = i;
            break;
        }
    }

    if (_videoStreamIndex != -1) {
        _videoCodecCtx = _formatCtx->streams[_videoStreamIndex]->codec;
    }
    
    if (_audioStreamIndex != -1) {
        _audioCodecCtx = _formatCtx->streams[_audioStreamIndex]->codec;
    }
    
//    if (_videoStreamIndex == -1 && _audioStreamIndex == -1)
//        return NO;
    
    return YES;
}

/*
- (void)readFrame:(void(^)(AVPacket* packet, int streamIndex))readBlock
       completion:(void(^)(BOOL finish))completion {

    if (cancelReadFrame_) {
        NSLog(@"Frame read canceled.");
        return;
    }
    
    AVPacket packet;
    av_init_packet(&packet);
    BOOL cancel = NO;

    while (av_read_frame(_formatCtx, &packet) >= 0) {
        
        @synchronized(self){
            if (readBlock) {
                readBlock(&packet, packet.stream_index);
            }
            av_free_packet(&packet);
            av_init_packet(&packet);
        }
        
        if (cancelReadFrame_) {
            cancel = YES;
            if (completion)
                completion(cancel);
            cancel = NO;
            break;
        }
    }
    
    if (completion) {
        completion(!cancel);
    }
}
*/


- (void)readFrame:(void(^)(AVPacket* packet, int streamIndex))readBlock
       completion:(void(^)(BOOL finish))completion {
    
    if (isCancelReadFrame_) {
        NSLog(@"Frame read canceled.");
        return;
    }
    
    if (readFrameBlock_ == nil)
        readFrameBlock_ = [readBlock copy];
    
    if (completionBlock_ == nil)
        completionBlock_ = [completion copy];
    
    AVPacket packet;
    av_init_packet(&packet);
    BOOL cancel = NO;
    while (av_read_frame(_formatCtx, &packet) >= 0) {

        @synchronized(self){
            
            if (readBlock) {
                readBlock(&packet, packet.stream_index);
            }
            av_free_packet(&packet);
            av_init_packet(&packet);
        }
        
        
        if (isCancelReadFrame_) {
            cancel = YES;
            if (!isCancelForSeek_ && completion)
                completion(cancel);
            break;
        }
    }
    
    if (!isCancelForSeek_ && completion && isCancelReadFrame_ == NO) {
        completion(!cancel);
    }
    isCancelReadFrame_ = NO;
    
    if (isCancelForSeek_) {
        
        dispatch_async(dispatch_get_current_queue(), ^{
            seekBlock_();
        });
    }
}

- (void)cancelReadFrameWithSeek:(BOOL)forSeek {
    @synchronized(self) {
        isCancelForSeek_ = forSeek;
        isCancelReadFrame_ = YES;
    }
}

- (void)seekFrame:(int64_t)micSec {
    
    NSLog(@"@SEEK Start");
    
    @synchronized(self) {
        
        if (seekBlock_) {
            [seekBlock_ release];
            seekBlock_ = nil;
        }
        
        seekBlock_ = [^{
            
            int flag = 0;
            if (micSec < seekTime_)
                flag = AVSEEK_FLAG_BACKWARD;
            
            isCancelForSeek_    = NO;
            seekTime_           = micSec;
            
//            int ret = avformat_seek_file(_formatCtx, -1, 0, seekTime_, _formatCtx->duration, flag);
            int ret = av_seek_frame(_formatCtx, _audioStreamIndex, seekTime_, flag);
            NSLog(@"@SEEK result : %d, time : %lld", ret, seekTime_);

            [self readFrame:readFrameBlock_ completion:completionBlock_];
            
        } copy];

        [self cancelReadFrameWithSeek:YES];
    }
}
@end
