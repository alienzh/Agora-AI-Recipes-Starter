//
//  AgentViewController+SendMessage.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/12/19.
//

import UIKit

extension AgentViewController {
    /// 发送文本消息到 AI Agent
    /// - Parameter text: 要发送的文本内容
    func sendMessage(text: String) {
        guard let convoAIAPI = convoAIAPI, !text.isEmpty else { return }
        
        let message = TextMessage(text: text)
        self.showLoadingToast()
        convoAIAPI.chat(agentUserId: "\(agentUid)", message: message) {[weak self] error in
            self?.hideLoadingToast()
            if let error = error {
                self?.showErrorToast(error.message)
            } else {
                self?.clearInputTextField()
            }
        }
    }
}
