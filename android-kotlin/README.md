# agent-starter-convoai-android

## 功能概述

### 解决的问题

本示例项目展示了如何在 Android 应用中集成 Agora Conversational AI（对话式 AI）功能，实现与 AI 语音助手的实时对话交互。主要解决以下问题：

- **实时语音交互**：通过 Agora RTC SDK 实现与 AI 代理的实时音频通信
- **消息传递**：通过 Agora RTM SDK 实现与 AI 代理的消息交互和状态同步
- **实时转录**：支持实时显示用户和 AI 代理的对话转录内容
- **Agent 说话状态指示器**：通过动画效果实时显示 AI Agent 的说话状态
- **状态管理**：统一管理连接状态、静音状态、转录状态等 UI 状态

### 适用场景

- 智能客服系统：构建基于 AI 的实时语音客服应用
- 语音助手应用：开发类似 Siri、小爱同学的语音助手功能
- 实时语音转录：实时显示用户和 AI 代理的对话转录内容
- 语音交互游戏：开发需要语音交互的游戏应用
- 教育培训：构建语音交互式教学应用

### 前置条件

- Android Studio Hedgehog 或更高版本
- Android SDK API Level 26（Android 8.0）或更高
- Agora 开发者账号 [Console](https://console.shengwang.cn/)
- 已在 Agora 控制台开通 **实时消息 RTM** 功能（必需）
- 已创建 Agora 项目并获取 App ID 和 App Certificate
- 已创建 Conversational AI Pipeline 并获取 Pipeline ID [AI Studio](https://console-conversationai.shengwang.cn/product/ConversationAI/studio)
- 已配置 Agent 启动服务器（参考 [server-python](../server-python/README.md)）

## 快速开始

### 环境要求

- **开发环境**：
  - Android Studio Hedgehog 或更高版本
  - JDK 11 或更高版本
  - Gradle 8.13.0
  - Kotlin 2.0.21

- **运行环境**：
  - Android 8.0（API Level 26）或更高版本
  - 支持音频录制和播放的设备

### 依赖安装

1. **克隆项目**：
```bash
git clone https://github.com/alienzh/Agora-AI-Recipes-Starter.git
cd Agora-AI-Recipes-Starter/android-kotlin
```

2. **配置 Android 项目**：
   - 使用 Android Studio 打开项目
   - 等待 Gradle 同步完成

3. **配置 Agora Key**：
   
   1. 复制 `env.example.properties` 文件为 `env.properties`：
   ```bash
   cp env.example.properties env.properties
   ```
   
   2. 编辑 `env.properties` 文件，填入你的实际配置值：
   ```properties
   agora.appId=your_app_id
   agora.appCertificate=your_app_certificate
   agora.restKey=your_rest_key
   agora.restSecret=your_rest_secret
   agora.pipelineId=your_pipeline_id
   ```
   
   **配置项说明**：
   - `agora.appId`：你的 Agora App ID（必需）
   - `agora.appCertificate`：你的 App Certificate（必需，用于 Token 生成）
   - `agora.restKey`：REST API Key（必需，用于启动 Agent）
   - `agora.restSecret`：REST API Secret（必需，用于启动 Agent）
   - `agora.pipelineId`：Pipeline ID（必需，用于启动 Agent）
   
   **获取方式**：
   - App ID 和 App Certificate：在 [Agora Console](https://console.shengwang.cn/) 中创建项目后获取
   - REST Key 和 REST Secret：在 Agora Console 的项目设置中获取
   - Pipeline ID：在 [AI Studio](https://console-conversationai.shengwang.cn/product/ConversationAI/studio) 中创建 Pipeline 后获取
   
   **注意**：
   - `env.properties` 文件包含敏感信息，不会被提交到版本控制系统。请确保不要将你的实际凭证提交到代码仓库。
   - 每次启动时会自动生成随机的 channelName，无需手动配置。

4. **配置 Agent 启动方式**：
   
   有两种方式启动 Agent，在 `AgentStarter.kt` 中直接切换：
   
   **方式一：本地 HTTP 服务器模式**（推荐用于开发测试）
   
   1. 启动 Python HTTP 服务器：
   ```bash
   cd ../server-python
   python agora_http_server.py
   ```
   
   服务器默认运行在 `http://localhost:8080`。
   
   2. 在 `AgentStarter.kt` 中配置本地服务器 URL：
   ```kotlin
   object AgentStarter {
       // Switch between local server and Agora API by commenting/uncommenting the lines below
   //    private const val AGORA_API_BASE_URL = "https://api.sd-rtn.com/cn/api/conversational-ai-agent/v2/projects"
       private const val AGORA_API_BASE_URL = "http://10.0.2.2:8080"  // Android Emulator
   //    private const val AGORA_API_BASE_URL = "http://192.168.1.100:8080"  // Physical device (replace with your computer IP)
   }
   ```
   
   **IP 地址说明**：
   - **Android 模拟器**：使用 `http://10.0.2.2:8080`（`10.0.2.2` 是模拟器访问主机 localhost 的特殊 IP）
   - **真机**：使用 `http://<你的电脑IP>:8080`（查找电脑 IP：`ifconfig en0 | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}'`）
   
   **方式二：直接调用 Agora API 模式**（推荐用于生产环境）
   
   不需要启动 Python 服务器，Android 应用直接调用 Agora API。
   
   在 `AgentStarter.kt` 中配置：
   ```kotlin
   object AgentStarter {
       // Switch between local server and Agora API by commenting/uncommenting the lines below
       private const val AGORA_API_BASE_URL = "https://api.sd-rtn.com/cn/api/conversational-ai-agent/v2/projects"
   //    private const val AGORA_API_BASE_URL = "http://10.0.2.2:8080"  // Local server
   }
   ```
   
   **注意**：URL 切换在 `AgentStarter.kt` 中完成，不再使用 `env.properties` 中的 `agentServerUrl` 配置。

## 测试验证

1. **启动 Python HTTP 服务器**（如果使用 HTTP 服务器模式）：
   
   ```bash
   cd ../server-python
   python agora_http_server.py
   ```
   
   服务器启动后，Android 应用会自动通过 `AgentStarter.kt` 中配置的地址调用服务器来启动 Agent。
   
   **注意**：
   - 如果使用虚拟环境，请先激活虚拟环境：
     ```bash
     source venv/bin/activate  # macOS/Linux
     # 或
     venv\Scripts\activate  # Windows
     ```
   - 确保 Android 设备和电脑在同一局域网内（真机）或使用模拟器的特殊 IP（`10.0.2.2`）
   - 如果端口被占用，可以修改服务器端口和 Android 代码中的端口号

2. **运行 Android 应用**：
   - 在 Android Studio 中运行应用
   - 在 Agent Configuration 页面查看配置信息（App ID 和 Pipeline ID）
   - 点击"Start"按钮开始连接
   - 应用会自动生成随机的 channelName
   - 自动加入 RTC 频道并登录 RTM
   - 连接成功后自动导航到 Voice Assistant 页面
   - 自动启动 AI Agent（通过 RESTful API）
   - Agent 启动成功后即可开始对话

3. **验证功能**：
   - ✅ 检查是否成功加入 RTC 频道
   - ✅ 检查是否成功登录 RTM
   - ✅ 检查 Agent 是否成功启动（查看状态消息）
   - ✅ 验证音频传输是否正常
   - ✅ 测试静音/取消静音功能
   - ✅ 验证转录功能是否正常显示
   - ✅ 验证 Agent 说话状态指示器（VoiceWaveView）是否正常显示动画
   - ✅ 测试与 AI Agent 的对话交互

## 项目结构

```
android-kotlin/
├── app/
│   ├── src/
│   │   ├── main/
│   │   │   ├── java/
│   │   │   │   └── io/agora/convoai/example/voiceassistant/
│   │   │   │       ├── AgentApp.kt              # Application 类
│   │   │   │       ├── KeyCenter.kt             # 配置中心
│   │   │   │       ├── ui/
│   │   │   │       │   ├── MainActivity.kt       # 主 Activity
│   │   │   │       │   ├── AgentConfigFragment.kt    # Agent 配置界面
│   │   │   │       │   ├── VoiceAssistantFragment.kt # 语音助手界面
│   │   │   │       │   ├── ConversationViewModel.kt # 对话 ViewModel
│   │   │   │       │   ├── CommonDialog.kt      # 通用对话框
│   │   │   │       │   └── common/              # 通用 UI 组件
│   │   │   │       │       ├── BaseActivity.kt
│   │   │   │       │       ├── BaseFragment.kt
│   │   │   │       │       ├── BaseDialogFragment.kt
│   │   │   │       │       ├── SnackbarHelper.kt
│   │   │   │       │       └── VoiceWaveView.kt
│   │   │   │       ├── rtc/
│   │   │   │       │   ├── RtcManager.kt        # RTC 管理器
│   │   │   │       │   └── RtmManager.kt        # RTM 管理器
│   │   │   │       ├── tools/
│   │   │   │       │   ├── AgentStarter.kt      # Agent 启动器
│   │   │   │       │   ├── TokenGenerator.kt # Token 生成器
│   │   │   │       │   ├── PermissionHelp.kt    # 权限帮助类
│   │   │   │       │   └── Base64Encoding.kt    # Base64 编码工具
│   │   │   │       └── net/
│   │   │   │           ├── SecureOkHttpClient.kt # 安全 HTTP 客户端
│   │   │   │           └── HttpLogger.kt        # HTTP 日志记录器
│   │   │   └── res/                              # 资源文件
│   │   └── convoaiApi/                          # Conversational AI API（Kotlin）
│   └── build.gradle
├── env.properties                                # 环境配置（需要创建）
├── env.example.properties                        # 环境配置示例
└── README.md                                     # 本文档
```

## 相关资源

### API 文档链接

- [Agora RTC Android SDK 文档](https://doc.shengwang.cn/doc/rtc/android/landing-page)
- [Agora RTM Android SDK 文档](https://doc.shengwang.cn/doc/rtm2/android/landing-page)
- [Conversational AI RESTful API 文档](https://doc.shengwang.cn/doc/convoai/restful/landing-page)
- [Conversational AI Android 客户端组件 文档](https://doc.shengwang.cn/api-ref/convoai/android/android-component/overview)

### 相关 Recipes

- [Agora Recipes 主页](https://github.com/AgoraIO-Community)
- 其他 Agora 示例项目

### 社区支持

- [Agora 开发者社区](https://github.com/AgoraIO-Community)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/agora)

---

**注意**：使用本示例前，请确保已在 Agora 控制台开通 RTM 功能，否则组件无法正常工作。
