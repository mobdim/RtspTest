//
//  KNFFMpegRTSPSender.h
//  RtspTest
//
//  Created by ken on 13. 5. 8..
//  Copyright (c) 2013년 SH. All rights reserved.
//

#import <Foundation/Foundation.h>

#define RTSP_SEND_TCP   0
#define RTSP_SEND_UDP   1

@interface KNFFMpegRTSPSender : NSObject

- (id)initWithRTSPURL:(NSString *)url inputPath:(NSString *)inputPath sendOption:(int)opt;
- (BOOL)startSendFrame:(void(^)(BOOL fnish))completion;
@end
