//
//  ViewController.m
//  音频波形绘制
//
//  Created by 石川 on 2019/12/24.
//  Copyright © 2019 石川. All rights reserved.
//
#import <stdlib.h>
#import "ViewController.h"
#import "SeeAudio.h"
#import "SCPlayer.h"
#define screenW ([UIScreen mainScreen].bounds.size.width)
@interface ViewController ()<SCPlayerDelegate>
{
    AVURLAsset *asset;
    UIScrollView *vv;
    NSInteger ww;
}
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
   
    
SeeAudio *seec = [[SeeAudio alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:seec];
  
  
      
     AVURLAsset  *asset = [[AVURLAsset alloc]initWithURL:
                 [[NSBundle mainBundle] URLForResource:@"whenImissYou" withExtension:@"m4a"] options:nil];
        
       
        [seec renderPNGAudioPictogramLogForAsset:asset done:^(UIImage *image,NSInteger imageWidth) {
            UIScrollView *scrv = [[UIScrollView alloc] initWithFrame:self.view.bounds];
            [scrv setContentSize:CGSizeMake(imageWidth, 200)];
            [self.view addSubview:scrv];
            UIImageView *imgv = [[UIImageView alloc] initWithFrame:CGRectMake(0, 100, imageWidth, 200)];
            imgv.image = image;
            [scrv addSubview:imgv];
            [self.view addSubview:scrv];
            self->vv = scrv;
            
            
            SCPlayer *scp = [[SCPlayer alloc] initWithFrame:CGRectMake(0, 400, screenW, 300)];
            [scp replaceCurrentUrl:[NSString stringWithFormat:@"%@",[[NSBundle mainBundle] URLForResource:@"whenImissYou" withExtension:@"m4a"]]];
            scp.delegate = self;
            [self.view addSubview:scp];
            
            self->ww = imageWidth;
            
        }];
    
   
    UIView *v =[[UIView alloc] initWithFrame:CGRectMake(screenW/2, 0, 1, screenW)];
    v.backgroundColor = UIColor.redColor;
    [self.view addSubview:v];
    
}
-(void)timeRunAndTime:(NSInteger)runTime
{
    
  //线形运动，不要缓动
  [UIView animateWithDuration:26 delay:0.0 options:UIViewAnimationOptionCurveLinear animations:^{
      [self->vv setContentOffset:CGPointMake(self->ww-screenW, 0) animated:NO];
       } completion:^(BOOL finished) {
           
       }];
    
   
}
@end
