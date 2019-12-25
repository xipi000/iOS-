//
//  ViewController.m
//  音频波形绘制
//
//  Created by 石川 on 2019/12/24.
//  Copyright © 2019 石川. All rights reserved.
//

#import "ViewController.h"
#import "SeeAudio.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.whiteColor;
    SeeAudio *seeAu = [[SeeAudio alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:seeAu];
}


@end
