//
//  ConfigBackgroundView.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

import UIKit
import SnapKit

class ConfigBackgroundView: UIView {
    // MARK: - UI Components
    let logoImageView = UIImageView()
    let channelNameTextField = UITextField()
    let startButton = UIButton(type: .system)
    
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
        
        logoImageView.image = UIImage(named: "logo")
        logoImageView.contentMode = .scaleAspectFit
        addSubview(logoImageView)
        
        channelNameTextField.placeholder = "输入频道名称"
        channelNameTextField.borderStyle = .roundedRect
        addSubview(channelNameTextField)
        
        startButton.setTitle("Start", for: .normal)
        startButton.setTitleColor(.white, for: .normal)
        startButton.setTitleColor(.white.withAlphaComponent(0.5), for: .disabled)
        startButton.backgroundColor = .systemBlue.withAlphaComponent(0.4)
        startButton.layer.cornerRadius = 25
        startButton.isEnabled = false
        addSubview(startButton)
    }
    
    private func setupConstraints() {
        channelNameTextField.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.equalTo(250)
            make.height.equalTo(50)
        }
        
        logoImageView.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(channelNameTextField.snp.top).offset(-30)
        }
        
        startButton.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(channelNameTextField.snp.bottom).offset(30)
            make.width.equalTo(250)
            make.height.equalTo(50)
        }
    }
    
    // MARK: - Public Methods
    func updateButtonState(isEnabled: Bool) {
        startButton.isEnabled = isEnabled
        startButton.backgroundColor = isEnabled ? .systemBlue : .systemBlue.withAlphaComponent(0.4)
    }
}

