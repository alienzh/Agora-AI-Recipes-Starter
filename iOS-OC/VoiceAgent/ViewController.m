//
//  ViewController.m
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

#import "ViewController.h"
#import "ChatViewController.h"
#import <Masonry/Masonry.h>

@interface ViewController () <UITextFieldDelegate>

@property (nonatomic, strong) UIImageView *logoImageView;
@property (nonatomic, strong) UITextField *channelNameTextField;
@property (nonatomic, strong) UIButton *startButton;
@property (nonatomic, assign) NSInteger uid;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 生成随机 UID
    self.uid = arc4random() % (9999999 - 1000 + 1) + 1000;
    
    [self setupUI];
    [self setupConstraints];
}

- (void)setupUI {
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    self.title = @"VoiceAgent";
    self.navigationController.navigationBar.prefersLargeTitles = NO;
    
    // Logo ImageView
    self.logoImageView = [[UIImageView alloc] init];
    self.logoImageView.image = [UIImage imageNamed:@"logo"];
    self.logoImageView.contentMode = UIViewContentModeScaleAspectFit;
    [self.view addSubview:self.logoImageView];
    
    // Channel Name TextField
    self.channelNameTextField = [[UITextField alloc] init];
    self.channelNameTextField.placeholder = @"输入频道名称";
    self.channelNameTextField.borderStyle = UITextBorderStyleRoundedRect;
    self.channelNameTextField.delegate = self;
    [self.channelNameTextField addTarget:self 
                                   action:@selector(textFieldDidChange:) 
                         forControlEvents:UIControlEventEditingChanged];
    [self.view addSubview:self.channelNameTextField];
    
    // Start Button
    self.startButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.startButton setTitle:@"Start" forState:UIControlStateNormal];
    [self.startButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.startButton setTitleColor:[[UIColor whiteColor] colorWithAlphaComponent:0.5] 
                            forState:UIControlStateDisabled];
    self.startButton.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.4];
    self.startButton.layer.cornerRadius = 25;
    self.startButton.enabled = NO;
    [self.startButton addTarget:self 
                         action:@selector(startButtonTapped:) 
               forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.startButton];
}

- (void)setupConstraints {
    // Channel Name TextField Constraints
    [self.channelNameTextField mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view);
        make.centerY.equalTo(self.view);
        make.width.mas_equalTo(250);
        make.height.mas_equalTo(50);
    }];
    
    // Logo ImageView Constraints
    [self.logoImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view);
        make.bottom.equalTo(self.channelNameTextField.mas_top).offset(-30);
    }];
    
    // Start Button Constraints
    [self.startButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view);
        make.top.equalTo(self.channelNameTextField.mas_bottom).offset(30);
        make.width.mas_equalTo(250);
        make.height.mas_equalTo(50);
    }];
}

- (void)textFieldDidChange:(UITextField *)textField {
    [self updateButtonState];
}

- (void)startButtonTapped:(UIButton *)sender {
    NSString *channelName = [self.channelNameTextField.text stringByTrimmingCharactersInSet:
                            [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (channelName.length == 0) {
        return;
    }
    
    ChatViewController *chatViewController = [[ChatViewController alloc] initWithUid:self.uid 
                                                                              channel:channelName];
    [self.navigationController pushViewController:chatViewController animated:YES];
}

- (void)updateButtonState {
    NSString *channelName = [self.channelNameTextField.text stringByTrimmingCharactersInSet:
                            [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    BOOL isValid = channelName.length > 0;
    
    self.startButton.enabled = isValid;
    self.startButton.backgroundColor = isValid ? 
        [UIColor systemBlueColor] : 
        [[UIColor systemBlueColor] colorWithAlphaComponent:0.4];
}

@end
