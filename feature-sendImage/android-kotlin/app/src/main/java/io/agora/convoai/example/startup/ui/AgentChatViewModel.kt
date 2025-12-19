package io.agora.convoai.example.startup.ui

import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.agora.convoai.example.startup.AgentApp
import io.agora.convoai.example.startup.KeyCenter
import io.agora.convoai.example.startup.api.AgentStarter
import io.agora.convoai.example.startup.api.TokenGenerator
import io.agora.rtc2.Constants
import io.agora.rtc2.Constants.CLIENT_ROLE_BROADCASTER
import io.agora.rtc2.Constants.ERR_OK
import io.agora.rtc2.ChannelMediaOptions
import io.agora.rtc2.IRtcEngineEventHandler
import io.agora.rtc2.RtcEngine
import io.agora.rtc2.RtcEngineConfig
import io.agora.rtc2.RtcEngineEx
import io.agora.rtm.ErrorInfo
import io.agora.rtm.LinkStateEvent
import io.agora.rtm.PresenceEvent
import io.agora.rtm.ResultCallback
import io.agora.rtm.RtmClient
import io.agora.rtm.RtmConfig
import io.agora.rtm.RtmConstants
import io.agora.rtm.RtmEventListener
import io.agora.convoai.convoaiApi.AgentState
import io.agora.convoai.convoaiApi.ConversationalAIAPIConfig
import io.agora.convoai.convoaiApi.ConversationalAIAPIImpl
import io.agora.convoai.convoaiApi.IConversationalAIAPI
import io.agora.convoai.convoaiApi.IConversationalAIAPIEventHandler
import io.agora.convoai.convoaiApi.InterruptEvent
import io.agora.convoai.convoaiApi.MessageError
import io.agora.convoai.convoaiApi.MessageReceipt
import io.agora.convoai.convoaiApi.Metric
import io.agora.convoai.convoaiApi.ModuleError
import io.agora.convoai.convoaiApi.StateChangeEvent
import io.agora.convoai.convoaiApi.Transcript
import io.agora.convoai.convoaiApi.TranscriptRenderMode
import io.agora.convoai.convoaiApi.TranscriptStatus
import io.agora.convoai.convoaiApi.TranscriptType
import io.agora.convoai.convoaiApi.VoiceprintStateChangeEvent
import io.agora.convoai.convoaiApi.TextMessage
import io.agora.convoai.convoaiApi.ImageMessage
import io.agora.convoai.convoaiApi.Priority
import io.agora.convoai.convoaiApi.ConversationalAIAPIError
import io.agora.convoai.convoaiApi.ModuleType
import io.agora.convoai.convoaiApi.ChatMessageType
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import org.json.JSONObject

/**
 * ViewModel for managing conversation-related business logic
 */
class AgentChatViewModel : ViewModel() {

    companion object {
        private const val TAG = "ConversationViewModel"
        const val userId = 1001086
        const val agentUid = 1009527

        /**
         * Generate a random channel name
         */
        fun generateRandomChannelName(): String {
            return "channel_kotlin_${(1000..9999).random()}"
        }
    }

    /**
     * Connection state enum
     */
    enum class ConnectionState {
        Idle,
        Connecting,
        Connected,
        Error
    }

    // UI State - shared between AgentHomeFragment and VoiceAssistantFragment
    data class ConversationUiState constructor(
        val isMuted: Boolean = false,
        // Connection state
        val connectionState: ConnectionState = ConnectionState.Idle
    )

    private val _uiState = MutableStateFlow(ConversationUiState())
    val uiState: StateFlow<ConversationUiState> = _uiState.asStateFlow()

    // Transcript list - separate from UI state
    private val _transcriptList = MutableStateFlow<List<Transcript>>(emptyList())
    val transcriptList: StateFlow<List<Transcript>> = _transcriptList.asStateFlow()

    private val _agentState = MutableStateFlow<AgentState>(AgentState.IDLE)
    val agentState: StateFlow<AgentState?> = _agentState.asStateFlow()

    // Debug log list - for displaying logs in UI
    private val _debugLogList = MutableStateFlow<List<String>>(emptyList())
    val debugLogList: StateFlow<List<String>> = _debugLogList.asStateFlow()

    // Picture info for image message success
    data class PictureInfo(
        val uuid: String,
        val width: Int = 0,
        val height: Int = 0,
        val sizeBytes: Long = 0L,
        val sourceType: String = "",
        val sourceValue: String = "",
        val uploadTime: Long = 0L,
        val totalUserImages: Int = 0
    )

    // Picture error for image message failure
    data class PictureError(
        val uuid: String,
        val success: Boolean = true,
        val errorCode: Int? = null,
        val errorMessage: String? = null
    )

    private val _mediaInfoUpdate = MutableStateFlow<PictureInfo?>(null)
    val mediaInfoUpdate: StateFlow<PictureInfo?> = _mediaInfoUpdate.asStateFlow()

    private val _resourceError = MutableStateFlow<PictureError?>(null)
    val resourceError: StateFlow<PictureError?> = _resourceError.asStateFlow()

    private var unifiedToken: String? = null

    private var conversationalAIAPI: IConversationalAIAPI? = null

    private var channelName: String = ""

    private var rtcJoined = false
    private var rtmLoggedIn = false

    // Agent management
    private var agentId: String? = null

    // RTC and RTM instances
    private var rtcEngine: RtcEngineEx? = null
    private var rtmClient: RtmClient? = null
    private var isRtmLogin = false
    private var isLoggingIn = false
    private val rtcEventHandler = object : IRtcEngineEventHandler() {
        override fun onJoinChannelSuccess(channel: String?, uid: Int, elapsed: Int) {
            viewModelScope.launch {
                rtcJoined = true
                addStatusLog("Rtc onJoinChannelSuccess, channel:${channel} uid:$uid")
                Log.d(TAG, "RTC joined channel: $channel, uid: $uid")
                checkJoinAndLoginComplete()
            }
        }

        override fun onLeaveChannel(stats: RtcStats?) {
            super.onLeaveChannel(stats)
            viewModelScope.launch {
                addStatusLog("Rtc onLeaveChannel")
            }
        }

        override fun onUserJoined(uid: Int, elapsed: Int) {
            viewModelScope.launch {
                addStatusLog("Rtc onUserJoined, uid:$uid")
                if (uid == agentUid) {
                    Log.d(TAG, "Agent joined the channel, uid: $uid")
                } else {
                    Log.d(TAG, "User joined the channel, uid: $uid")
                }
            }
        }

        override fun onUserOffline(uid: Int, reason: Int) {
            viewModelScope.launch {
                addStatusLog("Rtc onUserOffline, uid:$uid")
                if (uid == agentUid) {
                    Log.d(TAG, "Agent left the channel, uid: $uid, reason: $reason")
                } else {
                    Log.d(TAG, "User left the channel, uid: $uid, reason: $reason")
                }
            }
        }

        override fun onError(err: Int) {
            viewModelScope.launch {
                _uiState.value = _uiState.value.copy(
                    connectionState = ConnectionState.Error
                )
                addStatusLog("Rtc onError: $err")
                Log.e(TAG, "RTC error: $err")
            }
        }

        override fun onTokenPrivilegeWillExpire(token: String?) {
            Log.d(TAG, "RTC onTokenPrivilegeWillExpire $channelName")
        }
    }

    // RTM event listener
    private val rtmEventListener = object : RtmEventListener {
        override fun onLinkStateEvent(event: LinkStateEvent?) {
            super.onLinkStateEvent(event)
            event ?: return

            Log.d(TAG, "Rtm link state changed: ${event.currentState}")

            when (event.currentState) {
                RtmConstants.RtmLinkState.CONNECTED -> {
                    Log.d(TAG, "Rtm connected successfully")
                    isRtmLogin = true
                    addStatusLog("Rtm connected successfully")
                }

                RtmConstants.RtmLinkState.FAILED -> {
                    Log.d(TAG, "RTM connection failed, need to re-login")
                    isRtmLogin = false
                    isLoggingIn = false
                    viewModelScope.launch {
                        _uiState.value = _uiState.value.copy(
                            connectionState = ConnectionState.Error
                        )
                        addStatusLog("Rtm connected failed")
                        unifiedToken = null
                    }
                }

                else -> {
                    // nothing
                }
            }
        }

        override fun onTokenPrivilegeWillExpire(channelName: String) {
            Log.d(TAG, "RTM onTokenPrivilegeWillExpire $channelName")
        }

        override fun onPresenceEvent(event: PresenceEvent) {
            super.onPresenceEvent(event)
            // Handle presence events if needed
        }
    }

    private val conversationalAIAPIEventHandler = object : IConversationalAIAPIEventHandler {
        override fun onAgentStateChanged(agentUserId: String, event: StateChangeEvent) {
            _agentState.value = event.state
        }

        override fun onAgentInterrupted(agentUserId: String, event: InterruptEvent) {
            // Handle interruption

        }

        override fun onAgentMetrics(agentUserId: String, metric: Metric) {
            // Handle metrics
        }

        override fun onAgentError(agentUserId: String, error: ModuleError) {
            // Handle agent error
        }

        override fun onMessageError(agentUserId: String, error: MessageError) {
            // Handle message error
            if (error.chatMessageType == ChatMessageType.Image) {
                try {
                    val json = JSONObject(error.message)
                    val errorObj = json.optJSONObject("error")
                    val pictureError = PictureError(
                        uuid = json.optString("uuid"),
                        success = json.optBoolean("success", true),
                        errorCode = errorObj?.optInt("code"),
                        errorMessage = errorObj?.optString("message")
                    )
                    _resourceError.value = pictureError
                    Log.e(TAG, "Image message error: ${pictureError.errorMessage} (code: ${pictureError.errorCode})")
                } catch (e: Exception) {
                    Log.e(TAG, "onMessageError: Failed to parse error message JSON: ${e.message}")
                }
            }
        }

        override fun onTranscriptUpdated(agentUserId: String, transcript: Transcript) {
            // Handle transcript updates with typing animation for agent messages
            addTranscript(transcript)
        }

        override fun onMessageReceiptUpdated(agentUserId: String, receipt: MessageReceipt) {
            // Handle message receipt
            if (receipt.type == ModuleType.Context && receipt.chatMessageType == ChatMessageType.Image) {
                try {
                    val json = JSONObject(receipt.message)
                    val pictureInfo = PictureInfo(
                        uuid = json.optString("uuid"),
                        width = json.optInt("width"),
                        height = json.optInt("height"),
                        sizeBytes = json.optLong("size_bytes"),
                        sourceType = json.optString("source_type"),
                        sourceValue = json.optString("source_value"),
                        uploadTime = json.optLong("upload_time"),
                        totalUserImages = json.optInt("total_user_images")
                    )
                    _mediaInfoUpdate.value = pictureInfo
                    Log.d(TAG, "Image message sent successfully: uuid=${pictureInfo.uuid}")
                } catch (e: Exception) {
                    Log.e(TAG, "onMessageReceiptUpdated: Failed to parse message JSON: ${e.message}")
                }
            }
        }

        override fun onAgentVoiceprintStateChanged(agentUserId: String, event: VoiceprintStateChangeEvent) {
            // Update voice print state to notify Activity

        }

        override fun onDebugLog(log: String) {
            // Only log to system log, don't collect for UI display
            // UI will only show ViewModel status messages (statusMessage)
            Log.d("conversationalAIAPI", log)
        }
    }

    init {
        // Create RTC engine and RTM client during initialization
        Log.d(TAG, "Initializing RTC engine and RTM client...")
        // Init RTC engine
        initRtcEngine()
        // Init RTM client
        initRtmClient()
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
            Log.d(TAG, "RTC engine and RTM client created successfully")
        } else {
            Log.e(TAG, "Failed to create RTC engine or RTM client")
            _uiState.value = _uiState.value.copy(
                connectionState = ConnectionState.Error
            )
        }
    }

    /**
     * Init RTC engine
     */
    private fun initRtcEngine() {
        if (rtcEngine != null) {
            return
        }
        val config = RtcEngineConfig()
        config.mContext = AgentApp.instance()
        config.mAppId = KeyCenter.AGORA_APP_ID
        config.mChannelProfile = Constants.CHANNEL_PROFILE_LIVE_BROADCASTING
        config.mAudioScenario = Constants.AUDIO_SCENARIO_DEFAULT
        config.mEventHandler = rtcEventHandler
        try {
            rtcEngine = (RtcEngine.create(config) as RtcEngineEx).apply {
                enableVideo()
                // load extension provider for AI-QoS
                loadExtensionProvider("ai_echo_cancellation_extension")
                loadExtensionProvider("ai_noise_suppression_extension")
            }
            Log.d(TAG, "initRtcEngine success")
            Log.d(TAG, "current sdk version: ${RtcEngine.getSdkVersion()}")
            addStatusLog("RtcEngine init successfully")
        } catch (e: Exception) {
            Log.e(TAG, "initRtcEngine error: $e")
            addStatusLog("RtcEngine init failed")
        }
    }

    /**
     * Init RTM client
     */
    private fun initRtmClient() {
        if (rtmClient != null) {
            return
        }

        val rtmConfig = RtmConfig.Builder(KeyCenter.AGORA_APP_ID, userId.toString()).build()
        try {
            rtmClient = RtmClient.create(rtmConfig)
            rtmClient?.addEventListener(rtmEventListener)
            Log.d(TAG, "RTM initRtmClient successfully")
            addStatusLog("RtmClient init successfully")
        } catch (e: Exception) {
            Log.e(TAG, "RTM initRtmClient error: ${e.message}")
            e.printStackTrace()
            addStatusLog("RtmClient init failed")
        }
    }

    /**
     * Login RTM
     */
    private fun loginRtm(rtmToken: String, completion: (Exception?) -> Unit) {
        Log.d(TAG, "Starting RTM login")

        if (isLoggingIn) {
            completion.invoke(Exception("Login already in progress"))
            Log.d(TAG, "Login already in progress")
            return
        }

        if (isRtmLogin) {
            completion.invoke(null) // Already logged in
            Log.d(TAG, "Already logged in")
            return
        }

        val client = this.rtmClient ?: run {
            completion.invoke(Exception("RTM client not initialized"))
            Log.d(TAG, "RTM client not initialized")
            return
        }

        isLoggingIn = true
        Log.d(TAG, "Performing logout to ensure clean environment before login")

        // Force logout first (synchronous flag update)
        isRtmLogin = false
        client.logout(object : ResultCallback<Void> {
            override fun onSuccess(responseInfo: Void?) {
                Log.d(TAG, "Logout completed, starting login")
                performRtmLogin(client, rtmToken, completion)
            }

            override fun onFailure(errorInfo: ErrorInfo?) {
                Log.d(TAG, "Logout failed but continuing with login: ${errorInfo?.errorReason}")
                performRtmLogin(client, rtmToken, completion)
            }
        })
    }

    private fun performRtmLogin(client: RtmClient, rtmToken: String, completion: (Exception?) -> Unit) {
        client.login(rtmToken, object : ResultCallback<Void> {
            override fun onSuccess(p0: Void?) {
                isRtmLogin = true
                isLoggingIn = false
                Log.d(TAG, "RTM login successful")
                completion.invoke(null)
                addStatusLog("Rtm login successful")
            }

            override fun onFailure(errorInfo: ErrorInfo?) {
                isRtmLogin = false
                isLoggingIn = false
                Log.e(TAG, "RTM token login failed: ${errorInfo?.errorReason}")
                completion.invoke(Exception("${errorInfo?.errorCode}"))
                addStatusLog("Rtm login failed, code: ${errorInfo?.errorCode}")
            }
        })
    }

    /**
     * Logout RTM
     */
    private fun logoutRtm() {
        Log.d(TAG, "RTM start logout")
        rtmClient?.logout(object : ResultCallback<Void> {
            override fun onSuccess(responseInfo: Void?) {
                isRtmLogin = false
                Log.d(TAG, "RTM logout successful")
            }

            override fun onFailure(errorInfo: ErrorInfo?) {
                Log.e(TAG, "RTM logout failed: ${errorInfo?.errorCode}")
                // Still mark as logged out since we attempted logout
                isRtmLogin = false
            }
        })
    }

    /**
     * Join RTC channel
     */
    private fun joinRtcChannel(rtcToken: String, channelName: String, uid: Int) {
        Log.d(TAG, "joinChannel channelName: $channelName, localUid: $uid")
        // join rtc channel
        val channelOptions = ChannelMediaOptions().apply {
            clientRoleType = CLIENT_ROLE_BROADCASTER
            publishMicrophoneTrack = true
            publishCameraTrack = false
            autoSubscribeAudio = true
            autoSubscribeVideo = true
        }
        val ret = rtcEngine?.joinChannel(rtcToken, channelName, uid, channelOptions)
        Log.d(TAG, "Joining RTC channel: $channelName, uid: $uid")
        if (ret == ERR_OK) {
            Log.d(TAG, "Join RTC room success")
        } else {
            Log.e(TAG, "Join RTC room failed, ret: $ret")
            addStatusLog("Rtc joinChannel failed ret: $ret")
        }
    }

    /**
     * Leave RTC channel
     */
    private fun leaveRtcChannel() {
        Log.d(TAG, "leaveChannel")
        rtcEngine?.leaveChannel()
    }

    /**
     * Mute local audio
     */
    private fun muteLocalAudio(mute: Boolean) {
        Log.d(TAG, "muteLocalAudio $mute")
        rtcEngine?.adjustRecordingSignalVolume(if (mute) 0 else 100)
    }

    /**
     * Check if both RTC and RTM are connected, then start agent
     */
    private fun checkJoinAndLoginComplete() {
        if (rtcJoined && rtmLoggedIn) {
            startAgent()
        }
    }

    /**
     * Start agent (called automatically after RTC and RTM are connected)
     */
    fun startAgent() {
        viewModelScope.launch {
            if (agentId != null) {
                Log.d(TAG, "Agent already started, agentId: $agentId")
                return@launch
            }

            // Generate token for agent (always required)
            val tokenResult = TokenGenerator.generateTokensAsync(
                channelName = channelName,
                uid = agentUid.toString()
            )

            val agentToken = tokenResult.fold(
                onSuccess = { token ->
                    addStatusLog("Generate agent token successfully")
                    token
                },
                onFailure = { exception ->
                    _uiState.value = _uiState.value.copy(
                        connectionState = ConnectionState.Error
                    )
                    addStatusLog("Generate agent token failed")
                    Log.e(TAG, "Failed to generate agent token: ${exception.message}", exception)
                    return@launch
                }
            )


            val startAgentResult = AgentStarter.startAgentAsync(
                channelName = channelName,
                agentRtcUid = agentUid.toString(),
                token = agentToken
            )
            startAgentResult.fold(
                onSuccess = { agentId ->
                    this@AgentChatViewModel.agentId = agentId
                    _uiState.value = _uiState.value.copy(
                        connectionState = ConnectionState.Connected
                    )
                    addStatusLog("Agent start successfully")
                    Log.d(TAG, "Agent started successfully, agentId: $agentId")
                },
                onFailure = { exception ->
                    _uiState.value = _uiState.value.copy(
                        connectionState = ConnectionState.Error
                    )
                    addStatusLog("Agent start failed")
                    Log.e(TAG, "Failed to start agent: ${exception.message}", exception)
                }
            )
        }
    }

    /**
     * Generate unified token for RTC and RTM
     *
     * @return Token string on success, null on failure
     */
    private suspend fun generateUserToken(): String? {
        // Get unified token for both RTC and RTM
        val tokenResult = TokenGenerator.generateTokensAsync(
            channelName = "",
            uid = userId.toString(),
        )

        return tokenResult.fold(
            onSuccess = { token ->
                addStatusLog("Generate user token successfully")
                unifiedToken = token
                token
            },
            onFailure = { exception ->
                _uiState.value = _uiState.value.copy(
                    connectionState = ConnectionState.Error
                )
                addStatusLog("Generate user token failed")
                Log.e(TAG, "Failed to get token: ${exception.message}", exception)
                null
            }
        )
    }

    /**
     * Join RTC channel and login RTM
     * @param channelName Channel name to join
     */
    fun joinChannelAndLogin(channelName: String) {
        viewModelScope.launch {
            this@AgentChatViewModel.channelName = channelName
            rtcJoined = false
            rtmLoggedIn = false

            _uiState.value = _uiState.value.copy(
                connectionState = ConnectionState.Connecting
            )

            // Get token if not available, otherwise use existing token
            val token = unifiedToken ?: generateUserToken() ?: return@launch

            // Join RTC channel with the unified token
            joinRtcChannel(token, channelName, userId)

            // Login RTM with the same unified token
            loginRtm(token) { exception ->
                viewModelScope.launch {
                    if (exception == null) {
                        rtmLoggedIn = true
                        conversationalAIAPI?.subscribeMessage(channelName) { errorInfo ->
                            if (errorInfo != null) {
                                Log.e(TAG, "Subscribe message error: ${errorInfo}")
                            }
                        }
                        checkJoinAndLoginComplete()
                    } else {
                        _uiState.value = _uiState.value.copy(
                            connectionState = ConnectionState.Error
                        )
                        Log.e(TAG, "RTM login failed: ${exception.message}", exception)
                    }
                }
            }

        }
    }

    /**
     * Toggle microphone mute state
     */
    fun toggleMute() {
        val newMuteState = !_uiState.value.isMuted
        _uiState.value = _uiState.value.copy(
            isMuted = newMuteState
        )
        muteLocalAudio(newMuteState)
        Log.d(TAG, "Microphone muted: $newMuteState")
    }

    /**
     * Send image message to agent
     * @param uuid Unique identifier for the image message (required)
     * @param imageUrl HTTP/HTTPS URL pointing to an image file (optional, mutually exclusive with imageBase64)
     * @param imageBase64 Base64 encoded image data (optional, mutually exclusive with imageUrl, limited to 32KB total message size)
     * @param completion Callback with error if sending fails, null if successful
     */
    fun sendImageMessage(
        uuid: String,
        imageUrl: String? = null,
        imageBase64: String? = null,
        completion: (error: ConversationalAIAPIError?) -> Unit
    ) {
        if (_uiState.value.connectionState != ConnectionState.Connected) {
            Log.w(TAG, "Cannot send image message: not connected to agent")
            completion.invoke(ConversationalAIAPIError.UnknownError("Please connect to agent first"))
            return
        }

        // Clear previous error for this uuid if exists
        val resourceError = _resourceError.value
        if ((resourceError is PictureError) && resourceError.uuid == uuid) {
            _resourceError.value = null
        }

        val imageMessage = ImageMessage(
            uuid = uuid,
            imageUrl = imageUrl,
            imageBase64 = imageBase64
        )

        conversationalAIAPI?.chat(agentUid.toString(), imageMessage) { error: ConversationalAIAPIError? ->
            if (error != null) {
                Log.e(TAG, "Send image message failed: ${error.message}")
                addStatusLog("Send image message failed: ${error.message}")
            } else {
                Log.d(TAG, "Image message sent successfully: uuid=$uuid")
                addStatusLog("Image message sent successfully")
            }
            completion.invoke(error)
        }
    }

    /**
     * Add a new transcript to the list
     */
    fun addTranscript(transcript: Transcript) {
        viewModelScope.launch {
            val currentList = _transcriptList.value.toMutableList()
            // Update existing transcript if same turnId, otherwise add new
            val existingIndex =
                currentList.indexOfFirst { it.turnId == transcript.turnId && it.type == transcript.type }
            if (existingIndex >= 0) {
                currentList[existingIndex] = transcript
            } else {
                currentList.add(transcript)
            }
            _transcriptList.value = currentList
        }
    }

    /**
     * Add image message to transcript list (not sorted by turnId, just append to end)
     * @param imageUrl The image URL to display
     * @param uuid The UUID of the image message
     */
    fun addImageMessageToTranscript(imageUrl: String, uuid: String) {
        viewModelScope.launch {
            val currentList = _transcriptList.value.toMutableList()
            // Create a new transcript for the image message
            // Use current timestamp as turnId to ensure uniqueness
            val imageTranscript = Transcript(
                turnId = System.currentTimeMillis(),
                userId = userId.toString(),
                text = imageUrl, // Store image URL in text field
                status = TranscriptStatus.END,
                type = TranscriptType.USER,
                renderMode = TranscriptRenderMode.Text
            )
            // Add to end of list (not sorted by turnId)
            currentList.add(imageTranscript)
            _transcriptList.value = currentList
            Log.d(TAG, "Image message added to transcript: $imageUrl")
        }
    }

    /**
     * Clear media info update to avoid duplicate processing
     */
    fun clearMediaInfoUpdate() {
        _mediaInfoUpdate.value = null
    }

    /**
     * Clear resource error to avoid duplicate processing
     */
    fun clearResourceError() {
        _resourceError.value = null
    }

    /**
     * Add a status message to debug log list
     * This is used to track ViewModel state changes that are shown via SnackbarHelper
     */
    private fun addStatusLog(message: String) {
        if (message.isEmpty()) return
        viewModelScope.launch {
            val currentLogs = _debugLogList.value.toMutableList()
            currentLogs.add(message)
            // Keep only last 100 logs to avoid memory issues
            if (currentLogs.size > 20) {
                currentLogs.removeAt(0)
            }
            _debugLogList.value = currentLogs
        }
    }

    /**
     * Hang up and cleanup connections
     */
    fun hangup() {
        viewModelScope.launch {
            try {
                conversationalAIAPI?.unsubscribeMessage(channelName) { errorInfo ->
                    if (errorInfo != null) {
                        Log.e(TAG, "Unsubscribe message error: ${errorInfo}")
                    }
                }

                // Stop agent if it was started
                if (agentId != null) {
                    val stopResult = AgentStarter.stopAgentAsync(
                        agentId = agentId!!
                    )
                    stopResult.fold(
                        onSuccess = {
                            Log.d(TAG, "Agent stopped successfully")
                            addStatusLog("Agent stopped successfully")
                        },
                        onFailure = { exception ->
                            Log.e(TAG, "Failed to stop agent: ${exception.message}", exception)
                        }
                    )
                    agentId = null
                }

                leaveRtcChannel()
                rtcJoined = false
                _uiState.value = _uiState.value.copy(
                    connectionState = ConnectionState.Idle
                )
                _transcriptList.value = emptyList()
                _agentState.value = AgentState.IDLE
                Log.d(TAG, "Hangup completed")
            } catch (e: Exception) {
                Log.e(TAG, "Error during hangup: ${e.message}", e)
            }
        }
    }

    override fun onCleared() {
        super.onCleared()
        leaveRtcChannel()
        logoutRtm()

        // Cleanup RTM client
        rtmClient?.let { client ->
            try {
                client.removeEventListener(rtmEventListener)
            } catch (e: Exception) {
                Log.e(TAG, "Error removing RTM event listener: ${e.message}")
            }
        }

        // Note: RtcEngine.destroy() should be called carefully as it's a global operation
        // Consider managing RTC engine lifecycle at Application level
        rtcEngine = null
        rtmClient = null
    }
}

