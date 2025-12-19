# Android 代码示例库

> 快速复制粘贴起步，涵盖常见开发场景

---

## 📋 目录

### 基础示例

1. [RTC 使用示例](#rtc-使用示例)
2. [RTM 使用示例](#rtm-使用示例)
3. [ConversationalAIAPI 集成示例](#conversationalaiapi-集成示例)
4. [初始化 ConversationalAIAPIConfig](#初始化-conversationalaiapiconfig)
5. [音频最佳实践](#音频最佳实践)
6. [监听字幕消息](#监听字幕消息)
7. [监听 Agent 状态](#监听-agent-状态)

### 进阶示例

1. [发送文本消息](#发送文本消息)
2. [发送打断消息](#发送打断消息)
3. [发送图片消息](#发送图片消息)
4. [图片发送成功、失败处理](#图片发送成功失败处理)
5. [声纹回调处理](#声纹回调处理)

---

# 基础示例

## RTC 使用示例

初始化 RTC Engine，配置音频场景和事件监听：

```kotlin
private var rtcEngine: RtcEngineEx? = null

private val rtcEventHandler = object : IRtcEngineEventHandler() {
    override fun onJoinChannelSuccess(channel: String?, uid: Int, elapsed: Int) {
        Log.d(TAG, "RTC joined channel: $channel, uid: $uid")
        // Handle join success
    }

    override fun onUserJoined(uid: Int, elapsed: Int) {
        Log.d(TAG, "User joined the channel, uid: $uid")
    }

    override fun onUserOffline(uid: Int, reason: Int) {
        Log.d(TAG, "User left the channel, uid: $uid, reason: $reason")
    }

    override fun onError(err: Int) {
        Log.e(TAG, "RTC error: $err")
        // Handle error
    }

    override fun onTokenPrivilegeWillExpire(token: String?) {
        Log.d(TAG, "RTC token will expire, need to renew")
        // Renew token
    }
}

private fun initRtcEngine() {
    if (rtcEngine != null) {
        return
    }
    val config = RtcEngineConfig()
    config.mContext = applicationContext
    config.mAppId = "YOUR_APP_ID"
    config.mChannelProfile = Constants.CHANNEL_PROFILE_LIVE_BROADCASTING
    config.mAudioScenario = Constants.AUDIO_SCENARIO_DEFAULT
    config.mEventHandler = rtcEventHandler
    
    try {
        rtcEngine = (RtcEngine.create(config) as RtcEngineEx).apply {
            enableVideo()
            // Load extension providers for AI-QoS
            loadExtensionProvider("ai_echo_cancellation_extension")
            loadExtensionProvider("ai_noise_suppression_extension")
        }
        Log.d(TAG, "RTC Engine initialized successfully")
    } catch (e: Exception) {
        Log.e(TAG, "RTC Engine initialization failed: ${e.message}")
    }
}

// Join RTC channel
private fun joinRtcChannel(token: String, channelName: String, uid: Int) {
    val channelOptions = ChannelMediaOptions().apply {
        clientRoleType = Constants.CLIENT_ROLE_BROADCASTER
        publishMicrophoneTrack = true
        publishCameraTrack = false
        autoSubscribeAudio = true
        autoSubscribeVideo = true
    }
    val ret = rtcEngine?.joinChannel(token, channelName, uid, channelOptions)
    if (ret == Constants.ERR_OK) {
        Log.d(TAG, "Join RTC channel success")
    } else {
        Log.e(TAG, "Join RTC channel failed, ret: $ret")
    }
}

// Leave RTC channel
private fun leaveRtcChannel() {
    rtcEngine?.leaveChannel()
}

// Mute local audio
private fun muteLocalAudio(mute: Boolean) {
    rtcEngine?.adjustRecordingSignalVolume(if (mute) 0 else 100)
}
```

## RTM 使用示例

初始化 RTM Client，处理登录和连接状态：

```kotlin
private var rtmClient: RtmClient? = null
private var isRtmLogin = false

private val rtmEventListener = object : RtmEventListener {
    override fun onLinkStateEvent(event: LinkStateEvent?) {
        event ?: return
        when (event.currentState) {
            RtmConstants.RtmLinkState.CONNECTED -> {
                Log.d(TAG, "RTM connected successfully")
                isRtmLogin = true
            }
            RtmConstants.RtmLinkState.FAILED -> {
                Log.d(TAG, "RTM connection failed")
                isRtmLogin = false
            }
            else -> {
                // Handle other states
            }
        }
    }

    override fun onTokenPrivilegeWillExpire(channelName: String) {
        Log.d(TAG, "RTM token will expire, need to renew")
        // Renew token
    }
}

private fun initRtmClient() {
    if (rtmClient != null) {
        return
    }
    val rtmConfig = RtmConfig.Builder("YOUR_APP_ID", "USER_ID").build()
    try {
        rtmClient = RtmClient.create(rtmConfig)
        rtmClient?.addEventListener(rtmEventListener)
        Log.d(TAG, "RTM Client initialized successfully")
    } catch (e: Exception) {
        Log.e(TAG, "RTM Client initialization failed: ${e.message}")
    }
}

// Login RTM
private fun loginRtm(rtmToken: String, completion: (Exception?) -> Unit) {
    val client = rtmClient ?: run {
        completion.invoke(Exception("RTM client not initialized"))
        return
    }
    
    client.login(rtmToken, object : ResultCallback<Void> {
        override fun onSuccess(p0: Void?) {
            isRtmLogin = true
            Log.d(TAG, "RTM login successful")
            completion.invoke(null)
        }

        override fun onFailure(errorInfo: ErrorInfo?) {
            isRtmLogin = false
            Log.e(TAG, "RTM login failed: ${errorInfo?.errorReason}")
            completion.invoke(Exception("${errorInfo?.errorCode}"))
        }
    })
}

// Logout RTM
private fun logoutRtm() {
    rtmClient?.logout(object : ResultCallback<Void> {
        override fun onSuccess(responseInfo: Void?) {
            isRtmLogin = false
            Log.d(TAG, "RTM logout successful")
        }

        override fun onFailure(errorInfo: ErrorInfo?) {
            Log.e(TAG, "RTM logout failed: ${errorInfo?.errorCode}")
            isRtmLogin = false
        }
    })
}
```

## ConversationalAIAPI 集成示例

完整的 ConversationalAIAPI 集成流程：

```kotlin
private var conversationalAIAPI: IConversationalAIAPI? = null

// Initialize after RTC and RTM are ready
fun initializeConversationalAIAPI() {
    if (rtcEngine != null && rtmClient != null) {
        conversationalAIAPI = ConversationalAIAPIImpl(
            ConversationalAIAPIConfig(
                rtcEngine = rtcEngine!!,
                rtmClient = rtmClient!!,
                enableLog = true
            )
        )
        conversationalAIAPI?.loadAudioSettings(Constants.AUDIO_SCENARIO_AI_CLIENT)
        conversationalAIAPI?.addHandler(conversationalAIAPIEventHandler)
        Log.d(TAG, "ConversationalAIAPI initialized successfully")
    } else {
        Log.e(TAG, "RTC or RTM not initialized")
    }
}

// Subscribe to channel messages
fun subscribeToChannel(channelName: String) {
    conversationalAIAPI?.subscribeMessage(channelName) { errorInfo ->
        if (errorInfo != null) {
            Log.e(TAG, "Subscribe message error: ${errorInfo}")
        } else {
            Log.d(TAG, "Subscribed to channel: $channelName")
        }
    }
}

// Unsubscribe from channel messages
fun unsubscribeFromChannel(channelName: String) {
    conversationalAIAPI?.unsubscribeMessage(channelName) { errorInfo ->
        if (errorInfo != null) {
            Log.e(TAG, "Unsubscribe message error: ${errorInfo}")
        } else {
            Log.d(TAG, "Unsubscribed from channel: $channelName")
        }
    }
}
```

## 初始化 ConversationalAIAPIConfig

配置 ConversationalAIAPI 的各种参数：

```kotlin
// Basic configuration
val config = ConversationalAIAPIConfig(
    rtcEngine = rtcEngine!!,
    rtmClient = rtmClient!!,
    enableLog = true
)

// Configuration with transcript render mode
val configWithRenderMode = ConversationalAIAPIConfig(
    rtcEngine = rtcEngine!!,
    rtmClient = rtmClient!!,
    renderMode = TranscriptRenderMode.Text, // or TranscriptRenderMode.Word
    enableLog = true
)

// Create API instance
val api = ConversationalAIAPIImpl(config)

// Load audio settings for AI client scenario
api.loadAudioSettings(Constants.AUDIO_SCENARIO_AI_CLIENT)

// Add event handler
api.addHandler(conversationalAIAPIEventHandler)
```

## 音频最佳实践

配置音频参数以获得最佳体验：

```kotlin
// Load audio settings for AI client scenario
conversationalAIAPI?.loadAudioSettings(Constants.AUDIO_SCENARIO_AI_CLIENT)

// Adjust recording signal volume (0-100)
rtcEngine?.adjustRecordingSignalVolume(100)

// Enable audio enhancement extensions
rtcEngine?.loadExtensionProvider("ai_echo_cancellation_extension")
rtcEngine?.loadExtensionProvider("ai_noise_suppression_extension")

// Mute/unmute local audio
fun toggleMute(mute: Boolean) {
    rtcEngine?.adjustRecordingSignalVolume(if (mute) 0 else 100)
}
```

## 监听字幕消息

通过事件处理器监听字幕更新：

```kotlin
private val conversationalAIAPIEventHandler = object : IConversationalAIAPIEventHandler {
    override fun onTranscriptUpdated(agentUserId: String, transcript: Transcript) {
        // Handle transcript updates
        // transcript.text contains the subtitle text
        // transcript.type indicates USER or AGENT
        // transcript.turnId is the conversation turn ID
        
        Log.d(TAG, "Transcript updated: ${transcript.text}")
        Log.d(TAG, "Type: ${transcript.type}, TurnId: ${transcript.turnId}")
        
        // Update UI with new transcript
        updateTranscriptUI(transcript)
    }
    
    // ... other handler methods
}

// Add handler to API
conversationalAIAPI?.addHandler(conversationalAIAPIEventHandler)

// Example: Store transcripts in a list
private val transcriptList = mutableListOf<Transcript>()

private fun updateTranscriptUI(transcript: Transcript) {
    // Update existing transcript if same turnId, otherwise add new
    val existingIndex = transcriptList.indexOfFirst { 
        it.turnId == transcript.turnId && it.type == transcript.type 
    }
    if (existingIndex >= 0) {
        transcriptList[existingIndex] = transcript
    } else {
        transcriptList.add(transcript)
    }
    // Notify UI to update
}
```

## 监听 Agent 状态

监听 Agent 状态变化（IDLE, SILENT, LISTENING, THINKING, SPEAKING）：

```kotlin
private val _agentState = MutableStateFlow<AgentState>(AgentState.IDLE)
val agentState: StateFlow<AgentState> = _agentState.asStateFlow()

private val conversationalAIAPIEventHandler = object : IConversationalAIAPIEventHandler {
    override fun onAgentStateChanged(agentUserId: String, event: StateChangeEvent) {
        _agentState.value = event.state
        
        when (event.state) {
            AgentState.IDLE -> {
                Log.d(TAG, "Agent is idle")
            }
            AgentState.SILENT -> {
                Log.d(TAG, "Agent is silent")
            }
            AgentState.LISTENING -> {
                Log.d(TAG, "Agent is listening")
            }
            AgentState.THINKING -> {
                Log.d(TAG, "Agent is thinking")
            }
            AgentState.SPEAKING -> {
                Log.d(TAG, "Agent is speaking")
            }
            AgentState.UNKNOWN -> {
                Log.d(TAG, "Agent state unknown")
            }
        }
        
        // Update UI based on agent state
        updateAgentStateUI(event.state)
    }
    
    // ... other handler methods
}

// Observe agent state in UI
viewModelScope.launch {
    agentState.collect { state ->
        when (state) {
            AgentState.SPEAKING -> {
                // Show speaking indicator
            }
            AgentState.LISTENING -> {
                // Show listening indicator
            }
            // ... handle other states
        }
    }
}
```

---

# 进阶示例

## 发送文本消息

发送文本消息到 Agent，支持优先级和可中断设置：

```kotlin
// Basic text message
fun sendTextMessage(agentUserId: String, text: String) {
    val message = TextMessage(text = text)
    conversationalAIAPI?.chat(agentUserId, message) { error ->
        if (error != null) {
            Log.e(TAG, "Send text message failed: ${error}")
            // Handle error
        } else {
            Log.d(TAG, "Text message sent successfully")
        }
    }
}

// High priority interrupt message
fun sendInterruptMessage(agentUserId: String, text: String) {
    val message = TextMessage(
        priority = Priority.INTERRUPT,
        responseInterruptable = true,
        text = text
    )
    conversationalAIAPI?.chat(agentUserId, message) { error ->
        if (error != null) {
            Log.e(TAG, "Send interrupt message failed: ${error}")
        } else {
            Log.d(TAG, "Interrupt message sent successfully")
        }
    }
}

// Append priority message (queued after current interaction)
fun sendAppendMessage(agentUserId: String, text: String) {
    val message = TextMessage(
        priority = Priority.APPEND,
        text = text
    )
    conversationalAIAPI?.chat(agentUserId, message) { error ->
        if (error != null) {
            Log.e(TAG, "Send append message failed: ${error}")
        } else {
            Log.d(TAG, "Append message sent successfully")
        }
    }
}

// Non-interruptable message
fun sendNonInterruptableMessage(agentUserId: String, text: String) {
    val message = TextMessage(
        priority = Priority.INTERRUPT,
        responseInterruptable = false,
        text = text
    )
    conversationalAIAPI?.chat(agentUserId, message) { error ->
        if (error != null) {
            Log.e(TAG, "Send non-interruptable message failed: ${error}")
        } else {
            Log.d(TAG, "Non-interruptable message sent successfully")
        }
    }
}
```

## 发送打断消息

使用 interrupt 方法立即打断 Agent 的当前响应：

```kotlin
fun interruptAgent(agentUserId: String) {
    conversationalAIAPI?.interrupt(agentUserId) { error ->
        if (error != null) {
            Log.e(TAG, "Interrupt failed: ${error}")
            when (error) {
                is ConversationalAIAPIError.RtmError -> {
                    Log.e(TAG, "RTM error: ${error.errorCode}, ${error.errorReason}")
                }
                is ConversationalAIAPIError.UnknownError -> {
                    Log.e(TAG, "Unknown error: ${error.message}")
                }
            }
        } else {
            Log.d(TAG, "Agent interrupted successfully")
        }
    }
}
```

## 发送图片消息

发送图片消息，支持 URL 和 Base64 两种格式：

```kotlin
// Send image via URL (recommended for large images)
fun sendImageByUrl(agentUserId: String, imageUrl: String) {
    val message = ImageMessage(
        uuid = UUID.randomUUID().toString(),
        imageUrl = imageUrl
    )
    conversationalAIAPI?.chat(agentUserId, message) { error ->
        if (error != null) {
            Log.e(TAG, "Send image failed: ${error}")
            handleImageSendError(error)
        } else {
            Log.d(TAG, "Image sent successfully")
            handleImageSendSuccess(message.uuid)
        }
    }
}

// Send image via Base64 (limited to 32KB total message size)
fun sendImageByBase64(agentUserId: String, imageBase64: String) {
    val message = ImageMessage(
        uuid = UUID.randomUUID().toString(),
        imageBase64 = imageBase64
    )
    conversationalAIAPI?.chat(agentUserId, message) { error ->
        if (error != null) {
            Log.e(TAG, "Send image failed: ${error}")
            handleImageSendError(error)
        } else {
            Log.d(TAG, "Image sent successfully")
            handleImageSendSuccess(message.uuid)
        }
    }
}

// Convert bitmap to base64
fun sendBitmapAsImage(agentUserId: String, bitmap: Bitmap) {
    val outputStream = ByteArrayOutputStream()
    bitmap.compress(Bitmap.CompressFormat.JPEG, 80, outputStream)
    val imageBytes = outputStream.toByteArray()
    val base64Image = android.util.Base64.encodeToString(
        imageBytes,
        android.util.Base64.NO_WRAP
    )
    
    sendImageByBase64(agentUserId, base64Image)
}
```

## 图片发送成功、失败处理

处理图片发送的成功和失败回调：

```kotlin
private val conversationalAIAPIEventHandler = object : IConversationalAIAPIEventHandler {
    // Handle message receipt (success confirmation)
    override fun onMessageReceiptUpdated(agentUserId: String, receipt: MessageReceipt) {
        when (receipt.chatMessageType) {
            ChatMessageType.Image -> {
                when (receipt.type) {
                    ModuleType.CONTEXT -> {
                        // Image upload successful, parse receipt message
                        Log.d(TAG, "Image upload successful: ${receipt.message}")
                        try {
                            // receipt.message is usually a JSON string
                            val jsonObject = JSONObject(receipt.message)
                            val imageUuid = jsonObject.optString("uuid")
                            val imageUrl = jsonObject.optString("image_url")
                            
                            Log.d(TAG, "Image UUID: $imageUuid, URL: $imageUrl")
                            handleImageUploadSuccess(imageUuid, imageUrl)
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to parse receipt: ${e.message}")
                        }
                    }
                    else -> {
                        // Handle other module types
                    }
                }
            }
            else -> {
                // Handle other message types
            }
        }
    }
    
    // Handle message errors (failure)
    override fun onMessageError(agentUserId: String, error: MessageError) {
        when (error.chatMessageType) {
            ChatMessageType.Image -> {
                Log.e(TAG, "Image message error: code=${error.code}, message=${error.message}")
                handleImageSendError(error)
            }
            else -> {
                // Handle other message type errors
            }
        }
    }
    
    // ... other handler methods
}

private fun handleImageUploadSuccess(uuid: String, imageUrl: String?) {
    // Update UI to show image was sent successfully
    // e.g., update message status in chat list
    Log.d(TAG, "Image upload success: uuid=$uuid, url=$imageUrl")
}

private fun handleImageSendError(error: MessageError) {
    // Handle image send error
    // error.code: error code
    // error.message: error description (usually JSON string)
    // error.timestamp: error timestamp
    
    Log.e(TAG, "Image send error: code=${error.code}")
    try {
        val errorJson = JSONObject(error.message)
        val reason = errorJson.optString("reason", "Unknown error")
        Log.e(TAG, "Error reason: $reason")
        
        // Show error to user
        showErrorToUser("Image send failed: $reason")
    } catch (e: Exception) {
        Log.e(TAG, "Failed to parse error message: ${e.message}")
        showErrorToUser("Image send failed")
    }
}

private fun handleImageSendError(error: ConversationalAIAPIError) {
    when (error) {
        is ConversationalAIAPIError.RtmError -> {
            Log.e(TAG, "RTM error: ${error.errorCode}, ${error.errorReason}")
            showErrorToUser("Network error: ${error.errorReason}")
        }
        is ConversationalAIAPIError.UnknownError -> {
            Log.e(TAG, "Unknown error: ${error.message}")
            showErrorToUser("Unknown error: ${error.message}")
        }
    }
}
```

## 声纹回调处理

监听和处理声纹注册成功回调：

```kotlin
private val conversationalAIAPIEventHandler = object : IConversationalAIAPIEventHandler {
    override fun onAgentVoiceprintStateChanged(
        agentUserId: String,
        event: VoiceprintStateChangeEvent
    ) {
        when (event.status) {
            VoiceprintStatus.REGISTER_SUCCESS -> {
                Log.d(TAG, "Voiceprint registration successful")
                // Handle voiceprint registration success
            }
            else -> {
                // Handle other statuses if needed
            }
        }
    }
    
    // ... other handler methods
}
```

---

# 完整示例：ViewModel 集成

完整的 ViewModel 示例，整合所有功能：

```kotlin
class AgentChatViewModel : ViewModel() {
    private var conversationalAIAPI: IConversationalAIAPI? = null
    private var rtcEngine: RtcEngineEx? = null
    private var rtmClient: RtmClient? = null
    
    private val _agentState = MutableStateFlow<AgentState>(AgentState.IDLE)
    val agentState: StateFlow<AgentState> = _agentState.asStateFlow()
    
    private val _transcriptList = MutableStateFlow<List<Transcript>>(emptyList())
    val transcriptList: StateFlow<List<Transcript>> = _transcriptList.asStateFlow()
    
    private val conversationalAIAPIEventHandler = object : IConversationalAIAPIEventHandler {
        override fun onAgentStateChanged(agentUserId: String, event: StateChangeEvent) {
            _agentState.value = event.state
        }
        
        override fun onTranscriptUpdated(agentUserId: String, transcript: Transcript) {
            viewModelScope.launch {
                val currentList = _transcriptList.value.toMutableList()
                val existingIndex = currentList.indexOfFirst { 
                    it.turnId == transcript.turnId && it.type == transcript.type 
                }
                if (existingIndex >= 0) {
                    currentList[existingIndex] = transcript
                } else {
                    currentList.add(transcript)
                }
                _transcriptList.value = currentList
            }
        }
        
        override fun onMessageReceiptUpdated(agentUserId: String, receipt: MessageReceipt) {
            // Handle message receipt
        }
        
        override fun onMessageError(agentUserId: String, error: MessageError) {
            // Handle message error
        }
        
        override fun onAgentVoiceprintStateChanged(
            agentUserId: String,
            event: VoiceprintStateChangeEvent
        ) {
            // Handle voiceprint state change
        }
        
        // ... implement other required methods
    }
    
    fun initializeAPI() {
        // Initialize RTC and RTM first, then create API
        if (rtcEngine != null && rtmClient != null) {
            conversationalAIAPI = ConversationalAIAPIImpl(
                ConversationalAIAPIConfig(
                    rtcEngine = rtcEngine!!,
                    rtmClient = rtmClient!!,
                    enableLog = true
                )
            )
            conversationalAIAPI?.loadAudioSettings(Constants.AUDIO_SCENARIO_AI_CLIENT)
            conversationalAIAPI?.addHandler(conversationalAIAPIEventHandler)
        }
    }
    
    fun sendTextMessage(agentUserId: String, text: String) {
        val message = TextMessage(text = text)
        conversationalAIAPI?.chat(agentUserId, message) { error ->
            if (error != null) {
                Log.e(TAG, "Send text failed: ${error}")
            }
        }
    }
    
    fun sendImageMessage(agentUserId: String, imageUrl: String) {
        val message = ImageMessage(
            uuid = UUID.randomUUID().toString(),
            imageUrl = imageUrl
        )
        conversationalAIAPI?.chat(agentUserId, message) { error ->
            if (error != null) {
                Log.e(TAG, "Send image failed: ${error}")
            }
        }
    }
    
    fun interruptAgent(agentUserId: String) {
        conversationalAIAPI?.interrupt(agentUserId) { error ->
            if (error != null) {
                Log.e(TAG, "Interrupt failed: ${error}")
            }
        }
    }
}
```

---

**相关文档**:

- [README.md](./README.md) - 快速开始指南
- [STARTUP_GUIDE.md](./STARTUP_GUIDE.md) - 启动指南
