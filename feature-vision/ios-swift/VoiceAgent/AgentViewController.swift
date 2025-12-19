//
//  ViewController.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

import UIKit
import SnapKit
import AgoraRtcKit
import AgoraRtmKit

class AgentViewController: UIViewController {
    // MARK: - Default UID values - single source of truth
    static let DEFAULT_USER_UID: Int = 1001
    static let DEFAULT_AGENT_UID: Int = 2001
    static let DEFAULT_CHANNEL_NAME: String = "channel_vision_001"
    
    // MARK: - UI Components
    private let channelInputView = ChannelInputView()
    private let chatBackgroundView = ChatBackgroundView()
    private let debugInfoTextView = UITextView()
    
    // MARK: - Local View
    private let localView = UIView()
    private let localViewSmallSize = CGSize(width: 90, height: 120)
    private let localViewSmallCornerRadius: CGFloat = 8
    private let localViewExpandedCornerRadius: CGFloat = 0
    private var isLocalViewExpanded: Bool = false  // Default collapsed
    
    // MARK: - State
    private var uid: Int = DEFAULT_USER_UID
    private var channel: String = ""
    private var transcripts: [Transcript] = []
    private var isMicMuted: Bool = false
    private var isCameraOn: Bool = true
    private var isLoading: Bool = false
    private var isError: Bool = false
    private var initializationError: Error?
    private var currentAgentState: AgentState = .unknown
    
    // MARK: - Agora Components
    private var token: String = ""
    private var rtcEngine: AgoraRtcEngineKit?
    private var rtmEngine: AgoraRtmClientKit?
    private var convoAIAPI: ConversationalAIAPI?
    private var agentUid: Int = DEFAULT_AGENT_UID
    
    // MARK: - UserDefaults Keys (removed - now using default constants)
    
    // MARK: - Toast
    private var loadingToast: UIView?
    
    // MARK: - Debug Info Helper
    private func addDebugMessage(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let debugMessage = "[\(timestamp)] \(message)\n"
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.debugInfoTextView.text += debugMessage
            
            // Auto-scroll to bottom
            let bottom = NSRange(location: self.debugInfoTextView.text.count - 1, length: 1)
            self.debugInfoTextView.scrollRangeToVisible(bottom)
        }
    }
    
    private func clearDebugMessages() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.debugInfoTextView.text = "等待连接...\n"
        }
    }
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        // Hide navigation bar for better space utilization
        navigationController?.setNavigationBarHidden(true, animated: false)
        setupUI()
        setupConstraints()
        initializeEngines()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .white
        
        // Debug Info TextView (always visible)
        // Debug Info TextView
        debugInfoTextView.isEditable = false
        debugInfoTextView.isSelectable = true
        debugInfoTextView.font = .systemFont(ofSize: 11)
        debugInfoTextView.textColor = .label
        debugInfoTextView.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        debugInfoTextView.layer.cornerRadius = 8
        debugInfoTextView.layer.borderWidth = 0.5
        debugInfoTextView.layer.borderColor = UIColor.separator.cgColor
        debugInfoTextView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        debugInfoTextView.text = "等待连接...\n"
        view.addSubview(debugInfoTextView)
        
        // Chat Background View
        chatBackgroundView.tableView.delegate = self
        chatBackgroundView.tableView.dataSource = self
        chatBackgroundView.tableView.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        chatBackgroundView.micButton.addTarget(self, action: #selector(toggleMicrophone), for: .touchUpInside)
        chatBackgroundView.endCallButton.addTarget(self, action: #selector(endCall), for: .touchUpInside)
        chatBackgroundView.videoToggleButton.addTarget(self, action: #selector(toggleVideo), for: .touchUpInside)
        view.addSubview(chatBackgroundView)
        
        // Channel Input View (added after chatBackgroundView to be on top)
        channelInputView.setDefaultValues(
            channelName: AgentViewController.DEFAULT_CHANNEL_NAME
        )
        channelInputView.onJoinChannelTapped = { [weak self] inputData in
            self?.handleJoinChannel(inputData: inputData)
        }
        view.addSubview(channelInputView)
        
        // Local Video View (added to chatBackgroundView, expandable/collapsible)
        localView.backgroundColor = .black
        localView.layer.cornerRadius = localViewSmallCornerRadius
        localView.clipsToBounds = true
        localView.isUserInteractionEnabled = true
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(toggleLocalViewSize))
        localView.addGestureRecognizer(tapGesture)
        chatBackgroundView.addSubview(localView)
    }
    
    private func setupConstraints() {
        debugInfoTextView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(8)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(120)
        }
        channelInputView.snp.makeConstraints { make in
            make.top.equalTo(debugInfoTextView.snp.bottom)
            make.left.right.bottom.equalToSuperview()
        }
        
        // Chat Background View (below debug view)
        chatBackgroundView.snp.makeConstraints { make in
            make.top.equalTo(debugInfoTextView.snp.bottom).offset(20)
            make.left.right.bottom.equalToSuperview()
        }
        
        // Local View (default collapsed, top-right corner of transcript area)
        localView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.right.equalToSuperview().inset(12)
            make.width.equalTo(localViewSmallSize.width)
            make.height.equalTo(localViewSmallSize.height)
        }
    }
    
    // MARK: - Engine Initialization
    private func initializeEngines() {
        initializeRTM()
        initializeRTC()
        initializeConvoAIAPI()
    }
    
    private func initializeRTM() {
        // RTM client is initialized with DEFAULT_USER_UID
        // Since userId is read-only, no need to recreate RTM client
        let rtmConfig = AgoraRtmClientConfig(appId: KeyCenter.AG_APP_ID, userId: "\(uid)")
        rtmConfig.areaCode = [.CN, .NA]
        rtmConfig.presenceTimeout = 30
        rtmConfig.heartbeatInterval = 10
        rtmConfig.useStringUserId = true
        
        do {
            let rtmClient = try AgoraRtmClientKit(rtmConfig, delegate: self)
            self.rtmEngine = rtmClient
            print("[Engine Init] RTM initialized successfully, userId: \(uid)")
            addDebugMessage("RTM Client 初始化成功，userId: \(uid)")
        } catch {
            print("[Engine Init] RTM initialization failed: \(error)")
            addDebugMessage("RTM Client 初始化失败")
        }
    }
    
    private func initializeRTC() {
        let rtcConfig = AgoraRtcEngineConfig()
        rtcConfig.appId = KeyCenter.AG_APP_ID
        rtcConfig.channelProfile = .liveBroadcasting
        rtcConfig.audioScenario = .aiClient
        let rtcEngine = AgoraRtcEngineKit.sharedEngine(with: rtcConfig, delegate: self)
        
        rtcEngine.enableVideo()
        rtcEngine.enableAudioVolumeIndication(100, smooth: 3, reportVad: false)
        
        let cameraConfig = AgoraCameraCapturerConfiguration()
        cameraConfig.cameraDirection = .rear
        rtcEngine.setCameraCapturerConfiguration(cameraConfig)
        
        rtcEngine.setParameters("{\"che.audio.enable.predump\":{\"enable\":\"true\",\"duration\":\"60\"}}")
        
        self.rtcEngine = rtcEngine
        print("[Engine Init] RTC initialized successfully")
        addDebugMessage("RTC Engine 初始化成功")
    }
    
    private func initializeConvoAIAPI() {
        guard let rtcEngine = self.rtcEngine else {
            print("[Engine Init] RTC engine is nil, cannot init ConvoAI API")
            return
        }
        
        guard let rtmEngine = self.rtmEngine else {
            print("[Engine Init] RTM engine is nil, cannot init ConvoAI API")
            return
        }
        
        let config = ConversationalAIAPIConfig(rtcEngine: rtcEngine, rtmEngine: rtmEngine, renderMode: .words, enableLog: true)
        let convoAIAPI = ConversationalAIAPIImpl(config: config)
        convoAIAPI.addHandler(handler: self)
        
        self.convoAIAPI = convoAIAPI
        print("[Engine Init] ConvoAI API initialized successfully")
    }
    
    // MARK: - Connection Flow
    private func startConnection() {
        isLoading = true
        showLoadingToast()
        
        Task {
            do {
                // 1. 生成用户token
                try await generateUserToken()
                
                // 2. RTM 登录
                try await loginRTM()
                
                // 3. RTC 加入频道
                try await joinRTCChannel()
                
                // 4. 订阅 ConvoAI 消息
                try await subscribeConvoAIMessage()
                
                await MainActor.run {
                    isLoading = false
                    hideLoadingToast()
                    channelInputView.isHidden = true
                }
            } catch {
                await MainActor.run {
                    initializationError = error
                    isLoading = false
                    isError = true
                    hideLoadingToast()
                    showErrorToast(error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Token Generation
    private func generateUserToken() async throws {
        addDebugMessage("获取 Token 调用中...")
        
        return try await withCheckedThrowingContinuation { continuation in
            NetworkManager.shared.generateToken(channelName: channel, uid: "\(uid)", types: [.rtc, .rtm]) { token in
                guard let token = token else {
                    self.addDebugMessage("获取 Token 调用失败")
                    continuation.resume(throwing: NSError(domain: "generateUserToken", code: -1, userInfo: [NSLocalizedDescriptionKey: "获取 token 失败，请重试"]))
                    return
                }
                self.token = token
                self.addDebugMessage("获取 Token 调用成功")
                continuation.resume()
            }
        }
    }
    
    // MARK: - Channel Connection
    @MainActor
    private func loginRTM() async throws {
        guard let rtmEngine = self.rtmEngine else {
            throw NSError(domain: "loginRTM", code: -1, userInfo: [NSLocalizedDescriptionKey: "RTM engine 未初始化"])
        }
        
        addDebugMessage("RTM Login 调用中...")
        
        return try await withCheckedThrowingContinuation { continuation in
            rtmEngine.login(token) { res, error in
                if let error = error {
                    self.addDebugMessage("RTM Login 调用失败: \(error.localizedDescription)")
                    continuation.resume(throwing: NSError(domain: "loginRTM", code: -1, userInfo: [NSLocalizedDescriptionKey: "rtm 登录失败: \(error.localizedDescription)"]))
                } else if let _ = res {
                    self.addDebugMessage("RTM Login 调用成功")
                    continuation.resume()
                } else {
                    self.addDebugMessage("RTM Login 调用失败")
                    continuation.resume(throwing: NSError(domain: "loginRTM", code: -1, userInfo: [NSLocalizedDescriptionKey: "rtm 登录失败"]))
                }
            }
        }
    }
    
    @MainActor
    private func joinRTCChannel() async throws {
        guard let rtcEngine = self.rtcEngine else {
            throw NSError(domain: "joinRTCChannel", code: -1, userInfo: [NSLocalizedDescriptionKey: "RTC engine 未初始化"])
        }
        
        // Setup local video preview
        setupLocalVideo()
        
        addDebugMessage("joinChannel 调用中...")
        
        let options = AgoraRtcChannelMediaOptions()
        options.clientRoleType = .broadcaster
        options.publishMicrophoneTrack = true
        options.publishCameraTrack = true  // Enable camera track for vision
        options.autoSubscribeAudio = true
        options.autoSubscribeVideo = false
        let result = rtcEngine.joinChannel(byToken: token, channelId: channel, uid: UInt(uid), mediaOptions: options)
        if result != 0 {
            addDebugMessage("joinChannel 调用失败: ret=\(result)")
            throw NSError(domain: "joinRTCChannel", code: Int(result), userInfo: [NSLocalizedDescriptionKey: "加入 RTC 频道失败，错误码: \(result)"])
        } else {
            addDebugMessage("joinChannel 调用成功: ret=\(result)")
        }
    }
    
    @MainActor
    private func subscribeConvoAIMessage() async throws {
        guard let convoAIAPI = self.convoAIAPI else {
            throw NSError(domain: "subscribeConvoAIMessage", code: -1, userInfo: [NSLocalizedDescriptionKey: "ConvoAI API 未初始化"])
        }
            
        return try await withCheckedThrowingContinuation { continuation in
            convoAIAPI.subscribeMessage(channelName: channel) { err in
                if let error = err {
                    continuation.resume(throwing: NSError(domain: "subscribeConvoAIMessage", code: -1, userInfo: [NSLocalizedDescriptionKey: "订阅消息失败: \(error.message)"]))
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - View Management
    private func resetConnectionState() {
        rtcEngine?.stopPreview()
        rtcEngine?.leaveChannel()
        rtmEngine?.logout()
        convoAIAPI?.unsubscribeMessage(channelName: channel, completion: { error in
            
        })
        
        // Collapse video view when agent stops
        if isLocalViewExpanded {
            toggleLocalViewSize()
        }
        
        channelInputView.isHidden = false
        
        transcripts.removeAll()
        chatBackgroundView.tableView.reloadData()
        clearDebugMessages()
        isMicMuted = false
        isCameraOn = true
        chatBackgroundView.updateVideoButtonState(isCameraOn: true)
        currentAgentState = .unknown
        chatBackgroundView.updateStatusView(state: .unknown)
        token = ""
    }
    
    // MARK: - UI Updates
    private func updateAgentStatusView() {
        chatBackgroundView.updateStatusView(state: currentAgentState)
    }
    
    // MARK: - Local Video Management
    private func setupLocalVideo() {
        guard let rtcEngine = self.rtcEngine else { return }
        
        rtcEngine.startPreview()
        
        let videoCanvas = AgoraRtcVideoCanvas()
        videoCanvas.uid = 0  // 0 for local user
        videoCanvas.view = localView
        videoCanvas.renderMode = .hidden
        rtcEngine.setupLocalVideo(videoCanvas)
        
        chatBackgroundView.bringSubviewToFront(localView)
        addDebugMessage("Local video setup")
    }
    
    @objc private func toggleLocalViewSize() {
        // Only allow expand when connected and camera is on
        if (!isCameraOn || channelInputView.isHidden == false) && !isLocalViewExpanded {
            return
        }
        
        isLocalViewExpanded.toggle()
        
        localView.snp.remakeConstraints { make in
            if isLocalViewExpanded {
                // Expanded: cover transcript area
                make.edges.equalTo(chatBackgroundView.tableView)
            } else {
                // Collapsed: small window at top-right corner
                make.top.equalToSuperview().offset(8)
                make.right.equalToSuperview().inset(12)
                make.width.equalTo(localViewSmallSize.width)
                make.height.equalTo(localViewSmallSize.height)
            }
        }
        
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) { [weak self] in
            guard let self = self else { return }
            self.localView.layer.cornerRadius = self.isLocalViewExpanded ? self.localViewExpandedCornerRadius : self.localViewSmallCornerRadius
            self.chatBackgroundView.layoutIfNeeded()
        }
    }
    
    // MARK: - Actions
    private func handleJoinChannel(inputData: ChannelInputData) {
        guard !inputData.channelName.isEmpty else {
            addDebugMessage("ERROR: 频道名称不能为空")
            return
        }
        
        // Set channel name
        self.channel = inputData.channelName
        // Note: uid and agentUid use default constants
        
        startConnection()
    }
    
    @objc private func toggleMicrophone() {
        isMicMuted.toggle()
        chatBackgroundView.updateMicButtonState(isMuted: isMicMuted)
        rtcEngine?.adjustRecordingSignalVolume(isMicMuted ? 0 : 100)
    }
    
    @objc private func toggleVideo() {
        isCameraOn.toggle()
        chatBackgroundView.updateVideoButtonState(isCameraOn: isCameraOn)
        
        if isCameraOn {
            rtcEngine?.startPreview()
            rtcEngine?.muteLocalVideoStream(false)
        } else {
            rtcEngine?.stopPreview()
            rtcEngine?.muteLocalVideoStream(true)
            
            // Auto collapse video view when camera is turned off
            if isLocalViewExpanded {
                toggleLocalViewSize()
            }
        }
        
        addDebugMessage(isCameraOn ? "Camera on" : "Camera off")
    }
    
    @objc private func endCall() {
        resetConnectionState()
    }
    
    // MARK: - Toast
    private func showLoadingToast() {
        let toast = UIView()
        toast.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        toast.layer.cornerRadius = 10
        view.addSubview(toast)
        
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.color = .white
        indicator.startAnimating()
        toast.addSubview(indicator)
        
        toast.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(100)
        }
        
        indicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        loadingToast = toast
    }
    
    private func hideLoadingToast() {
        loadingToast?.removeFromSuperview()
        loadingToast = nil
    }
    
    private func showErrorToast(_ message: String) {
        let toast = UIView()
        toast.backgroundColor = UIColor.red.withAlphaComponent(0.9)
        toast.layer.cornerRadius = 10
        view.addSubview(toast)
        
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 14)
        toast.addSubview(label)
        
        toast.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.lessThanOrEqualTo(300)
        }
        
        label.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            toast.removeFromSuperview()
        }
    }
}

// MARK: - UITableViewDataSource & Delegate
extension AgentViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return transcripts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TranscriptCell", for: indexPath) as! TranscriptCell
        cell.configure(with: transcripts[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
}

// MARK: - AgoraRtcEngineDelegate
extension AgentViewController: AgoraRtcEngineDelegate {
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        print("[RTC Call Back] didJoinChannel: \(channel), uid: \(uid)")
        addDebugMessage("onJoinChannelSuccess")
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        print("[RTC Call Back] didJoinedOfUid uid: \(uid)")
        addDebugMessage("onUserJoined: \(uid)")
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        print("[RTC Call Back] didOfflineOfUid uid: \(uid)")
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        print("[RTC Call Back] didOccurError: \(errorCode.rawValue)")
        addDebugMessage("onError: \(errorCode.rawValue)")
    }
}

// MARK: - AgoraRtmClientDelegate
extension AgentViewController: AgoraRtmClientDelegate {
    func rtmKit(_ rtmKit: AgoraRtmClientKit, didReceiveLinkStateEvent event: AgoraRtmLinkStateEvent) {
        print("<<< [rtmKit:didReceiveLinkStateEvent]")
        switch event.currentState {
        case .connected:
            print("RTM connected successfully")
        case .disconnected:
            print("RTM disconnected")
        case .failed:
            print("RTM connection failed, need to re-login")
        default:
            break
        }
    }
}

// MARK: - ConversationalAIAPIEventHandler
extension AgentViewController: ConversationalAIAPIEventHandler {
    func onAgentVoiceprintStateChanged(agentUserId: String, event: VoiceprintStateChangeEvent) {
        print("onAgentVoiceprintStateChanged: \(event)")
    }
    
    func onMessageError(agentUserId: String, error: MessageError) {
        print("onMessageError: \(error)")
    }
    
    func onMessageReceiptUpdated(agentUserId: String, messageReceipt: MessageReceipt) {
        print("onMessageReceiptUpdated: \(messageReceipt)")
    }
    
    func onAgentStateChanged(agentUserId: String, event: StateChangeEvent) {
        print("onAgentStateChanged: \(event)")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentAgentState = event.state
            self.updateAgentStatusView()
        }
    }
    
    func onAgentInterrupted(agentUserId: String, event: InterruptEvent) {
        print("<<< [onAgentInterrupted]")
    }
    
    func onAgentMetrics(agentUserId: String, metrics: Metric) {
        print("<<< [onAgentMetrics] metrics: \(metrics)")
    }
    
    func onAgentError(agentUserId: String, error: ModuleError) {
        print("<<< [onAgentError] error: \(error)")
    }
    
    func onTranscriptUpdated(agentUserId: String, transcript: Transcript) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let index = self.transcripts.firstIndex(where: {
                $0.turnId == transcript.turnId &&
                $0.type.rawValue == transcript.type.rawValue &&
                $0.userId == transcript.userId
            }) {
                self.transcripts[index] = transcript
            } else {
                self.transcripts.append(transcript)
            }
            
            self.chatBackgroundView.tableView.reloadData()
            
            if !self.transcripts.isEmpty {
                let indexPath = IndexPath(row: self.transcripts.count - 1, section: 0)
                self.chatBackgroundView.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
            }
        }
    }
    
    func onDebugLog(log: String) {
        print(log)
    }
}
