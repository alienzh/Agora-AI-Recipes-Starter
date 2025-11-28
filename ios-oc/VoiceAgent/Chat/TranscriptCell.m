//
//  TranscriptCell.m
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

#import "TranscriptCell.h"
#import <Masonry/Masonry.h>
#import "VoiceAgent-Swift.h"

@interface TranscriptCell ()

@property (nonatomic, strong) UIView *avatarView;
@property (nonatomic, strong) UILabel *avatarLabel;
@property (nonatomic, strong) UILabel *messageLabel;
@property (nonatomic, strong) UIView *containerView;

@end

@implementation TranscriptCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        [self setupUI];
    }
    return self;
}

- (void)setupUI {
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    self.backgroundColor = [UIColor clearColor];
    
    self.containerView = [[UIView alloc] init];
    self.containerView.backgroundColor = [UIColor colorWithWhite:0.95 alpha:1.0];
    self.containerView.layer.cornerRadius = 8;
    [self.contentView addSubview:self.containerView];
    
    self.avatarView = [[UIView alloc] init];
    self.avatarView.layer.cornerRadius = 16;
    [self.containerView addSubview:self.avatarView];
    
    self.avatarLabel = [[UILabel alloc] init];
    self.avatarLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    self.avatarLabel.textColor = [UIColor whiteColor];
    self.avatarLabel.textAlignment = NSTextAlignmentCenter;
    [self.avatarView addSubview:self.avatarLabel];
    
    self.messageLabel = [[UILabel alloc] init];
    self.messageLabel.font = [UIFont systemFontOfSize:15];
    self.messageLabel.textColor = [UIColor labelColor];
    self.messageLabel.numberOfLines = 0;
    [self.containerView addSubview:self.messageLabel];
    
    [self.containerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.contentView).offset(4);
        make.left.equalTo(self.contentView).offset(20);
        make.bottom.equalTo(self.contentView).offset(-4);
        make.right.equalTo(self.contentView).offset(-20);
    }];
    
    [self.avatarView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.equalTo(self.containerView).inset(12);
        make.width.height.mas_equalTo(32);
    }];
    
    [self.avatarLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.avatarView);
    }];
    
    [self.messageLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.avatarView.mas_right).offset(12);
        make.right.top.bottom.equalTo(self.containerView).inset(12);
    }];
}

- (void)configureWithTranscript:(id)transcript {
    Transcript *t = (Transcript *)transcript;
    BOOL isAgent = t.type == TranscriptTypeAgent;
    self.avatarView.backgroundColor = isAgent ? [UIColor blueColor] : [UIColor greenColor];
    self.avatarLabel.text = isAgent ? @"AI" : @"我";
    self.messageLabel.text = t.text;
}

@end

