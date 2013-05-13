//
//  KNFFMpegAACEncoder.h
//  RtspTest
//
//  Created by ken on 13. 5. 13..
//  Copyright (c) 2013년 SH. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "avcodec.h"
#import "avformat.h"

@class KNFFmpegFrameReader;
@interface KNFFMpegAACEncoder : NSObject

@property (assign) AVCodecContext* codecCtx;
@property (assign) AVCodec* codec;

- (id)initWithReader:(KNFFmpegFrameReader *)reader;
- (void)encode:(AVFrame *)rawFrame completion:(void(^)(AVPacket* pkt))completion;
@end
