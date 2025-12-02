//
//  ConfigBackgroundView.m
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

#import "ConfigBackgroundView.h"
#import <Masonry/Masonry.h>

@interface ConfigBackgroundView ()

@property (nonatomic, strong, readwrite) UITextField *channelNameTextField;
@property (nonatomic, strong, readwrite) UIButton *startButton;

@end

@implementation ConfigBackgroundView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupUI];
        [self setupConstraints];
    }
    return self;
}

- (instancetype)init {
    return [self initWithFrame:CGRectZero];
}

- (void)setupUI {
    self.backgroundColor = [UIColor whiteColor];
    
    // Channel Name TextField
    self.channelNameTextField = [[UITextField alloc] init];
    self.channelNameTextField.placeholder = @"输入频道名称";
    self.channelNameTextField.borderStyle = UITextBorderStyleRoundedRect;
    [self addSubview:self.channelNameTextField];
    
    // Start Button
    self.startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.startButton setTitle:@"连接对话式AI引擎" forState:UIControlStateNormal];
    [self.startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.startButton setTitleColor:[[UIColor whiteColor] colorWithAlphaComponent:0.5] 
                            forState:UIControlStateDisabled];
    self.startButton.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.4];
    self.startButton.layer.cornerRadius = 25;
    self.startButton.enabled = NO;
    [self addSubview:self.startButton];
}

- (void)setupConstraints {
    [self.channelNameTextField mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self);
        make.centerY.equalTo(self).offset(-40);
        make.width.mas_equalTo(250);
        make.height.mas_equalTo(50);
    }];
    
    [self.startButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self);
        make.top.equalTo(self.channelNameTextField.mas_bottom).offset(30);
        make.width.mas_equalTo(250);
        make.height.mas_equalTo(50);
    }];
}

- (void)updateButtonState:(BOOL)isEnabled {
    self.startButton.enabled = isEnabled;
    self.startButton.backgroundColor = isEnabled ? 
        [UIColor systemBlueColor] : 
        [[UIColor systemBlueColor] colorWithAlphaComponent:0.4];
}

@end

