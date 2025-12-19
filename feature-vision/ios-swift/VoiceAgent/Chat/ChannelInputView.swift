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
}

/// Callback closure type
typealias ChannelInputCallback = (ChannelInputData) -> Void

class ChannelInputView: UIView {
    // MARK: - UI Components
    private let channelNameLabel = UILabel()
    private let channelNameTextField = UITextField()
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
        backgroundColor = .white
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
        
        startButton.setTitle("加入频道", for: .normal)
        startButton.setTitleColor(.white, for: .normal)
        startButton.setTitleColor(.white.withAlphaComponent(0.5), for: .disabled)
        startButton.backgroundColor = .systemBlue
        startButton.layer.cornerRadius = 8
        startButton.isEnabled = false
        startButton.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
        addSubview(startButton)
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
        
        startButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(channelNameTextField.snp.bottom).offset(16)
            make.width.equalTo(240)
            make.height.equalTo(40)
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
        
        let inputData = ChannelInputData(channelName: channelName)
        
        onJoinChannelTapped?(inputData)
    }
    
    // MARK: - Public Methods
    func updateButtonState(isEnabled: Bool) {
        startButton.isEnabled = isEnabled
        startButton.backgroundColor = isEnabled ? .systemBlue : .systemBlue.withAlphaComponent(0.4)
    }
    
    /// Set default channel name
    /// Should be called from ViewController with value from constants
    func setDefaultValues(channelName: String) {
        channelNameTextField.text = channelName
        updateButtonState(isEnabled: !channelName.isEmpty)
    }
    
    /// Load saved channel name and fill input field
    func loadSavedChannelName(_ channelName: String?) {
        if let channelName = channelName, !channelName.isEmpty {
            channelNameTextField.text = channelName
        }
    }
}

