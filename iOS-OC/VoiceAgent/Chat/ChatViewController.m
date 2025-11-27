//
//  ChatViewController.m
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

#import "ChatViewController.h"
#import "AgentStateView.h"
#import "TranscriptCell.h"
#import "KeyCenter.h"
#import "AgentManager.h"
#import <Masonry/Masonry.h>
#import <AgoraRtcKit/AgoraRtcKit.h>
#import <AgoraRtmKit/AgoraRtmKit.h>
#import "VoiceAgent-Swift.h"

// MARK: - Initialization Operation
@interface InitializationOperation : NSOperation

@property (nonatomic, weak) ChatViewController *viewController;
@property (nonatomic, copy) BOOL (^executionBlock)(NSError **error);
@property (nonatomic, strong) NSError *operationError;

- (instancetype)initWithBlock:(BOOL (^)(NSError **error))block;

@end

@implementation InitializationOperation

- (instancetype)initWithBlock:(BOOL (^)(NSError **error))block {
    self = [super init];
    if (self) {
        _executionBlock = block;
    }
    return self;
}

- (void)main {
    if (self.isCancelled) {
        return;
    }
    
    NSError *error = nil;
    BOOL success = NO;
    
    if (self.executionBlock) {
        success = self.executionBlock(&error);
    }
    
    if (!success) {
        self.operationError = error;
    }
}

@end

@interface ChatViewController () <UITableViewDataSource, UITableViewDelegate, AgoraRtcEngineDelegate, AgoraRtmClientDelegate, ConversationalAIAPIEventHandler>

// MARK: - UI Components
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) AgentStateView *statusView;
@property (nonatomic, strong) UIView *controlBarView;
@property (nonatomic, strong) UIButton *micButton;
@property (nonatomic, strong) UIButton *endCallButton;

// MARK: - State
@property (nonatomic, strong) NSMutableArray<Transcript *> *transcripts;
@property (nonatomic, assign) BOOL isMicMuted;
@property (nonatomic, assign) BOOL isLoading;
@property (nonatomic, assign) BOOL isError;
@property (nonatomic, strong) NSError *initializationError;
@property (nonatomic, assign) NSInteger currentAgentState; // AgentState enum value

// MARK: - Agora Components
@property (nonatomic, strong) NSString *token;
@property (nonatomic, strong) NSString *agentToken;
@property (nonatomic, strong) NSString *agentId;
@property (nonatomic, strong) AgoraRtcEngineKit *rtcEngine;
@property (nonatomic, strong) AgoraRtmClientKit *rtmEngine;
@property (nonatomic, strong) ConversationalAIAPIImpl *convoAIAPI;
@property (nonatomic, assign) NSInteger agentUid;
@property (nonatomic, assign) NSInteger uid;
@property (nonatomic, copy) NSString *channel;

// MARK: - Toast
@property (nonatomic, strong) UIView *loadingToast;

@end

@implementation ChatViewController

- (instancetype)initWithUid:(NSInteger)uid channel:(NSString *)channel {
    self = [super init];
    if (self) {
        _uid = uid;
        _channel = channel;
        _agentUid = arc4random() % (99999999 - 10000000 + 1) + 10000000;
        _transcripts = [NSMutableArray array];
        _isMicMuted = NO;
        _isLoading = NO;
        _isError = NO;
        _currentAgentState = 5; // unknown
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
    [self setupConstraints];
    [self start];
}

// MARK: - UI Setup
- (void)setupUI {
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    self.title = @"VoiceAgent";
    self.navigationController.navigationBar.prefersLargeTitles = NO;
    self.navigationItem.hidesBackButton = YES;
    
    // TableView for transcripts
    self.tableView = [[UITableView alloc] init];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.backgroundColor = [UIColor clearColor];
    [self.tableView registerClass:[TranscriptCell class] forCellReuseIdentifier:@"TranscriptCell"];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tableView];
    
    // Status View
    self.statusView = [[AgentStateView alloc] init];
    self.statusView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statusView];
    
    // Control Bar
    self.controlBarView = [[UIView alloc] init];
    self.controlBarView.backgroundColor = [UIColor whiteColor];
    self.controlBarView.layer.cornerRadius = 16;
    self.controlBarView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.controlBarView.layer.shadowOpacity = 0.1;
    self.controlBarView.layer.shadowOffset = CGSizeMake(0, 2);
    self.controlBarView.layer.shadowRadius = 8;
    self.controlBarView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.controlBarView];
    
    // Mic Button
    self.micButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.micButton setImage:[UIImage systemImageNamed:@"mic.fill"] forState:UIControlStateNormal];
    self.micButton.tintColor = [UIColor blackColor];
    [self.micButton addTarget:self action:@selector(toggleMicrophone) forControlEvents:UIControlEventTouchUpInside];
    self.micButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlBarView addSubview:self.micButton];
    
    // End Call Button
    self.endCallButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.endCallButton setImage:[UIImage systemImageNamed:@"phone.down.fill"] forState:UIControlStateNormal];
    self.endCallButton.tintColor = [UIColor whiteColor];
    self.endCallButton.backgroundColor = [UIColor redColor];
    self.endCallButton.layer.cornerRadius = 25;
    [self.endCallButton addTarget:self action:@selector(endCall) forControlEvents:UIControlEventTouchUpInside];
    self.endCallButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.controlBarView addSubview:self.endCallButton];
}

- (void)setupConstraints {
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(self.view);
        make.bottom.equalTo(self.statusView.mas_top);
    }];
    
    [self.statusView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.view).inset(20);
        make.bottom.equalTo(self.controlBarView.mas_top).offset(-20);
        make.height.mas_equalTo(30);
    }];
    
    [self.controlBarView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.view).inset(20);
        make.bottom.equalTo(self.view.mas_safeAreaLayoutGuideBottom).offset(-40);
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

// MARK: - Business Logic
- (void)start {
    self.isLoading = YES;
    [self showLoadingToast];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 1;
    queue.name = @"com.voiceagent.initialization";
    
    // 生成user token 
    InitializationOperation *generateUserTokenOp = [self createGenerateUserTokenOperation];
    // 启动 RTM
    InitializationOperation *startRTMOp = [self createStartRTMOperation:generateUserTokenOp];
    // 启动 RTC
    InitializationOperation *startRTCOp = [self createStartRTCOperation:startRTMOp];
    // 启动 ConvoAIAPI
    InitializationOperation *startConvoAIAPIOp = [self createStartConvoAIAPIOperation:startRTCOp];
    // 生成 agent token
    InitializationOperation *generateAgentTokenOp = [self createGenerateAgentTokenOperation:startConvoAIAPIOp];
    // 启动 agent
    InitializationOperation *startAgentOp = [self createStartAgentOperation:generateAgentTokenOp];
    
    NSArray<InitializationOperation *> *operations = @[generateUserTokenOp, startRTMOp, startRTCOp, startConvoAIAPIOp, generateAgentTokenOp, startAgentOp];
    NSBlockOperation *completionOp = [self createCompletionOperation:operations];
    [completionOp addDependency:startAgentOp];
    
    NSMutableArray<NSOperation *> *allOperations = [NSMutableArray arrayWithArray:operations];
    [allOperations addObject:completionOp];
    [queue addOperations:allOperations waitUntilFinished:NO];
}

// MARK: - Operation Creators
- (InitializationOperation *)createGenerateUserTokenOperation {
    __weak typeof(self) weakSelf = self;
    return [[InitializationOperation alloc] initWithBlock:^BOOL(NSError **error) {
        return [weakSelf generateUserToken:error];
    }];
}

- (InitializationOperation *)createStartRTMOperation:(InitializationOperation *)dependingOn {
    __weak typeof(self) weakSelf = self;
    InitializationOperation *operation = [[InitializationOperation alloc] initWithBlock:^BOOL(NSError **error) {
        if (dependingOn.operationError) {
            if (error) *error = dependingOn.operationError;
            return NO;
        }
        return [weakSelf startRTM:error];
    }];
    [operation addDependency:dependingOn];
    return operation;
}

- (InitializationOperation *)createStartRTCOperation:(InitializationOperation *)dependingOn {
    __weak typeof(self) weakSelf = self;
    InitializationOperation *operation = [[InitializationOperation alloc] initWithBlock:^BOOL(NSError **error) {
        if (dependingOn.operationError) {
            if (error) *error = dependingOn.operationError;
            return NO;
        }
        return [weakSelf startRTC:error];
    }];
    [operation addDependency:dependingOn];
    return operation;
}

- (InitializationOperation *)createStartConvoAIAPIOperation:(InitializationOperation *)dependingOn {
    __weak typeof(self) weakSelf = self;
    InitializationOperation *operation = [[InitializationOperation alloc] initWithBlock:^BOOL(NSError **error) {
        if (dependingOn.operationError) {
            if (error) *error = dependingOn.operationError;
            return NO;
        }
        return [weakSelf startConvoAIAPI:error];
    }];
    [operation addDependency:dependingOn];
    return operation;
}

- (InitializationOperation *)createGenerateAgentTokenOperation:(InitializationOperation *)dependingOn {
    __weak typeof(self) weakSelf = self;
    InitializationOperation *operation = [[InitializationOperation alloc] initWithBlock:^BOOL(NSError **error) {
        if (dependingOn.operationError) {
            if (error) *error = dependingOn.operationError;
            return NO;
        }
        return [weakSelf generateAgentToken:error];
    }];
    [operation addDependency:dependingOn];
    return operation;
}

- (InitializationOperation *)createStartAgentOperation:(InitializationOperation *)dependingOn {
    __weak typeof(self) weakSelf = self;
    InitializationOperation *operation = [[InitializationOperation alloc] initWithBlock:^BOOL(NSError **error) {
        if (dependingOn.operationError) {
            if (error) *error = dependingOn.operationError;
            return NO;
        }
        return [weakSelf startAgent:error];
    }];
    [operation addDependency:dependingOn];
    return operation;
}

- (NSBlockOperation *)createCompletionOperation:(NSArray<InitializationOperation *> *)operations {
    __weak typeof(self) weakSelf = self;
    return [NSBlockOperation blockOperationWithBlock:^{
        NSError *finalError = nil;
        for (InitializationOperation *op in operations) {
            if (op.operationError) {
                finalError = op.operationError;
                break;
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (finalError) {
                weakSelf.initializationError = finalError;
                weakSelf.isLoading = NO;
                weakSelf.isError = YES;
                [weakSelf hideLoadingToast];
                [weakSelf showErrorToast:finalError.localizedDescription];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [weakSelf endCall];
                });
            } else {
                weakSelf.isLoading = NO;
                [weakSelf hideLoadingToast];
            }
        });
    }];
}

- (BOOL)generateUserToken:(NSError **)error {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block BOOL success = NO;
    __block NSError *blockError = nil;
    
    NSArray<NSNumber *> *types = @[@1, @2];
    
    [AgentManager generateTokenWithChannelName:self.channel 
                                           uid:[NSString stringWithFormat:@"%ld", (long)self.uid] 
                                        types:types 
                                      success:^(NSString * _Nullable token) {
        if (token && token.length > 0) {
            self.token = token;
            success = YES;
        } else {
            blockError = [NSError errorWithDomain:@"generateUserToken" 
                                             code:-1 
                                         userInfo:@{NSLocalizedDescriptionKey: @"获取 token 失败，请重试"}];
        }
        dispatch_semaphore_signal(semaphore);
    }];
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    if (!success && error) {
        *error = blockError ?: [NSError errorWithDomain:@"generateUserToken" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"获取 token 失败，请重试"}];
    }
    
    return success;
}

- (BOOL)startRTC:(NSError **)error {
    AgoraRtcEngineConfig *rtcConfig = [[AgoraRtcEngineConfig alloc] init];
    rtcConfig.appId = [KeyCenter AG_APP_ID];
    rtcConfig.channelProfile = AgoraChannelProfileLiveBroadcasting;
    rtcConfig.audioScenario = AgoraAudioScenarioAiClient;
    
    self.rtcEngine = [AgoraRtcEngineKit sharedEngineWithConfig:rtcConfig delegate:self];
    
    [self.rtcEngine enableVideo];
    [self.rtcEngine enableAudioVolumeIndication:100 smooth:3 reportVad:NO];
    
    AgoraCameraCapturerConfiguration *cameraConfig = [[AgoraCameraCapturerConfiguration alloc] init];
    cameraConfig.cameraDirection = AgoraCameraDirectionRear;
    [self.rtcEngine setCameraCapturerConfiguration:cameraConfig];
    
    [self.rtcEngine setParameters:@"{\"che.audio.enable.predump\":{\"enable\":\"true\",\"duration\":\"60\"}}"];
    
    AgoraRtcChannelMediaOptions *options = [[AgoraRtcChannelMediaOptions alloc] init];
    options.clientRoleType = AgoraClientRoleBroadcaster;
    options.publishMicrophoneTrack = YES;
    options.publishCameraTrack = NO;
    options.autoSubscribeAudio = YES;
    options.autoSubscribeVideo = YES;
    
    NSInteger result = [self.rtcEngine joinChannelByToken:self.token channelId:self.channel uid:self.uid mediaOptions:options joinSuccess:nil];
    if (result != 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"ChatViewController" code:result userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"加入 RTC 频道失败，错误码: %ld", (long)result]}];
        }
        return NO;
    }
    
    return YES;
}

- (BOOL)startRTM:(NSError **)error {
    AgoraRtmClientConfig *rtmConfig = [[AgoraRtmClientConfig alloc] initWithAppId:[KeyCenter AG_APP_ID] userId:[NSString stringWithFormat:@"%ld", (long)self.uid]];
    rtmConfig.areaCode = AgoraRtmAreaCodeCN | AgoraRtmAreaCodeNA;
    rtmConfig.presenceTimeout = 30;
    rtmConfig.heartbeatInterval = 10;
    rtmConfig.useStringUserId = YES;
    
    NSError *initError = nil;
    self.rtmEngine = [[AgoraRtmClientKit alloc] initWithConfig:rtmConfig delegate:self error:&initError];
    if (initError) {
        if (error) {
            *error = initError;
        }
        return NO;
    }
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block BOOL success = NO;
    __block NSError *blockError = nil;
    
    [self.rtmEngine loginByToken:self.token completion:^(AgoraRtmCommonResponse * _Nullable response, AgoraRtmErrorInfo * _Nullable errorInfo) {
        if (errorInfo == nil) {
            success = YES;
        } else {
            blockError = [NSError errorWithDomain:@"loginRTM" code:errorInfo.errorCode userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"rtm 登录失败: %@", errorInfo.reason]}];
        }
        dispatch_semaphore_signal(semaphore);
    }];
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    if (!success && error) {
        *error = blockError ?: [NSError errorWithDomain:@"loginRTM" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"rtm 登录失败"}];
    }
    
    return success;
}

- (BOOL)startConvoAIAPI:(NSError **)error {
    if (!self.rtcEngine) {
        if (error) {
            *error = [NSError errorWithDomain:@"startConvoAIAPI" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"rtc 为空"}];
        }
        return NO;
    }
    
    if (!self.rtmEngine) {
        if (error) {
            *error = [NSError errorWithDomain:@"startConvoAIAPI" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"rtm 为空"}];
        }
        return NO;
    }
    
    ConversationalAIAPIConfig *config = [[ConversationalAIAPIConfig alloc] initWithRtcEngine:self.rtcEngine rtmEngine:self.rtmEngine renderMode:TranscriptRenderModeWords enableLog:YES];
    self.convoAIAPI = [[ConversationalAIAPIImpl alloc] initWithConfig:config];
    [self.convoAIAPI addHandlerWithHandler:self];
    
    [self.convoAIAPI subscribeMessageWithChannelName:self.channel completion:^(ConversationalAIAPIError * _Nullable err) {
        if (err) {
            NSLog(@"[subscribeMessage] <<<< error: %@", err.message);
        }
    }];
    
    return YES;
}

- (BOOL)generateAgentToken:(NSError **)error {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block BOOL success = NO;
    __block NSError *blockError = nil;
    
    NSArray<NSNumber *> *types = @[@1, @2];
    
    [AgentManager generateTokenWithChannelName:self.channel 
                                           uid:[NSString stringWithFormat:@"%ld", (long)self.agentUid] 
                                        types:types 
                                      success:^(NSString * _Nullable token) {
        if (token && token.length > 0) {
            self.agentToken = token;
            success = YES;
        } else {
            blockError = [NSError errorWithDomain:@"generateAgentToken" 
                                             code:-1 
                                         userInfo:@{NSLocalizedDescriptionKey: @"获取 token 失败，请重试"}];
        }
        dispatch_semaphore_signal(semaphore);
    }];
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    if (!success && error) {
        *error = blockError ?: [NSError errorWithDomain:@"generateAgentToken" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"获取 token 失败，请重试"}];
    }
    
    return success;
}

- (BOOL)startAgent:(NSError **)error {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block BOOL success = NO;
    __block NSError *blockError = nil;
    
    NSDictionary *parameter = @{
        @"name": self.channel,
        @"pipeline_id": [KeyCenter AG_PIPELINE_ID],
        @"properties": @{
            @"channel": self.channel,
            @"agent_rtc_uid": [NSString stringWithFormat:@"%ld", (long)self.agentUid],
            @"remote_rtc_uids": @[@"*"],
            @"token": self.agentToken
        }
    };
    
    [AgentManager startAgentWithParameter:parameter completion:^(NSString * _Nullable agentId, NSError * _Nullable err) {
        if (err) {
            blockError = [NSError errorWithDomain:@"startAgent" code:-1 userInfo:@{NSLocalizedDescriptionKey: err.localizedDescription}];
        } else if (agentId) {
            self.agentId = agentId;
            success = YES;
        } else {
            blockError = [NSError errorWithDomain:@"startAgent" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"请求失败"}];
        }
        dispatch_semaphore_signal(semaphore);
    }];
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    if (!success && error) {
        *error = blockError;
    }
    
    return success;
}

- (void)toggleMicrophone {
    self.isMicMuted = !self.isMicMuted;
    NSString *imageName = self.isMicMuted ? @"mic.slash.fill" : @"mic.fill";
    [self.micButton setImage:[UIImage systemImageNamed:imageName] forState:UIControlStateNormal];
    [self.rtcEngine adjustRecordingSignalVolume:self.isMicMuted ? 0 : 100];
}

- (void)endCall {
    [AgentManager stopAgentWithAgentId:self.agentId completion:^(NSError * _Nullable error) {
            
    }];
    [self.rtcEngine leaveChannel:nil];
    [AgoraRtcEngineKit destroy];
    self.rtcEngine = nil;
    
    [self.rtmEngine logout:nil];
    [self.rtmEngine destroy];
    self.rtmEngine = nil;
    
    [self.convoAIAPI destroy];
    self.convoAIAPI = nil;
    
    [self.navigationController popViewControllerAnimated:YES];
}

// MARK: - Status View
- (void)updateStatusView {
    [self.statusView updateState:self.currentAgentState];
}

// MARK: - Toast
- (void)showLoadingToast {
    UIView *toast = [[UIView alloc] init];
    toast.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
    toast.layer.cornerRadius = 10;
    toast.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:toast];
    
    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    indicator.color = [UIColor whiteColor];
    [indicator startAnimating];
    indicator.translatesAutoresizingMaskIntoConstraints = NO;
    [toast addSubview:indicator];
    
    [toast mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.view);
        make.width.height.mas_equalTo(100);
    }];
    
    [indicator mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(toast);
    }];
    
    self.loadingToast = toast;
}

- (void)hideLoadingToast {
    [self.loadingToast removeFromSuperview];
    self.loadingToast = nil;
}

- (void)showErrorToast:(NSString *)message {
    UIView *toast = [[UIView alloc] init];
    toast.backgroundColor = [[UIColor redColor] colorWithAlphaComponent:0.9];
    toast.layer.cornerRadius = 10;
    toast.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:toast];
    
    UILabel *label = [[UILabel alloc] init];
    label.text = message;
    label.textColor = [UIColor whiteColor];
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont systemFontOfSize:14];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [toast addSubview:label];
    
    [toast mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.view);
        make.width.mas_lessThanOrEqualTo(300);
    }];
    
    [label mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(toast).inset(16);
    }];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [toast removeFromSuperview];
    });
}

// MARK: - UITableViewDataSource & Delegate
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.transcripts.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    TranscriptCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TranscriptCell" forIndexPath:indexPath];
    [cell configureWithTranscript:self.transcripts[indexPath.row]];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return UITableViewAutomaticDimension;
}

// MARK: - AgoraRtcEngineDelegate
- (void)rtcEngine:(AgoraRtcEngineKit *)engine didJoinedOfUid:(NSUInteger)uid elapsed:(NSInteger)elapsed {
    NSLog(@"[RTC Call Back] didJoinedOfUid uid: %lu", (unsigned long)uid);
}

- (void)rtcEngine:(AgoraRtcEngineKit *)engine didOfflineOfUid:(NSUInteger)uid reason:(AgoraUserOfflineReason)reason {
    NSLog(@"[RTC Call Back] didOfflineOfUid uid: %lu", (unsigned long)uid);
}

// MARK: - AgoraRtmClientDelegate
- (void)rtmKit:(AgoraRtmClientKit *)rtmKit didReceiveLinkStateEvent:(AgoraRtmLinkStateEvent *)event {
    NSLog(@"<<< [rtmKit:didReceiveLinkStateEvent]");
    switch (event.currentState) {
        case AgoraRtmClientConnectionStateConnected:
            NSLog(@"RTM connected successfully");
            break;
        case AgoraRtmClientConnectionStateDisconnected:
            NSLog(@"RTM disconnected");
            break;
        case AgoraRtmClientConnectionStateFailed:
            NSLog(@"RTM connection failed, need to re-login");
            break;
        default:
            break;
    }
}

// MARK: - ConversationalAIAPIEventHandler
- (void)onAgentVoiceprintStateChangedWithAgentUserId:(NSString *)agentUserId event:(VoiceprintStateChangeEvent *)event {
    NSLog(@"onAgentVoiceprintStateChanged: %@", event);
}

- (void)onMessageErrorWithAgentUserId:(NSString *)agentUserId error:(MessageError *)error {
    NSLog(@"onMessageError: %@", error);
}

- (void)onMessageReceiptUpdatedWithAgentUserId:(NSString *)agentUserId messageReceipt:(MessageReceipt *)messageReceipt {
    NSLog(@"onMessageReceiptUpdated: %@", messageReceipt);
}

- (void)onAgentStateChangedWithAgentUserId:(NSString *)agentUserId event:(StateChangeEvent *)event {
    NSLog(@"onAgentStateChanged: %@", event);
    dispatch_async(dispatch_get_main_queue(), ^{
        self.currentAgentState = event.state;
        [self updateStatusView];
    });
}

- (void)onAgentInterruptedWithAgentUserId:(NSString *)agentUserId event:(InterruptEvent *)event {
    NSLog(@"<<< [onAgentInterrupted]");
}

- (void)onAgentMetricsWithAgentUserId:(NSString *)agentUserId metrics:(Metric *)metrics {
    NSLog(@"<<< [onAgentMetrics] metrics: %@", metrics);
}

- (void)onAgentErrorWithAgentUserId:(NSString *)agentUserId error:(ModuleError *)error {
    NSLog(@"<<< [onAgentError] error: %@", error);
}

- (void)onTranscriptUpdatedWithAgentUserId:(NSString *)agentUserId transcript:(Transcript *)transcript {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSInteger index = NSNotFound;
        for (NSInteger i = 0; i < self.transcripts.count; i++) {
            Transcript *t = self.transcripts[i];
            if (t.turnId == transcript.turnId &&
                t.type == transcript.type &&
                [t.userId isEqualToString:transcript.userId]) {
                index = i;
                break;
            }
        }
        
        if (index != NSNotFound) {
            [self.transcripts replaceObjectAtIndex:index withObject:transcript];
        } else {
            [self.transcripts addObject:transcript];
        }
        
        [self.tableView reloadData];
        
        if (self.transcripts.count > 0) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.transcripts.count - 1 inSection:0];
            [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
        }
    });
}

- (void)onDebugLogWithLog:(NSString *)log {
    NSLog(@"%@", log);
}

@end
