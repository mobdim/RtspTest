//
//  SHViewController.h
//  RtspTest
//
//  Created by ken on 13. 4. 25..
//  Copyright (c) 2013년 SH. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>

@interface SHViewController : UIViewController 

@property (retain, nonatomic) IBOutlet UIView* viewMovie;

- (IBAction)extract:(id)sender;
- (IBAction)mp3:(id)sender;

- (IBAction)backward:(id)sender;
- (IBAction)forward:(id)sender;
@end
