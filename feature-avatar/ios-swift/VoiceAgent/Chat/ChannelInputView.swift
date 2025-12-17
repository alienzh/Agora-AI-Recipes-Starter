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
    
    // MARK: - Scroll View
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
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
        
        // Setup scroll view
        addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        // Channel name
        channelNameTextField.placeholder = "输入频道名称"
        channelNameTextField.borderStyle = .roundedRect
        channelNameTextField.keyboardType = .default
        channelNameTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        contentView.addSubview(channelNameTextField)
        
        // User UID
        uidTextField.placeholder = "用户UID"
        uidTextField.borderStyle = .roundedRect
        uidTextField.keyboardType = .numberPad
        contentView.addSubview(uidTextField)
        
        // Agent UID
        agentUidTextField.placeholder = "Agent UID"
        agentUidTextField.borderStyle = .roundedRect
        agentUidTextField.keyboardType = .numberPad
        contentView.addSubview(agentUidTextField)
        
        // Avatar UID
        avatarUidTextField.placeholder = "Avatar UID"
        avatarUidTextField.borderStyle = .roundedRect
        avatarUidTextField.keyboardType = .numberPad
        contentView.addSubview(avatarUidTextField)
        
        startButton.setTitle("加入频道", for: .normal)
        startButton.setTitleColor(.white, for: .normal)
        startButton.setTitleColor(.white.withAlphaComponent(0.5), for: .disabled)
        startButton.backgroundColor = .systemBlue.withAlphaComponent(0.4)
        startButton.layer.cornerRadius = 25
        startButton.isEnabled = false
        startButton.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
        contentView.addSubview(startButton)
    }
    
    private func setupConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }
        
        channelNameTextField.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(40)
            make.width.equalTo(280)
            make.height.equalTo(44)
        }
        
        uidTextField.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(channelNameTextField.snp.bottom).offset(16)
            make.width.equalTo(280)
            make.height.equalTo(44)
        }
        
        agentUidTextField.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(uidTextField.snp.bottom).offset(16)
            make.width.equalTo(280)
            make.height.equalTo(44)
        }
        
        avatarUidTextField.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(agentUidTextField.snp.bottom).offset(16)
            make.width.equalTo(280)
            make.height.equalTo(44)
        }
        
        startButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(avatarUidTextField.snp.bottom).offset(30)
            make.width.equalTo(280)
            make.height.equalTo(50)
            make.bottom.equalToSuperview().offset(-40)
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

