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
    private let channelNameLabel = UILabel()
    private let channelNameTextField = UITextField()
    private let uidLabel = UILabel()
    private let uidTextField = UITextField()
    private let agentUidLabel = UILabel()
    private let agentUidTextField = UITextField()
    private let avatarUidLabel = UILabel()
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
        
        // Channel Name Label
        channelNameLabel.text = "频道名称"
        channelNameLabel.font = .systemFont(ofSize: 11)
        channelNameLabel.textColor = .systemGray
        addSubview(channelNameLabel)
        
        // Channel name
        channelNameTextField.placeholder = "输入频道名称"
        channelNameTextField.borderStyle = .roundedRect
        channelNameTextField.keyboardType = .default
        channelNameTextField.backgroundColor = .white
        channelNameTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        addSubview(channelNameTextField)
        
        // User UID Label (Read-only)
        uidLabel.text = "本地用户 UID"
        uidLabel.font = .systemFont(ofSize: 11)
        uidLabel.textColor = .systemGray
        addSubview(uidLabel)
        
        // User UID (Read-only)
        uidTextField.placeholder = "本地用户UID"
        uidTextField.borderStyle = .roundedRect
        uidTextField.keyboardType = .numberPad
        uidTextField.backgroundColor = UIColor(white: 0.95, alpha: 1.0)  // Gray background for read-only
        uidTextField.isUserInteractionEnabled = false  // Read-only
        addSubview(uidTextField)
        
        // Agent UID Label
        agentUidLabel.text = "Agent UID"
        agentUidLabel.font = .systemFont(ofSize: 11)
        agentUidLabel.textColor = .systemGray
        addSubview(agentUidLabel)
        
        // Agent UID
        agentUidTextField.placeholder = "Agent UID"
        agentUidTextField.borderStyle = .roundedRect
        agentUidTextField.keyboardType = .numberPad
        agentUidTextField.backgroundColor = .white
        addSubview(agentUidTextField)
        
        // Avatar UID Label
        avatarUidLabel.text = "Avatar UID"
        avatarUidLabel.font = .systemFont(ofSize: 11)
        avatarUidLabel.textColor = .systemGray
        addSubview(avatarUidLabel)
        
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
        
        // Note: Default values will be set via setDefaultValues() method
    }
    
    private func setupConstraints() {
        channelNameLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(12)
            make.width.equalTo(240)
        }
        
        channelNameTextField.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(channelNameLabel.snp.bottom).offset(3)
            make.width.equalTo(240)
            make.height.equalTo(32)
        }
        
        uidLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(channelNameTextField.snp.bottom).offset(10)
            make.width.equalTo(240)
        }
        
        uidTextField.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(uidLabel.snp.bottom).offset(3)
            make.width.equalTo(240)
            make.height.equalTo(32)
        }
        
        agentUidLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(uidTextField.snp.bottom).offset(10)
            make.width.equalTo(240)
        }
        
        agentUidTextField.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(agentUidLabel.snp.bottom).offset(3)
            make.width.equalTo(240)
            make.height.equalTo(32)
        }
        
        avatarUidLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(agentUidTextField.snp.bottom).offset(10)
            make.width.equalTo(240)
        }
        
        avatarUidTextField.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(avatarUidLabel.snp.bottom).offset(3)
            make.width.equalTo(240)
            make.height.equalTo(32)
        }
        
        startButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(avatarUidTextField.snp.bottom).offset(16)
            make.width.equalTo(240)
            make.height.equalTo(40)
            make.bottom.equalToSuperview().offset(-20)  // Define view height, leave space for keyboard
        }
    }
    
    // MARK: - Touch Handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Dismiss keyboard when tapping outside text fields
        endEditing(true)
    }
    
    // MARK: - Actions
    @objc private func textFieldDidChange() {
        let channelName = channelNameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let isValid = !channelName.isEmpty
        updateButtonState(isEnabled: isValid)
    }
    
    @objc private func startButtonTapped() {
        let channelName = channelNameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let userIdText = uidTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)  // Read-only
        let agentUidText = agentUidTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)  // Editable
        let avatarUidText = avatarUidTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)  // Editable
        
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
    
    /// Set default values for input fields
    /// Should be called from ViewController with values from constants
    ///
    /// Note: Only userId is read-only to ensure consistency with RTM client
    /// initialization and token generation. agentUid and avatarUid are editable.
    func setDefaultValues(channelName: String, userId: Int, agentUid: Int, avatarUid: Int) {
        channelNameTextField.text = channelName
        // Set userId (read-only)
        uidTextField.text = "\(userId)"
        // Set default values for editable fields
        agentUidTextField.text = "\(agentUid)"
        avatarUidTextField.text = "\(avatarUid)"
        updateButtonState(isEnabled: !channelName.isEmpty)
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

