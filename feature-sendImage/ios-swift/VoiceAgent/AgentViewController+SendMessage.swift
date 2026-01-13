//
//  AgentViewController+SendMessage.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/12/19.
//

import UIKit

extension AgentViewController {
    /// 发送图片地址到 AI Agent
    /// - Parameter text: 要发送的图片地址
    func sendImage(imageUrl: String) {
        guard let convoAIAPI = convoAIAPI, !imageUrl.isEmpty else { return }
        let uuid = UUID().uuidString
        let message = ImageMessage(uuid: uuid, url: imageUrl)
        
        // 添加图片消息到对话列表
        let imageItem = ImageMessageItem(uuid: uuid, url: imageUrl, status: .sending)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.transcripts.append(.image(imageItem))
            self.chatBackgroundView.tableView.reloadData()
            
            if !self.transcripts.isEmpty {
                let indexPath = IndexPath(row: self.transcripts.count - 1, section: 0)
                self.chatBackgroundView.tableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
            }
        }

        self.showLoadingToast()
        convoAIAPI.chat(agentUserId: "\(agentUid)", message: message) {[weak self] error in
            self?.hideLoadingToast()
            if let error = error {
                self?.showErrorToast(error.message)
            }
        }
    }
}
