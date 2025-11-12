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

3. **配置 Agent 启动方式**：
   
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
   
   在 `env.properties` 中配置 REST API 凭证：
   ```properties
   agora.restKey=your_rest_key
   agora.restSecret=your_rest_secret
   agora.pipelineId=your_pipeline_id
   ```

### 配置说明

1. **配置 App ID 和 App Certificate**：
   
   1. 复制 `env.example.properties` 文件为 `env.properties`：
   ```bash
   cp env.example.properties env.properties
   ```
   
   2. 编辑 `env.properties` 文件，填入你的实际配置值：
   - `agora.appId`：你的 Agora App ID
   - `agora.appCertificate`：你的 App Certificate（可选，用于 Token 生成）
   - `agora.restKey`：REST API Key（直接 API 模式必需，HTTP 服务器模式也需要）
   - `agora.restSecret`：REST API Secret（直接 API 模式必需，HTTP 服务器模式也需要）
   - `agora.pipelineId`：Pipeline ID（直接 API 模式必需，HTTP 服务器模式也需要）
   
   **注意**：URL 切换在 `AgentStarter.kt` 中完成，不再使用 `env.properties` 中的 `agentServerUrl` 配置。

2. **权限配置**：
   
   确保 `AndroidManifest.xml` 中包含以下权限：
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
```

## 实现步骤

### 步骤1：基础设置

1. **初始化 RTC Engine**：
   
   在 `RtcManager.kt` 中创建 RTC Engine 实例：
```kotlin
val config = RtcEngineConfig()
config.mContext = context
config.mAppId = appId
config.mChannelProfile = Constants.CHANNEL_PROFILE_LIVE_BROADCASTING
config.mAudioScenario = Constants.AUDIO_SCENARIO_DEFAULT
config.mEventHandler = rtcEventHandler
val rtcEngine = RtcEngine.create(config) as RtcEngineEx
rtcEngine.enableVideo()
```

2. **初始化 RTM Client**：
   
   在 `RtmManager.kt` 中创建 RTM Client 实例：
```kotlin
val rtmConfig = RtmConfig.Builder(appId, userId.toString()).build()
val rtmClient = RtmClient.create(rtmConfig)
rtmClient.addEventListener(rtmEventListener)
```

3. **配置 ConversationalAI API**：
   
   在 `ConversationViewModel.kt` 中初始化 API：
```kotlin
val config = ConversationalAIAPIConfig(
    rtcEngine = rtcEngine,
    rtmClient = rtmClient,
    enableLog = true,
    renderMode = TranscriptRenderMode.Text
)
conversationalAIAPI = ConversationalAIAPIImpl(config)
```

### 步骤2：核心实现

1. **加入频道和登录 RTM**：
   
   实现 `joinChannelAndLogin()` 方法，依次加入 RTC 频道和登录 RTM：
```kotlin
fun joinChannelAndLogin(channelName: String) {
    // Generate unified token for RTC and RTM
    val token = generateUnifiedToken(channelName, userId)
    
    // Join RTC channel
    val options = ChannelMediaOptions().apply {
        clientRoleType = Constants.CLIENT_ROLE_BROADCASTER
        publishMicrophoneTrack = true
        autoSubscribeAudio = true
    }
    rtcEngine.joinChannel(token, channelName, userId, options)
    
    // Login RTM
    rtmClient.login(token) { error ->
        if (error == null) {
            // RTM login successful
        }
    }
}
```

2. **订阅 RTM 消息**：
   
   订阅频道消息以接收 AI Agent 的状态和转录：
```kotlin
conversationalAIAPI?.subscribeMessage(channelName) { result ->
    if (result.isSuccess) {
        // Handle subscription success
    }
}
```

3. **注册事件处理器**：
   
   实现 `IConversationalAIAPIEventHandler` 接口，处理各种事件：
```kotlin
conversationalAIAPI?.addHandler(object : IConversationalAIAPIEventHandler {
    override fun onTranscript(transcript: Transcript) {
        // Update transcript list
        _transcriptList.value = _transcriptList.value + transcript
    }
    
    override fun onStateChange(event: StateChangeEvent) {
        // Update agent state
        _agentState.value = event.state
    }
    
    override fun onError(error: ModuleError) {
        // Handle errors
    }
})
```

4. **实现 UI 状态观察**：
   
   在 `VoiceAssistantFragment.kt` 中观察 Agent 状态，控制说话状态指示器：
```kotlin
lifecycleScope.launch {
    viewModel.agentState.collect { agentState ->
        agentState?.let {
            if (agentState == AgentState.SPEAKING) {
                agentSpeakingIndicator.startAnimation()
            } else {
                agentSpeakingIndicator.stopAnimation()
            }
        }
    }
}
```

   观察转录列表，实现字幕显示：
```kotlin
viewLifecycleOwner.lifecycleScope.launch {
    viewModel.transcriptList.collect { transcriptList ->
        transcriptAdapter.submitList(transcriptList) 
        if (autoScrollToBottom) {
            scrollToBottom()
            }
    }
}
```

### 步骤3：测试验证

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
   - 输入频道名称
   - 点击"Start"按钮
   - 应用会自动启动 Agent 并加入频道

3. **验证功能**：
   - ✅ 检查是否成功加入 RTC 频道
   - ✅ 检查是否成功登录 RTM
   - ✅ 验证音频传输是否正常
   - ✅ 测试静音/取消静音功能
   - ✅ 验证转录功能是否正常显示
   - ✅ 验证 Agent 说话状态指示器是否正常显示动画
   - ✅ 测试与 AI Agent 的对话交互

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
