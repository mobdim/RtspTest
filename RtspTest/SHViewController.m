//
//  SHViewController.m
//  RtspTest
//
//  Created by ken on 13. 4. 25..
//  Copyright (c) 2013년 SH. All rights reserved.
//

#import "SHViewController.h"
#import "KNFFmpegFrameReader.h"
#import "avformat.h"
#import "avcodec.h"
#import "time.h"
#import "timestamp.h"

#import "KNFFMpegRTSPSender.h"

@interface SHViewController () {
    AVFormatContext* oc;

    BOOL isSeek_;
}
@property (retain, nonatomic) KNFFmpegFrameReader* reader;
@property (retain, nonatomic) MPMoviePlayerController* movie;
@end

@implementation SHViewController

@synthesize viewMovie = _viewMovie;
@synthesize reader = _reader;
@synthesize movie = _movie;

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    av_register_all();
    avcodec_register_all();
    avformat_network_init();
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)extract:(id)sender {


    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        NSString* docPath = [NSString stringWithFormat:@"%@/gh.avi", documentsDirectory];
        
        
        NSString* filePath = [[NSBundle mainBundle] pathForResource:@"Ailee_720" ofType:@"mp4"];
        KNFFmpegFrameReader* r = [[KNFFmpegFrameReader alloc] initWithURL:filePath withOption:kNetNone];
        self.reader = r;
        [r release];

        char server[] = "rtp://222.112.235.244:554/live/saeha/ios";

        avformat_alloc_output_context2(&oc, 0, "rtsp", server);

        oc->duration = _reader.formatCtx->duration;

        NSLog(@"server : %s, duration : %lld", oc->filename, oc->duration);

        
        int e = avio_open2(&oc->pb, oc->filename, AVIO_FLAG_WRITE, NULL, NULL);
        if (e != 0) {
            NSLog(@"open----------->>>>>>>>>>%d", e);
            return;
        }
        
        NSLog(@"seekable : %d",         oc->pb->seekable);

        __block AVStream *vstream = avformat_new_stream( oc, NULL );
        if ( ! vstream )
            return;
        // initalize codec
        vstream->time_base = _reader.formatCtx->streams[_reader.videoStreamIndex]->time_base;
        vstream->duration = _reader.formatCtx->streams[_reader.videoStreamIndex]->duration;
        vstream->pts = _reader.formatCtx->streams[_reader.videoStreamIndex]->pts;
        vstream->avg_frame_rate = _reader.formatCtx->streams[_reader.videoStreamIndex]->avg_frame_rate;

        __block AVCodecContext* vcodec = vstream->codec;
        avcodec_copy_context(vcodec, _reader.formatCtx->streams[_reader.videoStreamIndex]->codec);
        vcodec->flags |= CODEC_FLAG_GLOBAL_HEADER;
        NSLog(@"%d:%d ID:%d  %d,%d, -- %d", vcodec->width, vcodec->height, vcodec->codec_id, vcodec->time_base.den, vcodec->time_base.num, oc->nb_streams);

        __block AVStream *astream = avformat_new_stream( oc, NULL );
        if ( ! astream )
            return;

        astream->time_base = _reader.formatCtx->streams[_reader.audioStreamIndex]->time_base;
        astream->duration = _reader.formatCtx->streams[_reader.audioStreamIndex]->duration;
        astream->pts = _reader.formatCtx->streams[_reader.audioStreamIndex]->pts;

        __block  AVCodecContext* acodec = astream->codec;
        avcodec_copy_context(acodec, _reader.formatCtx->streams[_reader.audioStreamIndex]->codec);
        acodec->flags |= CODEC_FLAG_GLOBAL_HEADER;



        __block BOOL pts_fail = NO;
        if(av_cmp_q(vcodec->sample_aspect_ratio, vstream->sample_aspect_ratio)){

            vstream->sample_aspect_ratio = vcodec->sample_aspect_ratio;
            
            vstream->time_base.den = 48000;
            vstream->time_base.num = 1001;
            
            vcodec->time_base.den = 48000;
            vcodec->time_base.num = 1001;

            pts_fail = YES;
        }
        
        
        AVDictionary *opts = 0;
	    av_dict_set(&opts, "rtsp_transport", "tcp", 0);
        e = avformat_write_header(oc, &opts);
        av_dict_free(&opts);
        if (e != 0) {
            NSLog(@"header----------->>>>>>>>>>%d", e);
            return;
        }
        NSLog(@"stream start");

        __block int readVFrame = 0;
        __block int readAFrame = 0;
        
        __block int_fast64_t video_pts;
        __block int_fast64_t audio_pts;
        __block int64_t start = av_gettime();
        [_reader readFrame:^(AVPacket *packet, int streamIndex) {
            
            int64_t end = av_gettime() - start;
            int64_t cur_pts = packet->pts;
            
//            if (isSeek_) {
//                
//                
//                if (packet->stream_index == 0)
//                    ++readVFrame;
//                
//                if (packet->stream_index == 1)
//                    ++readAFrame;
//                
//                
//                if ((readVFrame >= 1) && (readAFrame >= 1)){
//                    readVFrame = readAFrame = 0;
//                    isSeek_ = NO;
//                }else
//                    packet->pts = packet->dts = AV_NOPTS_VALUE;
//            }
//

//            packet->dts = AV_NOPTS_VALUE;
//            vstream->first_dts = AV_NOPTS_VALUE;
//            vstream->cur_dts = AV_NOPTS_VALUE;
//            astream->first_dts = AV_NOPTS_VALUE;
//            astream->cur_dts = AV_NOPTS_VALUE;

            
//            if (isSeek_) {
////                오디오/비디오 둘다적용후나갈것.
//                if (streamIndex == _reader.videoStreamIndex) {
////                    vstream->first_dts = packet->dts - 10000;
////                    vstream->cur_dts = packet->dts - 10000;
//                    
//                    vstream->first_dts = AV_NOPTS_VALUE;
//                    vstream->cur_dts = AV_NOPTS_VALUE;
//
//                    
//                    
//                    ++readVFrame;
//                }
//
//                if (streamIndex == _reader.audioStreamIndex) {
////                    astream->first_dts = packet->dts - 10000;
////                    astream->cur_dts = packet->dts - 10000;
//                    
//                    astream->first_dts = AV_NOPTS_VALUE;
//                    astream->cur_dts = AV_NOPTS_VALUE;
//
//                    
//                    ++readAFrame;
//                }
//                
//                if (readVFrame > 1 && readAFrame > 1)
//                    isSeek_ = NO;
//            }

            if (av_interleaved_write_frame(oc, packet) != 0) {
                start = av_gettime();
                return;
            }
            avio_flush(oc->pb);
            
            
            if (streamIndex == _reader.videoStreamIndex) {
                
                int64_t sync = cur_pts - video_pts;
//                NSLog(@"-----------v pts  : %lld", sync);
                if ((sync > end) && (sync  < 1000000)) {
                    av_usleep((sync - end) * 10);
                }
                video_pts =  cur_pts;
            }
            
            if (streamIndex == _reader.audioStreamIndex) {
                
                int64_t sync = cur_pts - audio_pts;
//                NSLog(@"-----------a pts  : %lld", sync);
                if ((sync > end) && (sync  < 1000000)) {
                    av_usleep((sync - end) * 10);
                }
                audio_pts =  cur_pts;
            }
            
            start = av_gettime();
            

        } completion:^(BOOL finish) {
            
            avcodec_close(vcodec);
            vcodec = NULL;
            
            avcodec_close(acodec);
            acodec = NULL;

            av_free(oc);
            
            oc = NULL;

            NSLog(@"@!!!DONE");
        }];
    });



    dispatch_async(dispatch_get_main_queue(), ^{
        NSURL* url = [[NSBundle mainBundle] URLForResource:@"Ailee_720" withExtension:@"mp4"];
        
        MPMoviePlayerController* m = [[MPMoviePlayerController alloc] initWithContentURL:url];
        self.movie = m;
        _movie.view.frame = _viewMovie.bounds;
        [_viewMovie addSubview:_movie.view];
        [m release];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(MPMoviePlayerLoadStateDidChange:)
                                                     name:MPMoviePlayerLoadStateDidChangeNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(MPMoviePlaybackStateDidChange:)
                                                     name:MPMoviePlayerPlaybackStateDidChangeNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(MPMoviePlaybackDidFinish:)
                                                     name:MPMoviePlayerPlaybackDidFinishNotification
                                                   object:nil];
        
        
        
        [_movie setControlStyle:MPMovieControlStyleEmbedded];
        [_movie setFullscreen:NO];
        [_movie setShouldAutoplay:NO];
        [_movie setMovieSourceType:MPMovieSourceTypeFile];
        [_movie setScalingMode:MPMovieScalingModeAspectFit];
        [_movie prepareToPlay];
    });

    
    
    NSURL* url = [[NSBundle mainBundle] URLForResource:@"Ailee_720" withExtension:@"mp4"];

    MPMoviePlayerController* m = [[MPMoviePlayerController alloc] initWithContentURL:url];
    self.movie = m;
    _movie.view.frame = _viewMovie.bounds;
    [_viewMovie addSubview:_movie.view];
    [m release];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(MPMoviePlayerLoadStateDidChange:)
                                                 name:MPMoviePlayerLoadStateDidChangeNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(MPMoviePlaybackStateDidChange:)
                                                 name:MPMoviePlayerPlaybackStateDidChangeNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(MPMoviePlaybackDidFinish:)
                                                 name:MPMoviePlayerPlaybackDidFinishNotification
                                               object:nil];
    
    

    [_movie setControlStyle:MPMovieControlStyleEmbedded];
    [_movie setFullscreen:NO];
    [_movie setShouldAutoplay:NO];
    [_movie setMovieSourceType:MPMovieSourceTypeFile];
    [_movie setScalingMode:MPMovieScalingModeAspectFit];
    [_movie prepareToPlay];
}

- (void)MPMoviePlayerLoadStateDidChange:(NSNotification *)notification {
    
    NSLog(@"MOVIE STATE : %d", _movie.loadState);
    
    if ((_movie.loadState & MPMovieLoadStatePlaythroughOK) == MPMovieLoadStatePlaythroughOK)
    {
        [_movie play];
        
        NSString* filePath = [[NSBundle mainBundle] pathForResource:@"Ailee_720" ofType:@"mp4"];
        KNFFmpegFrameReader* r = [[KNFFmpegFrameReader alloc] initWithURL:filePath withOption:kNetNone];
        NSLog(@"content play length is %g (%lld) seconds", _movie.duration, r.formatCtx->duration);
        [r release];
    }
}

int64_t prevSeek = 0;
- (void)MPMoviePlaybackStateDidChange:(NSNotification *)notification  {
    
    NSLog(@"CURRENT TIME : %f : %lld", _movie.currentPlaybackTime, (int64_t)(_movie.currentPlaybackTime * 100000));

    
    if (_movie.playbackState == MPMoviePlaybackStatePlaying) {
        NSLog(@"State : MPMoviePlaybackStatePlaying");
        
        if (isSeek_) {
            int64_t seekTime = ((int64_t)(_movie.currentPlaybackTime * 100000))/2;
            if (prevSeek == seekTime)
                return;
            NSLog(@"----------------->>MP SEEK !!!!!!!!!!");
            
            [_reader seekFrame:seekTime];
          
            prevSeek = seekTime;
//            isSeek_ = NO;
        }
    }

    if (_movie.playbackState == MPMoviePlaybackStatePaused) {
        NSLog(@"State : MPMoviePlaybackStatePaused");
    }

    if (_movie.playbackState == MPMoviePlaybackStateStopped) {
        NSLog(@"State : MPMoviePlaybackStateStopped");
    }

    if (_movie.playbackState == MPMoviePlaybackStateStopped) {
        NSLog(@"State : MPMoviePlaybackStateStopped");
    }
    
    if (_movie.playbackState == MPMoviePlaybackStateSeekingBackward) {
        NSLog(@"State : MPMoviePlaybackStateSeekingBackward");
        
        isSeek_ = YES;
    }
    
    if (_movie.playbackState == MPMoviePlaybackStateSeekingForward) {
        NSLog(@"State : MPMoviePlaybackStateSeekingForward");
        
        isSeek_ = YES;
    }
}

- (void)MPMoviePlaybackDidFinish:(NSNotification *)notification  {
    NSLog(@"State : MPMoviePlaybackDidFinish");
}

- (IBAction)mp3:(id)sender {

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        NSString* filePath = [[NSBundle mainBundle] pathForResource:@"Ailee_720" ofType:@"mp4"];
        NSString* rtspURL = @"222.112.235.244:554/live/saeha/ios";
        
        
        KNFFMpegRTSPSender* sender = [[KNFFMpegRTSPSender alloc] initWithRTSPURL:rtspURL
                                                                       inputPath:filePath
                                                                      sendOption:RTSP_SEND_TCP];
        [sender startSendFrame:^(BOOL fnish) {
            if (fnish) {
                [sender release];
            }
        }];
    });
}

- (IBAction)backward:(id)sender {

    isSeek_ = YES;
    [_reader seekFrame:4925754/2];
}

- (IBAction)forward:(id)sender {

    isSeek_ = YES;
    [_reader seekFrame:12404058/2];

}

@end
