//
//  ViewController.swift
//  VoiceAgent
//
//  Created by HeZhengQing on 2025/11/17.
//

import Cocoa
import AgoraRtcKit
import SnapKit

class ViewController: NSViewController {
    
    // MARK: - UI Components - Left Panel (Control)
    private var leftPanel: NSView!
    private var channelTextField: NSTextField!
    private var startStopButton: NSButton!  // Combined Start/Stop Agent button
    private var muteButton: NSButton!
    
    // Status labels (3 lines, title on left, detail on right)
    private var micTitleLabel: NSTextField!       // Line 1 title: "Microphone"
    private var micDetailLabel: NSTextField!      // Line 1 detail: "Active" / "Muted"
    private var channelTitleLabel: NSTextField!   // Line 2 title: "Channel"
    private var channelDetailLabel: NSTextField!  // Line 2 detail: "Connected" / "Disconnected"
    private var agentTitleLabel: NSTextField!     // Line 3 title: "Agent"
    private var agentDetailLabel: NSTextField!    // Line 3 detail: "Not Started" / "Connected"
    
    // MARK: - UI Components - Right Panel (Transcript)
    private var rightPanel: NSView!
    private var messageListView: MessageListView!  // Replaced transcriptTextView with MessageListView
    private var transcriptCountLabel: NSTextField!
    private var clearButton: NSButton!
    
    // MARK: - Properties
    
    // Managers
    private let rtcManager = RtcManager.shared
    private let rtmManager = RtmManager.shared
    private var convoAIAPI: ConversationalAIAPI?  // ConversationalAI API for transcript processing
    
    // State
    private var channelName: String = ""
    private var isActive: Bool = false  // Track if agent is active (joined channel + agent started)
    private var isMuted: Bool = false
    private var transcripts: [Transcript] = []  // Changed to [Transcript] type
    
    // Tokens and IDs (moved from KeyCenter to ViewController)
    private var token: String = ""
    private var agentToken: String = ""
    private var agentId: String = ""
    private let userUid: UInt = 1001086  // User UID
    private let agentUid: UInt = 1009527  // Agent UID
    
    // MARK: - Constants
    private let leftPanelWidth: CGFloat = 220
    private let panelSpacing: CGFloat = 1
    private let padding: CGFloat = 20
    private let buttonHeight: CGFloat = 32
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
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
        // Create RTC Engine with self as delegate (no forwarding)
        _ = rtcManager.createRtcEngine(delegate: self)
        
        // Initialize RTM Client
        rtmManager.initializeClient(userId: "\(userUid)")
        
        // Set initial status
        updateMicStatus(muted: false)
        updateChannelStatus(connected: false, message: "Ready")
        updateAgentStatus(message: "Not Started")
    }
    
    // MARK: - Actions
    
    @objc private func startStopButtonTapped() {
        // Disable button to prevent repeated clicks
        startStopButton.isEnabled = false
        
        if isActive {
            // Stop agent and leave channel
            stopAgentAndLeaveChannel()
        } else {
            // Join channel and start agent
            joinChannelAndStartAgent()
        }
    }
    
    /// Join channel and start agent (combined operation)
    private func joinChannelAndStartAgent() {
        var channel = channelTextField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Generate random channel name if empty
        if channel.isEmpty {
            channel = generateRandomChannelName()
            channelTextField.stringValue = channel
        }
        
        self.channelName = channel
        
        // Clear old transcripts when starting
        transcripts.removeAll()
        updateTranscripts()
        
        updateChannelStatus(connected: false, message: "Generating token...")
        updateAgentStatus(message: "Initializing...")
        
        // Step 1: Generate user token and join channel
        TokenGenerator.generateToken(channelName: channel, uid: "\(userUid)", types: [.rtc, .rtm]) { [weak self] token in
            guard let self = self else { return }
            
            guard let token = token else {
                self.updateChannelStatus(connected: false, message: "Token failed")
                self.updateAgentStatus(message: "Failed")
                self.startStopButton.isEnabled = true
                return
            }
            
            self.token = token
            self.updateChannelStatus(connected: false, message: "Joining...")
            
            // Join RTC channel
            self.rtcManager.joinChannel(rtcToken: token, channelName: channel, uid: self.userUid)
            
            // Login RTM
            self.rtmManager.login(token: token) { [weak self] error in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    if let error = error {
                        self.updateChannelStatus(connected: false, message: "RTM login failed")
                        self.updateAgentStatus(message: "Failed")
                        self.startStopButton.isEnabled = true
                        print("❌ RTM login error: \(error)")
                        return
                    }
                    
                    self.updateChannelStatus(connected: true, message: "Connected")
                    
                    // Step 2: Initialize ConversationalAI API
                    self.initializeConvoAIAPI(channel: channel)
                    
                    // Step 3: Start agent (similar to Android)
                    self.startAgent()
                }
            }
            
            self.updateUIState(idle: false)
        }
    }
    
    /// Initialize ConversationalAI API for transcript processing
    private func initializeConvoAIAPI(channel: String) {
        let rtcEngine = rtcManager.getRtcEngine()
        guard let rtmEngine = rtmManager.getRtmClient() else {
            print("[ViewController] ❌ Cannot initialize ConvoAIAPI: RTM client is nil")
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
                self.updateAgentStatus(message: "Token failed")
                self.startStopButton.isEnabled = true
                return
            }
            
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
                    self.agentId = agentId
                    self.isActive = true
                    self.startStopButton.title = "Stop Agent"
                    self.startStopButton.contentTintColor = .systemRed
                    self.startStopButton.isEnabled = true
                    self.updateAgentStatus(message: "Launching...")
                    print("✅ Agent started with ID: \(agentId), waiting for channel join...")
                    
                case .failure(let error):
                    self.updateAgentStatus(message: "Start failed")
                    self.stopAgentAndLeaveChannel()
                    print("❌ Agent start error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    @objc private func muteButtonTapped() {
        isMuted.toggle()
        rtcManager.muteLocalAudio(mute: isMuted)
        muteButton.title = isMuted ? "Unmute" : "Mute"
        updateMicStatus(muted: isMuted)
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
        rtcManager.leaveChannel()
        rtmManager.logout()
        
        // Step 4: Reset all state
        channelName = ""
        isActive = false
        isMuted = false
        transcripts = []
        token = ""
        agentToken = ""
        agentId = ""
        updateTranscripts()  // Update UI with empty transcripts
        
        // Reset button
        startStopButton.title = "Start Agent"
        startStopButton.contentTintColor = .systemGreen
        startStopButton.isEnabled = true
        muteButton.title = "Mute"
        
        // Update all status labels
        updateMicStatus(muted: false)
        updateChannelStatus(connected: false, message: "Disconnected")
        updateAgentStatus(message: "Not Started")
        updateUIState(idle: true)
        
        print("✅ Stop agent and leave channel completed")
    }
    
    @objc private func clearTranscriptTapped() {
        // Clear transcripts data
        transcripts.removeAll()
        
        // Update UI
        messageListView.clearMessages()
        transcriptCountLabel.stringValue = "Total: 0 messages"
        
        // Add animation feedback
        clearButton.animator().alphaValue = 0.5
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.clearButton.animator().alphaValue = 1.0
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateUIState(idle: Bool) {
        channelTextField.isEnabled = idle
        muteButton.isEnabled = !idle
    }
    
    private func updateTranscripts() {
        // Update message list view (handles formatting and scrolling internally)
        messageListView.updateTranscripts(transcripts)
        
        // Update count with timestamp
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        transcriptCountLabel.stringValue = "Total: \(transcripts.count) messages • \(timestamp)"
    }
    
    // MARK: - Status Update Helpers
    
    private func updateMicStatus(muted: Bool) {
        DispatchQueue.main.async { [weak self] in
            if muted {
                self?.micDetailLabel.stringValue = "Muted"
            } else {
                self?.micDetailLabel.stringValue = "Active"
            }
        }
    }
    
    private func updateChannelStatus(connected: Bool, message: String? = nil) {
        DispatchQueue.main.async { [weak self] in
            if connected {
                self?.channelDetailLabel.stringValue = message ?? "Connected"
            } else {
                self?.channelDetailLabel.stringValue = message ?? "Disconnected"
            }
        }
    }
    
    private func updateAgentStatus(message: String) {
        DispatchQueue.main.async { [weak self] in
            self?.agentDetailLabel.stringValue = message
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

// MARK: - AgoraRtcEngineDelegate (Direct implementation, no forwarding)
extension ViewController: AgoraRtcEngineDelegate {
    
    /// Called when local user joins channel
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinChannel channel: String, withUid uid: UInt, elapsed: Int) {
        print("[RTC] Local user joined channel: \(channel), uid: \(uid), elapsed: \(elapsed)ms")
        // Channel status already updated in RTM login callback
    }
    
    /// Called when a remote user joins the channel (similar to Android onUserJoined)
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        print("[RTC] User joined: \(uid), elapsed: \(elapsed)ms")
        
        // Check if this is the agent joining
        if uid == agentUid && isActive {
            updateAgentStatus(message: "Connected")
            print("✅ Agent joined the channel, uid: \(uid)")
        } else {
            print("ℹ️ Other user joined the channel, uid: \(uid)")
        }
    }
    
    /// Called when a remote user leaves the channel (similar to Android onUserOffline)
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        print("[RTC] User offline: \(uid), reason: \(reason.rawValue)")
        
        // Check if this is the agent leaving
        if uid == agentUid && isActive {
            updateAgentStatus(message: "Disconnected")
            print("⚠️ Agent left the channel, uid: \(uid), reason: \(reason.rawValue)")
        } else {
            print("ℹ️ Other user left the channel, uid: \(uid)")
        }
    }
    
    /// Called when RTC connection state changes
    func rtcEngine(_ engine: AgoraRtcEngineKit, connectionChangedTo state: AgoraConnectionState, reason: AgoraConnectionChangedReason) {
        print("[RTC] Connection state changed to: \(state.rawValue), reason: \(reason.rawValue)")
        
        switch state {
        case .connected:
            print("✅ RTC connected")
            
        case .disconnected, .failed:
            updateChannelStatus(connected: false, message: "Connection lost")
            print("❌ RTC disconnected")
            
        default:
            break
        }
    }
    
    /// Called when RTC error occurs (similar to Android onError)
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOccurError errorCode: AgoraErrorCode) {
        print("[RTC] ❌ Error occurred: \(errorCode.rawValue)")
        updateChannelStatus(connected: false, message: "RTC error: \(errorCode.rawValue)")
    }
    
    /// Called when token will expire
    func rtcEngine(_ engine: AgoraRtcEngineKit, tokenPrivilegeWillExpire token: String) {
        print("[RTC] ⚠️ Token will expire, need to renew")
        // TODO: Implement token renewal logic
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
        
        // Create left panel (Control Panel)
        setupLeftPanel()
        
        // Create right panel (Transcript Panel)
        setupRightPanel()
        
        // Layout main panels
        leftPanel.snp.makeConstraints { make in
            make.left.top.bottom.equalToSuperview()
            make.width.equalTo(leftPanelWidth)
        }
        
        rightPanel.snp.makeConstraints { make in
            make.left.equalTo(leftPanel.snp.right).offset(panelSpacing)
            make.top.bottom.right.equalToSuperview()
            // IMPORTANT: Allow panel to be flexible
            make.width.greaterThanOrEqualTo(400).priority(.high)
        }
    }
    
    private func setupLeftPanel() {
        leftPanel = NSView()
        leftPanel.wantsLayer = true
        leftPanel.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        // Add subtle shadow for depth
        leftPanel.shadow = NSShadow()
        leftPanel.layer?.shadowOpacity = 0.1
        leftPanel.layer?.shadowRadius = 4
        leftPanel.layer?.shadowOffset = NSSize(width: 2, height: 0)
        view.addSubview(leftPanel)
        
        // Channel input section
        let channelLabel = NSTextField(labelWithString: "Channel")
        channelLabel.font = .systemFont(ofSize: 11, weight: .medium)
        channelLabel.textColor = .secondaryLabelColor
        channelLabel.isBordered = false
        channelLabel.isEditable = false
        channelLabel.backgroundColor = .clear
        leftPanel.addSubview(channelLabel)
        
        channelTextField = NSTextField()
        channelTextField.placeholderString = "Enter or auto-generate"
        channelTextField.font = .systemFont(ofSize: 12)
        leftPanel.addSubview(channelTextField)
        
        // Action buttons
        startStopButton = createButton(title: "Start Agent", action: #selector(startStopButtonTapped))
        leftPanel.addSubview(startStopButton)
        
        muteButton = createButton(title: "Mute", action: #selector(muteButtonTapped))
        leftPanel.addSubview(muteButton)
        
        // Separator
        let separator2 = createSeparator()
        leftPanel.addSubview(separator2)
        
        // Status section title
        let statusSectionLabel = NSTextField(labelWithString: "Status")
        statusSectionLabel.font = .systemFont(ofSize: 11, weight: .medium)
        statusSectionLabel.textColor = .secondaryLabelColor
        statusSectionLabel.alignment = .center
        statusSectionLabel.isBordered = false
        statusSectionLabel.isEditable = false
        statusSectionLabel.backgroundColor = .clear
        leftPanel.addSubview(statusSectionLabel)
        
        // Microphone status (Line 1)
        micTitleLabel = NSTextField(labelWithString: "Microphone")
        micTitleLabel.font = .systemFont(ofSize: 12)
        micTitleLabel.alignment = .left
        micTitleLabel.textColor = .secondaryLabelColor
        micTitleLabel.isBordered = false
        micTitleLabel.isEditable = false
        micTitleLabel.backgroundColor = .clear
        leftPanel.addSubview(micTitleLabel)
        
        micDetailLabel = NSTextField(labelWithString: "Active")
        micDetailLabel.font = .systemFont(ofSize: 12)
        micDetailLabel.alignment = .right
        micDetailLabel.textColor = .labelColor
        micDetailLabel.isBordered = false
        micDetailLabel.isEditable = false
        micDetailLabel.backgroundColor = .clear
        leftPanel.addSubview(micDetailLabel)
        
        // Channel connection status (Line 2)
        channelTitleLabel = NSTextField(labelWithString: "Channel")
        channelTitleLabel.font = .systemFont(ofSize: 12)
        channelTitleLabel.alignment = .left
        channelTitleLabel.textColor = .secondaryLabelColor
        channelTitleLabel.isBordered = false
        channelTitleLabel.isEditable = false
        channelTitleLabel.backgroundColor = .clear
        leftPanel.addSubview(channelTitleLabel)
        
        channelDetailLabel = NSTextField(labelWithString: "Disconnected")
        channelDetailLabel.font = .systemFont(ofSize: 12)
        channelDetailLabel.alignment = .right
        channelDetailLabel.textColor = .labelColor
        channelDetailLabel.isBordered = false
        channelDetailLabel.isEditable = false
        channelDetailLabel.backgroundColor = .clear
        leftPanel.addSubview(channelDetailLabel)
        
        // Agent status (Line 3)
        agentTitleLabel = NSTextField(labelWithString: "Agent")
        agentTitleLabel.font = .systemFont(ofSize: 12)
        agentTitleLabel.alignment = .left
        agentTitleLabel.textColor = .secondaryLabelColor
        agentTitleLabel.isBordered = false
        agentTitleLabel.isEditable = false
        agentTitleLabel.backgroundColor = .clear
        leftPanel.addSubview(agentTitleLabel)
        
        agentDetailLabel = NSTextField(labelWithString: "Not Started")
        agentDetailLabel.font = .systemFont(ofSize: 12)
        agentDetailLabel.alignment = .right
        agentDetailLabel.textColor = .labelColor
        agentDetailLabel.isBordered = false
        agentDetailLabel.isEditable = false
        agentDetailLabel.backgroundColor = .clear
        leftPanel.addSubview(agentDetailLabel)
        
        // Layout left panel
        channelLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.left.right.equalToSuperview().inset(16)
        }
        
        channelTextField.snp.makeConstraints { make in
            make.top.equalTo(channelLabel.snp.bottom).offset(6)
            make.left.right.equalToSuperview().inset(16)
            make.height.equalTo(24)
        }
        
        startStopButton.snp.makeConstraints { make in
            make.top.equalTo(channelTextField.snp.bottom).offset(16)
            make.left.right.equalToSuperview().inset(16)
            make.height.equalTo(buttonHeight)
        }
        
        muteButton.snp.makeConstraints { make in
            make.top.equalTo(startStopButton.snp.bottom).offset(8)
            make.left.right.equalToSuperview().inset(16)
            make.height.equalTo(buttonHeight)
        }
        
        separator2.snp.makeConstraints { make in
            make.top.equalTo(muteButton.snp.bottom).offset(16)
            make.left.right.equalToSuperview().inset(12)
            make.height.equalTo(1)
        }
        
        statusSectionLabel.snp.makeConstraints { make in
            make.top.equalTo(separator2.snp.bottom).offset(16)
            make.left.right.equalToSuperview().inset(16)
        }
        
        // Line 1: Microphone (title left, detail right)
        micTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(statusSectionLabel.snp.bottom).offset(12)
            make.left.equalToSuperview().inset(16)
        }
        
        micDetailLabel.snp.makeConstraints { make in
            make.top.equalTo(micTitleLabel.snp.top)
            make.right.equalToSuperview().inset(16)
            make.left.greaterThanOrEqualTo(micTitleLabel.snp.right).offset(8)
        }
        
        // Line 2: Channel (title left, detail right)
        channelTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(micTitleLabel.snp.bottom).offset(8)
            make.left.equalToSuperview().inset(16)
        }
        
        channelDetailLabel.snp.makeConstraints { make in
            make.top.equalTo(channelTitleLabel.snp.top)
            make.right.equalToSuperview().inset(16)
            make.left.greaterThanOrEqualTo(channelTitleLabel.snp.right).offset(8)
        }
        
        // Line 3: Agent (title left, detail right)
        agentTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(channelTitleLabel.snp.bottom).offset(8)
            make.left.equalToSuperview().inset(16)
        }
        
        agentDetailLabel.snp.makeConstraints { make in
            make.top.equalTo(agentTitleLabel.snp.top)
            make.right.equalToSuperview().inset(16)
            make.left.greaterThanOrEqualTo(agentTitleLabel.snp.right).offset(8)
        }
    }
    
    private func setupRightPanel() {
        rightPanel = NSView()
        rightPanel.wantsLayer = true
        rightPanel.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        // Add subtle border
        rightPanel.layer?.borderWidth = 0.5
        rightPanel.layer?.borderColor = NSColor.separatorColor.cgColor
        view.addSubview(rightPanel)
        
        // Title
        let titleLabel = NSTextField(labelWithString: "💬 Conversation Transcript")
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.isBordered = false
        titleLabel.isEditable = false
        titleLabel.backgroundColor = .clear
        rightPanel.addSubview(titleLabel)
        
        // Clear button
        clearButton = NSButton(title: "Clear", target: self, action: #selector(clearTranscriptTapped))
        clearButton.bezelStyle = .rounded
        clearButton.font = .systemFont(ofSize: 11)
        clearButton.contentTintColor = .systemGray
        rightPanel.addSubview(clearButton)
        
        // Separator
        let separator = createSeparator()
        rightPanel.addSubview(separator)
        
        // Message list view (replaces transcriptTextView)
        messageListView = MessageListView()
        rightPanel.addSubview(messageListView)
        
        // Bottom info bar
        transcriptCountLabel = NSTextField(labelWithString: "Total: 0 messages")
        transcriptCountLabel.font = .systemFont(ofSize: 11)
        transcriptCountLabel.textColor = .secondaryLabelColor
        transcriptCountLabel.alignment = .left
        transcriptCountLabel.isBordered = false
        transcriptCountLabel.isEditable = false
        transcriptCountLabel.backgroundColor = .clear
        rightPanel.addSubview(transcriptCountLabel)
        
        // Layout right panel
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(16)
            make.left.equalToSuperview().offset(padding)
        }
        
        clearButton.snp.makeConstraints { make in
            make.centerY.equalTo(titleLabel)
            make.right.equalToSuperview().offset(-padding)
            make.width.equalTo(70)
            make.height.equalTo(24)
        }
        
        separator.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.left.right.equalToSuperview().inset(padding)
            make.height.equalTo(1)
        }
        
        messageListView.snp.makeConstraints { make in
            make.top.equalTo(separator.snp.bottom).offset(12)
            make.left.right.equalToSuperview().inset(padding)
            make.bottom.equalTo(transcriptCountLabel.snp.top).offset(-8)
        }
        
        transcriptCountLabel.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(padding)
            make.bottom.equalToSuperview().offset(-12)
            make.height.equalTo(16)
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
