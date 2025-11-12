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
- 已获取 REST Key 和 REST Secret（用于客户端启动 Agent）

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
cd Agora-AI-Recipes-Starter/android-kotlin-selfstart
```

2. **配置 Android 项目**：
   - 使用 Android Studio 打开项目
   - 等待 Gradle 同步完成

### 配置说明

1. **配置 App ID、App Certificate、Pipeline ID 和 REST 凭证**：
   
   1. 复制 `env.example.properties` 文件为 `env.properties`：
   ```bash
   cp env.example.properties env.properties
   ```
   
   2. 编辑 `env.properties` 文件，填入你的实际配置值：
   - `agora.appId`：你的 Agora App ID
   - `agora.appCertificate`：你的 App Certificate（可选，用于 Token 生成）
   - `agora.restKey`：你的 REST Key（用于客户端启动 Agent）
   - `agora.restSecret`：你的 REST Secret（用于客户端启动 Agent）
   - `agora.pipelineId`：你的 Pipeline ID

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
   
   实现 `joinChannelAndLogin()` 方法，依次加入 RTC 频道和登录 RTM。
```kotlin
fun joinChannelAndLogin(channelName: String) {
    // Generate unified token for RTC and RTM
    val token = TokenGenerator.generateTokensAsync(
        channelName = "",
        uid = userId.toString()
    )
   
    // Join RTC channel
    RtcManager.joinChannel(token, randomChannelName, userId)
    
    // Login RTM
    CovRtmManager.login(token) { error ->
        if (error == null) {
            // RTM login successful, subscribe to messages
            conversationalAIAPI?.subscribeMessage(randomChannelName) { errorInfo ->
                // Handle subscription result
            }
        }
    }
}
```

2. **客户端启动 Agent**：
   
   在 RTC 和 RTM 连接成功后，客户端会自动启动 Agent：
```kotlin
fun startAgent() {
    // Generate random channel name for agent
    val agentChannelName = uiState.value.channelName
    
    // Generate token for agentUid (not user token)
    val agentToken = TokenGenerator.generateTokensAsync(
        channelName = agentChannelName,
        uid = agentUid.toString()
    )
    
    // Start agent using AgentAIStudioStarter
    val result = AgentAIStudioStarter.startAgentAsync(
        name = "default_agent",
        pipelineId = KeyCenter.PIPELINE_ID,
        channel = agentChannelName,
        agentRtcUid = agentUid.toString(),
        token = agentToken
    )
    
    result.fold(
        onSuccess = { agentId ->
            // Agent started successfully, save agentId to UI state
            _uiState.value = _uiState.value.copy(
                agentStarted = true,
                agentId = agentId
            )
        },
        onFailure = { exception ->
            // Handle agent start failure
            _uiState.value = _uiState.value.copy(
                agentStartFailed = true,
                statusMessage = "Failed to start agent: ${exception.message}"
            )
        }
    )
}
```

3. **订阅 RTM 消息**：
   
   在 RTM 登录成功后，自动订阅频道消息以接收 AI Agent 的状态和转录：
```kotlin
conversationalAIAPI?.subscribeMessage(channelName) { errorInfo ->
    if (errorInfo != null) {
        Log.e(TAG, "Subscribe message error: ${errorInfo}")
    }
}
```

4. **注册事件处理器**：
   
   实现 `IConversationalAIAPIEventHandler` 接口，处理各种事件：
```kotlin
conversationalAIAPI?.addHandler(object : IConversationalAIAPIEventHandler {
    override fun onTranscriptUpdated(agentUserId: String, transcript: Transcript) {
        // Update transcript list
        addTranscript(transcript)
    }
    
    override fun onAgentStateChanged(agentUserId: String, event: StateChangeEvent) {
        // Update agent state
        _agentState.value = event.state
    }
    
    override fun onAgentError(agentUserId: String, error: ModuleError) {
        // Handle agent errors
    }
    
    override fun onMessageError(agentUserId: String, error: MessageError) {
        // Handle message errors
    }
})
```

5. **停止 Agent**：
   
   在挂断时，需要停止 Agent：
```kotlin
fun hangup() {
    // Stop agent first
    stopAgent()
    
    // Then cleanup RTC and RTM connections
    conversationalAIAPI?.unsubscribeMessage(channelName) { errorInfo ->
        // Handle unsubscribe result
    }
    RtcManager.leaveChannel()
    CovRtmManager.logout()
}

private fun stopAgent() {
    val currentAgentId = _uiState.value.agentId
    if (currentAgentId.isEmpty()) {
        return
    }
    
    AgentAIStudioStarter.stopAgentAsync(currentAgentId).fold(
        onSuccess = {
            _uiState.value = _uiState.value.copy(
                agentStarted = false,
                agentId = ""
            )
        },
        onFailure = { exception ->
            Log.e(TAG, "Failed to stop agent: ${exception.message}", exception)
        }
    )
}
```

6. **实现 UI 状态观察**：
   
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

1. **运行 Android 应用**：
   - 在 Android Studio 中运行应用
   - 应用会自动生成随机的频道名称
   - 点击"Start Agent"按钮

2. **验证功能**：
   - ✅ 检查是否成功加入 RTC 频道
   - ✅ 检查是否成功登录 RTM
   - ✅ 验证 Agent 是否成功启动（查看 Agent ID 是否显示）
   - ✅ 验证音频传输是否正常
   - ✅ 测试静音/取消静音功能
   - ✅ 验证转录功能是否正常显示
   - ✅ 验证 Agent 说话状态指示器是否正常显示动画
   - ✅ 测试与 AI Agent 的对话交互
   - ✅ 验证挂断时 Agent 是否正确停止

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
