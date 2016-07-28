//
//  FMLClipFrameView.m
//  VideoClip
//
//  Created by samo on 16/7/27.
//  Copyright © 2016年 Collion. All rights reserved.
//

#import "FMLClipFrameView.h"
#import <Masonry.h>
#import <AVFoundation/AVFoundation.h>
#import "AVAsset+FMLVideo.h"
#import <BlocksKit+UIKit.h>

#define FMLLineW 3                // 线宽
#define FMLImagesViewH 40  // 预览图高度

#define FMLImageCount 8     // 显示的图片个数

@interface FMLClipFrameView ()

@property (nonatomic, assign) Float64 totalSeconds;         ///< 总秒数
@property (nonatomic, strong) AVAsset *asset;
@property (nonatomic, assign) NSUInteger minSeconds;  ///< 最少多少秒

@property (nonatomic, strong) UILabel *startTimeLabel;  ///< 开始秒数
@property (nonatomic, strong) UILabel *endTimeLabel;   ///< 结束秒数
@property (nonatomic, strong) UILabel *clipSecondLabel; ///< 一共截多少秒

@property (nonatomic, strong) UIView *imagesView;   ///< 显示帧图片列表

@property (nonatomic, strong) UIView *leftDragView;     ///< 左边时间拖拽view
@property (nonatomic, strong) UIView *rightDragView;  ///< 右边时间拖拽view

@end

@implementation FMLClipFrameView

- (instancetype)initWithAsset:(AVAsset *)asset minSeconds:(NSUInteger)seconds
{
    if (self = [super init]) {
        _asset = asset;
        _minSeconds = seconds;
        
        [self initView];
        [self initData];
    }
    
    return self;
}

#pragma mark - 初始化
- (void)initView
{
    self.backgroundColor = [UIColor whiteColor];
    
    UILabel *startTimeLabel = [UILabel new];
    startTimeLabel.text = @"00:00";
    [self addSubview:startTimeLabel];
    self.startTimeLabel = startTimeLabel;
    [startTimeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(15);
        make.top.mas_equalTo(15);
    }];
    
    UILabel *endTimeLabel = [UILabel new];
    endTimeLabel.text = @"00:00";
    [self addSubview:endTimeLabel];
    self.endTimeLabel = endTimeLabel;
    [endTimeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.mas_equalTo(-15);
        make.top.mas_equalTo(startTimeLabel);
    }];
    
    UILabel *clipSecondLabel = [UILabel new];
    [self addSubview:clipSecondLabel];
    self.clipSecondLabel = clipSecondLabel;
    [clipSecondLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(startTimeLabel);
        make.centerX.mas_equalTo(self);
    }];
    
    UIView *imagesView = [UIView new];
    [self addSubview:imagesView];
    self.imagesView = imagesView;
    [imagesView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.mas_equalTo(startTimeLabel.mas_bottom).offset(15);
        make.height.mas_equalTo(FMLImagesViewH);
        make.left.mas_equalTo(0);
        make.right.mas_equalTo(0);
    }];
    
    [self setUpDragView];
}

/** 初始化拖拽view */
- (void)setUpDragView
{
    // 添加左右拖拽view
    UIView *leftDragView = [UIView new];
    [leftDragView addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(leftDragGesture:)]];
    leftDragView.layer.contents = (id) [UIImage imageNamed:@"cut_bar_left"].CGImage;
    [self addSubview:leftDragView];
    [leftDragView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.size.mas_equalTo(CGSizeMake(28, 75));
        make.left.mas_equalTo(0);
        make.top.mas_equalTo(self.imagesView).offset(-6);
    }];
    
    UIView *rightDragView = [UIView new];
    [rightDragView addGestureRecognizer:[[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(rightDragGesture:)]];
    rightDragView.layer.contents = (id) [UIImage imageNamed:@"cut_bar_right"].CGImage;
    [self addSubview:rightDragView];
    [rightDragView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.size.mas_equalTo(CGSizeMake(28, 75));
        make.right.mas_equalTo(0);
        make.top.mas_equalTo(self.imagesView).offset(-6);
    }];
    
    // 添加一个底层蓝色背景的view
    UIView *imagesBackView = [UIView new];
    imagesBackView.backgroundColor = SMSColor(2, 212, 225);
    [self insertSubview:imagesBackView belowSubview:self.imagesView];
    [imagesBackView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(leftDragView.mas_left).offset(FMLLineW);
        make.right.mas_equalTo(rightDragView.mas_right).offset(-FMLLineW);
        make.top.mas_equalTo(self.imagesView.mas_top).offset(-FMLLineW);
        make.bottom.mas_equalTo(self.imagesView.mas_bottom).offset(FMLLineW);
    }];
    
    // 添加左右侧阴影view
    UIView *leftShadowView = [UIView new];
    leftShadowView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    [self addSubview:leftShadowView];
    [leftShadowView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.mas_equalTo(0);
        make.right.mas_equalTo(leftDragView.mas_left);
        make.top.bottom.mas_equalTo(imagesBackView);
    }];
    
    UIView *rightShadowView = [UIView new];
    rightShadowView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    [self addSubview:rightShadowView];
    [rightShadowView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.mas_equalTo(0);
        make.left.mas_equalTo(rightDragView.mas_right);
        make.top.bottom.mas_equalTo(imagesBackView);
    }];
}

- (void)initData
{
    __block NSUInteger i = 0;
    CGFloat imageW = [UIScreen mainScreen].bounds.size.width / FMLImageCount;
    CGFloat imageH = FMLImagesViewH;
    
    __weak typeof(self) weakSelf = self;
    [self.asset getImagesCount:FMLImageCount imageBackBlock:^(UIImage *image) {
        CGFloat imageX = i * imageW;
        
        CALayer *imageLayer = [CALayer new];
        imageLayer.contents = (id) image.CGImage;
        imageLayer.frame = CGRectMake(imageX, 0, imageW, imageH);
        
        [weakSelf.imagesView.layer addSublayer:imageLayer];
        
        i++;
    }];
    
    // 现实秒数
    self.totalSeconds = [self.asset getSeconds];
    self.endTimeLabel.text = [self secondsToStr:self.totalSeconds];
    self.clipSecondLabel.text = [NSString stringWithFormat:@"%.1f", self.totalSeconds];
}

/** 将秒转为字符串 */
- (NSString *)secondsToStr:(Float64)seconds
{
    NSInteger secondI = (NSInteger) seconds;
    NSInteger second = ceil(secondI % 60);
    NSInteger minute = ceil((secondI / 60) % secondI);
    return [NSString stringWithFormat:@"%02ld:%02ld", second, minute];
}

#pragma mark - 拖拽事件
 - (void)leftDragGesture:(UIPanGestureRecognizer *)ges
{
    CGPoint translation = [ges translationInView:self];
    
    if (ges.view.x + translation.x >= 0) {
        [ges.view mas_updateConstraints:^(MASConstraintMaker *make) {
            make.left.mas_equalTo(ges.view.x + translation.x);
        }];
    }
    
    [ges setTranslation:CGPointZero inView:self];
    
    Float64 leftSecond = ges.view.x / self.width * self.totalSeconds;
    self.startTimeLabel.text = [self secondsToStr:leftSecond];
    
}

- (void)rightDragGesture:(UIPanGestureRecognizer *)ges
{
    CGPoint translation = [ges translationInView:self];
    
    if (CGRectGetMaxX(ges.view.frame)+ translation.x <= self.width) {
        CGFloat distance = self.width - (CGRectGetMaxX(ges.view.frame) + translation.x);
        [ges.view mas_updateConstraints:^(MASConstraintMaker *make) {
            make.right.mas_equalTo(-distance);
        }];
    }
    
    [ges setTranslation:CGPointZero inView:self];
}

@end
