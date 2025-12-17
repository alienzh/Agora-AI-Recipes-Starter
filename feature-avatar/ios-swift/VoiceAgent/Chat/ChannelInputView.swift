//
//  ChannelInputView.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

import UIKit
import SnapKit

/// Channel input data model
struct ChannelInputData {
    let channelName: String
    let userId: Int?
    let agentUid: Int?
    let avatarUid: Int?
}

/// Callback closure type
typealias ChannelInputCallback = (ChannelInputData) -> Void

class ChannelInputView: UIView {
    // MARK: - UI Components
    private let channelNameTextField = UITextField()
    private let uidTextField = UITextField()
    private let agentUidTextField = UITextField()
    private let avatarUidTextField = UITextField()
    private let startButton = UIButton(type: .system)
    
    // MARK: - Callback
    var onJoinChannelTapped: ChannelInputCallback?
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        backgroundColor = .systemBackground
        
        // Channel name
        channelNameTextField.placeholder = "输入频道名称"
        channelNameTextField.borderStyle = .roundedRect
        channelNameTextField.keyboardType = .default
        channelNameTextField.backgroundColor = .white
        channelNameTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        addSubview(channelNameTextField)
        
        // User UID
        uidTextField.placeholder = "用户UID"
        uidTextField.borderStyle = .roundedRect
        uidTextField.keyboardType = .numberPad
        uidTextField.backgroundColor = .white
        addSubview(uidTextField)
        
        // Agent UID
        agentUidTextField.placeholder = "Agent UID"
        agentUidTextField.borderStyle = .roundedRect
        agentUidTextField.keyboardType = .numberPad
        agentUidTextField.backgroundColor = .white
        addSubview(agentUidTextField)
        
        // Avatar UID
        avatarUidTextField.placeholder = "Avatar UID"
        avatarUidTextField.borderStyle = .roundedRect
        avatarUidTextField.keyboardType = .numberPad
        avatarUidTextField.backgroundColor = .white
        addSubview(avatarUidTextField)
        
        startButton.setTitle("加入频道", for: .normal)
        startButton.setTitleColor(.white, for: .normal)
        startButton.setTitleColor(.white.withAlphaComponent(0.5), for: .disabled)
        startButton.backgroundColor = .systemBlue
        startButton.layer.cornerRadius = 8
        startButton.isEnabled = false
        startButton.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
        addSubview(startButton)
        
        // Set default values
        channelNameTextField.text = "channel_avatar_001"
        uidTextField.text = "1001"
        agentUidTextField.text = "2001"
        avatarUidTextField.text = "3001"
        updateButtonState(isEnabled: true)
    }
    
    private func setupConstraints() {
        channelNameTextField.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(12)
            make.width.equalTo(240)
            make.height.equalTo(32)
        }
        
        uidTextField.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(channelNameTextField.snp.bottom).offset(6)
            make.width.equalTo(240)
            make.height.equalTo(32)
        }
        
        agentUidTextField.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(uidTextField.snp.bottom).offset(6)
            make.width.equalTo(240)
            make.height.equalTo(32)
        }
        
        avatarUidTextField.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(agentUidTextField.snp.bottom).offset(6)
            make.width.equalTo(240)
            make.height.equalTo(32)
        }
        
        startButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(avatarUidTextField.snp.bottom).offset(12)
            make.width.equalTo(240)
            make.height.equalTo(36)
            make.bottom.equalToSuperview().offset(-12)
        }
    }
    
    // MARK: - Actions
    @objc private func textFieldDidChange() {
        let channelName = channelNameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let isValid = !channelName.isEmpty
        updateButtonState(isEnabled: isValid)
    }
    
    @objc private func startButtonTapped() {
        let channelName = channelNameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let userIdText = uidTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let agentUidText = agentUidTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let avatarUidText = avatarUidTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let userId = userIdText?.isEmpty == false ? Int(userIdText!) : nil
        let agentUid = agentUidText?.isEmpty == false ? Int(agentUidText!) : nil
        let avatarUid = avatarUidText?.isEmpty == false ? Int(avatarUidText!) : nil
        
        let inputData = ChannelInputData(
            channelName: channelName,
            userId: userId,
            agentUid: agentUid,
            avatarUid: avatarUid
        )
        
        onJoinChannelTapped?(inputData)
    }
    
    // MARK: - Public Methods
    func updateButtonState(isEnabled: Bool) {
        startButton.isEnabled = isEnabled
        startButton.backgroundColor = isEnabled ? .systemBlue : .systemBlue.withAlphaComponent(0.4)
    }
    
    /// Load saved channel name and fill input field
    func loadSavedChannelName(_ channelName: String?) {
        if let channelName = channelName, !channelName.isEmpty {
            channelNameTextField.text = channelName
        }
    }
    
    /// Load saved UIDs and fill input fields
    func loadSavedUIDs(userId: Int?, agentUid: Int?, avatarUid: Int?) {
        if let userId = userId, userId > 0 {
            uidTextField.text = "\(userId)"
        }
        if let agentUid = agentUid, agentUid > 0 {
            agentUidTextField.text = "\(agentUid)"
        }
        if let avatarUid = avatarUid, avatarUid > 0 {
            avatarUidTextField.text = "\(avatarUid)"
        }
    }
}

