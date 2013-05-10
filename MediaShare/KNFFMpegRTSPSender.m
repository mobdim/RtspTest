//
//  KNFFMpegRTSPSender.m
//  RtspTest
//
//  Created by ken on 13. 5. 8..
//  Copyright (c) 2013년 SH. All rights reserved.
//

#import "KNFFMpegRTSPSender.h"
#import "KNFFmpegFrameReader.h"
#import "time.h"

@interface KNFFMpegRTSPSender() {
    
    AVFormatContext* rtspCtx_;
}

@property (copy, nonatomic) NSString* rtspURL;
@property (copy, nonatomic) NSString* inputURL;
@property (assign) int sendOption;
@property (retain, nonatomic) KNFFmpegFrameReader* reader;

- (BOOL)initInput;
- (BOOL)initOutput;
- (void)genVideoStream;
- (void)genAudioStream;
- (BOOL)writeRTSPHeader;

@end

@implementation KNFFMpegRTSPSender

@synthesize rtspURL         = _rtspURL;
@synthesize inputURL        = _inputURL;
@synthesize sendOption      = _sendOption;
@synthesize reader          = _reader;

#pragma mark - View Cycle
- (void)dealloc {
    
    [_rtspURL release];
    [_inputURL release];
    
    [_reader release];
    
    if (rtspCtx_) {
        avio_close(rtspCtx_->pb);
        avformat_free_context(rtspCtx_);
        rtspCtx_ = NULL;
    }
    
    avformat_network_deinit();
    
    [super dealloc];
}

- (id)initWithRTSPURL:(NSString *)url inputPath:(NSString *)inputPath sendOption:(int)opt {

    self = [super init];
    if (self) {
        
        avformat_network_init();

        self.rtspURL    = [NSString stringWithFormat:@"rtp://%@", url];
        self.inputURL   = inputPath;
        self.sendOption = opt;
    }
    return self;
}


#pragma mark - Private
- (BOOL)initInput {
    
    KNFFmpegFrameReader* r = [[KNFFmpegFrameReader alloc] initWithURL:_inputURL
                                                           withOption:kNetNone];
    if (!r)
        return NO;

    self.reader = r;
    [r release];
    
    return YES;
}

- (BOOL)initOutput {
    
    int ret = avformat_alloc_output_context2(&rtspCtx_, 0, "rtsp", [_rtspURL UTF8String]);
    if (ret < 0) {
        NSLog(@"avformat_alloc_output_context2 error : %d", ret);
        return NO;
    }
    rtspCtx_->duration = _reader.formatCtx->duration;

    ret = avio_open2(&rtspCtx_->pb, rtspCtx_->filename, AVIO_FLAG_WRITE, NULL, NULL);
    if (ret != 0) {
        NSLog(@"avio_open2 error : %d", ret);
        return NO;
    }
    
    
    return YES;
}

- (void)genVideoStream {
    
    if (_reader.videoStreamIndex == -1)
        return;
    
    AVStream* vstream = avformat_new_stream(rtspCtx_, NULL);
    if (!vstream)
        return;
    
    vstream->time_base = _reader.formatCtx->streams[_reader.videoStreamIndex]->time_base;
    vstream->duration = _reader.formatCtx->streams[_reader.videoStreamIndex]->duration;
    vstream->pts = _reader.formatCtx->streams[_reader.videoStreamIndex]->pts;
    vstream->avg_frame_rate = _reader.formatCtx->streams[_reader.videoStreamIndex]->avg_frame_rate;
    
    AVCodecContext* vcodec = vstream->codec;
    avcodec_copy_context(vcodec, _reader.formatCtx->streams[_reader.videoStreamIndex]->codec);
    vcodec->flags |= CODEC_FLAG_GLOBAL_HEADER;
}

- (void)genAudioStream {
    
    if (_reader.audioStreamIndex == -1)
        return;
    
    AVStream* astream = avformat_new_stream(rtspCtx_, NULL);
    if (!astream)
        return;
    
    astream->time_base = _reader.formatCtx->streams[_reader.audioStreamIndex]->time_base;
    astream->duration = _reader.formatCtx->streams[_reader.audioStreamIndex]->duration;
    astream->pts = _reader.formatCtx->streams[_reader.audioStreamIndex]->pts;

    
    AVCodecContext* acodec = astream->codec;
    avcodec_copy_context(acodec, _reader.formatCtx->streams[_reader.audioStreamIndex]->codec);
    acodec->flags |= CODEC_FLAG_GLOBAL_HEADER;
}

- (BOOL)writeRTSPHeader {

    AVDictionary* opts = 0;
    if (_sendOption == RTSP_SEND_TCP)
        av_dict_set(&opts, "rtsp_transport", "tcp", 0);
    
    if (_sendOption == RTSP_SEND_UDP)
        av_dict_set(&opts, "rtsp_transport", "udp", 0);
    
    int ret = avformat_write_header(rtspCtx_, opts ? &opts : 0);
    if (ret != 0) {
        NSLog(@"avformat_write_header error : %d", ret);
        return NO;
    }
    av_dump_format(rtspCtx_, 0, rtspCtx_->filename, 1);
    NSLog(@"\n");
    
    return YES;
}

- (BOOL)startSendFrame:(void(^)(BOOL fnish))completion {
    
    if ([self initInput] == NO)
        return NO;
    
    if ([self initOutput] == NO)
        return NO;
    
    [self genVideoStream];
    [self genAudioStream];
    
    if ([self writeRTSPHeader] == NO)
        return NO;
    
    
    NSLog(@"@RTSP Send start.");
    __block int_fast64_t video_pts = 0;
    __block int_fast64_t audio_pts = 0;
    __block int64_t start = av_gettime();
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        ///블록 안에서 디버그 메세지 찍으면 싱크 틀어짐.
        
        [_reader readFrame:^(AVPacket *packet, int streamIndex) {
            
            int64_t end = av_gettime() - start;
            
            if (av_interleaved_write_frame(rtspCtx_, packet) != 0) {
                start = av_gettime();
                return;
            }
            
            if (streamIndex == _reader.videoStreamIndex) {
                
                int64_t sync = packet->pts - video_pts;
                //                NSLog(@"-----------v pts  : %lld", sync);
                if ((sync > end) && (sync  < 1000000)) {
                    av_usleep((sync - end) * 10);
                }
                video_pts =  packet->pts;
            }
            
            if (streamIndex == _reader.audioStreamIndex) {
                
                int64_t sync = packet->pts - audio_pts;
                //                NSLog(@"-----------a pts  : %lld", sync);
                if ((sync > end) && (sync  < 1000000)) {
                    av_usleep((sync - end) * 10);
                }
                audio_pts =  packet->pts;
            }

            start = av_gettime();

        } completion:^(BOOL finish) {

            if (rtspCtx_) {
                avio_close(rtspCtx_->pb);
                avformat_free_context(rtspCtx_);
                rtspCtx_ = NULL;
            }

            NSLog(@"@RTSP Send End.");
            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(YES);
                });
            }
        }];
    });
    
    return YES;
}
@end
