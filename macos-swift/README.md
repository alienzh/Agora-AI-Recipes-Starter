# agent-starter-convoai-macos

[![Platform](https://img.shields.io/badge/platform-macOS-blue.svg)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/swift-5.0+-orange.svg)](https://swift.org/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

## 功能概述

### 解决的问题

本示例项目展示了如何在 macOS 应用中集成 Agora Conversational AI（对话式 AI）功能，实现与 AI 语音助手的实时对话交互。主要解决以下问题：

- 🎤 **实时语音交互**：通过 Agora RTC SDK 实现与 AI 代理的实时音频通信
- 💬 **消息传递**：通过 Agora RTM v2.x SDK 实现与 AI 代理的消息交互和状态同步
- 📝 **实时转录**：支持实时显示用户和 AI 代理的对话转录内容（自定义 MessageListView）
- 🟢 **Agent 状态指示器**：通过动画效果实时显示 AI Agent 的说话状态
- 🎯 **状态管理**：统一管理连接状态、静音状态、转录状态等 UI 状态
- 🌐 **统一网络层**：HTTPClient 封装，支持 Token 生成和 Agent 管理
- 🔧 **灵活配置**：User UID 和 Agent UID 支持动态配置

### 适用场景

- 智能客服系统：构建基于 AI 的实时语音客服应用
- 语音助手应用：开发类似 Siri 的桌面语音助手功能
- 实时语音转录：实时显示用户和 AI 代理的对话转录内容
- 教育培训：构建语音交互式教学应用
- 会议辅助：提供智能会议助手和实时转录功能

### 前置条件

- macOS 10.13 或更高版本（开发和运行）
- Xcode 14.0 或更高版本
- CocoaPods 1.11.0 或更高版本
- Agora 开发者账号 [Console](https://console.shengwang.cn/)
- 已在 Agora 控制台开通 **实时消息 RTM** 功能（必需）
- 已创建 Agora 项目并获取 App ID 和 App Certificate
- 已创建 Conversational AI Pipeline 并获取 Pipeline ID [AI Studio](https://console-conversationai.shengwang.cn/product/ConversationAI/studio)
- 已配置 Agent 启动服务器（参考 [server-python](../server-python/README.md)）

## 快速开始

### 环境要求

- **开发环境**：
  - macOS 10.13 或更高版本
  - Xcode 14.0 或更高版本
  - Swift 5.0 或更高版本
  - CocoaPods 1.11.0 或更高版本

- **运行环境**：
  - macOS 10.13 或更高版本
  - 支持音频录制和播放的设备

### 依赖安装

1. **克隆项目**：
```bash
git clone https://github.com/alienzh/Agora-AI-Recipes-Starter.git
cd Agora-AI-Recipes-Starter/macos-swift
```

2. **安装 CocoaPods 依赖**：
```bash
# Install CocoaPods if not already installed
sudo gem install cocoapods

# Install project dependencies
pod install
```

3. **打开 Xcode 工作空间**：
```bash
# IMPORTANT: Open .xcworkspace, not .xcodeproj
open VoiceAgent.xcworkspace
```

4. **配置 Agent 启动方式**：
   
   有两种方式启动 Agent，在 `KeyCenter.swift` 中直接切换：
   
   **方式一：本地 HTTP 服务器模式**（推荐用于开发测试）
   
   1. 启动 Python HTTP 服务器：
   ```bash
   cd ../server-python
   python agora_http_server.py
   ```
   
   服务器默认运行在 `http://localhost:8080`。
   
   2. 在 `KeyCenter.swift` 中配置本地服务器 URL：
   ```swift
   struct KeyCenter {
       // Switch between local server and Agora API by changing this URL
       static let AGENT_SERVER_BASE_URL = "http://localhost:8080"
   //    static let AGENT_SERVER_BASE_URL = "https://api.sd-rtn.com/cn/api/conversational-ai-agent/v2/projects"
   }
   ```
   
   **方式二：直接调用 Agora API 模式**（推荐用于生产环境）
   
   不需要启动 Python 服务器，macOS 应用直接调用 Agora API。
   
   在 `KeyCenter.swift` 中配置：
   ```swift
   struct KeyCenter {
       // Switch between local server and Agora API by changing this URL
   //    static let AGENT_SERVER_BASE_URL = "http://localhost:8080"
       static let AGENT_SERVER_BASE_URL = "https://api.sd-rtn.com/cn/api/conversational-ai-agent/v2/projects"
   }
   ```
   
   确保在 `KeyCenter.swift` 中配置了 REST API 凭证。

### 配置说明

1. **配置 App ID 和凭证**：
   
   编辑 `VoiceAgent/KeyCenter.swift` 文件，填入你的实际配置值：
   
```swift
struct KeyCenter {
    // Agora Credentials - Replace with your actual values
    static let AGORA_APP_ID = "your_app_id"
    static let AGORA_APP_CERTIFICATE = ""  // Optional, leave empty if not using
    
    // REST API Credentials (for direct API mode)
    static let REST_KEY = "your_rest_key"
    static let REST_SECRET = "your_rest_secret"
    
    // Pipeline Configuration
    static let PIPELINE_ID = "your_pipeline_id"
    
    // Agent Server Configuration
    // Switch between local server and Agora API by changing this URL
    static let AGENT_SERVER_BASE_URL = "https://api.sd-rtn.com/cn/api/conversational-ai-agent/v2/projects"
}
```

> **注意**：从 v2.0 开始，User UID 和 Agent UID 已移至 `ViewController.swift` 中管理，便于动态配置。Channel Name 也支持自动生成。

2. **配置说明**：
   - `AGORA_APP_ID`：你的 Agora App ID（**必需**）
   - `AGORA_APP_CERTIFICATE`：你的 App Certificate（可选，用于 Token 生成）
   - `REST_KEY`：REST API Key（**直接 API 模式必需**）
   - `REST_SECRET`：REST API Secret（**直接 API 模式必需**）
   - `PIPELINE_ID`：你的 Conversational AI Pipeline ID（**必需**）
   - `AGENT_SERVER_BASE_URL`：Agent 服务器地址（切换本地服务器或 Agora API）

3. **User ID 和 Agent ID 配置**：
   
   如需修改 User UID 或 Agent UID，请编辑 `VoiceAgent/Scene/ViewController.swift` 中的 `userUid` 和 `agentUid` 属性。

4. **权限配置**：
   
   确保 `VoiceAgent.entitlements` 中包含以下权限：
```xml
<key>com.apple.security.device.audio-input</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.network.server</key>
<true/>
```

5. **Info.plist 配置**：
   
   确保 `Info.plist` 中包含麦克风权限说明：
```xml
<key>NSMicrophoneUsageDescription</key>
<string>VoiceAgent needs access to your microphone for voice conversation with AI agent.</string>
```

## 实现步骤

### 步骤1：基础设置

1. **初始化 RTC Engine**：在 `RtcManager.swift` 中创建 RTC Engine 实例，配置音频场景和角色。

2. **初始化 RTM Client**：在 `RtmManager.swift` 中创建 RTM Client 实例，使用 KeyCenter 中的 APP_ID 和 User ID。

3. **配置 ConversationalAI API**：在 `ViewController.swift` 中初始化 ConversationalAI API，订阅频道消息以接收 AI Agent 的状态和转录。

### 步骤2：核心实现

1. **加入频道和登录 RTM**：
   - 生成统一的 RTC 和 RTM Token
   - 加入 RTC 频道进行音频通信
   - 登录 RTM 进行消息传递
   - 初始化 ConversationalAI API 订阅 Agent 消息

2. **订阅 RTM 消息**：在 `ConversationalAIAPIImpl` 中订阅频道消息以接收 AI Agent 的状态和转录。

3. **注册事件处理器**：实现 `ConversationalAIAPIEventHandler` 协议，处理转录更新、Agent 状态变化等事件。

4. **实现 UI 状态观察**：观察 Agent 状态（Speaking/Listening/Thinking），控制说话状态指示器动画和字幕显示。

### 步骤3：测试验证

1. **启动 Python HTTP 服务器**（如果使用 HTTP 服务器模式）：
   
   ```bash
   cd ../server-python
   python agora_http_server.py
   ```
   
   服务器启动后，macOS 应用会自动通过 `KeyCenter.swift` 中配置的地址调用服务器来启动 Agent。
   
   **注意**：
   - 如果使用虚拟环境，请先激活虚拟环境：
     ```bash
     source venv/bin/activate  # macOS/Linux
     ```
   - 确保服务器成功启动在 `http://localhost:8080`
   - 如果端口被占用，可以修改服务器端口和 macOS 代码中的端口号

2. **运行 macOS 应用**：
   - 在 Xcode 中按 `Cmd + R` 运行应用
   - 或点击 Xcode 工具栏中的 Run 按钮
   - 输入频道名称（或留空自动生成）
   - 点击"Join Channel"按钮
   - 点击"Start Agent"按钮启动 Agent

3. **验证功能**：
   - ✅ 检查是否成功加入 RTC 频道
   - ✅ 检查是否成功登录 RTM
   - ✅ 验证音频传输是否正常
   - ✅ 测试静音/取消静音功能
   - ✅ 验证转录功能是否正常显示
   - ✅ 验证 Agent 说话状态指示器是否正常显示动画
   - ✅ 测试与 AI Agent 的对话交互

## 项目结构

```
macos-swift/
├── VoiceAgent/
│   ├── ConversationalAIAPI/        # ConversationalAI API 实现
│   │   ├── ConversationalAIAPI.swift
│   │   ├── ConversationalAIAPIImpl.swift
│   │   └── Transcript/
│   │       └── TranscriptController.swift
│   ├── Managers/                   # 管理器类
│   │   ├── RtcManager.swift        # RTC SDK 管理器
│   │   └── RtmManager.swift        # RTM SDK 管理器
│   ├── Network/                    # 网络请求相关
│   │   ├── HTTPClient.swift        # 统一 HTTP 请求封装 (NEW)
│   │   ├── TokenGenerator.swift    # Token 生成器（使用 HTTPClient）
│   │   └── AgentManager.swift      # Agent 启动/停止管理（使用 HTTPClient）
│   ├── Scene/                      # UI 界面
│   │   ├── AppDelegate.swift       # 应用入口
│   │   ├── ViewController.swift    # 主视图控制器（包含 User/Agent UID）
│   │   └── MessageListView.swift   # 消息列表视图（实时字幕）
│   ├── Resouces/                   # 资源文件
│   │   ├── Assets.xcassets/
│   │   └── Base.lproj/
│   │       └── Main.storyboard
│   ├── KeyCenter.swift             # 配置中心（仅核心配置）
│   └── Info.plist                  # 应用信息和权限配置
├── VoiceAgent.entitlements         # macOS 沙盒权限配置
├── Podfile                         # CocoaPods 依赖配置
├── Podfile.lock                    # CocoaPods 依赖锁定
└── VoiceAgent.xcworkspace/         # Xcode 工作空间（⚠️ 打开此文件）

```

## 核心依赖

- **ShengwangRtcEngine_macOS (4.6.0)**：Agora RTC SDK for macOS
- **AgoraRtm**：Agora RTM SDK for macOS（RTM v2.x API）
- **SnapKit**：Swift Auto Layout DSL（用于 UI 布局）

## 核心组件说明

### HTTPClient.swift

统一的 HTTP 请求封装类，为 `TokenGenerator` 和 `AgentManager` 提供网络请求能力。

**主要功能**：
- ✅ 统一的 POST/GET 请求接口
- ✅ 自动 JSON 序列化/反序列化
- ✅ 主线程回调（UI 安全）
- ✅ 支持自定义 Headers
- ✅ Basic Auth 辅助方法

### TokenGenerator & AgentManager

这两个类使用 `HTTPClient` 进行网络请求，提供 Token 生成和 Agent 管理功能。

## 相关资源

### API 文档链接

- [Agora RTC macOS SDK 文档](https://doc.shengwang.cn/doc/rtc/macos/landing-page)
- [Agora RTM iOS SDK 文档](https://doc.shengwang.cn/doc/rtm2/ios/landing-page)（macOS 使用相同 API）
- [Conversational AI RESTful API 文档](https://doc.shengwang.cn/doc/convoai/restful/landing-page)
- [Conversational AI iOS 客户端组件 文档](https://doc.shengwang.cn/api-ref/convoai/ios/ios-component/overview)

### 相关 Recipes

- [Agora Recipes 主页](https://github.com/AgoraIO-Community)
- [Android Kotlin 版本](../android-kotlin/README.md)
- [Windows C++ 版本](../windows-cpp/README.md)
- 其他 Agora 示例项目

### 社区支持

- [Agora 开发者社区](https://github.com/AgoraIO-Community)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/agora)

---

**注意事项**：
- ✅ 使用本示例前，请确保已在 Agora 控制台开通 **RTM v2.x** 功能
- ✅ 首次运行时，macOS 会请求麦克风权限，请点击"允许"
- ✅ 如果遇到代码签名问题，请在 Xcode 中配置你的 Team ID
- ✅ 必须打开 `.xcworkspace` 文件，而不是 `.xcodeproj` 文件
- ✅ 运行前请先执行 `pod install` 安装依赖

