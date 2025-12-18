package io.agora.convoai.example.startup.ui

import android.util.Log
import android.view.View
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import io.agora.convoai.example.startup.AgentApp
import io.agora.convoai.example.startup.KeyCenter
import io.agora.convoai.example.startup.api.TokenGenerator
import io.agora.rtc2.Constants
import io.agora.rtc2.Constants.CLIENT_ROLE_BROADCASTER
import io.agora.rtc2.Constants.ERR_OK
import io.agora.rtc2.ChannelMediaOptions
import io.agora.rtc2.IRtcEngineEventHandler
import io.agora.rtc2.RtcEngine
import io.agora.rtc2.RtcEngineConfig
import io.agora.rtc2.RtcEngineEx
import io.agora.rtc2.video.VideoCanvas
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
import io.agora.convoai.convoaiApi.VoiceprintStateChangeEvent
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/**
 * ViewModel for managing conversation-related business logic
 */
class AgentChatViewModel : ViewModel() {

    companion object {
        private const val TAG = "ConversationViewModel"

        // Default UID values - single source of truth
        const val DEFAULT_USER_UID = 1001
        const val DEFAULT_AGENT_UID = 2001
        const val DEFAULT_CHANNEL_NAME = "channel_vision_001"

        /**
         * Generate a random channel name
         */
        fun generateRandomChannelName(): String {
            return "channel_kotlin_${(1000..9999).random()}"
        }
    }

    // UIDs - initialized with default values
    private var userId: Int = DEFAULT_USER_UID
    private var agentUid: Int = DEFAULT_AGENT_UID
    
    // SharedPreferences keys
    private val prefs by lazy {
        AgentApp.instance().getSharedPreferences("uid_prefs", android.content.Context.MODE_PRIVATE)
    }
    private val kSavedChannelName = "saved_channel_name"
    private val kSavedUserId = "saved_user_id"
    private val kSavedAgentUid = "saved_agent_uid"

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
        // Camera state for vision feature
        val isCameraOn: Boolean = true,
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

    private var unifiedToken: String? = null

    private var conversationalAIAPI: IConversationalAIAPI? = null

    private var channelName: String = ""

    private var rtcJoined = false
    private var rtmLoggedIn = false


    // Local video view reference for vision feature
    private var localVideoView: View? = null

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
        }

        override fun onTranscriptUpdated(agentUserId: String, transcript: Transcript) {
            // Handle transcript updates with typing animation for agent messages
            addTranscript(transcript)
        }

        override fun onMessageReceiptUpdated(agentUserId: String, receipt: MessageReceipt) {
            // Handle message receipt
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
     * For vision feature: publishCameraTrack = true, autoSubscribeVideo = false
     */
    private fun joinRtcChannel(rtcToken: String, channelName: String, uid: Int) {
        Log.d(TAG, "joinChannel channelName: $channelName, localUid: $uid")
        // join rtc channel
        val channelOptions = ChannelMediaOptions().apply {
            clientRoleType = CLIENT_ROLE_BROADCASTER
            publishMicrophoneTrack = true
            // Enable camera track for vision feature
            publishCameraTrack = true
            autoSubscribeAudio = true
            // No need to subscribe remote video for vision AI
            autoSubscribeVideo = false
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
     * Check if both RTC and RTM are connected, then update connection state
     */
    private fun checkJoinAndLoginComplete() {
        if (rtcJoined && rtmLoggedIn) {
            _uiState.value = _uiState.value.copy(
                connectionState = ConnectionState.Connected
            )
            addStatusLog("RTC and RTM connected successfully")
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
     * @param userId User UID (required)
     * @param agentUid Agent UID (required)
     */
    fun joinChannelAndLogin(
        channelName: String,
        userId: Int?,
        agentUid: Int?
    ) {
        // Validate UIDs
        if (userId == null || userId <= 0) {
            addStatusLog("ERROR: 用户UID不能为空")
            _uiState.value = _uiState.value.copy(
                connectionState = ConnectionState.Error
            )
            return
        }
        if (agentUid == null || agentUid <= 0) {
            addStatusLog("ERROR: Agent UID不能为空")
            _uiState.value = _uiState.value.copy(
                connectionState = ConnectionState.Error
            )
            return
        }
        
        // Set UIDs
        this.userId = userId
        this.agentUid = agentUid
        
        // Save channel name and UIDs for next time
        saveChannelNameAndUIDs()
        
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
            joinRtcChannel(token, channelName, this@AgentChatViewModel.userId)

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
     * Setup local video preview for vision feature
     * @param view The view to render local video
     */
    fun setupLocalVideo(view: View) {
        localVideoView = view
        rtcEngine?.let { engine ->
            engine.startPreview()
            val videoCanvas = VideoCanvas(view, VideoCanvas.RENDER_MODE_HIDDEN, 0)
            engine.setupLocalVideo(videoCanvas)
            Log.d(TAG, "Local video preview setup completed")
            addStatusLog("Local video preview started")
        }
    }

    /**
     * Toggle camera on/off for vision feature
     */
    fun toggleVideo() {
        val newCameraState = !_uiState.value.isCameraOn
        _uiState.value = _uiState.value.copy(
            isCameraOn = newCameraState
        )

        rtcEngine?.let { engine ->
            if (newCameraState) {
                engine.startPreview()
                engine.muteLocalVideoStream(false)
                Log.d(TAG, "Camera turned ON")
            } else {
                engine.stopPreview()
                engine.muteLocalVideoStream(true)
                Log.d(TAG, "Camera turned OFF")
            }
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
     * Load saved channel name and UIDs from SharedPreferences
     */
    fun loadSavedChannelNameAndUIDs(): Pair<String?, Pair<Int?, Int?>> {
        val savedChannelName = prefs.getString(kSavedChannelName, null)?.takeIf { it.isNotEmpty() }
        val savedUserId = if (prefs.getInt(kSavedUserId, 0) > 0) prefs.getInt(kSavedUserId, 0) else null
        val savedAgentUid = if (prefs.getInt(kSavedAgentUid, 0) > 0) prefs.getInt(kSavedAgentUid, 0) else null
        return Pair(savedChannelName, Pair(savedUserId, savedAgentUid))
    }
    
    /**
     * Load saved UIDs from SharedPreferences (for backward compatibility)
     */
    fun loadSavedUIDs(): Pair<Int?, Int?> {
        val (_, uids) = loadSavedChannelNameAndUIDs()
        return uids
    }
    
    /**
     * Save channel name and UIDs to SharedPreferences
     */
    private fun saveChannelNameAndUIDs() {
        prefs.edit().apply {
            channelName.takeIf { it.isNotEmpty() }?.let { putString(kSavedChannelName, it) }
            putInt(kSavedUserId, userId)
            putInt(kSavedAgentUid, agentUid)
            apply()
        }
    }
    
    /**
     * Add a status message to debug log list
     * This is used to track ViewModel state changes that are shown via SnackbarHelper
     */
    fun addStatusLog(message: String) {
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

                // Stop video preview and cleanup local video
                rtcEngine?.stopPreview()
                localVideoView = null

                leaveRtcChannel()
                rtcJoined = false
                _uiState.value = _uiState.value.copy(
                    connectionState = ConnectionState.Idle,
                    isCameraOn = true  // Reset camera state
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

