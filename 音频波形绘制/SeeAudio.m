//
//  SeeAudio.m
//  音频波形绘制
//
//  Created by 石川 on 2019/12/24.
//  Copyright © 2019 石川. All rights reserved.
//

#import "SeeAudio.h"
#import <AVFoundation/AVFoundation.h>
#import <stdlib.h>
#define noiseFloor (-50.0)
#define decibel(amplitude) (20 * log10( fabsf(amplitude)/32767.0 )) //转换为[0 - 100]
#define minMaxX(x,mn,mx) (x<=mn?mn:(x>=mx?mx:x)) //(x<=noiseFloor?noiseFloor:(x>=0?0:x)
#define spaceX 4;
/*
 if(x<=-50){
    return -50;
 }else{
     if(x>=0){
         return 0;
    }else{
       return x;
   }
 }
 
 */
@interface SeeAudio ()
{
    /*
     1.为了音视频的编辑显示以及其他处理，需要设置一个最的小标准，因而产生CMTime，
     （eg:如果音视频编辑器上的一格，表示好几帧，那么这几帧无法拆分）
     2.eg：0.001s 播放了 1 帧，用CMTime表示，最好是一个CMTime的value增加 1 ，音视频增加1帧。
     （只要设置timescale=1000，value = 0.001s * （1000份/s）= 1 份 ）
     3.不能以增加零点几个CMTime的value，音视频增加1帧，这样就没有意义了，所以只能大，可以用增加几个CMTime的value，音视频增加1帧。
     eg：如果设置 timescale = 10000  CMTime的value增加10，音视频增加1帧。
     
     typedef struct {
     CMTimeValue value; // 当前的CMTimeValue 的值
     CMTimeScale timescale; //时间尺  时间基  当前的CMTimeValue 的参考标准 ( 即把1s分为多少份)
     CMTimeFlags flags;
     CMTimeEpoch epoch;
     } CMTime
     
     eg:timescale = 1000 份/s; 时间 2.5s 转换为CMTime 的value为多大
     value = 2.5 * 1000 = 2500;
     
     真实时间 = value/timescale = （2500 份） / （1000 份/s）= 2.5s;
     */
    int64_t totalSamples; //时间标尺下的总时长（CMTime value）（timescale 即把1s分为多少份 ）
    
    AVURLAsset *asset;
    UIImageView *imageView;
    AVPlayer *p;
    
    int targetOverDraw;
    int tickHeight;
    float duration;
    UInt32 channelCount;
    Float32 maximum;
    NSMutableData *fullSongData;
    int noisyFloot;
    CGFloat workDeskWidth;
    int allTime;
}
@end


@implementation SeeAudio

-(instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    [self tese1];
    return self;
}
-(void)tese1
{
    
    targetOverDraw = 1;
    tickHeight = 40;
    noisyFloot = -50;
    workDeskWidth = 0;
    
    
    asset = [[AVURLAsset alloc]initWithURL:[[NSBundle mainBundle] URLForResource:@"whenImissYou" withExtension:@"mp3"] options:nil];
    imageView.image =nil;
    totalSamples = asset.duration.value;
    AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:asset];
    p = [[AVPlayer  alloc] initWithPlayerItem:item];
    [p play];
    
    NSLog(@"totalSamples=%lld",totalSamples);
    NSLog(@"时间标尺-timescale=%d",asset.duration.timescale);
    allTime = (int)asset.duration.value/asset.duration.timescale; 
    workDeskWidth = 20 * allTime;
    
    
    
    [self renderPNGAudioPictogramLogForAsset:asset done:^(UIImage *image, UIImage *selectedImage,NSInteger imageWidth) {
        UIScrollView *scrv = [[UIScrollView alloc] initWithFrame:self.bounds];
        [scrv setContentSize:CGSizeMake(imageWidth, 400)];
        [self addSubview:scrv];
        UIImageView *imgv = [[UIImageView alloc] initWithFrame:CGRectMake(0, 100, imageWidth, 400)];
        imgv.image = image;
        [scrv addSubview:imgv];
    }];
    
}
- (void)renderPNGAudioPictogramLogForAsset:(AVURLAsset *)songAsset
                                      done:(void(^)(UIImage *image, UIImage *selectedImage,NSInteger imageWidth))done
{
    // TODO: break out subsampling code
    NSLog(@"self.frame.size.with:%f",[UIScreen mainScreen].scale);
    CGFloat widthInPixels =  workDeskWidth * [UIScreen mainScreen].scale;
    CGFloat heightInPixels = (self.frame.size.height) * [UIScreen mainScreen].scale;
    
    NSError *error = nil;
    //创建多媒体阅读器
    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:songAsset error:&error];
    //筛选出audio
    NSArray *audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
    //获取其中的一个音频轨道
    AVAssetTrack *songTrack =[audioTracks objectAtIndex:0];
    //CMTime  时间 = value / 时间基
    duration = songAsset.duration.value/songAsset.duration.timescale;
    int32_t timescale = asset.duration.timescale;
    
    NSLog(@"duration=%f",duration);
    NSDictionary *outputSettingsDict = [[NSDictionary alloc] initWithObjectsAndKeys:
                                        [NSNumber numberWithInt:kAudioFormatLinearPCM],AVFormatIDKey,
                                        //     [NSNumber numberWithInt:44100.0],AVSampleRateKey, /*Not Supported*/
                                        //     [NSNumber numberWithInt: 2],AVNumberOfChannelsKey,    /*Not Supported*/
                                        [NSNumber numberWithInt:16],AVLinearPCMBitDepthKey,
                                        [NSNumber numberWithBool:NO],AVLinearPCMIsBigEndianKey,
                                        [NSNumber numberWithBool:NO],AVLinearPCMIsFloatKey,
                                        [NSNumber numberWithBool:NO],AVLinearPCMIsNonInterleaved,
                                        nil];
    // You can read the samples in the track in their stored format, or you can convert them to a different format.
    AVAssetReaderTrackOutput *output = [[AVAssetReaderTrackOutput alloc] initWithTrack:songTrack outputSettings:outputSettingsDict];
    [reader addOutput:output];
   

    
    NSArray *formatDesc = songTrack.formatDescriptions;
    for(unsigned int i = 0; i < [formatDesc count]; ++i) {
        CMAudioFormatDescriptionRef item = (__bridge CMAudioFormatDescriptionRef)[formatDesc objectAtIndex:i];
        //获取多媒体描述
        const AudioStreamBasicDescription* fmtDesc = CMAudioFormatDescriptionGetStreamBasicDescription(item);
        if (!fmtDesc) return; //!
        channelCount = fmtDesc->mChannelsPerFrame;
    }
    
    UInt32 bytesPerInputSample = 2 * channelCount;
    maximum = noiseFloor;
    Float64 tally = 0;
    Float32 tallyCount = 0;
    Float32 outSamples = 0;
    NSInteger downsampleFactor = totalSamples / widthInPixels;
    downsampleFactor = downsampleFactor<1 ? 1 : downsampleFactor;
    if(fullSongData){
        fullSongData = nil;
    }
    //    if(allSongSamples){
    //        [allSongSamples release];
    //        allSongSamples = nil;
    //    }
    //    allSongSamples = [[NSMutableData alloc] initWithCapacity:self.totalSamples];
    
    fullSongData = [[NSMutableData alloc] initWithCapacity:(unsigned long int)totalSamples/downsampleFactor*2]; // 16-bit samples
    [reader startReading];
    
   /*
   CMVideoFormatDesc：video的格式，包括宽高、颜色空间、编码格式、SPS、PPS
   CVPixelBuffer:包含未压缩的像素格式，宽高
   CMBlockBuffer:未压缩的的图像数据
   CMSampleBuufer:存放一个或多个压缩或未压缩的媒体文件
    */
    while (reader.status == AVAssetReaderStatusReading) {
        AVAssetReaderTrackOutput * trackOutput = (AVAssetReaderTrackOutput *)[reader.outputs objectAtIndex:0];
        //CMSampleBufferRef:这是一个包含零个或多个解码后（未解码）特定媒体类型的样本（音频，视频，多路复用等）
        CMSampleBufferRef sampleBufferRef = [trackOutput copyNextSampleBuffer];
        if (sampleBufferRef) {
            //未压缩的的图像数据
            CMBlockBufferRef blockBufferRef = CMSampleBufferGetDataBuffer(sampleBufferRef);
            size_t bufferLength = CMBlockBufferGetDataLength(blockBufferRef);
            NSMutableData * data = [NSMutableData dataWithLength:bufferLength];
            /*
             @param    theSourceBuffer
             @param    offsetToData
             @param    dataLength
             @param    destination
             */
            CMBlockBufferCopyDataBytes(blockBufferRef, 0, bufferLength, data.mutableBytes);
            
           
            SInt16 *samples = (SInt16 *)data.mutableBytes;
            // 16 = [8][8],两位表示一个fream
            long sampleCount = bufferLength / bytesPerInputSample;
            for (int i=0; i<sampleCount; i++) {
                Float32 sample = (Float32) *samples++;//获取一帧一帧的采样
               
                //                [allSongSamples appendBytes:&sample length:sizeof(sample)];
               sample = decibel(sample);
               sample = minMaxX(sample,noiseFloor,0);
                tally += sample;
                //获取多个声道中的一个声道数据
                for (int j=1; j<channelCount; j++)
                    samples++;
                
                tallyCount++;
                
                /*
                   把帧加起来求平均值，因为帧数太多
                   从音频中获取采样率为，1s，44100
                   份为10份，一份为44100/10 = 4410，
                   把这4410加起来求平均值，然后放入缓冲区，即一个条形的高度
                 */
                if (tallyCount == (timescale/10)) {
                    sample = tally / tallyCount;
                                 
                    maximum = maximum > sample ? maximum : sample;//求最大的平均值
                    int sampleLen = sizeof(sample);
                    [fullSongData appendBytes:&sample length:sampleLen];
                    tally = 0;
                    tallyCount = 0;
                    outSamples++;
                }
            }
            CMSampleBufferInvalidate(sampleBufferRef);
            CFRelease(sampleBufferRef);
            data =nil;
        }
    }
    //每一秒画 10 个条形图
    NSInteger drowCount = duration*10*spaceX;
    
    if (reader.status == AVAssetReaderStatusCompleted){
        NSLog(@"FDWaveformView: start rendering PNG W= %f", outSamples);
        [self plotLogGraph:(Float32 *)fullSongData.bytes
              maximumValue:maximum
              mimimumValue:noiseFloor
               drowCount:drowCount
               imageHeight:heightInPixels
                      done:done];
    }
   
    
}
#define yellowLine (-16.0)
#define plotChannelOneColor [[UIColor blackColor] CGColor]
#define waveColor [[UIColor blueColor] CGColor]

- (void) plotLogGraph:(Float32 *) samples
         maximumValue:(Float32) normalizeMax
         mimimumValue:(Float32) normalizeMin
          drowCount:(NSInteger)drowCount
          imageHeight:(float) imageHeight
                 done:(void(^)(UIImage *image, UIImage *selectedImage,NSInteger imageWidth))done
{
    // TODO: switch to a synchronous function that paints onto a given context
   
    CGSize imageSize = CGSizeMake(drowCount, 400);
    // 0.0 表示不做任何缩放，必须这初始化，其他方法会造成颜色变淡
    UIGraphicsBeginImageContextWithOptions(imageSize,YES,0.0); // this is leaking memory?
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetAlpha(context,1.0);
    CGContextSetLineWidth(context, 1.0);
    CGContextSetStrokeColorWithColor(context, UIColor.whiteColor.CGColor);

    int imageCentreY = 400/2;
    int offsetX = 0;
    for (NSInteger intSample=0; intSample<drowCount; intSample++) {
        Float32 sample = *(samples++);
        if(!sample) { NSLog(@"wrong wrong------"); break;}
        int offsetY = (fabsf(sample)-50)*2;

        CGContextMoveToPoint(context, offsetX, imageCentreY-offsetY);
        CGContextAddLineToPoint(context, offsetX, imageCentreY+offsetY);
        CGContextStrokePath(context);
        offsetX+=spaceX;
    }
    
    int oneTime = (workDeskWidth*[UIScreen mainScreen].scale)/allTime;
    CGContextSetLineWidth(context, 1.0);
    CGContextSetStrokeColorWithColor(context, UIColor.blackColor.CGColor);
    for (int time = 0; time < allTime; time++) {
         CGContextMoveToPoint(context, time*oneTime,300);
         CGContextAddLineToPoint(context, time*oneTime,350);
         CGContextStrokePath(context);
        NSDictionary *dict  =@{NSFontAttributeName:[UIFont systemFontOfSize:50] };
        [[NSString stringWithFormat:@"%d",time] drawAtPoint:CGPointMake(time*oneTime, 400) withAttributes:dict];
        
    }
    
   
    //draw line
    UIBezierPath *line = [UIBezierPath bezierPath];
    [line moveToPoint:CGPointMake(0, 0)];
    [line addLineToPoint:CGPointMake(imageSize.width,0)];
    [line setLineWidth:1.0];
    [line stroke];
    //center line
    [line moveToPoint:CGPointMake(0, 400/2)];
    [line addLineToPoint:CGPointMake(imageSize.width, 400/2)];
    [line setLineWidth:1.0];
    [line stroke];

    [line moveToPoint:CGPointMake(0, 400)];
    [line addLineToPoint:CGPointMake(imageSize.width, 400)];
    [line setLineWidth:1.0];
    [line stroke];
   
    
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    done(image, nil,drowCount);
}
@end
