//
//  ChatViewController.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

import UIKit
import SnapKit
import AgoraRtcKit
import AgoraRtmKit

class ChatViewController: UIViewController {
    let uid: Int
    let channel: String
    
    // MARK: - UI Components
    private let tableView = UITableView()
    private let statusView = AgentStateView()
    private let controlBarView = UIView()
    private let micButton = UIButton(type: .system)
    private let endCallButton = UIButton(type: .system)
    
    // MARK: - State
    private var transcripts: [Transcript] = []
    private var isMicMuted: Bool = false
    private var isLoading: Bool = false
    private var isError: Bool = false
    private var initializationError: Error?
    private var currentAgentState: AgentState = .unknown
    
    // MARK: - Agora Components
    private var token: String = ""
    private var agentToken: String = ""
    private var agentId: String = ""
    private var rtcEngine: AgoraRtcEngineKit?
    private var rtmEngine: AgoraRtmClientKit?
    private var convoAIAPI: ConversationalAIAPI?
    private let agentUid = Int.random(in: 10000000...99999999)
    
    // MARK: - Initialization
    init(uid: Int, channel: String) {
        self.uid = uid
        self.channel = channel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        start()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        title = "VoiceAgent"
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.hidesBackButton = true
        
        // TableView for transcripts
        tableView.delegate = self
        tableView.dataSource = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.register(TranscriptCell.self, forCellReuseIdentifier: "TranscriptCell")
        view.addSubview(tableView)
        
        // Status View
        view.addSubview(statusView)
        
        // Control Bar
        controlBarView.backgroundColor = .white
        controlBarView.layer.cornerRadius = 16
        controlBarView.layer.shadowColor = UIColor.black.cgColor
        controlBarView.layer.shadowOpacity = 0.1
        controlBarView.layer.shadowOffset = CGSize(width: 0, height: 2)
        controlBarView.layer.shadowRadius = 8
        view.addSubview(controlBarView)
        
        // Mic Button
        micButton.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        micButton.tintColor = .black
        micButton.addTarget(self, action: #selector(toggleMicrophone), for: .touchUpInside)
        controlBarView.addSubview(micButton)
        
        // End Call Button
        endCallButton.setImage(UIImage(systemName: "phone.down.fill"), for: .normal)
        endCallButton.tintColor = .white
        endCallButton.backgroundColor = .red
        endCallButton.layer.cornerRadius = 25
        endCallButton.addTarget(self, action: #selector(endCall), for: .touchUpInside)
        controlBarView.addSubview(endCallButton)
    }
    
    private func setupConstraints() {
        tableView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.bottom.equalTo(statusView.snp.top)
        }
        
        statusView.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(20)
            make.bottom.equalTo(controlBarView.snp.top).offset(-20)
            make.height.equalTo(30)
        }
        
        controlBarView.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(20)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-40)
            make.height.equalTo(60)
        }
        
        micButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalTo(endCallButton.snp.left).offset(-30)
            make.width.height.equalTo(40)
        }
        
        endCallButton.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(50)
        }
    }
    
    // MARK: - Business Logic
    private func start() {
        isLoading = true
        showLoadingToast()
        
        Task {
            do {
                //0：生成用户token
                try await generateUserToken()
                
                //1：启动rtm
                try await startRTM()
                
                //2：启动RTC
                try await startRTC()
                
                //3：启动ConvoAI组件
                try await startConvoAIAPI()
                
                //4：生成agentToken
                try await generateAgentToken()
                
                //5：启动agent
                try await startAgent()
                
                await MainActor.run {
                    isLoading = false
                    hideLoadingToast()
                }
            } catch {
                await MainActor.run {
                    initializationError = error
                    isLoading = false
                    isError = true
                    hideLoadingToast()
                    showErrorToast(error.localizedDescription)
                    
                    // 2秒后自动退出
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.endCall()
                    }
                }
            }
        }
    }
    
    private func generateUserToken() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            NetworkManager.shared.generateToken(channelName: channel, uid: "\(uid)", types: [.rtc, .rtm]) { token in
                guard let token = token else {
                    continuation.resume(throwing: NSError(domain: "generateUserToken", code: -1, userInfo: [NSLocalizedDescriptionKey: "获取 token 失败，请重试"]))
                    return
                }
                self.token = token
                continuation.resume()
            }
        }
    }
    
    @MainActor
    private func startRTC() async throws {
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
        
        let options = AgoraRtcChannelMediaOptions()
        options.clientRoleType = .broadcaster
        options.publishMicrophoneTrack = true
        options.publishCameraTrack = false
        options.autoSubscribeAudio = true
        options.autoSubscribeVideo = true
        let result = rtcEngine.joinChannel(byToken: token, channelId: channel, uid: UInt(uid), mediaOptions: options)
        if result != 0 {
            throw NSError(domain: "ChatViewController", code: Int(result), userInfo: [NSLocalizedDescriptionKey: "加入 RTC 频道失败，错误码: \(result)"])
        }
        self.rtcEngine = rtcEngine
    }
    
    @MainActor
    private func startRTM() async throws {
        let rtmConfig = AgoraRtmClientConfig(appId: KeyCenter.AG_APP_ID, userId: "\(uid)")
        rtmConfig.areaCode = [.CN, .NA]
        rtmConfig.presenceTimeout = 30
        rtmConfig.heartbeatInterval = 10
        rtmConfig.useStringUserId = true
        let rtmClient = try AgoraRtmClientKit(rtmConfig, delegate: self)
        self.rtmEngine = rtmClient
        
        return try await withCheckedThrowingContinuation { continuation in
            rtmClient.login(token) { res, error in
                if let error = error {
                    continuation.resume(throwing: NSError(domain: "loginRTM", code: -1, userInfo: [NSLocalizedDescriptionKey: "rtm 登录失败: \(error.localizedDescription)"]))
                } else if let _ = res {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(domain: "loginRTM", code: -1, userInfo: [NSLocalizedDescriptionKey: "rtm 登录失败"]))
                }
            }
        }
    }
    
    @MainActor
    private func startConvoAIAPI() async throws {
        guard let rtcEngine = self.rtcEngine else {
            throw NSError(domain: "startConvoAIAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "rtc 为空"])
        }
        
        guard let rtmEngine = self.rtmEngine else {
            throw NSError(domain: "startConvoAIAPI", code: -1, userInfo: [NSLocalizedDescriptionKey: "rtm 为空"])
        }
        
        let config = ConversationalAIAPIConfig(rtcEngine: rtcEngine, rtmEngine: rtmEngine, renderMode: .words, enableLog: true)
        let convoAIAPI = ConversationalAIAPIImpl(config: config)
        convoAIAPI.addHandler(handler: self)
        convoAIAPI.subscribeMessage(channelName: channel) { err in
            if let error = err {
                print("[subscribeMessage] <<<< error: \(error.message)")
            }
        }
        
        self.convoAIAPI = convoAIAPI
    }
    
    private func generateAgentToken() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            NetworkManager.shared.generateToken(channelName: channel, uid: "\(agentUid)", types: [.rtc, .rtm]) { token in
                guard let token = token else {
                    continuation.resume(throwing: NSError(domain: "generateAgentToken", code: -1, userInfo: [NSLocalizedDescriptionKey: "获取 token 失败，请重试"]))
                    return
                }
                self.agentToken = token
                continuation.resume()
            }
        }
    }
    
    private func startAgent() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let parameter: [String: Any] = [
                "name": channel,
                "pipeline_id": KeyCenter.AG_PIPELINE_ID,
                "properties": [
                    "channel": channel,
                    "agent_rtc_uid": "\(agentUid)",
                    "remote_rtc_uids": ["*"],
                    "token": agentToken
                ]
            ]
            AgentManager.startAgent(parameter: parameter) { agentId, error in
                if let error = error {
                    continuation.resume(throwing: NSError(domain: "startAgent", code: -1, userInfo: [NSLocalizedDescriptionKey: error.localizedDescription]))
                    return
                }
                
                if let agentId = agentId {
                    self.agentId = agentId
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(domain: "startAgent", code: -1, userInfo: [NSLocalizedDescriptionKey: "请求失败"]))
                }
            }
        }
    }
    
    @objc private func toggleMicrophone() {
        isMicMuted.toggle()
        let imageName = isMicMuted ? "mic.slash.fill" : "mic.fill"
        micButton.setImage(UIImage(systemName: imageName), for: .normal)
        rtcEngine?.adjustRecordingSignalVolume(isMicMuted ? 0 : 100)
    }
    
    @objc private func endCall() {
        AgentManager.stopAgent(agentId: agentId, completion: nil)
        rtcEngine?.leaveChannel()
        AgoraRtcEngineKit.destroy()
        rtcEngine = nil
        
        rtmEngine?.logout()
        rtmEngine?.destroy()
        rtmEngine = nil
        
        convoAIAPI?.destroy()
        convoAIAPI = nil
        
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - Status View
    private func updateStatusView() {
        statusView.updateState(currentAgentState)
    }
    
    // MARK: - Toast
    private var loadingToast: UIView?
    
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
extension ChatViewController: UITableViewDataSource, UITableViewDelegate {
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
extension ChatViewController: AgoraRtcEngineDelegate {
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        print("[RTC Call Back] didJoinedOfUid uid: \(uid)")
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        print("[RTC Call Back] didOfflineOfUid uid: \(uid)")
    }
}

// MARK: - AgoraRtmClientDelegate
extension ChatViewController: AgoraRtmClientDelegate {
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
extension ChatViewController: ConversationalAIAPIEventHandler {
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
            self.updateStatusView()
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
            
            self.tableView.reloadData()
            
            if !self.transcripts.isEmpty {
                let indexPath = IndexPath(row: self.transcripts.count - 1, section: 0)
                self.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
            }
        }
    }
    
    func onDebugLog(log: String) {
        print(log)
    }
}

// MARK: - TranscriptCell
class TranscriptCell: UITableViewCell {
    private let avatarView = UIView()
    private let avatarLabel = UILabel()
    private let messageLabel = UILabel()
    private let containerView = UIView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        
        containerView.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        containerView.layer.cornerRadius = 8
        contentView.addSubview(containerView)
        
        avatarView.layer.cornerRadius = 16
        containerView.addSubview(avatarView)
        
        avatarLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        avatarLabel.textColor = .white
        avatarLabel.textAlignment = .center
        avatarView.addSubview(avatarLabel)
        
        messageLabel.font = .systemFont(ofSize: 15)
        messageLabel.textColor = .label
        messageLabel.numberOfLines = 0
        containerView.addSubview(messageLabel)
        
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 4, left: 20, bottom: 4, right: 20))
        }
        
        avatarView.snp.makeConstraints { make in
            make.left.top.equalToSuperview().inset(12)
            make.width.height.equalTo(32)
        }
        
        avatarLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        messageLabel.snp.makeConstraints { make in
            make.left.equalTo(avatarView.snp.right).offset(12)
            make.right.top.bottom.equalToSuperview().inset(12)
        }
    }
    
    func configure(with transcript: Transcript) {
        let isAgent = transcript.type == .agent
        avatarView.backgroundColor = isAgent ? .blue : .green
        avatarLabel.text = isAgent ? "AI" : "我"
        messageLabel.text = transcript.text
    }
}
