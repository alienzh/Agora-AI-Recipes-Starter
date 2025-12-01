//
//  AgentViewModel.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

import Foundation
import SwiftUI
import AgoraRtcKit
import AgoraRtmKit

class AgentViewModel: NSObject, ObservableObject {
    // MARK: - UI State
    @Published var channelName: String = ""
    @Published var showConfigView: Bool = true
    @Published var showChatView: Bool = false
    
    // MARK: - Connection State
    @Published var isLoading: Bool = false
    @Published var isError: Bool = false
    @Published var initializationError: Error?
    @Published var transcripts: [Transcript] = []
    @Published var isMicMuted: Bool = false
    
    // MARK: - Properties
    private let uid = Int.random(in: 1000...9999999)
    private var channel: String = ""
    private var token: String = ""
    private var agentToken: String = ""
    private var agentId: String = ""
    private let agentUid = Int.random(in: 10000000...99999999)
    
    // MARK: - Agora Components
    private var rtcEngine: AgoraRtcEngineKit?
    private var rtmEngine: AgoraRtmClientKit?
    private var convoAIAPI: ConversationalAIAPI?
    
    override init() {
        super.init()
        print("[AgentViewModel] AgentViewModel initialized")
        initializeEngines()
    }
    
    // MARK: - Engine Initialization
    private func initializeEngines() {
        initializeRTM()
        initializeRTC()
        initializeConvoAIAPI()
    }
    
    private func initializeRTM() {
        let rtmConfig = AgoraRtmClientConfig(appId: KeyCenter.AG_APP_ID, userId: "\(uid)")
        rtmConfig.areaCode = [.CN, .NA]
        rtmConfig.presenceTimeout = 30
        rtmConfig.heartbeatInterval = 10
        rtmConfig.useStringUserId = true
        
        do {
            let rtmClient = try AgoraRtmClientKit(rtmConfig, delegate: self)
            self.rtmEngine = rtmClient
            print("[Engine Init] RTM initialized successfully")
        } catch {
            print("[Engine Init] RTM initialization failed: \(error)")
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
    func startConnection() {
        let trimmedChannelName = channelName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedChannelName.isEmpty else { return }
        
        self.channel = trimmedChannelName
        isLoading = true
        
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
                
                // 5. 生成agentToken
                try await generateAgentToken()
                
                // 6. 启动agent
                try await startAgent()
                
                await MainActor.run {
                    isLoading = false
                    switchToChatView()
                }
            } catch {
                await MainActor.run {
                    initializationError = error
                    isLoading = false
                    isError = true
                }
            }
        }
    }
    
    // MARK: - Token Generation
    private func generateUserToken() async throws {
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume(throwing: NSError(domain: "generateUserToken", code: -1, userInfo: [NSLocalizedDescriptionKey: "self 被释放"]))
                return
            }
            
            NetworkManager.shared.generateToken(channelName: self.channel, uid: "\(self.uid)", types: [.rtc, .rtm]) { token in
                guard let token = token else {
                    continuation.resume(throwing: NSError(domain: "generateUserToken", code: -1, userInfo: [NSLocalizedDescriptionKey: "获取 token 失败，请重试"]))
                    return
                }
                self.token = token
                continuation.resume()
            }
        }
    }
    
    private func generateAgentToken() async throws {
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume(throwing: NSError(domain: "generateAgentToken", code: -1, userInfo: [NSLocalizedDescriptionKey: "self 被释放"]))
                return
            }
            
            NetworkManager.shared.generateToken(channelName: self.channel, uid: "\(self.agentUid)", types: [.rtc, .rtm]) { token in
                guard let token = token else {
                    continuation.resume(throwing: NSError(domain: "generateAgentToken", code: -1, userInfo: [NSLocalizedDescriptionKey: "获取 token 失败，请重试"]))
                    return
                }
                self.agentToken = token
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
        
        return try await withCheckedThrowingContinuation { continuation in
            rtmEngine.login(token) { res, error in
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
    private func joinRTCChannel() async throws {
        guard let rtcEngine = self.rtcEngine else {
            throw NSError(domain: "joinRTCChannel", code: -1, userInfo: [NSLocalizedDescriptionKey: "RTC engine 未初始化"])
        }
        
        let options = AgoraRtcChannelMediaOptions()
        options.clientRoleType = .broadcaster
        options.publishMicrophoneTrack = true
        options.publishCameraTrack = false
        options.autoSubscribeAudio = true
        options.autoSubscribeVideo = true
        let result = rtcEngine.joinChannel(byToken: token, channelId: channel, uid: UInt(uid), mediaOptions: options)
        if result != 0 {
            throw NSError(domain: "joinRTCChannel", code: Int(result), userInfo: [NSLocalizedDescriptionKey: "加入 RTC 频道失败，错误码: \(result)"])
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
    
    // MARK: - Agent Management
    private func startAgent() async throws {
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self = self else {
                continuation.resume(throwing: NSError(domain: "startAgent", code: -1, userInfo: [NSLocalizedDescriptionKey: "self 被释放"]))
                return
            }
            
            let parameter: [String: Any] = [
                "name": self.channel,
                "pipeline_id": KeyCenter.AG_PIPELINE_ID,
                "properties": [
                    "channel": self.channel,
                    "agent_rtc_uid": "\(agentUid)",
                    "remote_rtc_uids": ["*"],
                    "token": self.agentToken
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
    
    // MARK: - View Management
    private func switchToChatView() {
        showConfigView = false
        showChatView = true
    }
    
    func switchToConfigView() {
        showChatView = false
        showConfigView = true
    }
    
    // MARK: - Actions
    func toggleMicrophone() {
        isMicMuted.toggle()
        rtcEngine?.adjustRecordingSignalVolume(isMicMuted ? 0 : 100)
    }
    
    func endCall() {
        AgentManager.stopAgent(agentId: agentId, completion: nil)
        resetConnectionState()
    }
    
    private func resetConnectionState() {
        rtcEngine?.leaveChannel()
        rtmEngine?.logout()
        convoAIAPI?.unsubscribeMessage(channelName: channel, completion: { error in
            
        })
        
        switchToConfigView()
        
        transcripts.removeAll()
        isMicMuted = false
        agentId = ""
        token = ""
        agentToken = ""
    }
}

// MARK: - AgoraRtcEngineDelegate
extension AgentViewModel: AgoraRtcEngineDelegate {
    func rtcEngine(_ engine: AgoraRtcEngineKit, didJoinedOfUid uid: UInt, elapsed: Int) {
        print("[RTC Call Back] didJoinedOfUid uid: \(uid)")
    }
    
    func rtcEngine(_ engine: AgoraRtcEngineKit, didOfflineOfUid uid: UInt, reason: AgoraUserOfflineReason) {
        print("[RTC Call Back] didOfflineOfUid uid: \(uid)")
    }
}

// MARK: - AgoraRtmClientDelegate
extension AgentViewModel: AgoraRtmClientDelegate {
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
extension AgentViewModel: ConversationalAIAPIEventHandler {
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
        }
    }
    
    func onDebugLog(log: String) {
        print(log)
    }
}

