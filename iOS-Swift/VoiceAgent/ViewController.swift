//
//  ViewController.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

import UIKit
import SnapKit

class ViewController: UIViewController {
    private let logoImageView = UIImageView()
    private let channelNameTextField = UITextField()
    private let startButton = UIButton(type: .system)
    private let uid = Int.random(in: 1000...9999999)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        title = "VoiceAgent"
        navigationController?.navigationBar.prefersLargeTitles = false
        
        logoImageView.image = UIImage(named: "logo")
        logoImageView.contentMode = .scaleAspectFit
        view.addSubview(logoImageView)
        
        channelNameTextField.placeholder = "输入频道名称"
        channelNameTextField.borderStyle = .roundedRect
        channelNameTextField.addTarget(self, action: #selector(textFieldDidChange), for: .editingChanged)
        view.addSubview(channelNameTextField)
        
        startButton.setTitle("Start", for: .normal)
        startButton.setTitleColor(.white, for: .normal)
        startButton.setTitleColor(.white.withAlphaComponent(0.5), for: .disabled)
        startButton.backgroundColor = .systemBlue.withAlphaComponent(0.4)
        startButton.layer.cornerRadius = 25
        startButton.isEnabled = false
        startButton.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
        view.addSubview(startButton)
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
    
    @objc private func textFieldDidChange() {
        updateButtonState()
    }
    
    @objc private func startButtonTapped() {
        let channelName = channelNameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !channelName.isEmpty else { return }
        
        let chatViewController = ChatViewController(uid: uid, channel: channelName)
        navigationController?.pushViewController(chatViewController, animated: true)
    }
    
    private func updateButtonState() {
        let channelName = channelNameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let isValid = !channelName.isEmpty
        startButton.isEnabled = isValid
        startButton.backgroundColor = isValid ? .systemBlue : .systemBlue.withAlphaComponent(0.4)
    }
}

