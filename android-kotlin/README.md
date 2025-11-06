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
- 已配置 Agent 启动服务器（参考 [agent-starter-server](../agent-starter-server/README.md)）

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
git clone <repository-url>
cd agent-starter-convoai-android
```

2. **配置 Android 项目**：
   - 使用 Android Studio 打开项目
   - 等待 Gradle 同步完成

3. **配置 Agent 启动服务器**：
   
   参考 [agent-starter-server](../agent-starter-server/README.md) 的说明配置和启动 Agent 服务器。

### 配置说明

1. **配置 App ID 和 App Certificate**：
   
   在 `app/src/main/java/io/agora/convoai/example/voiceassistant/KeyCenter.kt` 中配置你的 App ID 和 App Certificate。

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
        transcriptAdapter.submitList(transcriptList) {
            // Scroll to bottom when new transcript is added
            if (transcriptList.isNotEmpty()) {
                rvTranscript.smoothScrollToPosition(transcriptList.size - 1)
            }
        }
    }
}
```

### 步骤3：测试验证

1. **启动 AI Agent**：
   
   参考 [agent-starter-server](../agent-starter-server/README.md) 的说明启动 Agent 服务器：
```bash
cd ../agent-starter-server
source venv/bin/activate
python agora_starter_server.py start --channelName "test_channel"
```

2. **运行 Android 应用**：
   - 在 Android Studio 中运行应用
   - 输入频道名称（与 Agent 启动时的频道名称一致）
   - 点击"Start"按钮

3. **验证功能**：
   - ✅ 检查是否成功加入 RTC 频道
   - ✅ 检查是否成功登录 RTM
   - ✅ 验证音频传输是否正常
   - ✅ 测试静音/取消静音功能
   - ✅ 验证转录功能是否正常显示
   - ✅ 验证 Agent 说话状态指示器是否正常显示动画
   - ✅ 测试与 AI Agent 的对话交互

## 扩展功能

### 高级配置

本示例展示了基础的 Conversational AI 集成方式。更多高级功能请参考 [ConversationalAI API 组件文档](./app/src/main/java/io/agora/convoai/convoaiApi/README.md)，包括：

- **自定义音频参数**：配置不同的音频场景（标准模式、数字人模式等）
- **自定义转录渲染模式**：支持文本模式和逐词模式
- **发送消息给 AI Agent**：发送文本消息、图片消息，支持优先级控制
- **打断 Agent**：实现打断 AI Agent 的功能
- **消息状态跟踪**：处理消息发送成功/失败的回调
- **事件处理**：处理 Agent 状态变化、错误、指标等事件

### 性能优化

- 使用 `AUDIO_SCENARIO_AI_CLIENT` 场景以获得最佳 AI 对话质量
- 根据网络状况调整音频编码参数
- 及时清理不再使用的 Transcript 数据
- 使用 `DiffUtil` 优化 RecyclerView 更新性能
- 实现 Token 自动刷新机制
- 处理网络断开重连逻辑

### 最佳实践

- 实现完善的错误处理机制，包括网络错误、Token 过期等
- 使用 StateFlow 统一管理 UI 状态
- 将业务逻辑与 UI 分离，使用 ViewModel 管理状态
- 在加入频道前检查并请求麦克风权限
- 正确管理 RTC Engine 和 RTM Client 的生命周期
- 在 Activity/Fragment 销毁时清理资源
- 启用 API 日志以便调试：`enableLog = true`


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
