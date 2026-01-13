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
    var onSendImageButtonTapped: (() -> Void)?
    
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
        inputTextField.placeholder = "请输入图片地址"
        inputTextField.text = "http://e.hiphotos.baidu.com/image/pic/item/a1ec08fa513d2697e542494057fbb2fb4316d81e.jpg"
        inputTextField.borderStyle = .none
        inputTextField.font = .systemFont(ofSize: 15)
        inputTextField.backgroundColor = .clear
        inputContainerView.addSubview(inputTextField)
        
        // Send Button
        sendButton.setTitle("发送图片", for: .normal)
        sendButton.setTitleColor(.systemBlue, for: .normal)
        sendButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        sendButton.addTarget(self, action: #selector(sendImageButtonTapped), for: .touchUpInside)
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
            make.width.greaterThanOrEqualTo(90)
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
    
    func resetInputTextField() {
        inputTextField.text = "http://e.hiphotos.baidu.com/image/pic/item/a1ec08fa513d2697e542494057fbb2fb4316d81e.jpg"
    }
    
    // MARK: - Actions
    @objc private func sendImageButtonTapped() {
        onSendImageButtonTapped?()
    }
}

// MARK: - TranscriptCell
class TranscriptCell: UITableViewCell {
    private let avatarView = UIView()
    private let avatarLabel = UILabel()
    private let messageLabel = UILabel()
    private let messageImageView = UIImageView()
    private let statusLabel = UILabel()
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
        
        // Image View
        messageImageView.contentMode = .scaleAspectFill
        messageImageView.clipsToBounds = true
        messageImageView.layer.cornerRadius = 8
        messageImageView.backgroundColor = UIColor(white: 0.9, alpha: 1.0)
        messageImageView.isHidden = true
        containerView.addSubview(messageImageView)
        
        // Status Label
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .systemGray
        statusLabel.isHidden = true
        containerView.addSubview(statusLabel)
        
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
        
        messageImageView.snp.makeConstraints { make in
            make.left.equalTo(avatarView.snp.right).offset(12)
            make.top.equalToSuperview().inset(12)
            make.width.equalTo(200)
            make.height.equalTo(150)
        }
        
        statusLabel.snp.makeConstraints { make in
            make.left.equalTo(avatarView.snp.right).offset(12)
            make.top.equalTo(messageImageView.snp.bottom).offset(4)
            make.bottom.equalToSuperview().inset(12)
        }
    }
    
    func configure(with transcript: Transcript) {
        // 显示文本消息
        messageLabel.isHidden = false
        messageImageView.isHidden = true
        statusLabel.isHidden = true
        
        let isAgent = transcript.type == .agent
        avatarView.backgroundColor = isAgent ? .blue : .green
        avatarLabel.text = isAgent ? "AI" : "我"
        messageLabel.text = transcript.text
        
        // 更新约束 - 文本消息时 messageLabel 占据全部空间
        messageLabel.snp.remakeConstraints { make in
            make.left.equalTo(avatarView.snp.right).offset(12)
            make.right.top.bottom.equalToSuperview().inset(12)
        }
    }
    
    func configure(with imageItem: ImageMessageItem) {
        // 显示图片消息
        messageLabel.isHidden = true
        messageImageView.isHidden = false
        statusLabel.isHidden = false
        
        avatarView.backgroundColor = .green
        avatarLabel.text = "我"
        
        // 加载图片
        if let url = URL(string: imageItem.url) {
            loadImage(from: url)
        } else {
            messageImageView.image = UIImage(systemName: "photo")
        }
        
        // 更新状态
        switch imageItem.status {
        case .sending:
            statusLabel.text = "发送中..."
            statusLabel.textColor = .systemBlue
        case .success:
            statusLabel.text = "发送成功"
            statusLabel.textColor = .systemGreen
        case .failed:
            statusLabel.text = "发送失败"
            statusLabel.textColor = .systemRed
        }
        
        // 更新约束 - 图片消息时 messageLabel 不参与布局
        messageLabel.snp.remakeConstraints { make in
            make.left.equalTo(avatarView.snp.right).offset(12)
            make.right.top.equalToSuperview().inset(12)
            make.height.equalTo(0)
        }
    }
    
    private func loadImage(from url: URL) {
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  let image = UIImage(data: data),
                  error == nil else {
                DispatchQueue.main.async {
                    self?.messageImageView.image = UIImage(systemName: "photo")
                }
                return
            }
            
            DispatchQueue.main.async {
                self.messageImageView.image = image
            }
        }.resume()
    }
}
