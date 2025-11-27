//
//  RtcManager.swift
//  VoiceAgent
//
//  Created on 2025
//  Copyright © 2025 Agora. All rights reserved.
//

import Foundation
import AgoraRtcKit

// MARK: - RTC Manager Protocol
protocol RtcManagerProtocol {
    
    /// Creates and initializes an RTC engine instance
    /// - Parameter delegate: The delegate object for the RTC engine to receive callback events
    /// - Returns: The initialized AgoraRtcEngineKit instance
    func createRtcEngine(delegate: AgoraRtcEngineDelegate) -> AgoraRtcEngineKit
    
    /// Joins an RTC channel
    func joinChannel(rtcToken: String, channelName: String, uid: UInt)
    
    /// Leave RTC channel
    func leaveChannel()
    
    /// Renew RTC token
    func renewToken(token: String)
    
    /// Mutes or unmutes the local audio
    /// - Parameter mute: True to mute, false to unmute
    func muteLocalAudio(mute: Bool)
    
    /// Returns the RTC engine instance
    func getRtcEngine() -> AgoraRtcEngineKit
    
    /// Destroys the engine and releases resources
    func destroy()
}

// MARK: - RTC Manager
class RtcManager: NSObject {
    
    // MARK: - Properties
    static let shared = RtcManager()
    
    private var rtcEngine: AgoraRtcEngineKit!
    
    // MARK: - Initialization
    private override init() {
        super.init()
    }
}

// MARK: - RtcManagerProtocol Implementation
extension RtcManager: RtcManagerProtocol {
    
    func createRtcEngine(delegate: AgoraRtcEngineDelegate) -> AgoraRtcEngineKit {
        let config = AgoraRtcEngineConfig()
        config.appId = KeyCenter.AGORA_APP_ID
        config.channelProfile = .liveBroadcasting
        config.audioScenario = .default
        
        rtcEngine = AgoraRtcEngineKit.sharedEngine(with: config, delegate: delegate)
        
        print("[RtcManager] RTC Engine initialized, SDK version: \(AgoraRtcEngineKit.getSdkVersion())")
        return rtcEngine
    }
    
    func joinChannel(rtcToken: String, channelName: String, uid: UInt) {
        rtcEngine.enableVideo()
        
        let cameraConfig = AgoraCameraCapturerConfiguration()
        rtcEngine.setCameraCapturerConfiguration(cameraConfig)
        
        // Audio pre-dump (optional, for debugging)
        rtcEngine.setParameters("{\"che.audio.enable.predump\":{\"enable\":\"true\",\"duration\":\"60\"}}")
        
        let options = AgoraRtcChannelMediaOptions()
        options.clientRoleType = .broadcaster
        options.publishMicrophoneTrack = true
        options.publishCameraTrack = false
        options.autoSubscribeAudio = true
        options.autoSubscribeVideo = true
        
        let result = rtcEngine.joinChannel(byToken: rtcToken, channelId: channelName, uid: uid, mediaOptions: options)
        
        if result == 0 {
            print("[RtcManager] Joining channel: \(channelName), uid: \(uid)")
        } else {
            print("[RtcManager] ❌ Failed to join channel, error code: \(result)")
        }
    }
    
    func muteLocalAudio(mute: Bool) {
        rtcEngine.adjustRecordingSignalVolume(mute ? 0 : 100)
        print("[RtcManager] Local audio \(mute ? "muted" : "unmuted")")
    }
    
    func getRtcEngine() -> AgoraRtcEngineKit {
        return rtcEngine
    }
    
    func leaveChannel() {
        rtcEngine.leaveChannel()
        print("[RtcManager] Left channel")
    }
    
    func renewToken(token: String) {
        rtcEngine.renewToken(token)
        print("[RtcManager] Token renewed")
    }
    
    func destroy() {
        rtcEngine = nil
        AgoraRtcEngineKit.destroy()
        print("[RtcManager] RTC Engine destroyed")
    }
}

