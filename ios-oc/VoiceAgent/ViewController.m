//
//  ViewController.m
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

#import "ViewController.h"
#import "TranscriptCell.h"
#import "KeyCenter.h"
#import "AgentManager.h"
#import "ConfigBackgroundView.h"
#import "ChatBackgroundView.h"
#import <Masonry/Masonry.h>
#import <AgoraRtcKit/AgoraRtcKit.h>
#import <AgoraRtmKit/AgoraRtmKit.h>
#import "VoiceAgent-Swift.h"

// MARK: - Initialization Operation
@interface InitializationOperation : NSOperation

@property (nonatomic, weak) ViewController *viewController;
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

@interface ViewController () <UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate, AgoraRtcEngineDelegate, AgoraRtmClientDelegate, ConversationalAIAPIEventHandler>

// MARK: - UI Components
@property (nonatomic, strong) ConfigBackgroundView *configBackgroundView;
@property (nonatomic, strong) ChatBackgroundView *chatBackgroundView;

// MARK: - State
@property (nonatomic, assign) NSInteger uid;
@property (nonatomic, copy) NSString *channel;
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

// MARK: - Toast
@property (nonatomic, strong) UIView *loadingToast;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 生成随机 UID
    self.uid = arc4random() % (9999999 - 1000 + 1) + 1000;
    self.agentUid = arc4random() % (99999999 - 10000000 + 1) + 10000000;
    self.transcripts = [NSMutableArray array];
    self.isMicMuted = NO;
    self.isLoading = NO;
    self.isError = NO;
    self.currentAgentState = 5; // unknown
    
    [self setupUI];
    [self setupConstraints];
    [self initializeEngines];
}

// MARK: - UI Setup
- (void)setupUI {
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.title = @"VoiceAgent";
    self.navigationController.navigationBar.prefersLargeTitles = NO;
    
    // Config Background View
    self.configBackgroundView = [[ConfigBackgroundView alloc] init];
    self.configBackgroundView.channelNameTextField.delegate = self;
    [self.configBackgroundView.channelNameTextField addTarget:self 
                                                        action:@selector(textFieldDidChange:) 
                                              forControlEvents:UIControlEventEditingChanged];
    [self.configBackgroundView.startButton addTarget:self 
                                               action:@selector(startButtonTapped:) 
                                     forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.configBackgroundView];
    
    // Chat Background View
    self.chatBackgroundView = [[ChatBackgroundView alloc] init];
    self.chatBackgroundView.hidden = YES;
    self.chatBackgroundView.tableView.delegate = self;
    self.chatBackgroundView.tableView.dataSource = self;
    [self.chatBackgroundView.micButton addTarget:self 
                                           action:@selector(toggleMicrophone) 
                                 forControlEvents:UIControlEventTouchUpInside];
    [self.chatBackgroundView.endCallButton addTarget:self 
                                               action:@selector(endCall) 
                                     forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.chatBackgroundView];
}

- (void)setupConstraints {
    [self.configBackgroundView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    
    [self.chatBackgroundView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
}

// MARK: - Engine Initialization
- (void)initializeEngines {
    [self initializeRTM];
    [self initializeRTC];
    [self initializeConvoAIAPI];
}

- (void)initializeRTM {
    AgoraRtmClientConfig *rtmConfig = [[AgoraRtmClientConfig alloc] initWithAppId:[KeyCenter AG_APP_ID] userId:[NSString stringWithFormat:@"%ld", (long)self.uid]];
    rtmConfig.areaCode = AgoraRtmAreaCodeCN | AgoraRtmAreaCodeNA;
    rtmConfig.presenceTimeout = 30;
    rtmConfig.heartbeatInterval = 10;
    rtmConfig.useStringUserId = YES;
    
    NSError *initError = nil;
    self.rtmEngine = [[AgoraRtmClientKit alloc] initWithConfig:rtmConfig delegate:self error:&initError];
    if (initError) {
        NSLog(@"[Engine Init] RTM initialization failed: %@", initError);
    } else {
        NSLog(@"[Engine Init] RTM initialized successfully");
    }
}

- (void)initializeRTC {
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
    
    NSLog(@"[Engine Init] RTC initialized successfully");
}

- (void)initializeConvoAIAPI {
    if (!self.rtcEngine) {
        NSLog(@"[Engine Init] RTC engine is nil, cannot init ConvoAI API");
        return;
    }
    
    if (!self.rtmEngine) {
        NSLog(@"[Engine Init] RTM engine is nil, cannot init ConvoAI API");
        return;
    }
    
    ConversationalAIAPIConfig *config = [[ConversationalAIAPIConfig alloc] initWithRtcEngine:self.rtcEngine rtmEngine:self.rtmEngine renderMode:TranscriptRenderModeWords enableLog:YES];
    self.convoAIAPI = [[ConversationalAIAPIImpl alloc] initWithConfig:config];
    [self.convoAIAPI addHandlerWithHandler:self];
    
    NSLog(@"[Engine Init] ConvoAI API initialized successfully");
}

// MARK: - Connection Flow
- (void)startConnection {
    NSString *channelName = [self.configBackgroundView.channelNameTextField.text stringByTrimmingCharactersInSet:
                            [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (channelName.length == 0) {
        return;
    }
    
    self.channel = channelName;
    self.isLoading = YES;
    [self showLoadingToast];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
    queue.maxConcurrentOperationCount = 1;
    queue.name = @"com.voiceagent.connection";
    
    // 1. 生成用户token
    InitializationOperation *generateUserTokenOp = [self createGenerateUserTokenOperation];
    // 2. RTM 登录
    InitializationOperation *loginRTMOp = [self createLoginRTMOperation:generateUserTokenOp];
    // 3. RTC 加入频道
    InitializationOperation *joinRTCOp = [self createJoinRTCOperation:loginRTMOp];
    // 4. 订阅 ConvoAI 消息
    InitializationOperation *subscribeConvoAIOp = [self createSubscribeConvoAIOperation:joinRTCOp];
    // 5. 生成agentToken
    InitializationOperation *generateAgentTokenOp = [self createGenerateAgentTokenOperation:subscribeConvoAIOp];
    // 6. 启动agent
    InitializationOperation *startAgentOp = [self createStartAgentOperation:generateAgentTokenOp];
    
    NSArray<InitializationOperation *> *operations = @[generateUserTokenOp, loginRTMOp, joinRTCOp, subscribeConvoAIOp, generateAgentTokenOp, startAgentOp];
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

- (InitializationOperation *)createLoginRTMOperation:(InitializationOperation *)dependingOn {
    __weak typeof(self) weakSelf = self;
    InitializationOperation *operation = [[InitializationOperation alloc] initWithBlock:^BOOL(NSError **error) {
        if (dependingOn.operationError) {
            if (error) *error = dependingOn.operationError;
            return NO;
        }
        return [weakSelf loginRTM:error];
    }];
    [operation addDependency:dependingOn];
    return operation;
}

- (InitializationOperation *)createJoinRTCOperation:(InitializationOperation *)dependingOn {
    __weak typeof(self) weakSelf = self;
    InitializationOperation *operation = [[InitializationOperation alloc] initWithBlock:^BOOL(NSError **error) {
        if (dependingOn.operationError) {
            if (error) *error = dependingOn.operationError;
            return NO;
        }
        return [weakSelf joinRTCChannel:error];
    }];
    [operation addDependency:dependingOn];
    return operation;
}

- (InitializationOperation *)createSubscribeConvoAIOperation:(InitializationOperation *)dependingOn {
    __weak typeof(self) weakSelf = self;
    InitializationOperation *operation = [[InitializationOperation alloc] initWithBlock:^BOOL(NSError **error) {
        if (dependingOn.operationError) {
            if (error) *error = dependingOn.operationError;
            return NO;
        }
        return [weakSelf subscribeConvoAIMessage:error];
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
            } else {
                weakSelf.isLoading = NO;
                [weakSelf hideLoadingToast];
                [weakSelf switchToChatView];
            }
        });
    }];
}

// MARK: - Token Generation
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

// MARK: - Channel Connection
- (BOOL)loginRTM:(NSError **)error {
    if (!self.rtmEngine) {
        if (error) {
            *error = [NSError errorWithDomain:@"loginRTM" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"RTM engine 未初始化"}];
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

- (BOOL)joinRTCChannel:(NSError **)error {
    if (!self.rtcEngine) {
        if (error) {
            *error = [NSError errorWithDomain:@"joinRTCChannel" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"RTC engine 未初始化"}];
        }
        return NO;
    }
    
    AgoraRtcChannelMediaOptions *options = [[AgoraRtcChannelMediaOptions alloc] init];
    options.clientRoleType = AgoraClientRoleBroadcaster;
    options.publishMicrophoneTrack = YES;
    options.publishCameraTrack = NO;
    options.autoSubscribeAudio = YES;
    options.autoSubscribeVideo = YES;
    
    NSInteger result = [self.rtcEngine joinChannelByToken:self.token channelId:self.channel uid:self.uid mediaOptions:options joinSuccess:nil];
    if (result != 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"joinRTCChannel" code:result userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"加入 RTC 频道失败，错误码: %ld", (long)result]}];
        }
        return NO;
    }
    
    return YES;
}

- (BOOL)subscribeConvoAIMessage:(NSError **)error {
    if (!self.convoAIAPI) {
        if (error) {
            *error = [NSError errorWithDomain:@"subscribeConvoAIMessage" code:-1 userInfo:@{NSLocalizedDescriptionKey: @"ConvoAI API 未初始化"}];
        }
        return NO;
    }
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block BOOL success = YES;
    __block NSError *blockError = nil;
    
    [self.convoAIAPI subscribeMessageWithChannelName:self.channel completion:^(ConversationalAIAPIError * _Nullable err) {
        if (err) {
            blockError = [NSError errorWithDomain:@"subscribeConvoAIMessage" code:-1 userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"订阅消息失败: %@", err.message]}];
            success = NO;
        }
        dispatch_semaphore_signal(semaphore);
    }];
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    if (!success && error) {
        *error = blockError;
    }
    
    return success;
}

// MARK: - Agent Management
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

// MARK: - View Management
- (void)switchToChatView {
    self.configBackgroundView.hidden = YES;
    self.chatBackgroundView.hidden = NO;
    self.navigationItem.hidesBackButton = YES;
}

- (void)switchToConfigView {
    self.chatBackgroundView.hidden = YES;
    self.configBackgroundView.hidden = NO;
    self.navigationItem.hidesBackButton = NO;
}

- (void)resetConnectionState {
    [self.rtcEngine leaveChannel:nil];
    [self.rtmEngine logout:nil];
    [self.convoAIAPI unsubscribeMessageWithChannelName:self.channel completion:^(ConversationalAIAPIError * _Nullable error) {
        
    }];
    
    [self switchToConfigView];
    
    [self.transcripts removeAllObjects];
    [self.chatBackgroundView.tableView reloadData];
    self.isMicMuted = NO;
    self.currentAgentState = 5; // unknown
    [self.chatBackgroundView updateStatusView:self.currentAgentState];
    self.agentId = @"";
    self.token = @"";
    self.agentToken = @"";
}

// MARK: - Actions
- (void)textFieldDidChange:(UITextField *)textField {
    [self updateButtonState];
}

- (void)startButtonTapped:(UIButton *)sender {
    [self startConnection];
}

- (void)toggleMicrophone {
    self.isMicMuted = !self.isMicMuted;
    [self.chatBackgroundView updateMicButtonState:self.isMicMuted];
    [self.rtcEngine adjustRecordingSignalVolume:self.isMicMuted ? 0 : 100];
}

- (void)endCall {
    [AgentManager stopAgentWithAgentId:self.agentId completion:^(NSError * _Nullable error) {
            
    }];
    [self resetConnectionState];
}

- (void)updateButtonState {
    NSString *channelName = [self.configBackgroundView.channelNameTextField.text stringByTrimmingCharactersInSet:
                            [NSCharacterSet whitespaceAndNewlineCharacterSet]];
    BOOL isValid = channelName.length > 0;
    
    [self.configBackgroundView updateButtonState:isValid];
}

// MARK: - Status View
- (void)updateStatusView {
    [self.chatBackgroundView updateStatusView:self.currentAgentState];
}

// MARK: - Toast
- (void)showLoadingToast {
    UIView *toast = [[UIView alloc] init];
    toast.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
    toast.layer.cornerRadius = 10;
    [self.view addSubview:toast];
    
    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    indicator.color = [UIColor whiteColor];
    [indicator startAnimating];
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
    [self.view addSubview:toast];
    
    UILabel *label = [[UILabel alloc] init];
    label.text = message;
    label.textColor = [UIColor whiteColor];
    label.numberOfLines = 0;
    label.textAlignment = NSTextAlignmentCenter;
    label.font = [UIFont systemFontOfSize:14];
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
        
        [self.chatBackgroundView.tableView reloadData];
        
        if (self.transcripts.count > 0) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:self.transcripts.count - 1 inSection:0];
            [self.chatBackgroundView.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionBottom animated:YES];
        }
    });
}

- (void)onDebugLogWithLog:(NSString *)log {
    NSLog(@"%@", log);
}

@end
