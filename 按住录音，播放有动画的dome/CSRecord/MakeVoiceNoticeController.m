//
//  MakeVoiceNoticeController.m
//  kyExpress_Internal
//
//  Created by iOS_Chris on 16/7/7.
//  Copyright © 2016年 kyExpress. All rights reserved.
//

#import "MakeVoiceNoticeController.h"

#import <AVFoundation/AVFoundation.h>

#include "lame.h"


#define kSCREEN_WIDTH ([UIScreen mainScreen].bounds.size.width)
#define kSCREEN_HEIGHT ([UIScreen mainScreen].bounds.size.height)//应用尺寸
#define RGBA(r,g,b,a) [UIColor colorWithRed:r/255.0f green:g/255.0f blue:b/255.0f alpha:a]
#define RGB(r,g,b) RGBA(r,g,b,1.0f)
#define kColorBack [UIColor groupTableViewBackgroundColor]

#define margin 15
#define kSandboxPathStr [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject]

#define kMp3FileName @"myRecord.mp3"
#define kCafFileName @"myRecord.caf"


@interface MakeVoiceNoticeController ()<AVAudioPlayerDelegate,AVAudioRecorderDelegate,UIGestureRecognizerDelegate>
@property (nonatomic,strong) UIView *recordView;
@property (nonatomic,strong) UIView *editView;
@property (nonatomic,strong) UIImageView *voiceView;
@property (nonatomic,strong) UILabel *timeLabel;  //录音计时
@property (nonatomic,strong) UILabel *timeLabel2;  //语音试听计时
@property (nonatomic,strong) UIImageView *recordBtn;

@property (nonatomic,strong) UIImageView *rotateImgView;

@property (nonatomic,strong) NSTimer *timer1;  //控制录音时长显示更新
@property (nonatomic,assign) NSInteger countNum;//录音计时（秒）
@property (nonatomic,copy) NSString *cafPathStr;
@property (nonatomic,copy) NSString *mp3PathStr;
@property (nonatomic,strong) AVAudioRecorder *audioRecorder;//音频录音机

@property (nonatomic, strong) CABasicAnimation *rotationAnimation;

@end

@implementation MakeVoiceNoticeController

/**
 *存放所有的音乐播放器
 */
static NSMutableDictionary *_musices;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    self.title = @"录音";
     self.navigationController.navigationBar.barTintColor = RGB(215, 155, 252);
    
    [self initEditView];
    [self.view addSubview:self.recordView];

    self.timeLabel2.text = @"";
    
    self.cafPathStr = [kSandboxPathStr stringByAppendingPathComponent:kCafFileName];
    self.mp3PathStr =  [kSandboxPathStr stringByAppendingPathComponent:kMp3FileName];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self stopPlayRecord];
    
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.view endEditing:YES];
}


#pragma mark - 语音编辑视图
- (void)initEditView{
    
    CGFloat commonW =kSCREEN_WIDTH - margin*2;
    UILabel *label1 = [[UILabel alloc]init];
    label1.text = @"语音试听";
    label1.textColor = [UIColor blackColor];
    label1.frame = CGRectMake(margin , margin , commonW * 0.6, 21);
    label1.font = [UIFont systemFontOfSize:16];
    
    CGFloat deleteW = 50.0;
    UIView *listenView = [[UIView alloc]init];
    listenView.frame = CGRectMake(margin, CGRectGetMaxY(label1.frame)+margin, commonW - deleteW - margin, 35);
    listenView.layer.cornerRadius = 3;
    listenView.clipsToBounds = YES;
    listenView.layer.borderColor = [UIColor purpleColor].CGColor;
    listenView.backgroundColor = [UIColor whiteColor];
    listenView.layer.borderWidth = 1;
    listenView.userInteractionEnabled = YES;
    [listenView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(playRecord)]];
    
    
    UIImageView *iconView = [[UIImageView alloc]initWithImage:[UIImage imageNamed:@"voice"]];
    CGFloat iconW = 11;
    CGFloat iconH = 14;
    CGFloat iconX = 8;
    CGFloat iconY = (listenView.frame.size.height - iconH) * 0.5;
    iconView.frame = CGRectMake(iconX, iconY, iconW, iconH);
    self.voiceView = iconView;
    [listenView addSubview:iconView];
    
    UILabel *timeLabel2 = [[UILabel alloc]init];
    CGFloat timeW = 120;
    CGFloat timeX = listenView.frame.size.width - timeW;
    timeLabel2.frame = CGRectMake(timeX, 0, timeW, listenView.frame.size.height);
    timeLabel2.text = @"\"";
    timeLabel2.textColor = [UIColor grayColor];
    timeLabel2.textAlignment = NSTextAlignmentRight;
    self.timeLabel2 = timeLabel2;
    [listenView addSubview:timeLabel2];
    
    [self.editView addSubview:label1];
    [self.editView addSubview:listenView];

    [self pictureChangeAnimationSetting];
}


#pragma mark - 动画效果

- (void)pictureChangeAnimationSetting
{
    NSArray *picArray = @[[UIImage imageNamed:@"voice1"],
                          [UIImage imageNamed:@"voice2"],
                          [UIImage imageNamed:@"voice3"],];
    
    //    self.imageView.image = [UIImage imageNamed:@"voice1"];
    
    
    //imageView的动画图片是数组images
    self.voiceView.animationImages = picArray;
    //按照原始比例缩放图片，保持纵横比
    self.voiceView.contentMode = UIViewContentModeScaleAspectFit;
    //切换动作的时间3秒，来控制图像显示的速度有多快，
    self.voiceView.animationDuration = 1;
    //动画的重复次数，想让它无限循环就赋成0
    self.voiceView.animationRepeatCount = 0;
    
}


-(UIView *)recordView{
    if (!_recordView) {
        CGFloat recordH = kSCREEN_HEIGHT * 0.4;
        CGFloat availH = recordH - margin * 4;
        
        _recordView = [[UIView alloc]initWithFrame:CGRectMake(0, kSCREEN_HEIGHT - recordH, kSCREEN_WIDTH, recordH)];
        _recordView.backgroundColor = [UIColor whiteColor];
        
        CGFloat timeH = availH * 0.2;
        CGFloat btnH = availH * 0.7;
        CGFloat noticeH = availH * 0.1;
        
        self.timeLabel.frame = CGRectMake(0, margin, kSCREEN_WIDTH, timeH);
        self.recordBtn.frame = CGRectMake((kSCREEN_WIDTH - btnH)*0.5, CGRectGetMaxY(self.timeLabel.frame) + margin, btnH, btnH);
        self.recordBtn.layer.cornerRadius = self.recordBtn.frame.size.width * 0.5;
        
        [self.recordBtn.layer setMasksToBounds:YES];
        //        [self.recordBtn addTarget:self action:@selector(recordNotice) forControlEvents:UIControlEventTouchDown];
        //        [self.recordBtn addTarget:self action:@selector(stopNotice) forControlEvents:UIControlEventTouchUpInside];
        
        //实例化长按手势监听
        
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleTableviewCellLongPressed:)];
        
        //代理
        longPress.delegate = self;
        longPress.minimumPressDuration = 0.5;
        [self.recordBtn addGestureRecognizer:longPress];
        
        self.rotateImgView.frame = CGRectMake(0, 0, btnH, btnH);
        self.rotateImgView.center = self.recordBtn.center;
        
        [_recordView addSubview:self.rotateImgView];
        [_recordView addSubview:self.timeLabel];
        [_recordView addSubview:self.recordBtn];
        
        
        UILabel *noticeLabel = [[UILabel alloc]init];
        noticeLabel.frame = CGRectMake(0, recordH - noticeH - margin, kSCREEN_WIDTH, noticeH);
        noticeLabel.textAlignment = NSTextAlignmentCenter;
        noticeLabel.textColor = [UIColor lightGrayColor];
        noticeLabel.font = [UIFont systemFontOfSize:14];
        noticeLabel.text = @"按住不放录制语音";
        //        noticeLabel.backgroundColor = [UIColor redColor];
        [_recordView addSubview:noticeLabel];
    }
    return _recordView;
}




//**************************************录音*********************************************

//长按事件的实现方法

- (void) handleTableviewCellLongPressed:(UILongPressGestureRecognizer *)gestureRecognizer {
    
    if (gestureRecognizer.state ==  UIGestureRecognizerStateBegan) {
        
        NSLog(@"UIGestureRecognizerStateBegan");
        [self startRecordNotice];
        
    }
    
    if (gestureRecognizer.state == UIGestureRecognizerStateChanged) {
        
    }
    
    if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        
        NSLog(@"UIGestureRecognizerStateEnded");
        [self stopRecordNotice];
        
    }
    
}




/**
 *  获得录音机对象
 *
 *  @return 录音机对象
 */
-(AVAudioRecorder *)audioRecorder{
    if (!_audioRecorder) {
        //创建录音文件保存路径
        NSURL *url=[NSURL URLWithString:self.cafPathStr];
        //创建录音格式设置
        NSDictionary *setting=[self getAudioSetting];
        //创建录音机
        NSError *error=nil;
        
        _audioRecorder=[[AVAudioRecorder alloc]initWithURL:url settings:setting error:&error];
        _audioRecorder.delegate=self;
        _audioRecorder.meteringEnabled=YES;//如果要监控声波则必须设置为YES
        if (error) {
            NSLog(@"创建录音机对象时发生错误，错误信息：%@",error.localizedDescription);
            return nil;
        }
    }
    return _audioRecorder;
}


/**
 *  取得录音文件设置
 *
 *  @return 录音设置
 */
-(NSDictionary *)getAudioSetting{
    //LinearPCM 是iOS的一种无损编码格式,但是体积较为庞大
    //录音设置
    NSMutableDictionary *recordSettings = [[NSMutableDictionary alloc] init];
    //录音格式 无法使用
    [recordSettings setValue :[NSNumber numberWithInt:kAudioFormatLinearPCM] forKey: AVFormatIDKey];
    //采样率
    [recordSettings setValue :[NSNumber numberWithFloat:11025.0] forKey: AVSampleRateKey];//44100.0
    //通道数
    [recordSettings setValue :[NSNumber numberWithInt:2] forKey: AVNumberOfChannelsKey];
    //线性采样位数
    //[recordSettings setValue :[NSNumber numberWithInt:16] forKey: AVLinearPCMBitDepthKey];
    //音频质量,采样质量
    [recordSettings setValue:[NSNumber numberWithInt:AVAudioQualityMin] forKey:AVEncoderAudioQualityKey];
    
    return recordSettings;
}


#pragma mark - 录音方法

- (void)startRecordNotice{
    self.timeLabel2.text = @"";

    [self stopMusicWithUrl:[NSURL URLWithString:self.cafPathStr]];

    [self.voiceView.layer removeAllAnimations];
    self.voiceView.image = [UIImage imageNamed:@"voice3"];
    
    if ([self.audioRecorder isRecording]) {
        [self.audioRecorder stop];
    }
    NSLog(@"----------开始录音----------");
    [self deleteOldRecordFile];  //如果不删掉，会在原文件基础上录制；虽然不会播放原来的声音，但是音频长度会是录制的最大长度。
    
    AVAudioSession *audioSession=[AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    
    [_recordBtn setImage:[UIImage imageNamed:@"record_high"]];
    
    if (![self.audioRecorder isRecording]) {//0--停止、暂停，1-录制中
        
        [self.audioRecorder record];//首次使用应用时如果调用record方法会询问用户是否允许使用麦克风
        self.countNum = 0;
        NSTimeInterval timeInterval =1 ; //0.1s
        self.timer1 = [NSTimer scheduledTimerWithTimeInterval:timeInterval  target:self selector:@selector(changeRecordTime)  userInfo:nil  repeats:YES];
        
        [self.timer1 fire];
    }
    
}

-(void)deleteOldRecordFile{
    NSFileManager* fileManager=[NSFileManager defaultManager];
    
    BOOL blHave=[[NSFileManager defaultManager] fileExistsAtPath:self.cafPathStr];
    if (!blHave) {
        NSLog(@"不存在");
        return ;
    }else {
        NSLog(@"存在");
        BOOL blDele= [fileManager removeItemAtPath:self.cafPathStr error:nil];
        if (blDele) {
            NSLog(@"删除成功");
        }else {
            NSLog(@"删除失败");
        }
    }
}

- (void)changeRecordTime
{
    
    self.countNum += 1;
    NSInteger min = self.countNum/60;
    NSInteger sec = self.countNum - min * 60;
    
    self.timeLabel.text = [NSString stringWithFormat:@"%02d:%02d",min,sec];
}


- (void)stopRecordNotice
{
    NSLog(@"----------结束录音----------");
    
    
    [self.audioRecorder stop];
    [self.timer1 invalidate];
    
    //停止旋转动画
    [self.rotateImgView.layer removeAllAnimations];
    self.voiceView.image = [UIImage imageNamed:@"voice3"];
    
    self.rotateImgView.image = [UIImage imageNamed:@"rcirle_norm"];
    [self.recordBtn setImage:[UIImage imageNamed:@"record_norm"]];

    [self audio_PCMtoMP3];
    
    //计算文件大小
    long long fileSize = [self fileSizeAtPath:self.mp3PathStr]/1024.0;
    NSString *fileSizeStr = [NSString stringWithFormat:@"%lld",fileSize];
    
    self.timeLabel2.text = [NSString stringWithFormat:@"%ld \" %@kb  ",(long)self.countNum,fileSizeStr];
    self.timeLabel.text = @"00:00";
  
    
    NSLog(@"timer isValid:%d",self.timer1.isValid);
//    NSLog(@"mp3PathStr:%@",self.mp3PathStr);
    NSLog(@"countNum %d , fileSizeStr : %@",self.countNum,fileSizeStr);
    
    /**
     
     20s  73k
     20s  320k
     
     */
}
//单个文件的大小
- (long long) fileSizeAtPath:(NSString*)filePath{
    
    NSFileManager* manager = [NSFileManager defaultManager];
    
    if ([manager fileExistsAtPath:filePath]){
        
        return [[manager attributesOfItemAtPath:filePath error:nil] fileSize];
        
    }else{
        NSLog(@"计算文件大小：文件不存在");
    }
    
    return 0;
}


#pragma mark - caf转mp3
- (void)audio_PCMtoMP3
{
    
    @try {
        int read, write;
        
        FILE *pcm = fopen([self.cafPathStr cStringUsingEncoding:1], "rb");  //source 被转换的音频文件位置
        fseek(pcm, 4*1024, SEEK_CUR);                                   //skip file header
        FILE *mp3 = fopen([self.mp3PathStr cStringUsingEncoding:1], "wb");  //output 输出生成的Mp3文件位置
        
        const int PCM_SIZE = 8192;
        const int MP3_SIZE = 8192;
        short int pcm_buffer[PCM_SIZE*2];
        unsigned char mp3_buffer[MP3_SIZE];
        
        lame_t lame = lame_init();
        lame_set_in_samplerate(lame, 11025.0);
        lame_set_VBR(lame, vbr_default);
        lame_init_params(lame);
        
        do {
            read = fread(pcm_buffer, 2*sizeof(short int), PCM_SIZE, pcm);
            if (read == 0)
                write = lame_encode_flush(lame, mp3_buffer, MP3_SIZE);
            else
                write = lame_encode_buffer_interleaved(lame, pcm_buffer, read, mp3_buffer, MP3_SIZE);
            
            fwrite(mp3_buffer, write, 1, mp3);
            
        } while (read != 0);
        
        lame_close(lame);
        fclose(mp3);
        fclose(pcm);
    }
    @catch (NSException *exception) {
        NSLog(@"%@",[exception description]);
    }
    @finally {
        NSLog(@"MP3生成成功: %@",self.mp3PathStr);
    }
    
}

- (void)stopMusicWithUrl:(NSURL *)fileUrl{
    if (!fileUrl) return;//如果没有传入文件名，那么就直接返回
    
    //1.取出对应的播放器
    AVAudioPlayer *player=[self musices][fileUrl];
    
    //2.停止
    if ([player isPlaying]) {
        [player stop];
        NSLog(@"播放结束:%@--------",fileUrl);
    }
    
    if ([[self musices].allKeys containsObject:fileUrl]) {
        
        [[self musices] removeObjectForKey:fileUrl];
    }
}

//**************************************播放*********************************************

#pragma mark - 播放
- (void)playRecord
{
    [self stopAllMusic];
    
    AVAudioSession *audioSession=[AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];  //此处需要恢复设置回放标志，否则会导致其它播放声音也会变小
    
    [self playMusicWithUrl:[NSURL URLWithString:self.cafPathStr]];
    [self.voiceView startAnimating];
}

- (void)stopPlayRecord
{
    [self stopMusicWithUrl:[NSURL URLWithString:self.cafPathStr]];
    [self.voiceView.layer removeAllAnimations];
    self.voiceView.image = [UIImage imageNamed:@"voice3"];
}




/**
 *播放音乐文件
 */
- (BOOL)playMusicWithUrl:(NSURL *)fileUrl
{
    //其他播放器停止播放
    [self stopAllMusic];
    
    if (!fileUrl) return NO;
    
    AVAudioSession *session=[AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];  //此处需要恢复设置回放标志，否则会导致其它播放声音也会变小
    [session setActive:YES error:nil];
    
    AVAudioPlayer *player=[self musices][fileUrl];
    
    if (!player) {
        //2.2创建播放器
        player=[[AVAudioPlayer alloc]initWithContentsOfURL:fileUrl error:nil];
    }
    
    player.delegate = self;
    
    if (![player prepareToPlay]){
        NSLog(@"缓冲失败--");
        //        [self myToast:@"播放器缓冲失败"];
        return NO;
    }
    
    [player play];
    
    //2.4存入字典
    [self musices][fileUrl]=player;
    
    
    NSLog(@"musices:%@ musices",self.musices);
    
    return YES;//正在播放，那么就返回YES
}
#pragma mark - AudioPlayer方法


-(void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    NSLog(@"delegate--播放完毕----------------------");
    [self.voiceView.layer removeAllAnimations];
    self.voiceView.image = [UIImage imageNamed:@"voice3"];
}


- (void)stopAllMusic
{
    
    if ([self musices].allKeys.count > 0) {
        for ( NSString *playID in [self musices].allKeys) {
            
            AVAudioPlayer *player=[self musices][playID];
            [player stop];
        }
    }
}



//******************************************init *****************************************

- (NSMutableDictionary *)musices
{
    if (_musices==nil) {
        _musices=[NSMutableDictionary dictionary];
    }
    return _musices;
}


-(UIImageView *)rotateImgView
{
    if (!_rotateImgView) {
        _rotateImgView = [[UIImageView alloc]init];
        _rotateImgView.image = [UIImage imageNamed:@"rcirle_norm"];
    }
    return _rotateImgView;
}


-(UIView *)editView
{
    if (!_editView) {
        _editView = [[UIView alloc]initWithFrame:CGRectMake(0, 64, kSCREEN_WIDTH, 200)];
        _editView.backgroundColor = kColorBack;
        [self.view addSubview:_editView];
    }
    return _editView;
}

-(UILabel *)timeLabel
{
    if (!_timeLabel) {
        _timeLabel = [[UILabel alloc]init];
        _timeLabel.textAlignment = NSTextAlignmentCenter;
        _timeLabel.font = [UIFont fontWithName:@"HelveticaNeue-Thin" size:42];
        _timeLabel.text = @"00:00";
        _timeLabel.textColor = RGB(215, 155, 252);
    }
    return _timeLabel;
}

- (UIImageView *)recordBtn
{
    
    if (!_recordBtn) {
        _recordBtn = [[UIImageView alloc]init];
        _recordBtn.backgroundColor = [UIColor clearColor];
        
        [_recordBtn setImage:[UIImage imageNamed:@"record_norm"]];
        _recordBtn.userInteractionEnabled = YES;//方便添加长按手势
    }
    
    return _recordBtn;
}


@end
