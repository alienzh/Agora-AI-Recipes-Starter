//
//  ChatBackgroundView.swift
//  VoiceAgent
//
//  Created by qinhui on 2025/11/17.
//

import UIKit
import SnapKit

class ChatBackgroundView: UIView {
    // MARK: - UI Components
    let tableView = UITableView()
    let statusView = AgentStateView()
    private let inputContainerView = UIView()
    let inputTextField = UITextField()
    let sendButton = UIButton(type: .system)
    private let controlBarView = UIView()
    let micButton = UIButton(type: .system)
    let endCallButton = UIButton(type: .system)
    
    // MARK: - Callbacks
    var onSendButtonTapped: (() -> Void)?
    
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
        
        // TableView for transcripts
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.register(TranscriptCell.self, forCellReuseIdentifier: "TranscriptCell")
        addSubview(tableView)
        
        // Status View
        addSubview(statusView)
        
        // Input Container View
        inputContainerView.backgroundColor = .white
        inputContainerView.layer.cornerRadius = 8
        inputContainerView.layer.borderWidth = 1
        inputContainerView.layer.borderColor = UIColor.separator.cgColor
        addSubview(inputContainerView)
        
        // Input TextField
        inputTextField.placeholder = "输入消息..."
        inputTextField.borderStyle = .none
        inputTextField.font = .systemFont(ofSize: 15)
        inputTextField.backgroundColor = .clear
        inputContainerView.addSubview(inputTextField)
        
        // Send Button
        sendButton.setTitle("发送", for: .normal)
        sendButton.setTitleColor(.systemBlue, for: .normal)
        sendButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        sendButton.addTarget(self, action: #selector(sendButtonTapped), for: .touchUpInside)
        inputContainerView.addSubview(sendButton)
        
        // Control Bar
        controlBarView.backgroundColor = .white
        controlBarView.layer.cornerRadius = 16
        addSubview(controlBarView)
        
        // Mic Button
        micButton.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        micButton.tintColor = .black
        controlBarView.addSubview(micButton)
        
        // End Call Button
        endCallButton.setImage(UIImage(systemName: "phone.down.fill"), for: .normal)
        endCallButton.tintColor = .white
        endCallButton.backgroundColor = .red
        endCallButton.layer.cornerRadius = 25
        controlBarView.addSubview(endCallButton)
    }
    
    private func setupConstraints() {
        tableView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.bottom.equalTo(statusView.snp.top)
        }
        
        statusView.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(20)
            make.bottom.equalTo(inputContainerView.snp.top).offset(-12)
            make.height.equalTo(30)
        }
        
        inputContainerView.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(20)
            make.bottom.equalTo(controlBarView.snp.top).offset(-12)
            make.height.equalTo(44)
        }
        
        inputTextField.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(12)
            make.top.bottom.equalToSuperview()
            make.right.equalTo(sendButton.snp.left).offset(-8)
        }
        
        sendButton.snp.makeConstraints { make in
            make.right.equalToSuperview().inset(12)
            make.centerY.equalToSuperview()
            make.width.equalTo(50)
        }
        
        controlBarView.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(20)
            make.bottom.equalTo(safeAreaLayoutGuide).offset(-40)
            make.height.equalTo(60)
        }
        
        micButton.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.right.equalTo(endCallButton.snp.left).offset(-30)
            make.width.height.equalTo(40)
        }
        
        endCallButton.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(50)
        }
    }
    
    // MARK: - Public Methods
    func updateMicButtonState(isMuted: Bool) {
        let imageName = isMuted ? "mic.slash.fill" : "mic.fill"
        micButton.setImage(UIImage(systemName: imageName), for: .normal)
    }
    
    func updateStatusView(state: AgentState) {
        statusView.updateState(state)
    }
    
    // MARK: - Actions
    @objc private func sendButtonTapped() {
        onSendButtonTapped?()
    }
}

// MARK: - TranscriptCell
class TranscriptCell: UITableViewCell {
    private let avatarView = UIView()
    private let avatarLabel = UILabel()
    private let messageLabel = UILabel()
    private let containerView = UIView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        selectionStyle = .none
        backgroundColor = .clear
        
        containerView.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        containerView.layer.cornerRadius = 8
        contentView.addSubview(containerView)
        
        avatarView.layer.cornerRadius = 16
        containerView.addSubview(avatarView)
        
        avatarLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        avatarLabel.textColor = .white
        avatarLabel.textAlignment = .center
        avatarView.addSubview(avatarLabel)
        
        messageLabel.font = .systemFont(ofSize: 15)
        messageLabel.textColor = .label
        messageLabel.numberOfLines = 0
        containerView.addSubview(messageLabel)
        
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 4, left: 20, bottom: 4, right: 20))
        }
        
        avatarView.snp.makeConstraints { make in
            make.left.top.equalToSuperview().inset(12)
            make.width.height.equalTo(32)
        }
        
        avatarLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        messageLabel.snp.makeConstraints { make in
            make.left.equalTo(avatarView.snp.right).offset(12)
            make.right.top.bottom.equalToSuperview().inset(12)
        }
    }
    
    func configure(with transcript: Transcript) {
        let isAgent = transcript.type == .agent
        avatarView.backgroundColor = isAgent ? .blue : .green
        avatarLabel.text = isAgent ? "AI" : "我"
        messageLabel.text = transcript.text
    }
}
