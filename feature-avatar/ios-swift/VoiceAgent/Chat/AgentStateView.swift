//
//  AgentStateView.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

import UIKit
import SnapKit

class AgentStateView: UIView {
    private let statusLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
        isHidden = true // 初始状态隐藏
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = UIColor.systemGray6
        layer.cornerRadius = 8
        
        statusLabel.textColor = .label
        statusLabel.font = .systemFont(ofSize: 14)
        statusLabel.textAlignment = .center
        addSubview(statusLabel)
    }
    
    private func setupConstraints() {
        statusLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(8)
        }
    }
    
    func updateState(_ state: AgentState) {
        // 不显示未知状态，直接隐藏视图
        if state == .unknown {
            isHidden = true
            return
        }
        
        isHidden = false
        let statusText: String
        switch state {
        case .idle:
            statusText = "空闲中"
        case .silent:
            statusText = "静默中"
        case .listening:
            statusText = "正在聆听"
        case .thinking:
            statusText = "思考中"
        case .speaking:
            statusText = "正在说话"
        case .unknown:
            statusText = "" // 不会执行到这里
        @unknown default:
            statusText = ""
        }
        statusLabel.text = statusText
    }
}
