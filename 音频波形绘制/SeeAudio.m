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
#define decibel(amplitude) (20.0 * log10(fabsf(amplitude)/32767.0))
#define minMaxX(x,mn,mx) (x<=mn?mn:(x>=mx?mx:x))

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
    workDeskWidth = 5000;
    
    
    asset = [[AVURLAsset alloc]initWithURL:[[NSBundle mainBundle] URLForResource:@"whenImissYou" withExtension:@"m4a"] options:nil];
    imageView.image =nil;
    totalSamples = asset.duration.value;
    AVPlayerItem *item = [AVPlayerItem playerItemWithAsset:asset];
    p = [[AVPlayer  alloc] initWithPlayerItem:item];
    [p play];
    
    NSLog(@"totalSamples=%lld",totalSamples);
    NSLog(@"时间标尺-timescale=%d",asset.duration.timescale);
    
    
    [self renderPNGAudioPictogramLogForAsset:asset done:^(UIImage *image, UIImage *selectedImage) {
        UIScrollView *scrv = [[UIScrollView alloc] initWithFrame:self.bounds];
        [scrv setContentSize:CGSizeMake(self->workDeskWidth, 300)];
        [self addSubview:scrv];
        UIImageView *imgv = [[UIImageView alloc] initWithFrame:CGRectMake(0, 100, self->workDeskWidth, 400)];
        imgv.image = image;
        [scrv addSubview:imgv];
    }];
    
}
- (void)renderPNGAudioPictogramLogForAsset:(AVURLAsset *)songAsset
                                      done:(void(^)(UIImage *image, UIImage *selectedImage))done
{
    // TODO: break out subsampling code
    NSLog(@"self.frame.size.with:%f",self.frame.size.width);
    CGFloat widthInPixels =  workDeskWidth * [UIScreen mainScreen].scale;
    CGFloat heightInPixels = (self.frame.size.height) * [UIScreen mainScreen].scale;
    
    NSError *error = nil;
    AVAssetReader *reader = [[AVAssetReader alloc] initWithAsset:songAsset error:&error];
    AVAssetTrack *songTrack = [songAsset.tracks objectAtIndex:0];
    duration = songAsset.duration.value/songAsset.duration.timescale;
    
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
    AVAssetReaderTrackOutput *output = [[AVAssetReaderTrackOutput alloc] initWithTrack:songTrack outputSettings:outputSettingsDict];
    [reader addOutput:output];
   

    
    NSArray *formatDesc = songTrack.formatDescriptions;
    for(unsigned int i = 0; i < [formatDesc count]; ++i) {
        CMAudioFormatDescriptionRef item = (__bridge CMAudioFormatDescriptionRef)[formatDesc objectAtIndex:i];
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
    
    fullSongData = [[NSMutableData alloc] initWithCapacity:totalSamples/downsampleFactor*2]; // 16-bit samples
    [reader startReading];
    
    while (reader.status == AVAssetReaderStatusReading) {
        AVAssetReaderTrackOutput * trackOutput = (AVAssetReaderTrackOutput *)[reader.outputs objectAtIndex:0];
        CMSampleBufferRef sampleBufferRef = [trackOutput copyNextSampleBuffer];
        if (sampleBufferRef) {
            CMBlockBufferRef blockBufferRef = CMSampleBufferGetDataBuffer(sampleBufferRef);
            size_t bufferLength = CMBlockBufferGetDataLength(blockBufferRef);
            NSMutableData * data = [NSMutableData dataWithLength:bufferLength];
            CMBlockBufferCopyDataBytes(blockBufferRef, 0, bufferLength, data.mutableBytes);
            
            double RMS;
            RMS = 0;
            // [allSongSamples appendBytes:data.mutableBytes length:bufferLength];
            
            SInt16 *samples = (SInt16 *)data.mutableBytes;
            long sampleCount = bufferLength / bytesPerInputSample;
            for (int i=0; i<sampleCount; i++) {
                Float32 sample = (Float32) *samples++;
                //                [allSongSamples appendBytes:&sample length:sizeof(sample)];
                sample = decibel(sample);
                sample = minMaxX(sample,noiseFloor,0);
                tally += sample; // Should be RMS?
                //                adPercent=sample;///32768.0f;
                //                RMS += adPercent*adPercent;
                
                for (int j=1; j<channelCount; j++)
                    samples++;
                tallyCount++;
                
                if (tallyCount == downsampleFactor) {
                    sample = tally / tallyCount;
                    //                    RMS = sqrt(RMS / tallyCount);
                    //                    sample = RMS;
                    maximum = maximum > sample ? maximum : sample;
                    int sampleLen = sizeof(sample);
                    [fullSongData appendBytes:&sample length:sampleLen];
                    tally = 0;
                    tallyCount = 0;
                    RMS = 0;
                    
                    outSamples++;
                }
            }
            CMSampleBufferInvalidate(sampleBufferRef);
            CFRelease(sampleBufferRef);
            data =nil;
        }
    }
    
    // if (reader.status == AVAssetReaderStatusFailed || reader.status == AVAssetReaderStatusUnknown)
    // Something went wrong. Handle it.
    if (reader.status == AVAssetReaderStatusCompleted){
        NSLog(@"FDWaveformView: start rendering PNG W= %f", outSamples);
        [self plotLogGraph:(Float32 *)fullSongData.bytes
              maximumValue:maximum
              mimimumValue:noiseFloor
               sampleCount:outSamples
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
          sampleCount:(NSInteger)sampleCount
          imageHeight:(float) imageHeight
                 done:(void(^)(UIImage *image, UIImage *selectedImage))done
{
    // TODO: switch to a synchronous function that paints onto a given context
    NSLog(@"begin ploglogGraph");
    //    float pp = self.frame.size.width /(self.frame.size.width-2*leading);
    //    float newSampleCount = sampleCount*pp;
    
    CGSize imageSize = CGSizeMake(sampleCount, imageHeight);
    UIGraphicsBeginImageContext(imageSize); // this is leaking memory?
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSetAlpha(context,1.0);
    CGContextSetLineWidth(context, 2.0);
    CGContextSetStrokeColorWithColor(context, waveColor);
    float halfGraphHeight = (imageHeight / 2);
    float centerLeft = halfGraphHeight;
    float minus =(normalizeMax - noisyFloot);
    if(minus<=0)
        minus=0.001;
    float sampleAdjustmentFactor = imageHeight / minus / 4;
    
    for (NSInteger intSample=0; intSample<sampleCount; intSample+=6) {
        Float32 sample = *(samples+=6);
        if(!sample) { NSLog(@"wrong wrong------"); break;}
        float pixels = (sample - noisyFloot) * sampleAdjustmentFactor;
        
        NSLog(@"bitHeight=%f",pixels);
        
        CGContextMoveToPoint(context, intSample, centerLeft-pixels);
        CGContextAddLineToPoint(context, intSample, centerLeft+pixels);
        CGContextStrokePath(context);
    }
    
    //draw line
    CGContextSetStrokeColorWithColor(context, plotChannelOneColor);
    float pixels = (yellowLine - noisyFloot) * sampleAdjustmentFactor;
    
    [[UIColor colorWithWhite:0.8 alpha:1.0] setFill];
    UIBezierPath *line = [UIBezierPath bezierPath];
    [line moveToPoint:CGPointMake(0, centerLeft-pixels)];
    [line addLineToPoint:CGPointMake(imageSize.width, centerLeft-pixels)];
    [line setLineWidth:1.0];
    [line stroke];
    //center line
    [line moveToPoint:CGPointMake(0, centerLeft)];
    [line addLineToPoint:CGPointMake(imageSize.width, centerLeft)];
    [line setLineWidth:1.0];
    [line stroke];
    
    [line moveToPoint:CGPointMake(0, centerLeft+pixels)];
    [line addLineToPoint:CGPointMake(imageSize.width, centerLeft+pixels)];
    [line setLineWidth:1.0];
    [line stroke];
    //end draw line
    
    UIImage *image1 = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsBeginImageContext(image1.size);
    [[UIColor lightTextColor] set];
    
    CGRect drawRect = CGRectMake(0, 0, imageSize.width, imageSize.height);
    [image1 drawInRect:drawRect];
    
    //    [[UIColor yellowColor] set];
    //    UIRectFillUsingBlendMode(drawRect, kCGBlendModeSourceAtop);
    //    UIImage *tintedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    NSLog(@"FDWaveformView: done rendering PNG W=%f H=%f", image1.size.width, image1.size.height);
    done(image1, nil);
}
@end
