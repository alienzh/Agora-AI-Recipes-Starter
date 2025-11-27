//
//  RtmManager.swift
//  VoiceAgent
//
//  Created on 2025
//  Copyright © 2025 Agora. All rights reserved.
//

import Foundation
import AgoraRtmKit

// MARK: - RTM Manager Protocol
protocol RtmManagerDelegate: AnyObject {
    func rtmManager(_ manager: RtmManager, didLoginSuccess userId: String)
    func rtmManager(_ manager: RtmManager, didLoginFailed error: Error?)
    func rtmManager(_ manager: RtmManager, didReceiveMessage message: String, from userId: String)
    func rtmManager(_ manager: RtmManager, connectionStateChanged state: Int)
}

// MARK: - RTM Manager
/// Manages Agora RTM (Real-Time Messaging) client lifecycle and operations
class RtmManager: NSObject {
    
    // MARK: - Properties
    static let shared = RtmManager()
    
    private var rtmClient: AgoraRtmClientKit?
    weak var delegate: RtmManagerDelegate?
    
    private var isLoggedIn: Bool = false
    private var currentUserId: String?
    
    // MARK: - Initialization
    private override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Initialize RTM Client
    /// - Parameter userId: User ID string
    func initializeClient(userId: String) {
        do {
            let config = AgoraRtmClientConfig(appId: KeyCenter.AGORA_APP_ID, userId: userId)
            rtmClient = try AgoraRtmClientKit(config, delegate: self)
            currentUserId = userId
            print("[RtmManager] RTM Client initialized for user: \(userId)")
        } catch {
            print("[RtmManager] Failed to initialize RTM Client: \(error)")
        }
    }
    
    /// Login to RTM
    /// - Parameter token: RTM token
    func login(token: String?, completion: @escaping (Error?) -> Void) {
        guard let client = rtmClient else {
            let error = NSError(domain: "RtmManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "RTM Client not initialized"])
            completion(error)
            return
        }
        
        client.login(token) { response, error in
            if let error = error {
                print("[RtmManager] Login failed: \(error.localizedDescription)")
                self.isLoggedIn = false
                self.delegate?.rtmManager(self, didLoginFailed: error)
                completion(error)
            } else {
                print("[RtmManager] Login successful")
                self.isLoggedIn = true
                self.delegate?.rtmManager(self, didLoginSuccess: self.currentUserId ?? "")
                completion(nil)
            }
        }
    }
    
    /// Logout from RTM
    func logout() {
        guard let client = rtmClient else { return }
        
        client.logout { response, error in
            if let error = error {
                print("[RtmManager] Logout error: \(error.localizedDescription)")
            } else {
                print("[RtmManager] Logout successful")
            }
        }
        
        isLoggedIn = false
        currentUserId = nil
    }
    
    /// Subscribe to a channel
    /// - Parameters:
    ///   - channelName: Channel name to subscribe
    ///   - completion: Completion handler
    func subscribe(channelName: String, completion: @escaping (Error?) -> Void) {
        guard let client = rtmClient else {
            let error = NSError(domain: "RtmManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "RTM Client not initialized"])
            completion(error)
            return
        }
        
        let subscribeOptions = AgoraRtmSubscribeOptions()
        subscribeOptions.features = [.message, .presence]
        
        client.subscribe(channelName: channelName, option: subscribeOptions) { response, error in
            if let error = error {
                print("[RtmManager] Subscribe to channel '\(channelName)' failed: \(error.localizedDescription)")
                completion(error)
            } else {
                print("[RtmManager] Subscribed to channel: \(channelName)")
                completion(nil)
            }
        }
    }
    
    /// Unsubscribe from a channel
    /// - Parameters:
    ///   - channelName: Channel name to unsubscribe
    ///   - completion: Completion handler
    func unsubscribe(channelName: String, completion: @escaping (Error?) -> Void) {
        guard let client = rtmClient else {
            let error = NSError(domain: "RtmManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "RTM Client not initialized"])
            completion(error)
            return
        }
        
        client.unsubscribe(channelName) { response, error in
            if let error = error {
                print("[RtmManager] Unsubscribe from channel '\(channelName)' failed: \(error.localizedDescription)")
                completion(error)
            } else {
                print("[RtmManager] Unsubscribed from channel: \(channelName)")
                completion(nil)
            }
        }
    }
    
    /// Publish message to a channel
    /// - Parameters:
    ///   - channelName: Channel name
    ///   - message: Message string
    ///   - completion: Completion handler
    func publish(channelName: String, message: String, completion: @escaping (Error?) -> Void) {
        guard let client = rtmClient else {
            let error = NSError(domain: "RtmManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "RTM Client not initialized"])
            completion(error)
            return
        }
        
        let publishOptions = AgoraRtmPublishOptions()
        publishOptions.channelType = .message
        
        client.publish(channelName: channelName, message: message, option: publishOptions) { response, error in
            if let error = error {
                print("[RtmManager] Publish message failed: \(error.localizedDescription)")
                completion(error)
            } else {
                print("[RtmManager] Message published to channel: \(channelName)")
                completion(nil)
            }
        }
    }
    
    /// Get RTM Client instance
    func getRtmClient() -> AgoraRtmClientKit? {
        return rtmClient
    }
    
    /// Destroy RTM Client
    func destroy() {
        logout()
        rtmClient = nil
        print("[RtmManager] RTM Client destroyed")
    }
}

// MARK: - AgoraRtmClientDelegate
extension RtmManager: AgoraRtmClientDelegate {
    
    func rtmKit(_ rtmClient: AgoraRtmClientKit, didReceiveMessageEvent event: AgoraRtmMessageEvent) {
        let message = event.message.stringData ?? ""
        let publisher = event.publisher
        
        print("[RtmManager] Received message from \(publisher): \(message)")
        delegate?.rtmManager(self, didReceiveMessage: message, from: publisher)
    }
    
    func rtmKit(_ rtmClient: AgoraRtmClientKit, channel channelName: String, connectionChangedToState state: AgoraRtmClientConnectionState, reason: AgoraRtmClientConnectionChangeReason) {
        print("[RtmManager] Connection state changed: \(state.rawValue), reason: \(reason.rawValue)")
        delegate?.rtmManager(self, connectionStateChanged: state.rawValue)
    }
}

