//
//  ChatBackgroundView.m
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

#import "ChatBackgroundView.h"
#import "TranscriptCell.h"
#import <Masonry/Masonry.h>

@interface ChatBackgroundView ()

@property (nonatomic, strong, readwrite) UITableView *tableView;
@property (nonatomic, strong, readwrite) AgentStateView *statusView;
@property (nonatomic, strong) UIView *controlBarView;
@property (nonatomic, strong, readwrite) UIButton *micButton;
@property (nonatomic, strong, readwrite) UIButton *endCallButton;

@end

@implementation ChatBackgroundView

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
    
    // TableView for transcripts
    self.tableView = [[UITableView alloc] init];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = [UIColor clearColor];
    [self.tableView registerClass:[TranscriptCell class] forCellReuseIdentifier:@"TranscriptCell"];
    [self addSubview:self.tableView];
    
    // Status View
    self.statusView = [[AgentStateView alloc] init];
    [self addSubview:self.statusView];
    
    // Control Bar
    self.controlBarView = [[UIView alloc] init];
    self.controlBarView.backgroundColor = [UIColor whiteColor];
    self.controlBarView.layer.cornerRadius = 16;
    self.controlBarView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.controlBarView.layer.shadowOpacity = 0.1;
    self.controlBarView.layer.shadowOffset = CGSizeMake(0, 2);
    self.controlBarView.layer.shadowRadius = 8;
    [self addSubview:self.controlBarView];
    
    // Mic Button
    self.micButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.micButton setImage:[UIImage systemImageNamed:@"mic.fill"] forState:UIControlStateNormal];
    self.micButton.tintColor = [UIColor blackColor];
    [self.controlBarView addSubview:self.micButton];
    
    // End Call Button
    self.endCallButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.endCallButton setImage:[UIImage systemImageNamed:@"phone.down.fill"] forState:UIControlStateNormal];
    self.endCallButton.tintColor = [UIColor whiteColor];
    self.endCallButton.backgroundColor = [UIColor redColor];
    self.endCallButton.layer.cornerRadius = 25;
    [self.controlBarView addSubview:self.endCallButton];
}

- (void)setupConstraints {
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(self);
        make.bottom.equalTo(self.statusView.mas_top);
    }];
    
    [self.statusView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self).inset(20);
        make.bottom.equalTo(self.controlBarView.mas_top).offset(-20);
        make.height.mas_equalTo(30);
    }];
    
    [self.controlBarView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self).inset(20);
        make.bottom.equalTo(self.mas_safeAreaLayoutGuideBottom).offset(-40);
        make.height.mas_equalTo(60);
    }];
    
    [self.micButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.controlBarView);
        make.right.equalTo(self.endCallButton.mas_left).offset(-30);
        make.width.height.mas_equalTo(40);
    }];
    
    [self.endCallButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.controlBarView);
        make.width.height.mas_equalTo(50);
    }];
}

- (void)updateMicButtonState:(BOOL)isMuted {
    NSString *imageName = isMuted ? @"mic.slash.fill" : @"mic.fill";
    [self.micButton setImage:[UIImage systemImageNamed:imageName] forState:UIControlStateNormal];
}

- (void)updateStatusView:(NSInteger)state {
    [self.statusView updateState:state];
}

- (void)reloadData {
    [self.tableView reloadData];
}

- (void)scrollToBottomAnimated:(BOOL)animated {
    NSInteger rowCount = [self.dataSource numberOfTranscriptsInChatBackgroundView:self];
    if (rowCount > 0) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:rowCount - 1 inSection:0];
        [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:animated];
    }
}

// MARK: - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.dataSource numberOfTranscriptsInChatBackgroundView:self];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    TranscriptCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TranscriptCell" forIndexPath:indexPath];
    Transcript *transcript = [self.dataSource chatBackgroundView:self transcriptAtIndex:indexPath.row];
    [cell configureWithTranscript:transcript];
    return cell;
}

// MARK: - UITableViewDelegate
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

@end

