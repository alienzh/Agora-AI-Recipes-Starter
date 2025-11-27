//
//  AgentManager.swift
//  VoiceAgent
//
//  Created on 2025
//  Copyright © 2025 Agora. All rights reserved.
//

import Foundation

// MARK: - Agent Starter
/// Unified interface for starting/stopping AI agents
/// Supports both local server and Agora API
class AgentManager {
    
    // MARK: - Properties
    private static let baseURL = KeyCenter.AGENT_SERVER_BASE_URL
    
    // MARK: - Public Methods
    
    /// Start an agent
    /// - Parameters:
    ///   - channelName: Channel name for the agent
    ///   - agentRtcUid: Agent RTC UID (optional)
    ///   - token: Agent token (required)
    ///   - completion: Completion handler with agentId or error
    static func startAgent(
        channelName: String,
        agentRtcUid: String,
        token: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let projectId = KeyCenter.AGORA_APP_ID
        let urlString = "\(baseURL)/\(projectId)/join/"
        
        // Build request payload
        let params: [String: Any] = [
            "name": channelName,
            "pipeline_id": KeyCenter.PIPELINE_ID,
            "properties": [
                "channel": channelName,
                "agent_rtc_uid": agentRtcUid,
                "remote_rtc_uids": ["*"],
                "token": token
            ]
        ]
        
        // Prepare headers with Authorization
        let headers = [
            "Authorization": HTTPClient.generateBasicAuth(
                username: KeyCenter.REST_KEY,
                password: KeyCenter.REST_SECRET
            )
        ]
        
        // Use HTTPClient for unified request handling
        HTTPClient.post(
            urlString: urlString,
            params: params,
            headers: headers
        ) { result in
            switch result {
            case .success(let json):
                if let agentId = json["agent_id"] as? String {
                    print("[AgentStarter] Agent started successfully, agentId: \(agentId)")
                    completion(.success(agentId))
                } else {
                    let error = NSError(
                        domain: "AgentStarter",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to parse agentId"]
                    )
                    completion(.failure(error))
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Stop an agent
    /// - Parameters:
    ///   - agentId: Agent ID to stop
    ///   - completion: Completion handler
    static func stopAgent(
        agentId: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let projectId = KeyCenter.AGORA_APP_ID
        let urlString = "\(baseURL)/\(projectId)/agents/\(agentId)/leave"
        
        // Prepare headers with Authorization
        let headers = [
            "Authorization": HTTPClient.generateBasicAuth(
                username: KeyCenter.REST_KEY,
                password: KeyCenter.REST_SECRET
            )
        ]
        
        // Use HTTPClient for unified request handling (POST with empty body)
        HTTPClient.post(
            urlString: urlString,
            params: nil,
            headers: headers
        ) { result in
            switch result {
            case .success:
                print("[AgentStarter] Agent stopped successfully")
                completion(.success(()))
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Check server health
    /// - Parameter completion: Completion handler
    static func checkServerHealth(completion: @escaping (Bool) -> Void) {
        // Health check only for local server
        guard baseURL.starts(with: "http://") else {
            // For Agora API, assume healthy
            completion(true)
            return
        }
        
        let urlString = "\(baseURL)/health"
        
        // Use HTTPClient for unified request handling
        HTTPClient.get(urlString: urlString) { result in
            switch result {
            case .success:
                completion(true)
            case .failure:
                completion(false)
            }
        }
    }
}

