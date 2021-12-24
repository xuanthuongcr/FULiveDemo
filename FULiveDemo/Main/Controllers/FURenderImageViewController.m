//
//  FURenderImageViewController.m
//  FULiveDemo
//
//  Created by L on 2018/6/22.
//  Copyright © 2018年 L. All rights reserved.
//

#import "FURenderImageViewController.h"
#import <MobileCoreServices/MobileCoreServices.h>
#import "FUVideoReader.h"
#import "FUManager.h"
#import "FUAPIDemoBar.h"
#import "FUItemsView.h"
#import "FUBodyBeautyView.h"
#import "FULvMuView.h"

#import "FUBaseViewControllerManager.h"
#import "FUStickerManager.h"
#import "FUGreenScreenManager.h"
#import "FUBodyBeautyManager.h"

#import "FULandmarkManager.h"

#import <FURenderKit/FUImageHelper.h>
#import <SVProgressHUD.h>
#import <MJExtension.h>


#define finalPath   [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"finalVideo.mp4"]

@interface FURenderImageViewController ()<UINavigationControllerDelegate, UIImagePickerControllerDelegate, UIGestureRecognizerDelegate, FUVideoReaderDelegate, FUAPIDemoBarDelegate, FUItemsViewDelegate,FULvMuViewDelegate, FUBodyBeautyViewDelegate>

{
    __block BOOL takePic ;
    
    BOOL videHasRendered ;
    
    // float w,h;
    
    CGPoint _currPoint;
}

@property (strong, nonatomic) FUBaseViewControllerManager *baseManager;
@property (strong, nonatomic) FUStickerManager *stickManager;
@property (strong, nonatomic) FUGreenScreenManager *greenScreenManager;
@property (strong, nonatomic) FUBodyBeautyManager *bodyBeautyManager;

@property (nonatomic, strong) FULiveModel *model;

@property (nonatomic, strong) FUGLDisplayView *glView;
@property (nonatomic, strong) FUVideoReader *videoReader;


@property (strong, nonatomic) UIButton *playBtn;

@property (strong, nonatomic) FUAPIDemoBar *demoBar;
@property (strong, nonatomic) FUItemsView *itemsView;

@property (strong, nonatomic) UIButton *downloadBtn;
@property (strong, nonatomic)  UILabel *tipLabel;
@property (strong, nonatomic) UILabel *noTrackLabel;
@property (nonatomic, strong) AVPlayer *avPlayer;
@property(nonatomic,strong)FUBodyBeautyView *mBodyBeautyView;

@property(strong,nonatomic) FULvMuView *lvmuEditeView;

// 定时器
@property (nonatomic, strong) CADisplayLink *displayLink;

@property (nonatomic,assign) NSInteger  degress;

/* 比对按钮 */
@property (strong, nonatomic) UIButton *compBtn;
/* 是否开启比对 */
@property (assign, nonatomic) BOOL openComp;

@property (nonatomic, strong) UIGestureRecognizer *panGesture;
@property (nonatomic, strong) UIGestureRecognizer *pinchGesture;

@property (nonatomic, assign) CGRect lvRect;

@property (nonatomic, strong) NSOperationQueue *renderOperationQueue;

@end

@implementation FURenderImageViewController {
    FUImageBuffer currentImageBuffer;
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor blackColor];
    
    self.baseManager = [[FUBaseViewControllerManager alloc] init];
    self.model = [FUManager shareManager].currentModel;
    
    [self setupView];
    
    if (self.model.type == FULiveModelTypeBeautifyFace) {
        
        self.demoBar.hidden = NO ;
        [self.itemsView removeFromSuperview ];
        self.itemsView = nil ;
        
        self.downloadBtn.transform = CGAffineTransformMakeTranslation(0, 30) ;
        
        /* 比对按钮 */
        _compBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_compBtn setImage:[UIImage imageNamed:@"demo_icon_contrast"] forState:UIControlStateNormal];
        [_compBtn addTarget:self action:@selector(compareTouchDown) forControlEvents:UIControlEventTouchDown];
        [_compBtn addTarget:self action:@selector(compareTouchUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
        _compBtn.hidden = YES;
        [self.view addSubview:_compBtn];
        if (iPhoneXStyle) {
            _compBtn.frame = CGRectMake(15 , self.view.frame.size.height - 70 - 182 - 34, 44, 44);
        }else{
            _compBtn.frame = CGRectMake(15 , self.view.frame.size.height - 70 - 182, 44, 44);
        }
        
    }else if(self.model.type == FULiveModelTypeBody){
        self.bodyBeautyManager = [[FUBodyBeautyManager alloc] init];
        self.demoBar.hidden = YES ;
        [self.itemsView removeFromSuperview];
        
        self.itemsView = nil ;
        
        self.downloadBtn.transform = CGAffineTransformMakeTranslation(0, -30) ;
        [self setupView1];
    }else if(self.model.type == FULiveModelTypeLvMu){
        self.demoBar.hidden = YES;
        self.greenScreenManager = [[FUGreenScreenManager alloc] init];
        self.greenScreenManager.greenScreen.keyColor = FUColorMakeWithUIColor([UIColor colorWithRed:0.0 green:1.0 blue:0.0 alpha:1.0]);
        self.greenScreenManager.greenScreen.center = CGPointMake(0.5, 0.5);

        [self setupLvMuSubView];
        [_lvmuEditeView reloadDataSoure:self.greenScreenManager.dataArray];
        [_lvmuEditeView reloadBgDataSource:self.greenScreenManager.bgDataArray];
        self.downloadBtn.hidden = YES;

        //默认取教室的背景录像
        FUGreenScreenBgModel *param = [self.greenScreenManager.bgDataArray objectAtIndex:3];
        NSString *urlStr = [[NSBundle mainBundle] pathForResource:param.videoPath ofType:@"mp4"];
        self.greenScreenManager.greenScreen.videoPath = urlStr;
    } else { //目前只包含道具贴纸内容
        self.demoBar.hidden = YES ;
        
        self.itemsView.delegate = self ;
        [self.view addSubview:self.itemsView];
        //自定义视频和图片时候不需要大冒险和表情帝，修复此bughttp://jira.faceunity.com/browse/NAMADEV-3820
        NSMutableArray *list = [NSMutableArray array];
        for (NSString *name in self.model.items) {
            if (![name isEqualToString:@"zhenxinhua_damaoxian"] && ![name isEqualToString:@"expression_shooting"]) {
                [list addObject:name];
            }
        }
        [self.itemsView updateCollectionArray:[list copy]];
        
        NSString *item = @"resetItem";
        if (self.model.items.count > 1) {
            item = self.model.items[1];
        }
        
        self.itemsView.selectedItem = item;
        __weak typeof(self) weak = self;
        switch (self.model.type) {//TODO: todo 目前只有道具贴纸开放，后续需求有增加在继续添加.
            case FULiveModelTypeItems: {
                
                self.stickManager.type = FUStickerPropType;
                [self.itemsView startAnimation];
                [self.stickManager loadItem:item completion:^(BOOL finished) {
                    [weak.itemsView stopAnimation];
                }];
            }
                break;
            case FULiveModelTypeGestureRecognition: {                
                self.stickManager.type = FUGestureType;
                [self.stickManager loadItem:item completion:^(BOOL finished) {
                    [weak.itemsView stopAnimation];
                }];
            }
            default:
                break;
        }
    }
    
    takePic = NO;
    videHasRendered = NO;
    
    [self.baseManager loadItem];
    // 设置不同图像加载模式
    [self.baseManager setFaceProcessorDetectMode:self.image ? FUFaceProcessorDetectModeImage : FUFaceProcessorDetectModeVideo];
}

-(void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self addObserver];
    
    if ((self.model.type == FULiveModelTypeBeautifyFace || self.model.type == FULiveModelTypeMakeUp) && FUShowLandmark) {
        // 添加点位测试开关
        [FULandmarkManager show];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self startRendering];
}

-(void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    if ((self.model.type == FULiveModelTypeBeautifyFace || self.model.type == FULiveModelTypeMakeUp) && FUShowLandmark) {
        // 移除点位测试开关
        [FULandmarkManager dismiss];
    }
    
    // 取消所有渲染任务
    [self.renderOperationQueue cancelAllOperations];
    
    [_avPlayer pause];
    _avPlayer = nil;
    
    _displayLink.paused = YES;
    [_displayLink invalidate];
    _displayLink = nil;

    if (self.lvmuEditeView) {
        [self.lvmuEditeView destoryLvMuView];
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void)dealloc {
    if ([[NSFileManager defaultManager] fileExistsAtPath:finalPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:finalPath error:nil];
    }
    if (&currentImageBuffer) {
        [UIImage freeImageBuffer:&currentImageBuffer];
    }
    NSLog(@"render control dealloc");
}

-(void)setupLvMuSubView{
    // Do any additional setup after loading the view.
    _lvmuEditeView = [[FULvMuView alloc] initWithFrame:CGRectZero];
    _lvmuEditeView.mDelegate = self;
    [self.view addSubview:_lvmuEditeView];
    [_lvmuEditeView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.bottom.equalTo(self.view);
        if (iPhoneXStyle) {
            make.height.mas_equalTo(195 + 34);
        }else{
            make.height.mas_equalTo(195);
        }
    }];
    
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *effectview = [[UIVisualEffectView alloc] initWithEffect:blur];
    [_lvmuEditeView addSubview:effectview];
    [_lvmuEditeView sendSubviewToBack:effectview];
    /* 磨玻璃 */
    [effectview mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.top.bottom.equalTo(_lvmuEditeView);
    }];
    
    CGAffineTransform photoTransform0 = CGAffineTransformMakeTranslation(0, 180 * -0.6) ;
    CGAffineTransform photoTransform1 = CGAffineTransformMakeScale(0.9, 0.9);
    self.downloadBtn.transform = CGAffineTransformConcat(photoTransform0, photoTransform1) ;
    [self initMovementGestures];
    
}

-(void)initMovementGestures
{
    
    self.panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePanGesture:)];
    self.panGesture.delegate = self;
    [self.view addGestureRecognizer:self.panGesture];
    //
    self.pinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(handlePinchGesture:)];
    self.pinchGesture.delegate = self;
    [self.view addGestureRecognizer:self.pinchGesture];
}

-(void)setupView{
    [self.view addSubview:self.glView];
    
    [self.glView mas_makeConstraints:^(MASConstraintMaker *make) {
         make.left.right.equalTo(self.view);
         if (@available(iOS 11.0, *)) {
             make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop);
             if(iPhoneXStyle){
                make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom).mas_offset(-50);
             }else{
                 make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom);
             }
         } else {
             // Fallback on earlier versions
             make.top.equalTo(self.view.mas_top);
             make.bottom.equalTo(self.view.mas_bottom);
         }
        
        make.left.right.equalTo(self.view);
     }];
    
    /* 播放按钮 */
    _playBtn = [[UIButton alloc] init];
    [_playBtn setBackgroundImage:[UIImage imageNamed:@"play_icon"] forState:UIControlStateNormal];
    [_playBtn setBackgroundImage:[UIImage imageNamed:@"Replay_icon"] forState:UIControlStateSelected];
    self.playBtn.hidden = YES;
    [_playBtn addTarget:self action:@selector(playAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_playBtn];
    [_playBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.centerX.equalTo(self.view);
        make.width.mas_equalTo(80);
        make.height.mas_equalTo(80);
    }];
    
    /* 返回按钮 */
    UIButton *backBtn = [[UIButton alloc] init];
    [backBtn setImage:[UIImage imageNamed:@"back_btn_normal"] forState:UIControlStateNormal];
    [backBtn addTarget:self action:@selector(backAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:backBtn];
    [backBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        if (@available(iOS 11.0, *)) {
            make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop).offset(20);
        } else {
            make.top.equalTo(self.view.mas_top).offset(30);
        }
        make.left.equalTo(self.view).offset(10);
        make.width.mas_equalTo(44);
        make.height.mas_equalTo(44);
    }];
    
    /* 未检测到人脸提示 */
    _noTrackLabel = [[UILabel alloc] init];
    _noTrackLabel.textColor = [UIColor whiteColor];
    _noTrackLabel.font = [UIFont systemFontOfSize:17];
    _noTrackLabel.textAlignment = NSTextAlignmentCenter;
    _noTrackLabel.text = FUNSLocalizedString(@"No_Face_Tracking", @"未检测到人脸");
    [self.view addSubview:_noTrackLabel];
    [_noTrackLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.view);
        make.width.mas_equalTo(140);
        make.height.mas_equalTo(22);
    }];
    
    /* 额外操作提示 */
    _tipLabel = [[UILabel alloc] init];
    _tipLabel.textColor = [UIColor whiteColor];
    _tipLabel.font = [UIFont systemFontOfSize:32];
    _tipLabel.textAlignment = NSTextAlignmentCenter;
    _tipLabel.text = @"张张嘴";
    _tipLabel.hidden = YES;
    [self.view addSubview:_tipLabel];
    [_tipLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.noTrackLabel.mas_bottom);
        make.centerX.equalTo(self.view);
        make.width.mas_equalTo(300);
        make.height.mas_equalTo(32);
    }];
    
    /* 美颜调节 */
    _demoBar = [[FUAPIDemoBar alloc] init];
    [_demoBar reloadShapView:self.baseManager.shapeParams];
    [_demoBar reloadSkinView:self.baseManager.skinParams];
    [_demoBar reloadFilterView:self.baseManager.filters];
    [_demoBar reloadStyleView:self.baseManager.styleParams defaultStyle:self.baseManager.currentStyle];
//    if (!self.baseManager.currentStyle) {
//        [_demoBar setDefaultFilter:self.baseManager.seletedFliter];
//    }
    _demoBar.mDelegate = self;

    [self.view addSubview:_demoBar];
    [_demoBar mas_makeConstraints:^(MASConstraintMaker *make) {
        if (@available(iOS 11.0, *)) {
            make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom);
        } else {
            make.bottom.equalTo(self.view.mas_bottom);
        }
        make.left.right.equalTo(self.view);
        make.height.mas_equalTo(280);
    }];
    
    /* 下载 */
    _downloadBtn = [[UIButton alloc] init];
    _downloadBtn.backgroundColor = [UIColor whiteColor];
    _downloadBtn.layer.cornerRadius = 85/2;
    [_downloadBtn setBackgroundImage:[UIImage imageNamed:@"demo_icon_save1"] forState:UIControlStateNormal];
    [_downloadBtn addTarget:self action:@selector(downLoadAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_downloadBtn];
    [_downloadBtn mas_makeConstraints:^(MASConstraintMaker *make) {
        if (@available(iOS 11.0, *)) {
            make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom).offset(-110);
        } else {
            make.bottom.equalTo(self.view.mas_bottom).offset(-110);
        }
        make.centerX.equalTo(self.view);
        make.width.mas_equalTo(85);
        make.height.mas_equalTo(85);
    }];
    
    /* 贴纸调节 */
    _itemsView = [[FUItemsView alloc] init];
    _itemsView.delegate = self;
    [self.view addSubview:_itemsView];
    [self.itemsView updateCollectionArray:self.model.items];
    
    [_itemsView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(self.view.mas_bottom);
        make.left.right.equalTo(self.view);
        if (iPhoneXStyle) {
            make.height.mas_equalTo(84 + 34);
        }else{
            make.height.mas_equalTo(84);
        }
    }];
    
    if(self.model.type == FULiveModelTypeLvMu){
        return;
    }
    
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *effectview = [[UIVisualEffectView alloc] initWithEffect:blur];
    effectview.alpha = 1.0;
    [self.itemsView addSubview:effectview];
    [self.itemsView sendSubviewToBack:effectview];
    /* 磨玻璃 */
    [effectview mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.top.bottom.equalTo(_itemsView);
    }];
    
}

-(void)setupView1{
    NSString *bodyBeautyPath=[[NSBundle mainBundle] pathForResource:@"BodyBeautyDefault" ofType:@"json"];
    NSData *bodyData=[[NSData alloc] initWithContentsOfFile:bodyBeautyPath];
    NSDictionary *bodyDic=[NSJSONSerialization JSONObjectWithData:bodyData options:NSJSONReadingMutableContainers error:nil];
    NSArray *dataArray = [FUPositionInfo mj_objectArrayWithKeyValuesArray:bodyDic];
    
    _mBodyBeautyView = [[FUBodyBeautyView alloc] initWithFrame:CGRectMake(0, [UIScreen mainScreen].bounds.size.height - 134, [UIScreen mainScreen].bounds.size.width, 134) dataArray:dataArray];
    _mBodyBeautyView.delegate = self;
    [self.view addSubview:_mBodyBeautyView];
}


-(void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    if (self.model.type == FULiveModelTypeBeautifyFace) {
        [self.demoBar hiddenTopViewWithAnimation:YES];
    }
    
    if (self.model.type == FULiveModelTypeLvMu) {
        if(!self.videoURL){
            self.downloadBtn.hidden = NO;
            return;
        }
        
        if(!self.playBtn.hidden){
            self.downloadBtn.hidden = NO;
        }
        
    }
    
}

#pragma mark - 视频/图片处理入口
- (void)startRendering {
    [self.baseManager setOnCameraChange];
    if (self.image) {
        [self processImage];
    }else {
        if (self.videoURL) {
            self.downloadBtn.hidden = YES ;
            self.playBtn.hidden = YES ;
            
            if (self.videoReader) {
                
                [self.videoReader setVideoURL:self.videoURL];
            }else {
                self.videoReader = [[FUVideoReader alloc] initWithVideoURL:self.videoURL];
                self.videoReader.delegate = self ;
                self.glView.origintation = (int)self.videoReader.videoOrientation;
                if (self.videoReader.videoOrientation == FUVideoReaderOrientationLandscapeRight || self.videoReader.videoOrientation == FUVideoReaderOrientationLandscapeLeft) {
                }
            }
            
            [self playAction:_playBtn];
        }
    }
}

- (void)addObserver{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willResignActive) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)willResignActive    {
    
    if (self.navigationController.visibleViewController == self) {
        if (self.image) {
            _displayLink.paused = YES ;
        }else {
            [self.videoReader stopReading];
            self.videoReader = nil;
            [_avPlayer pause];
            _avPlayer = nil;
        }
        if (self.greenScreenManager) {
            self.greenScreenManager.greenScreen.pause = YES;
        }
    }
}


- (void)didBecomeActive {
    if (self.image) {
        [self processImage];
    } else {
        if (self.navigationController.visibleViewController == self && self.downloadBtn.hidden == YES) {//播放过程中
            [self startAudio];
            [self startVideo];
            self.playBtn.hidden = YES;
        }
    }
   
    
    if (self.greenScreenManager) {
        self.greenScreenManager.greenScreen.pause = NO;
    }
}



-(void)setImage:(UIImage *)image {
    NSData *imageData0 = UIImageJPEGRepresentation(image, 1.0);
    UIImage *newImage = [UIImage imageWithData:imageData0];
    
    _image = newImage;
}

-(void)setVideoURL:(NSURL *)videoURL {
    _videoURL = videoURL ;
    
}


-(int)setOrientationWithDegress:(NSInteger)degress{
    switch (degress) {
        case 0:
            return 0;
            break;
        case 1:
            return 3;
            break;
        case 2:
            return 2;
            break;
            
        case 3:
            return 1;
            break;
    }
    return 0;
}

#pragma  mark -  UI事件
-(void)downLoadAction:(UIButton *)sender {
    if (self.image) {   // 下载图片
        takePic = YES ;
    }else {             // 下载视频
        UISaveVideoAtPathToSavedPhotosAlbum(finalPath, self, @selector(video:didFinishSavingWithError:contextInfo:), NULL);
        dispatch_async(dispatch_get_main_queue(), ^{
            self.downloadBtn.hidden = YES ;
        });
    }
}

// 开始播放
- (void)playAction:(UIButton *)sender {
    sender.selected = YES ;
    sender.hidden = YES ;
    videHasRendered = NO;
    self.downloadBtn.hidden = YES ;
    
    [self startAudio];
    [self startVideo];
}


- (void)startAudio {
    /* 音频的播放 */
    if (_avPlayer) {
        [_avPlayer pause];
        _avPlayer = nil ;
    }
    _avPlayer = [[AVPlayer alloc] init];
    AVPlayerItem *item = [AVPlayerItem playerItemWithURL:self.videoURL];
    [_avPlayer replaceCurrentItemWithPlayerItem:item];
    _avPlayer.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    [_avPlayer play];
}

- (void)startVideo {
    if (self.videoReader) {
        [self.videoReader setVideoURL:self.videoURL];
    }else {
        self.videoReader = [[FUVideoReader alloc] initWithVideoURL:self.videoURL];
        self.videoReader.delegate = self ;
    }
    [self.videoReader startReadWithDestinationPath:finalPath];
    
    self.glView.origintation = (int)self.videoReader.videoOrientation ;
}


- (void)backAction:(UIButton *)sender {
    if (self.baseManager) {
        [self.baseManager updateBeautyCache];
        [self.baseManager releaseItem];
    }
    
    if (self.stickManager) {
        [self.stickManager releaseItem];
    }

    if (self.greenScreenManager) {
        [self.greenScreenManager.greenScreen stopVideoDecode];
        [self.greenScreenManager releaseItem];
    }
    [self.videoReader stopReading];
    [self.videoReader destory];
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)compareTouchDown {
    self.openComp = YES;
}

- (void)compareTouchUp {
    self.openComp = NO;
}

#pragma mark - FUVideoReaderDelegate

-(CVPixelBufferRef)videoReaderDidReadVideoBuffer:(CVPixelBufferRef)pixelBuffer {
    
    UIImage *newImage = nil;
    CVPixelBufferRef outPixelBuffer = NULL;
    if (!_openComp) {
        FURenderInput *input = [[FURenderInput alloc] init];
        input.pixelBuffer = pixelBuffer;
        input.renderConfig.imageOrientation = 0;
        switch (self.videoReader.videoOrientation) {
            case FUVideoReaderOrientationPortrait:
                input.renderConfig.imageOrientation = FUImageOrientationUP;
                break;
            case FUVideoReaderOrientationLandscapeRight:
                input.renderConfig.imageOrientation = FUImageOrientationLeft;
                break;
            case FUVideoReaderOrientationUpsideDown:
                input.renderConfig.imageOrientation = FUImageOrientationDown;
                break;
            case FUVideoReaderOrientationLandscapeLeft:
                input.renderConfig.imageOrientation = FUImageOrientationRight;
                break;
            default:
                input.renderConfig.imageOrientation = FUImageOrientationUP;
                break;
        }
        FURenderOutput *outPut =  [[FURenderKit shareRenderKit] renderWithInput:input];
        outPixelBuffer = outPut.pixelBuffer;
 
        if (takePic) {
            takePic = NO ;
            newImage = [FUImageHelper imageFromPixelBuffer:outPixelBuffer];
            dispatch_async(dispatch_get_global_queue(0, 0), ^{
                if (newImage) {
                    UIImageWriteToSavedPhotosAlbum(newImage, self, @selector(image:didFinishSavingWithError:contextInfo:), NULL);
                }
            });
        }
    } else {
        outPixelBuffer = pixelBuffer;
    }
    
//    w = CVPixelBufferGetWidth(outPixelBuffer);
//    h = CVPixelBufferGetHeight(outPixelBuffer);
    [self.glView displayPixelBuffer:outPixelBuffer];
//    [self.glView displaySyncPixelBuffer:outPixelBuffer];
    
    if(self.model.type == FULiveModelTypeBeautifyFace){
        self.noTrackLabel.hidden = [self.baseManager faceTrace];
    }else{
        self.noTrackLabel.hidden = YES;
    }
    
    //绿慕取色
    if (self.greenScreenManager) {
        [self getColorWithPixelBuffer:outPixelBuffer];
    }
    
    return outPixelBuffer;
}

// 读取结束
-(void)videoReaderDidFinishReadSuccess:(BOOL)success {
    [self.videoReader startReadForLastFrame];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.playBtn.hidden = NO ;
        
        if (self.model.type == FULiveModelTypeLvMu) {
            if (self.lvmuEditeView.isHidenTop) {
                self.downloadBtn.hidden = NO ;
            }else{
                self.downloadBtn.hidden = YES ;
            }
        }else{
            self.downloadBtn.hidden = NO;
        }
        
        if (self.model.type == FULiveModelTypeBeautifyFace) {
            self.downloadBtn.hidden = self.demoBar.isTopViewShow ;
        }
    });
    
    //    [self.videoReader startReadForLastFrame];
    videHasRendered = YES ;
}

#pragma  mark ---- process image

- (void)processImage  {
    
    if (!_displayLink) {
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkAction)];
        [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
        [_displayLink setFrameInterval:10];
        _displayLink.paused = NO;
    }
    if (_displayLink.paused) {
        _displayLink.paused = NO ;
    }
}

- (void)displayLinkAction{
    
    [self.renderOperationQueue addOperationWithBlock:^{
        [self.baseManager updateBeautyBlurEffect];
        @autoreleasepool {//防止大图片，内存峰值过高
            UIImage *newImage = nil;
            currentImageBuffer = [_image getImageBuffer];
            if (!_openComp) {
                FURenderInput *input = [[FURenderInput alloc] init];
                input.renderConfig.imageOrientation = 0;
                switch (_image.imageOrientation) {
                    case UIImageOrientationUp:
                        input.renderConfig.imageOrientation = FUImageOrientationUP;
                        break;
                    case UIImageOrientationLeft:
                        input.renderConfig.imageOrientation = FUImageOrientationRight;
                        break;
                    case UIImageOrientationDown:
                        input.renderConfig.imageOrientation = FUImageOrientationDown;
                        break;
                    case UIImageOrientationRight:
                        input.renderConfig.imageOrientation = FUImageOrientationLeft;
                        break;
                    default:
                        input.renderConfig.imageOrientation = FUImageOrientationUP;
                        break;
                }
                input.imageBuffer = currentImageBuffer;

                FURenderOutput *outPut =  [[FURenderKit shareRenderKit] renderWithInput:input];

                if (takePic) {
                    currentImageBuffer = outPut.imageBuffer;
                    newImage = [UIImage imageWithRGBAImageBuffer:&currentImageBuffer autoFreeBuffer:NO];
                    takePic = NO ;
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                        UIImageWriteToSavedPhotosAlbum(newImage, self, @selector(image:didFinishSavingWithError:contextInfo:), NULL);
                    }];
                }
            }

            [self.glView displayImageData:currentImageBuffer.buffer0 withSize:currentImageBuffer.size];
            
            //绿慕取色
            if (self.greenScreenManager) {
                newImage = [UIImage imageWithRGBAImageBuffer:&currentImageBuffer autoFreeBuffer:NO];
                [self getColorWithImage:newImage];
            }
            [UIImage freeImageBuffer:&currentImageBuffer];
        }
        
        //绿慕特殊处理
        if(self.model.type == FULiveModelTypeLvMu){
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                self.noTrackLabel.hidden = YES;
            }];
            return ;
        }
        
        //美体特殊处理
        if (self.model.type == FULiveModelTypeBody) {
            BOOL result = [self.baseManager bodyTrace];
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                self.noTrackLabel.text = FUNSLocalizedString(@"未检测到人体",nil);
                self.noTrackLabel.hidden = result;
            }];
            return ;
        }
        
        
        BOOL isTrack = [self.baseManager faceTrace];
        
        if (!isTrack) {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                self.noTrackLabel.text = FUNSLocalizedString(@"未识别到人脸", nil) ;
                if (self.noTrackLabel.hidden) {
                    self.noTrackLabel.hidden = NO ;
                }
            }];
        }else {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                if (!self.noTrackLabel.hidden) {
                    self.noTrackLabel.hidden = YES ;
                }
            }];
        }
    }];
}


#pragma  mark -  FUBodyBeautyViewDelegate
-(void)bodyBeautyViewDidSelectPosition:(FUPositionInfo *)position{
    if (!position.bundleKey) {
        return;
    }
    [self.bodyBeautyManager setBodyBeautyModel:position];
}

#pragma  mark -  FULvMuViewDelegate && 绿慕模块
- (void)getColorWithPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    if (!CGPointEqualToPoint(CGPointZero, _currPoint)) {
        UIColor *color = [UIColor blackColor];
        CGPoint takePoint = [self currentTakePointWithImageWidth:CVPixelBufferGetWidth(pixelBuffer) imageHeight:CVPixelBufferGetHeight(pixelBuffer)];
        if (!CGPointEqualToPoint(CGPointZero, takePoint)) {
            // 获取实际点的颜色
            color = [FUGreenScreen pixelColorWithPixelBuffer:pixelBuffer point:takePoint];
        }
        if (color) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.lvmuEditeView setTakeColor:color];
            });
        }
    }
}


- (void)getColorWithImage:(UIImage *)image {
    if (!CGPointEqualToPoint(CGPointZero, _currPoint)) {
        UIColor *color = [UIColor blackColor];
        CGPoint takePoint = [self currentTakePointWithImageWidth:image.size.width imageHeight:image.size.height];
        if (!CGPointEqualToPoint(CGPointZero, takePoint)) {
            // 获取实际点的颜色
            color = [FUGreenScreen pixelColorWithImage:image point:takePoint];
        }
        if (color) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.lvmuEditeView setTakeColor:color];
            });
        }
    }
}

- (CGPoint)currentTakePointWithImageWidth:(CGFloat)width imageHeight:(CGFloat)height {
    CGFloat scale = [UIScreen mainScreen].scale;
    CGFloat viewWidth = CGRectGetWidth(self.glView.bounds) * scale;
    CGFloat viewHeight = CGRectGetHeight(self.glView.bounds) * scale;
    
    // 宽度比例
    CGFloat widthRatio = width / viewWidth;
    // 高度比例
    CGFloat heightRatio = height / viewHeight;
    // 图片实际在glView上的位置
    CGRect imageRect;
    // 展示图片的比例
    CGFloat targetRatio;
    // 对比高度比例和宽度比例决定高度充满还是宽度充满
    if (widthRatio >= heightRatio) {
        // 宽度充满
        targetRatio = widthRatio;
        CGFloat imageHeight = height / targetRatio;
        imageRect = CGRectMake(0, viewHeight/2.f - imageHeight/2.0, viewWidth, imageHeight);
    } else {
        // 高度充满
        targetRatio = heightRatio;
        CGFloat imageWidth = width / targetRatio;
        imageRect = CGRectMake(viewWidth/2.f - imageWidth/2.0, 0, imageWidth, viewHeight);
    }
    
    CGPoint takePoint = CGPointZero;
    if (CGRectContainsPoint(imageRect, CGPointMake(_currPoint.x * scale, _currPoint.y * scale))) {
        // 点位在图片展示区域内，则获取实际点
        CGPoint resultPoint = CGPointMake(_currPoint.x - imageRect.origin.x / scale, _currPoint.y - imageRect.origin.y / scale);
        takePoint = CGPointMake(resultPoint.x * targetRatio, resultPoint.y * targetRatio);
    }
    return takePoint;
}

-(void)beautyCollectionView:(FULvMuView *)beautyView didSelectedParam:(FUGreenScreenModel *)param{
    [self.greenScreenManager setGreenScreenModel:param];
}

- (void)lvmuViewDidSelectSafeArea:(FUGreenScreenSafeAreaModel *)model {
    if (model.effectImage) {
        [self.greenScreenManager updateSafeAreaImage:model.effectImage];
    }
}

- (void)lvmuViewDidCancelSafeArea {
    [self.greenScreenManager updateSafeAreaImage:nil];
}

-(void)colorDidSelected:(UIColor *)color {
    [self.greenScreenManager setGreenScreenWithColor:color];
    NSLog(@"取色值 %@",color);
}


-(void)lvmuViewShowTopView:(BOOL)shown{
    float h = shown?180:49;
    [self setPhotoScaleWithHeight:h show:shown];
    
    if(!self.videoURL){
        self.downloadBtn.hidden = shown;
        return;;
    }
    
    if(!self.playBtn.isHidden && !shown){
        self.downloadBtn.hidden = NO;
    }else{
        self.downloadBtn.hidden = YES;
    }
}


- (void)setPhotoScaleWithHeight:(CGFloat)height show:(BOOL)shown {
    if (shown) {
        
        CGAffineTransform photoTransform0 = CGAffineTransformMakeTranslation(0, height * -0.6) ;
        CGAffineTransform photoTransform1 = CGAffineTransformMakeScale(0.9, 0.9);
        [UIView animateWithDuration:0.35 animations:^{
            
            self.downloadBtn.transform = CGAffineTransformConcat(photoTransform0, photoTransform1) ;
            
        }];
    } else {
        [UIView animateWithDuration:0.35 animations:^{
            self.downloadBtn.transform = CGAffineTransformIdentity ;
        }];
    }
}

-(void)didSelectedParam:(FUGreenScreenBgModel *)param {
    if(param.videoPath){
        NSString *urlStr = [[NSBundle mainBundle] pathForResource:param.videoPath ofType:@"mp4"];
        self.greenScreenManager.greenScreen.videoPath = urlStr;
    }else{
        [self.greenScreenManager.greenScreen stopVideoDecode];
    }
}

/* 取色的时候，不rendder */
-(void)takeColorState:(FUTakeColorState)state{
    if (state == FUTakeColorStateStop) {
        self.greenScreenManager.greenScreen.cutouting = NO;
    }else{
        self.greenScreenManager.greenScreen.cutouting = YES;
    }
}

- (void)getPoint:(CGPoint)point {
    _currPoint = point;
}

//从外面获取全局的取点背景view，为了修复取点view加载Window上的系统兼容性问题
- (UIView *)takeColorBgView {
    UIView *bgView = [[UIView alloc] initWithFrame:self.glView.frame];
    [self.view insertSubview:bgView aboveSubview:self.glView];
    return bgView;
}

/**设置美颜参数*/
#pragma mark -  FUAPIDemoBarDelegate
- (void)resetDefaultValue:(NSUInteger)type {
    [self.baseManager resetDefaultParams:type];
}

//美型是否全部是默认参数
- (BOOL)isDefaultShapeValue {
    return [self.baseManager isDefaultShapeValue];
}

//美肤是否全部是默认参数
- (BOOL)isDefaultSkinValue {
    return [self.baseManager isDefaultSkinValue];
}


- (void)showTopView:(BOOL)shown{
    if (shown) {
        _compBtn.hidden = NO;
        self.downloadBtn.hidden = YES ;
    }else {
        _compBtn.hidden = YES;
        if (self.image) {
            self.downloadBtn.hidden = NO ;
        }else {
            self.downloadBtn.hidden = !videHasRendered ;
        }
    }
}

- (void)filterValueChange:(FUBeautyModel *)param{
    [self.baseManager setFilterkey:[param.strValue lowercaseString]];
    self.baseManager.beauty.filterLevel = param.mValue;
    self.baseManager.seletedFliter = param;
}

- (void)beautyParamValueChange:(FUBeautyModel *)param{
    switch (param.type) {
        case FUBeautyDefineShape: {
            [self.baseManager setShap:param.mValue forKey:param.mParam];
        }
            break;
        case FUBeautyDefineSkin: {
            [self.baseManager setSkin:param.mValue forKey:param.mParam];
        }
            break;
        case FUBeautyDefineStyle: {
            [self.baseManager setStyleBeautyParams:(FUStyleModel *)param];
        }
            break;
        default:
            break;
    }
}

- (void)dismissTipLabel {
    self.tipLabel.hidden = YES;
}

#pragma  mark ----  手势事件  -----
-(void)handlePanGesture:(UIPanGestureRecognizer *) panGesture{
    UIView *view = panGesture.view;
    if (panGesture.state == UIGestureRecognizerStateBegan || panGesture.state == UIGestureRecognizerStateChanged){
        CGPoint translation = [panGesture translationInView:view.superview];
        FUVideoReaderOrientation sdkOrientation = self.videoReader.videoOrientation;
        float dx ,dy;
        dx = translation.x/CGRectGetWidth(self.view.bounds);
        dy = translation.y/CGRectGetHeight(self.view.bounds);
        switch (sdkOrientation) {
            case FUVideoReaderOrientationPortrait:
                self.greenScreenManager.greenScreen.center = CGPointMake(self.greenScreenManager.greenScreen.center.x + dx, self.greenScreenManager.greenScreen.center.y + dy);
                break;
            case FUVideoReaderOrientationUpsideDown:
                self.greenScreenManager.greenScreen.center = CGPointMake(self.greenScreenManager.greenScreen.center.x - dx, self.greenScreenManager.greenScreen.center.y - dy);
                break;
            case FUVideoReaderOrientationLandscapeRight:
                self.greenScreenManager.greenScreen.center = CGPointMake(self.greenScreenManager.greenScreen.center.x + dy, self.greenScreenManager.greenScreen.center.y - dx);
                break;
            case FUVideoReaderOrientationLandscapeLeft:
                self.greenScreenManager.greenScreen.center = CGPointMake(self.greenScreenManager.greenScreen.center.x - dy, self.greenScreenManager.greenScreen.center.y + dx);
                break;
            default:
                self.greenScreenManager.greenScreen.center = CGPointMake(self.greenScreenManager.greenScreen.center.x + dx, self.greenScreenManager.greenScreen.center.y + dy);
                break;
        }
        [panGesture setTranslation:CGPointZero inView:view.superview];
    }
}

-(void)handlePinchGesture:(UIPinchGestureRecognizer *)pinchGesture{
    if (pinchGesture.state == UIGestureRecognizerStateBegan || pinchGesture.state == UIGestureRecognizerStateChanged) {
        self.greenScreenManager.greenScreen.scale *= pinchGesture.scale;
        pinchGesture.scale = 1;
    }
}


#pragma mark - FUItemsViewDelegate
- (void)itemsViewDidSelectedItem:(NSString *)item indexPath:(NSIndexPath *)indexPath {
    __weak typeof(self) weak = self;
    [self.itemsView startAnimation];
    [self.stickManager loadItem:item completion:^(BOOL finished) {
        /* 设置成默认检测方向 */
        switch (weak.stickManager.type) {
            case FUGestureType: {
//                int sdkOrientation = [weak setOrientationWithDegress:(int)weak.videoReader.videoOrientation];
//                weak.stickManager.gestureItem.rotMode = sdkOrientation;
            }
                break;
                
            default:
                break;
        }
        [weak.itemsView stopAnimation];
    }];
}


- (void)image: (UIImage *) image didFinishSavingWithError: (NSError *) error contextInfo: (void *) contextInfo  {
    if(error != NULL){
        [SVProgressHUD showErrorWithStatus:FUNSLocalizedString(@"保存图片失败", nil)];
    }else{
        [SVProgressHUD showSuccessWithStatus:FUNSLocalizedString(@"图片已保存到相册", nil)];
    }
}

- (void)video:(NSString *)videoPath didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{
    if(error != NULL){
        [SVProgressHUD showErrorWithStatus:FUNSLocalizedString(@"保存视频失败", nil)];
        
    }else{
        [SVProgressHUD showSuccessWithStatus:FUNSLocalizedString(@"视频已保存到相册", nil)];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


#pragma mark - Getters
- (FUGLDisplayView *)glView {
    if (!_glView) {
        _glView = [[FUGLDisplayView alloc] initWithFrame:self.view.bounds];
        // 长边充满，短边等比放大或缩小
        _glView.contentMode = FUGLDisplayViewContentModeScaleAspectFit;
    }
    return _glView;
}

- (FUStickerManager *)stickManager {
    if (!_stickManager) {
        _stickManager = [[FUStickerManager alloc] init];
    }
    return _stickManager;
}

- (NSOperationQueue *)renderOperationQueue {
    if (!_renderOperationQueue) {
        _renderOperationQueue = [[NSOperationQueue alloc] init];
        _renderOperationQueue.maxConcurrentOperationCount = 1;
    }
    return _renderOperationQueue;
}

@end
