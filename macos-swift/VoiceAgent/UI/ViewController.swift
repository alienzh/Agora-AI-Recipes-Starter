//
//  ViewController.swift
//  VoiceAgent
//
//  Created by HeZhengQing on 2025/11/17.
//

import Cocoa
import AgoraRtcKit
import AgoraRtmKit
import SnapKit

class ViewController: NSViewController {
    
    // MARK: - UI Components - Top Panel (Transcript)
    private var topPanel: NSView!
    private var messageListView: MessageListView!
    private var agentStatusLabel: NSTextField!  // Agent status at bottom-right of message list
    
    // MARK: - UI Components - Log Panel (right side, full height)
    private var logView: LogView!
    
    // MARK: - UI Components - Bottom Panel (Control)
    private var bottomPanel: NSView!
    private var muteButton: NSButton!
    private var startButton: NSButton!
    private var stopButton: NSButton!
    
    // MARK: - Properties
    
    // Agora Components (directly managed, no managers)
    private var rtcEngine: AgoraRtcEngineKit?
    private var rtmEngine: AgoraRtmClientKit?
    private var convoAIAPI: ConversationalAIAPI?
    
    // State
    private var channelName: String = ""
    private var isActive: Bool = false  // Track if agent is active (joined channel + agent started)
    private var isMuted: Bool = false
    private var transcripts: [Transcript] = []  // Changed to [Transcript] type
    
    // Tokens and IDs (moved from KeyCenter to ViewController)
    private var token: String = ""
    private var agentToken: String = ""
    private var agentId: String = ""
    private let userUid: UInt = 1001086
    private let agentUid: UInt = 1009527
    
    // MARK: - Constants
    private let bottomPanelHeight: CGFloat = 70
    private let panelSpacing: CGFloat = 1
    private let padding: CGFloat = 20
    private let buttonHeight: CGFloat = 44
    private let logViewWidth: CGFloat = 200
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("\n\n========== APP STARTED ==========\n")
        
        // Set a visible background color to verify view is loaded
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.1).cgColor
        
        setupUI()
        setupManagers()
        updateUIState(idle: true)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        
        // Configure window size (overrides Storyboard and cached size)
        if let window = view.window {
            window.isRestorable = false
            view.frame = NSRect(x: 0, y: 0, width: 1200, height: 800)
            window.setContentSize(NSSize(width: 1200, height: 800))
            window.minSize = NSSize(width: 800, height: 600)
            view.layoutSubtreeIfNeeded()
            window.center()
        }
    }
    private func setupManagers() {
        logView.clear()  // Clear previous logs
        initializeRTC()
        initializeRTM()
        
        // Set initial status
        updateAgentStatus(message: "Not Started")
    }
    
    // MARK: - Engine Initialization
    
    private func initializeRTC() {
        let rtcConfig = AgoraRtcEngineConfig()
        rtcConfig.appId = KeyCenter.AGORA_APP_ID
        rtcConfig.channelProfile = .liveBroadcasting
        rtcConfig.audioScenario = .aiClient
        let rtcEngine = AgoraRtcEngineKit.sharedEngine(with: rtcConfig, delegate: self)
        
        rtcEngine.enableVideo()
        rtcEngine.enableAudioVolumeIndication(100, smooth: 3, reportVad: false)
        
        let cameraConfig = AgoraCameraCapturerConfiguration()
        rtcEngine.setCameraCapturerConfiguration(cameraConfig)
        
        rtcEngine.setParameters("{\"che.audio.enable.predump\":{\"enable\":\"true\",\"duration\":\"60\"}}")
        
        self.rtcEngine = rtcEngine
        logToView("RTC init OK, v\(AgoraRtcEngineKit.getSdkVersion())")
    }
    
    private func initializeRTM() {
        let rtmConfig = AgoraRtmClientConfig(appId: KeyCenter.AGORA_APP_ID, userId: "\(userUid)")
        rtmConfig.areaCode = [.CN, .NA]
        rtmConfig.presenceTimeout = 30
        rtmConfig.heartbeatInterval = 10
        rtmConfig.useStringUserId = true
        
        do {
            let rtmClient = try AgoraRtmClientKit(rtmConfig, delegate: self)
            self.rtmEngine = rtmClient
            logToView("RTM init OK")
        } catch {
            logToView("RTM init FAIL: \(error)")
        }
    }
    
    // MARK: - Actions
    
    @objc private func startButtonTapped() {
        // Disable button to prevent repeated clicks
        startButton.isEnabled = false
        joinChannelAndStartAgent()
    }
    
    @objc private func stopButtonTapped() {
        // Disable button to prevent repeated clicks
        stopButton.isEnabled = false
        stopAgentAndLeaveChannel()
    }
    
    /// Join channel and start agent (combined operation)
    private func joinChannelAndStartAgent() {
        // Auto-generate channel name
        let channel = generateRandomChannelName()
        self.channelName = channel
        
        // Clear old transcripts when starting
        transcripts.removeAll()
        updateTranscripts()
        
        updateAgentStatus(message: "Generating token...")
        
        // Step 1: Generate user token and join channel
        TokenGenerator.generateToken(channelName: channel, uid: "\(userUid)", types: [.rtc, .rtm]) { [weak self] token in
            guard let self = self else { return }
            
            guard let token = token else {
                self.logToView("Token FAIL")
                self.updateAgentStatus(message: "Token failed")
                self.showIdleButtons()
                return
            }
            
            self.logToView("Token OK")
            self.token = token
            self.updateAgentStatus(message: "Joining...")
            
            // Join RTC channel
            self.joinRTCChannel(token: token, channelName: channel, uid: self.userUid)
            
            // Login RTM
            self.loginRTM(token: token) { [weak self] error in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if let error = error {
                        self.logToView("RTM login FAIL: \(error)")
                        self.updateAgentStatus(message: "RTM login failed")
                        self.showIdleButtons()
                        return
                    }
                    
                    self.logToView("RTM login OK")
                    self.updateAgentStatus(message: "Initializing...")
                    
                    // Step 2: Initialize ConversationalAI API
                    self.initializeConvoAIAPI(channel: channel)
                    
                    // Step 3: Start agent (similar to Android)
                    self.startAgent()
                }
            }
            
            self.updateUIState(idle: false)
        }
    }
    
    // MARK: - Channel Connection
    
    private func joinRTCChannel(token: String, channelName: String, uid: UInt) {
        guard let rtcEngine = self.rtcEngine else {
            logToView("joinChannel FAIL: nil")
            print("[RTC] ❌ RTC engine is nil")
            return
        }
        
        let options = AgoraRtcChannelMediaOptions()
        options.clientRoleType = .broadcaster
        options.publishMicrophoneTrack = true
        options.publishCameraTrack = false
        options.autoSubscribeAudio = true
        options.autoSubscribeVideo = true
        
        let result = rtcEngine.joinChannel(byToken: token, channelId: channelName, uid: uid, mediaOptions: options)
        logToView("joinChannel ret=\(result)")
    }
    
    private func loginRTM(token: String, completion: @escaping (Error?) -> Void) {
        guard let rtmEngine = self.rtmEngine else {
            let error = NSError(domain: "loginRTM", code: -1, userInfo: [NSLocalizedDescriptionKey: "RTM engine not initialized"])
            completion(error)
            return
        }
        
        rtmEngine.login(token) { response, error in
            if let error = error {
                print("[RTM] Login failed: \(error.localizedDescription)")
                completion(error)
            } else {
                print("[RTM] Login successful")
                completion(nil)
            }
        }
    }
    
    /// Initialize ConversationalAI API for transcript processing
    private func initializeConvoAIAPI(channel: String) {
        guard let rtcEngine = self.rtcEngine else {
            print("[ViewController] ❌ Cannot initialize ConvoAIAPI: RTC engine is nil")
            return
        }
        
        guard let rtmEngine = self.rtmEngine else {
            print("[ViewController] ❌ Cannot initialize ConvoAIAPI: RTM engine is nil")
            return
        }
        
        // Create ConversationalAI API config
        let config = ConversationalAIAPIConfig(
            rtcEngine: rtcEngine,
            rtmEngine: rtmEngine,
            renderMode: .words,  // Use words mode for real-time rendering
            enableLog: true
        )
        
        // Initialize API
        let api = ConversationalAIAPIImpl(config: config)
        api.addHandler(handler: self)  // Set self as event handler
        
        // Subscribe to messages
        api.subscribeMessage(channelName: channel) { error in
            if let error = error {
                print("[ConvoAIAPI] ❌ Subscribe error: \(error.message)")
            } else {
                print("[ConvoAIAPI] ✅ Subscribed to channel: \(channel)")
            }
        }
        
        self.convoAIAPI = api
        print("[ViewController] ✅ ConvoAIAPI initialized")
    }
    
    /// Start agent after channel is joined (Step 3 of joinChannelAndStartAgent)
    private func startAgent() {
        updateAgentStatus(message: "Generating agent token...")
        
        // Generate agent token
        TokenGenerator.generateToken(channelName: channelName, uid: "\(agentUid)", types: [.rtc, .rtm]) { [weak self] token in
            guard let self = self else { return }
            guard let token = token else {
                self.logToView("Agent token FAIL")
                self.updateAgentStatus(message: "Token failed")
                self.showIdleButtons()
                return
            }
            
            self.logToView("Agent token OK")
            self.agentToken = token
            self.updateAgentStatus(message: "Starting agent...")
            
            // Start agent using AgentManager (similar to Android)
            AgentManager.startAgent(
                channelName: self.channelName,
                agentRtcUid: "\(self.agentUid)",
                token: token
            ) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let agentId):
                    self.logToView("Agent start OK, id=\(agentId)")
                    self.agentId = agentId
                    self.isActive = true
                    self.showActiveButton()
                    self.updateAgentStatus(message: "Launching...")
                    
                case .failure(let error):
                    self.logToView("Agent start FAIL: \(error.localizedDescription)")
                    self.updateAgentStatus(message: "Start failed")
                    self.stopAgentAndLeaveChannel()
                }
            }
        }
    }
    
    @objc private func muteButtonTapped() {
        isMuted.toggle()
        rtcEngine?.adjustRecordingSignalVolume(isMuted ? 0 : 100)
        muteButton.title = isMuted ? "Unmute" : "Mute"
        print("[RTC] Local audio \(isMuted ? "muted" : "unmuted")")
    }
    
    /// Stop agent and leave channel (combined operation, similar to Android hangup)
    private func stopAgentAndLeaveChannel() {
        updateAgentStatus(message: "Stopping...")
        
        // Step 1: Unsubscribe from ConversationalAI messages
        convoAIAPI?.destroy()
        convoAIAPI = nil
        
        // Step 2: Stop agent if running
        if !agentId.isEmpty {
            AgentManager.stopAgent(agentId: agentId) { result in
                if case .failure(let error) = result {
                    print("❌ Failed to stop agent: \(error.localizedDescription)")
                } else {
                    print("✅ Agent stopped successfully")
                }
            }
        }
        
        // Step 3: Leave RTC channel and logout RTM
        rtcEngine?.leaveChannel()
        rtmEngine?.logout { response, error in
            if let error = error {
                print("❌ RTM logout error: \(error.localizedDescription)")
            } else {
                print("✅ RTM logout successful")
            }
        }
        print("[RTC] Left channel")
        
        // Step 4: Reset all state
        channelName = ""
        isActive = false
        isMuted = false
        transcripts = []
        token = ""
        agentToken = ""
        agentId = ""
        updateTranscripts()  // Update UI with empty transcripts
        
        // Reset buttons
        muteButton.title = "Mute"
        showIdleButtons()
        
        // Update status
        updateAgentStatus(message: "Not Started")
        updateUIState(idle: true)
        
        print("✅ Stop agent and leave channel completed")
    }
    
    
    // MARK: - Helper Methods
    
    private func updateUIState(idle: Bool) {
        muteButton.isEnabled = !idle
    }
    
    private func updateTranscripts() {
        // Update message list view (handles formatting and scrolling internally)
        messageListView.updateTranscripts(transcripts)
    }
    
    // MARK: - Status Update Helpers
    
    private func updateAgentStatus(message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.agentStatusLabel.stringValue = "Agent: \(message)"
        }
    }
    
    /// Show idle state button (Start only)
    private func showIdleButtons() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.startButton.isHidden = false
            self.startButton.isEnabled = true
            self.muteButton.isHidden = true
            self.stopButton.isHidden = true
        }
    }
    
    /// Show active state buttons (Mute + Stop)
    private func showActiveButton() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.startButton.isHidden = true
            self.muteButton.isHidden = false
            self.muteButton.isEnabled = true
            self.stopButton.isHidden = false
            self.stopButton.isEnabled = true
        }
    }
    
    
    /// Log to both console and UI
    private func logToView(_ message: String) {
        print("[Log] \(message)")
        DispatchQueue.main.async { [weak self] in
            self?.logView.addLog(message)
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - AgoraRtmClientDelegate
extension ViewController: AgoraRtmClientDelegate {
    
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

// MARK: - AgoraRtcEngineDelegate (Direct implementation, no forwarding)
extension ViewController: AgoraRtcEngineDelegate {
    
    /// Called when local user joins channel
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        logToView("onJoinSuccess uid=\(uid)")
    }
    
    /// Called when a remote user joins the channel
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        logToView("onUserJoined uid=\(uid)")
        
        // Check if this is the agent joining
        if uid == agentUid && isActive {
            updateAgentStatus(message: "Connected")
        }
    }
    
    /// Called when a remote user leaves the channel
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        logToView("onUserOffline uid=\(uid)")
        
        // Check if this is the agent leaving
        if uid == agentUid && isActive {
            updateAgentStatus(message: "Disconnected")
        }
    }
    
    /// Called when RTC connection state changes
    func rtcEngine(_ engine: AgoraRtcEngineKit, connectionChangedTo state: AgoraConnectionState, reason: AgoraConnectionChangedReason) {
        switch state {
        case .disconnected, .failed:
            updateAgentStatus(message: "Connection lost")
        default:
            break
        }
    }
    
    /// Called when RTC error occurs
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        logToView("onError code=\(errorCode.rawValue)")
        updateAgentStatus(message: "RTC error: \(errorCode.rawValue)")
    }
    
    /// Called when token will expire
    func rtcEngine(_ engine: AgoraRtcEngineKit, tokenPrivilegeWillExpire token: String) {
        logToView("Token expiring")
    }
}

// MARK: - ConversationalAIAPIEventHandler (Transcript processing)
extension ViewController: ConversationalAIAPIEventHandler {
    
    /// Called when transcript is updated (similar to iOS)
    func onTranscriptUpdated(agentUserId: String, transcript: Transcript) {
        print("[Transcript] Updated: \(transcript.text), type: \(transcript.type), status: \(transcript.status)")
        
        // Find existing transcript with same turnId and update, or append new one
        if let index = self.transcripts.firstIndex(where: {
            $0.turnId == transcript.turnId &&
            $0.type.rawValue == transcript.type.rawValue &&
            $0.userId == transcript.userId
        }) {
            // Update existing transcript
            self.transcripts[index] = transcript
        } else {
            // Add new transcript
            self.transcripts.append(transcript)
        }
        
        // Update UI (MessageListView handles scrolling internally)
        self.updateTranscripts()
    }
    
    /// Called when agent voiceprint state changes
    func onAgentVoiceprintStateChanged(agentUserId: String, event: VoiceprintStateChangeEvent) {
        print("[Voiceprint] State changed: \(event)")
    }
    
    /// Called when message error occurs
    func onMessageError(agentUserId: String, error: MessageError) {
        print("[Message] ❌ Error: \(error.message)")
    }
    
    /// Called when message receipt is updated
    func onMessageReceiptUpdated(agentUserId: String, messageReceipt: MessageReceipt) {
        print("[Message] Receipt updated: \(messageReceipt)")
    }
    
    /// Called when agent state changes
    func onAgentStateChanged(agentUserId: String, event: StateChangeEvent) {
        print("[Agent] State changed: \(event.state), turnId: \(event.turnId)")
        
        // Update agent status based on state
        switch event.state {
        case .idle:
            updateAgentStatus(message: "Idle")
        case .silent:
            updateAgentStatus(message: "Silent")
        case .listening:
            updateAgentStatus(message: "Listening")
        case .thinking:
            updateAgentStatus(message: "Thinking")
        case .speaking:
            updateAgentStatus(message: "Speaking")
        case .unknown:
            break
        @unknown default:
            break
        }
    }
    
    /// Called when agent is interrupted
    func onAgentInterrupted(agentUserId: String, event: InterruptEvent) {
        print("[Agent] Interrupted: turnId \(event.turnId)")
    }
    
    /// Called when agent metrics are updated
    func onAgentMetrics(agentUserId: String, metrics: Metric) {
        print("[Agent] Metrics: \(metrics)")
    }
    
    /// Called when agent error occurs
    func onAgentError(agentUserId: String, error: ModuleError) {
        print("[Agent] ❌ Error: \(error.message)")
    }
    
    /// Debug log callback
    func onDebugLog(log: String) {
        // Uncomment for verbose debugging
        // print("[Debug] \(log)")
    }
}


// MARK: - UI Creation
extension ViewController {
    
    private func setupUI() {
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        
        // Create log panel first (right side, full height)
        setupLogPanel()
        
        // Create top panel (Transcript)
        setupTopPanel()
        
        // Create bottom panel (Status + Control)
        setupBottomPanel()
        
        // Layout log panel - right side, full height
        logView.snp.makeConstraints { make in
            make.top.right.bottom.equalToSuperview()
            make.width.equalTo(logViewWidth)
        }
        
        // Layout main panels - vertical stack (left of logView)
        topPanel.snp.makeConstraints { make in
            make.top.left.equalToSuperview()
            make.right.equalTo(logView.snp.left).offset(-padding)
            make.bottom.equalTo(bottomPanel.snp.top).offset(-panelSpacing)
        }
        
        bottomPanel.snp.makeConstraints { make in
            make.left.bottom.equalToSuperview()
            make.right.equalTo(logView.snp.left).offset(-padding)
            make.height.equalTo(bottomPanelHeight)
        }
    }
    
    private func setupLogPanel() {
        logView = LogView()
        view.addSubview(logView)
    }
    
    private func setupTopPanel() {
        topPanel = NSView()
        topPanel.wantsLayer = true
        topPanel.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        view.addSubview(topPanel)
        
        // Message list view
        messageListView = MessageListView()
        topPanel.addSubview(messageListView)
        
        // Agent status label (bottom-right corner)
        agentStatusLabel = NSTextField(labelWithString: "Agent: Not Started")
        agentStatusLabel.font = .systemFont(ofSize: 11, weight: .regular)
        agentStatusLabel.textColor = .secondaryLabelColor
        agentStatusLabel.alignment = .right
        agentStatusLabel.isBordered = false
        agentStatusLabel.isEditable = false
        agentStatusLabel.backgroundColor = .clear
        topPanel.addSubview(agentStatusLabel)
        
        // Layout
        messageListView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(padding)
            make.left.right.equalToSuperview().inset(padding)
            make.bottom.equalTo(agentStatusLabel.snp.top).offset(-8)
        }
        
        agentStatusLabel.snp.makeConstraints { make in
            make.right.equalToSuperview().offset(-padding)
            make.bottom.equalToSuperview().offset(-12)
            make.height.equalTo(16)
        }
    }
    
    private func setupBottomPanel() {
        bottomPanel = NSView()
        bottomPanel.wantsLayer = true
        bottomPanel.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        bottomPanel.layer?.borderWidth = 0.5
        bottomPanel.layer?.borderColor = NSColor.separatorColor.cgColor
        view.addSubview(bottomPanel)
        
        // Start button (full width, shown when idle)
        startButton = createButton(title: "Start Agent", action: #selector(startButtonTapped))
        startButton.contentTintColor = .systemGreen
        bottomPanel.addSubview(startButton)
        
        // Mute button (left, shown when active)
        muteButton = createButton(title: "Mute", action: #selector(muteButtonTapped))
        muteButton.isHidden = true
        bottomPanel.addSubview(muteButton)
        
        // Stop button (right, shown when active)
        stopButton = createButton(title: "Stop Agent", action: #selector(stopButtonTapped))
        stopButton.contentTintColor = .systemRed
        stopButton.isHidden = true
        bottomPanel.addSubview(stopButton)
        
        // Layout - Start (full width, shown when idle)
        startButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.right.equalToSuperview().inset(padding)
            make.height.equalTo(buttonHeight)
        }
        
        // Layout - Mute + Stop (shown when active)
        muteButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalToSuperview().offset(padding)
            make.right.equalTo(bottomPanel.snp.centerX).offset(-4)
            make.height.equalTo(buttonHeight)
        }
        
        stopButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.equalTo(bottomPanel.snp.centerX).offset(4)
            make.right.equalToSuperview().offset(-padding)
            make.height.equalTo(buttonHeight)
        }
    }
    
    // MARK: - Helper Methods
    
    /// Generate random channel name
    private func generateRandomChannelName() -> String {
        let randomNumber = Int.random(in: 1000...9999)
        return "channel_macos_\(randomNumber)"
    }
    
    // MARK: - Helper Methods for UI
    
    private func createButton(title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.font = .systemFont(ofSize: 12, weight: .medium)
        button.wantsLayer = true
        
        // Modern button styling
        if title.contains("Start") {
            button.contentTintColor = .systemGreen
        } else if title.contains("Stop") {
            button.contentTintColor = .systemRed
        }
        
        return button
    }
    
    private func createSeparator() -> NSBox {
        let separator = NSBox()
        separator.boxType = .separator
        return separator
    }
}
