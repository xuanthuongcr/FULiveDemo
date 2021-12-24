//
//  FUMakeupController.m
//  FULiveDemo
//
//  Created by 孙慕 on 2019/1/30.
//  Copyright © 2019年 FaceUnity. All rights reserved.
//

#import "FUMakeupController.h"
#import "FUMakeUpView.h"
#import "FUManager.h"
#import "FUMakeupSupModel.h"
#import "MJExtension.h"
#import "FUColourView.h"
#import "FUMakeupManager.h"

#import "FULandmarkManager.h"

@interface FUMakeupController ()<FUMakeUpViewDelegate,FUColourViewDelegate>
/* 化妆视图 */
@property (nonatomic, strong) FUMakeUpView *makeupView ;
/* 颜色选择视图 */
@property (nonatomic, strong) FUColourView *colourView;

@property (strong, nonatomic) FUMakeupManager *makeupManager;
@end

@implementation FUMakeupController
- (void)viewDidLoad {
    [super viewDidLoad];
//    [[FUManager shareManager] loadMakeupType:@"new_face_tracker"];
    self.makeupManager = [[FUMakeupManager alloc] init];

    [self setupView];
    [self setupColourView];
    
    [self.makeupView reloadDataArray: self.makeupManager.dataArray];
    [self.makeupView reloadSupArray: self.makeupManager.supArray];
    
    /* 美妆道具 */
    [_makeupView setSelSupItem:1];
    
    self.canPushImageSelView = NO;
}

-(void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    
    // 添加点位测试开关
    if (FUShowLandmark) {
        [FULandmarkManager show];
    }
    
}
-(void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    
    if (FUShowLandmark) {
        [FULandmarkManager dismiss];
    }
}

- (void)headButtonViewBackAction:(UIButton *)btn {
    [super headButtonViewBackAction:btn];
    [self.makeupManager releaseItem];
}

-(void)setupColourView{
    if (iPhoneXStyle) {
        _colourView = [[FUColourView alloc] initWithFrame:CGRectMake(self.view.frame.size.width - 15 - 60, self.view.frame.size.height - 250 - 182 - 10 - 34, 60, 250)];
    }else{
        _colourView = [[FUColourView alloc] initWithFrame:CGRectMake(self.view.frame.size.width - 15 - 60, self.view.frame.size.height - 250 - 182 - 10, 60, 250)];
    }
    _colourView.delegate = self;
    _colourView.hidden = YES;
    [self.view addSubview:_colourView];
    
}

-(void)setupView{
    _makeupView = [[FUMakeUpView alloc] init];
    _makeupView.delegate = self;

    _makeupView.backgroundColor = [UIColor clearColor];
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *effectview = [[UIVisualEffectView alloc] initWithEffect:blur];
    [_makeupView.topView addSubview:effectview];
    [_makeupView.topView sendSubviewToBack:effectview];
    /* 磨玻璃 */
    [effectview mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.top.bottom.equalTo(_makeupView.topView);
    }];
    
    UIBlurEffect *blur1 = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *effectview1 = [[UIVisualEffectView alloc] initWithEffect:blur1];
    _makeupView.bottomCollection.backgroundView = effectview1;
    /* 磨玻璃 */
    [effectview1 mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.bottom.equalTo(_makeupView);
        make.height.mas_equalTo(_makeupView.bottomCollection.bounds.size.height);
    }];
    
    [self.view insertSubview:_makeupView belowSubview:self.photoBtn];
    
    [_makeupView mas_makeConstraints:^(MASConstraintMaker *make) {
        if (@available(iOS 11.0, *)) {
            make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom);
        } else {
            make.bottom.equalTo(self.view.mas_bottom);
        }
        make.left.right.equalTo(self.view);
        make.height.mas_equalTo(182);
    }];
    
    self.photoBtn.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0, -100), CGAffineTransformMakeScale(0.8, 0.8));
    
    if(iPhoneXStyle){
        UIBlurEffect *blur2 = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        UIVisualEffectView *effectview2 = [[UIVisualEffectView alloc] initWithEffect:blur2];
        [self.view addSubview:effectview2];
        [self.view sendSubviewToBack:effectview2];
        [effectview2 mas_makeConstraints:^(MASConstraintMaker *make) {
            make.bottom.equalTo(self.view.mas_bottom);
            make.left.right.equalTo(self.view);
            make.height.mas_equalTo(34);
        }];
    }
    
    
}

#pragma mark -  FUMakeUpViewDelegate
-(void)makeupViewDidSelectedSupModle:(FUMakeupSupModel *)model {
    [self.makeupManager setSupModel:model];
    [self modifyFilter:model];
}

-(void)makeupViewChangeValueSupModle:(FUMakeupSupModel *)model {
    [self.makeupManager setMakeupWholeModel:model];
    [self modifyFilter:model];
}

- (void)modifyFilter:(FUMakeupSupModel *)model {
    if (model.isCombined) {
        // 新组合妆直接设置滤镜程度
        [self.makeupManager updateMakeupFilterLevel:model];
    } else {
        // 老组合妆修改美颜的滤镜
        if (!model.selectedFilter || [model.selectedFilter isEqualToString:@""]) {
            FUBeautyModel *param = self.baseManager.seletedFliter;
            self.baseManager.beauty.filterName = [param.strValue lowercaseString];
            self.baseManager.beauty.filterLevel = param.mValue;
        }else {
            self.baseManager.beauty.filterName = [model.selectedFilter lowercaseString];
            self.baseManager.beauty.filterLevel = model.value;
        }
    }
    
}


- (void)makeupViewDidSelectedModel:(FUSingleMakeupModel *)model type:(UIMAKEUITYPE)type {
    model.realValue = model.value;
    [self.makeupManager setMakeupSupModel:model type:type];
    
}


-(void)makeupCustomShow:(BOOL)isShow{
    if (isShow) {
        [UIView animateWithDuration:0.2 animations:^{
            self.photoBtn.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0, -150), CGAffineTransformMakeScale(0.8, 0.8)) ;
        }];
    } else {
        [UIView animateWithDuration:0.2 animations:^{
            self.photoBtn.transform = CGAffineTransformConcat(CGAffineTransformMakeTranslation(0, -100), CGAffineTransformMakeScale(0.8, 0.8));
        }];
    }
}


-(void)makeupViewSelectiveColorArray:(NSArray<NSArray *> *)colors selColorIndex:(int)index {
    [_colourView setDataColors:colors];
    [_colourView setSelCell:index];
}

-(void)makeupSelColorState:(BOOL)state {
    _colourView.hidden = state ? NO :YES;
}


-(void)makeupViewDidSelTitle:(NSString *)nama{
    self.tipLabel.hidden = NO;
    self.tipLabel.text = FUNSLocalizedString(nama, nil);
    [FUMakeupController cancelPreviousPerformRequestsWithTarget:self selector:@selector(dismissTipLabel) object:nil];
    [self performSelector:@selector(dismissTipLabel) withObject:nil afterDelay:1];
}

- (void)dismissTipLabel{
    self.tipLabel.hidden = YES;
}

#pragma  mark -  FUColourViewDelegate
-(void)colourViewDidSelIndex:(int)index{
    [_makeupView changeSubItemColorIndex:index];
}

@end
