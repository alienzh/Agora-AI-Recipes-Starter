package io.agora.convoai.example.startup.ui;

import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import androidx.lifecycle.LiveData;
import androidx.lifecycle.MutableLiveData;
import androidx.lifecycle.ViewModel;

import io.agora.convoai.convoaiApi.AgentState;
import io.agora.convoai.convoaiApi.ConversationalAIAPIConfig;
import io.agora.convoai.convoaiApi.ConversationalAIAPIImpl;
import io.agora.convoai.convoaiApi.IConversationalAIAPI;
import io.agora.convoai.convoaiApi.IConversationalAIAPIEventHandler;
import io.agora.convoai.convoaiApi.InterruptEvent;
import io.agora.convoai.convoaiApi.MessageError;
import io.agora.convoai.convoaiApi.MessageReceipt;
import io.agora.convoai.convoaiApi.Metric;
import io.agora.convoai.convoaiApi.ModuleError;
import io.agora.convoai.convoaiApi.StateChangeEvent;
import io.agora.convoai.convoaiApi.Transcript;
import io.agora.convoai.convoaiApi.TranscriptRenderMode;
import io.agora.convoai.convoaiApi.VoiceprintStateChangeEvent;
import io.agora.convoai.example.startup.rtm.RtmManager.IRtmManagerListener;
import io.agora.rtm.PresenceEvent;
import kotlin.Unit;
import io.agora.convoai.example.startup.rtc.RtcManager;
import io.agora.convoai.example.startup.rtm.RtmManager;
import io.agora.convoai.example.startup.api.AgentStarter;
import io.agora.convoai.example.startup.api.TokenGenerator;
import io.agora.rtc2.Constants;
import io.agora.rtc2.IRtcEngineEventHandler;
import io.agora.rtc2.RtcEngineEx;
import io.agora.rtm.RtmClient;

import java.util.ArrayList;
import java.util.List;
import java.util.Random;

/**
 * ViewModel for managing conversation-related business logic
 */
public class ConversationViewModel extends ViewModel {
    private static final String TAG = "ConversationViewModel";
    public static final int userId = 1001086;
    public static final int agentUid = 1009527;

    /**
     * Generate a random channel name
     */
    public static String generateRandomChannelName() {
        Random random = new Random();
        int randomNum = random.nextInt(9000) + 1000; // 1000-9999
        return "channel_java_" + randomNum;
    }

    /**
     * Connection state enum
     */
    public enum ConnectionState {
        Idle,
        Connecting,
        Connected,
        Error
    }

    /**
     * UI State - shared between AgentConfigFragment and AgentLivingFragment
     */
    public static class ConversationUiState {
        public String statusMessage = "";
        public boolean isMuted = false;
        // Channel and user info
        public String channelName = "";
        public int userUid = 0;
        public int agentUid = 0;
        // Connection state
        public ConnectionState connectionState = ConnectionState.Idle;
        // Agent state
        public boolean agentStarted = false;

        public ConversationUiState() {
        }

        public ConversationUiState(
                String statusMessage,
                boolean isMuted,
                String channelName,
                int userUid,
                int agentUid,
                ConnectionState connectionState,
                boolean agentStarted
        ) {
            this.statusMessage = statusMessage;
            this.isMuted = isMuted;
            this.channelName = channelName;
            this.userUid = userUid;
            this.agentUid = agentUid;
            this.connectionState = connectionState;
            this.agentStarted = agentStarted;
        }

        public ConversationUiState copy() {
            ConversationUiState newState = new ConversationUiState();
            newState.statusMessage = this.statusMessage;
            newState.isMuted = this.isMuted;
            newState.channelName = this.channelName;
            newState.userUid = this.userUid;
            newState.agentUid = this.agentUid;
            newState.connectionState = this.connectionState;
            newState.agentStarted = this.agentStarted;
            return newState;
        }
    }

    private final MutableLiveData<ConversationUiState> _uiState = new MutableLiveData<>(new ConversationUiState());
    public LiveData<ConversationUiState> uiState = _uiState;

    // Transcript list - separate from UI state
    private final MutableLiveData<List<Transcript>> _transcriptList = new MutableLiveData<>(new ArrayList<>());
    public LiveData<List<Transcript>> transcriptList = _transcriptList;

    private final MutableLiveData<AgentState> _agentState = new MutableLiveData<>();
    public LiveData<AgentState> agentState = _agentState;

    private String unifiedToken = null;
    private IConversationalAIAPI conversationalAIAPI = null;
    private String channelName = "";
    private boolean rtcJoined = false;
    private boolean rtmLoggedIn = false;

    // Agent management
    private String agentId = null;
    // We rely on _uiState.agentStarted for UI, but keep local variable for logic check if needed
    // or just use _uiState.value.agentStarted.

    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    private final IRtcEngineEventHandler rtcEventHandler = new IRtcEngineEventHandler() {
        @Override
        public void onJoinChannelSuccess(String channel, int uid, int elapsed) {
            mainHandler.post(() -> {
                rtcJoined = true;
                ConversationUiState currentState = _uiState.getValue();
                if (currentState != null) {
                    ConversationUiState newState = currentState.copy();
                    newState.statusMessage = "Joined RTC channel successfully";
                    _uiState.setValue(newState);
                }
                Log.d(TAG, "RTC joined channel: " + channel + ", uid: " + uid);
                checkJoinAndLoginComplete();
            });
        }

        @Override
        public void onUserJoined(int uid, int elapsed) {
            mainHandler.post(() -> {
                ConversationUiState currentState = _uiState.getValue();
                if (currentState != null) {
                    ConversationUiState newState = currentState.copy();
                    if (uid == agentUid) {
                        newState.statusMessage = "Agent joined the channel";
                        newState.agentUid = uid;
                        _uiState.setValue(newState);
                        Log.d(TAG, "Agent joined the channel, uid: " + uid);
                    } else {
                        Log.d(TAG, "User joined the channel, uid: " + uid);
                    }
                }
            });
        }

        @Override
        public void onUserOffline(int uid, int reason) {
            mainHandler.post(() -> {
                ConversationUiState currentState = _uiState.getValue();
                if (currentState != null) {
                    ConversationUiState newState = currentState.copy();
                    if (uid == agentUid) {
                        newState.statusMessage = "Agent left the channel";
                        _uiState.setValue(newState);
                        Log.d(TAG, "Agent left the channel, uid: " + uid + ", reason: " + reason);
                    } else {
                        Log.d(TAG, "User left the channel, uid: " + uid + ", reason: " + reason);
                    }
                }
            });
        }

        @Override
        public void onError(int err) {
            mainHandler.post(() -> {
                ConversationUiState currentState = _uiState.getValue();
                if (currentState != null) {
                    ConversationUiState newState = currentState.copy();
                    newState.connectionState = ConnectionState.Error;
                    newState.statusMessage = "RTC error: " + err;
                    _uiState.setValue(newState);
                }
                Log.e(TAG, "RTC error: " + err);
            });
        }

        @Override
        public void onTokenPrivilegeWillExpire(String token) {
            super.onTokenPrivilegeWillExpire(token);
            renewToken();
        }
    };

    // RTM listener
    private final IRtmManagerListener rtmListener = new IRtmManagerListener() {
        @Override
        public void onFailed() {
            mainHandler.post(() -> {
                ConversationUiState currentState = _uiState.getValue();
                if (currentState != null) {
                    ConversationUiState newState = currentState.copy();
                    newState.connectionState = ConnectionState.Error;
                    newState.statusMessage = "RTM connection failed, attempting re-login";
                    _uiState.setValue(newState);
                }
                Log.d(TAG, "RTM connection failed, attempting re-login with new token");
            });
            unifiedToken = null;
        }

        @Override
        public void onTokenPrivilegeWillExpire(String channelName) {
            renewToken();
        }

        @Override
        public void onPresenceEvent(PresenceEvent event) {

        }
    };

    private final IConversationalAIAPIEventHandler conversationalAIAPIEventHandler = new IConversationalAIAPIEventHandler() {
        @Override
        public void onAgentStateChanged(String agentUserId, StateChangeEvent event) {
            mainHandler.post(() -> {
                _agentState.setValue(event.getState());
            });
        }

        @Override
        public void onAgentInterrupted(String agentUserId, InterruptEvent event) {
            // Handle interruption
        }

        @Override
        public void onAgentMetrics(String agentUserId, Metric metric) {
            // Handle metrics
        }

        @Override
        public void onAgentError(String agentUserId, ModuleError error) {
            // Handle agent error
        }

        @Override
        public void onMessageError(String agentUserId, MessageError error) {
            // Handle message error
        }

        @Override
        public void onTranscriptUpdated(String agentUserId, Transcript transcript) {
            // Handle transcript updates with typing animation for agent messages
            addTranscript(transcript);
        }

        @Override
        public void onMessageReceiptUpdated(String agentUserId, MessageReceipt receipt) {
            // Handle message receipt
        }

        @Override
        public void onAgentVoiceprintStateChanged(String agentUserId, VoiceprintStateChangeEvent event) {
            // Update voice print state to notify Activity
        }

        @Override
        public void onDebugLog(String log) {
            Log.d("conversationalAIAPI", log);
        }
    };

    public ConversationViewModel() {
        // Create RTC engine and RTM client during initialization
        try {
            Log.d(TAG, "Initializing RTC engine and RTM client...");

            RtcEngineEx rtcEngine = RtcManager.createRtcEngine(rtcEventHandler);
            if (rtcEngine == null) {
                throw new RuntimeException("Failed to create RtcEngine");
            }
            
            RtmClient rtmClient = RtmManager.createRtmClient(userId);
            // Setup RTM listener
            RtmManager.addListener(rtmListener);

            initializeAPIs(rtcEngine, rtmClient);

            Log.d(TAG, "RTC engine and RTM client created successfully");
        } catch (Exception e) {
            Log.e(TAG, "Error creating RTC/RTM instances: " + e.getMessage(), e);
            ConversationUiState currentState = _uiState.getValue();
            if (currentState != null) {
                ConversationUiState newState = currentState.copy();
                newState.statusMessage = "Error creating RTC/RTM: " + e.getMessage();
                _uiState.setValue(newState);
            }
        }
    }

    private void initializeAPIs(RtcEngineEx rtcEngine, RtmClient rtmClient) {
        conversationalAIAPI = new ConversationalAIAPIImpl(
                new ConversationalAIAPIConfig(
                        rtcEngine,
                        rtmClient,
                        TranscriptRenderMode.Text,
                        true // enableLog
                )
        );
        conversationalAIAPI.loadAudioSettings(Constants.AUDIO_SCENARIO_AI_CLIENT);
        conversationalAIAPI.addHandler(conversationalAIAPIEventHandler);
    }

    /**
     * Check if both RTC and RTM are connected, then start Agent
     */
    private void checkJoinAndLoginComplete() {
        if (rtcJoined && rtmLoggedIn) {
            ConversationUiState currentState = _uiState.getValue();
            if (currentState != null) {
                ConversationUiState newState = currentState.copy();
                newState.statusMessage = "RTC and RTM connected successfully. Starting agent...";
                _uiState.setValue(newState);
            }
            startAgent();
        }
    }

    /**
     * Callback interface for token generation
     */
    private interface TokenCallback {
        void onSuccess(String token);
        void onFailure(Exception e);
    }

    /**
     * Generate unified token
     */
    private void generateUnifiedToken(boolean isSilent, TokenCallback callback) {
        if (!isSilent) {
            ConversationUiState currentState = _uiState.getValue();
            if (currentState != null) {
                ConversationUiState newState = currentState.copy();
                newState.statusMessage = "Getting token...";
                _uiState.setValue(newState);
            }
        }

        TokenGenerator.generateTokens(
                "", // Empty channel name for wildcard or global token if applicable, or specific logic
                String.valueOf(userId),
                new TokenGenerator.AgoraTokenType[]{TokenGenerator.AgoraTokenType.RTC, TokenGenerator.AgoraTokenType.RTM},
                token -> {
                    unifiedToken = token;
                    callback.onSuccess(token);
                },
                callback::onFailure
        );
    }

    private void renewToken() {
        generateUnifiedToken(true, new TokenCallback() {
            @Override
            public void onSuccess(String token) {
                 RtcManager.renewToken(token);
                 RtmManager.renewToken(token, exception -> {
                     if (exception != null) {
                         unifiedToken = null;
                     }
                 });
                 Log.d(TAG, "Token renewed successfully");
            }

            @Override
            public void onFailure(Exception e) {
                Log.e(TAG, "Failed to renew token: " + e.getMessage());
            }
        });
    }

    /**
     * Start agent
     */
    public void startAgent() {
        ConversationUiState currentState = _uiState.getValue();
        if (currentState != null && currentState.agentStarted) {
            Log.d(TAG, "Agent already started");
            return;
        }

        if (channelName.isEmpty()) {
            if (currentState != null) {
                ConversationUiState newState = currentState.copy();
                newState.connectionState = ConnectionState.Error;
                newState.statusMessage = "Channel name is empty, cannot start agent";
                _uiState.setValue(newState);
            }
            Log.e(TAG, "Channel name is empty, cannot start agent");
            return;
        }

        if (currentState != null) {
            ConversationUiState newState = currentState.copy();
            newState.statusMessage = "Generating agent token...";
            _uiState.setValue(newState);
        }

        // Generate token for agent (always required)
        TokenGenerator.generateTokens(
                channelName,
                String.valueOf(agentUid),
                new TokenGenerator.AgoraTokenType[]{TokenGenerator.AgoraTokenType.RTC, TokenGenerator.AgoraTokenType.RTM},
                token -> {
                    mainHandler.post(() -> {
                        ConversationUiState state = _uiState.getValue();
                        if (state != null) {
                            ConversationUiState newState = state.copy();
                            newState.statusMessage = "Starting agent...";
                            _uiState.setValue(newState);
                        }

                        AgentStarter.startAgentAsync(
                                channelName,
                                String.valueOf(agentUid),
                                token,
                                new AgentStarter.AgentStartCallback() {
                                    @Override
                                    public void onSuccess(String agentId) {
                                        mainHandler.post(() -> {
                                            ConversationViewModel.this.agentId = agentId;
                                            
                                            ConversationUiState state = _uiState.getValue();
                                            if (state != null) {
                                                ConversationUiState newState = state.copy();
                                                newState.connectionState = ConnectionState.Connected;
                                                newState.agentStarted = true;
                                                newState.statusMessage = "Agent started successfully";
                                                _uiState.setValue(newState);
                                            }
                                            Log.d(TAG, "Agent started successfully, agentId: " + agentId);
                                        });
                                    }

                                    @Override
                                    public void onFailure(Exception e) {
                                        mainHandler.post(() -> {
                                            ConversationUiState state = _uiState.getValue();
                                            if (state != null) {
                                                ConversationUiState newState = state.copy();
                                                newState.connectionState = ConnectionState.Error;
                                                newState.statusMessage = "Failed to start agent: " + e.getMessage();
                                                _uiState.setValue(newState);
                                            }
                                            Log.e(TAG, "Failed to start agent: " + e.getMessage(), e);
                                        });
                                    }
                                }          
                        );
                    });
                },
                e -> {
                    mainHandler.post(() -> {
                        ConversationUiState state = _uiState.getValue();
                        if (state != null) {
                            ConversationUiState newState = state.copy();
                            newState.connectionState = ConnectionState.Error;
                            newState.statusMessage = "Failed to generate agent token: " + e.getMessage();
                            _uiState.setValue(newState);
                        }
                        Log.e(TAG, "Failed to generate agent token: " + e.getMessage(), e);
                    });
                }
        );
    }

    /**
     * Join RTC channel and login RTM
     *
     * @param channelName Channel name to join
     */
    public void joinChannelAndLogin(String channelName) {
        try {
            if (channelName == null || channelName.isEmpty()) {
                ConversationUiState currentState = _uiState.getValue();
                if (currentState != null) {
                    ConversationUiState newState = currentState.copy();
                    newState.statusMessage = "Channel name cannot be empty";
                    newState.connectionState = ConnectionState.Idle;
                    _uiState.setValue(newState);
                }
                Log.e(TAG, "Channel name is empty, cannot join channel");
                return;
            }

            this.channelName = channelName;
            rtcJoined = false;
            rtmLoggedIn = false;

            ConversationUiState currentState = _uiState.getValue();
            if (currentState != null) {
                ConversationUiState newState = currentState.copy();
                newState.channelName = channelName;
                newState.userUid = userId;
                newState.connectionState = ConnectionState.Connecting;
                newState.statusMessage = "Joining channel and logging in...";
                _uiState.setValue(newState);
            }

            TokenCallback onTokenReady = new TokenCallback() {
                @Override
                public void onSuccess(String token) {
                    mainHandler.post(() -> {
                        // Join RTC channel with the unified token
                        RtcManager.joinChannel(token, channelName, userId);

                        // Login RTM with the same unified token
                        RtmManager.login(token, errorInfo -> {
                            mainHandler.post(() -> {
                                if (errorInfo == null) {
                                    rtmLoggedIn = true;
                                    ConversationUiState state1 = _uiState.getValue();
                                    if (state1 != null) {
                                        ConversationUiState newState1 = state1.copy();
                                        newState1.statusMessage = "RTM logged in successfully";
                                        _uiState.setValue(newState1);
                                    }
                                    conversationalAIAPI.subscribeMessage(channelName, (io.agora.convoai.convoaiApi.ConversationalAIAPIError error) -> {
                                        if (error != null) {
                                            Log.e(TAG, "Subscribe message error: " + error);
                                        }
                                        return Unit.INSTANCE;
                                    });
                                    checkJoinAndLoginComplete();
                                } else {
                                    ConversationUiState state1 = _uiState.getValue();
                                    if (state1 != null) {
                                        ConversationUiState newState1 = state1.copy();
                                        newState1.connectionState = ConnectionState.Error;
                                        newState1.statusMessage = "RTM login failed: " + (errorInfo != null ? errorInfo.getMessage() : "Unknown error");
                                        _uiState.setValue(newState1);
                                    }
                                    Log.e(TAG, "RTM login failed: " + (errorInfo != null ? errorInfo.getMessage() : "Unknown error"));
                                }
                            });
                        });
                    });
                }

                @Override
                public void onFailure(Exception e) {
                    mainHandler.post(() -> {
                        ConversationUiState currentState1 = _uiState.getValue();
                        if (currentState1 != null) {
                            ConversationUiState newState = currentState1.copy();
                            newState.connectionState = ConnectionState.Error;
                            newState.statusMessage = "Failed to get token: " + e.getMessage();
                            _uiState.setValue(newState);
                        }
                        Log.e(TAG, "Failed to get token: " + e.getMessage(), e);
                    });
                }
            };


            // Get token if not available, otherwise use existing token
            if (unifiedToken == null || unifiedToken.isEmpty()) {
                generateUnifiedToken(false, onTokenReady);
            } else {
                onTokenReady.onSuccess(unifiedToken);
            }
        } catch (Exception e) {
            ConversationUiState currentState = _uiState.getValue();
            if (currentState != null) {
                ConversationUiState newState = currentState.copy();
                newState.connectionState = ConnectionState.Error;
                newState.statusMessage = "Error: " + e.getMessage();
                _uiState.setValue(newState);
            }
            Log.e(TAG, "Error joining channel/login: " + e.getMessage(), e);
        }
    }

    /**
     * Toggle microphone mute state
     */
    public void toggleMute() {
        ConversationUiState currentState = _uiState.getValue();
        if (currentState != null) {
            boolean newMuteState = !currentState.isMuted;
            ConversationUiState newState = currentState.copy();
            newState.isMuted = newMuteState;
            newState.statusMessage = newMuteState ? "Microphone muted" : "Microphone unmuted";
            _uiState.setValue(newState);
            RtcManager.muteLocalAudio(newMuteState);
            Log.d(TAG, "Microphone muted: " + newMuteState);
        }
    }

    /**
     * Add a new transcript to the list
     */
    public void addTranscript(Transcript transcript) {
        mainHandler.post(() -> {
            List<Transcript> currentList = new ArrayList<>(_transcriptList.getValue() != null ? _transcriptList.getValue() : new ArrayList<>());
            // Update existing transcript if same turnId, otherwise add new
            int existingIndex = -1;
            for (int i = 0; i < currentList.size(); i++) {
                Transcript t = currentList.get(i);
                if (t.getTurnId() == transcript.getTurnId() && t.getType() == transcript.getType()) {
                    existingIndex = i;
                    break;
                }
            }
            if (existingIndex >= 0) {
                currentList.set(existingIndex, transcript);
            } else {
                currentList.add(transcript);
            }
            _transcriptList.setValue(currentList);
        });
    }

    /**
     * Clear all transcripts
     */
    public void clearTranscripts() {
        mainHandler.post(() -> {
            _transcriptList.setValue(new ArrayList<>());
            Log.d(TAG, "Transcripts cleared");
        });
    }

    /**
     * Hang up and cleanup connections
     */
    public void hangup() {
        try {
            conversationalAIAPI.unsubscribeMessage(channelName, errorInfo -> {
                if (errorInfo != null) {
                    Log.e(TAG, "Unsubscribe message error: " + errorInfo);
                }
                return Unit.INSTANCE;
            });

            // Stop agent if it was started
            if (agentId != null) { // check agentId instead of state just to be safe
                ConversationUiState currentState = _uiState.getValue();
                if (currentState != null) {
                    ConversationUiState newState = currentState.copy();
                    newState.statusMessage = "Stopping agent...";
                    newState.agentStarted = false; // Reset immediately
                    _uiState.setValue(newState);
                }
                AgentStarter.stopAgentAsync(
                        agentId,
                        new AgentStarter.AgentStopCallback() {
                            @Override
                            public void onSuccess() {
                                mainHandler.post(() -> {
                                    Log.d(TAG, "Agent stopped successfully");
                                });
                            }

                            @Override
                            public void onFailure(Exception e) {
                                mainHandler.post(() -> {
                                    Log.e(TAG, "Failed to stop agent: " + e.getMessage(), e);
                                });
                            }
                        }
                );
                agentId = null;
            }

            RtcManager.leaveChannel();
            RtmManager.logout();
            rtcJoined = false;
            rtmLoggedIn = false;
            ConversationUiState currentState = _uiState.getValue();
            if (currentState != null) {
                ConversationUiState newState = currentState.copy();
                newState.statusMessage = "";
                newState.connectionState = ConnectionState.Idle;
                newState.agentStarted = false;
                _uiState.setValue(newState);
            }
            clearTranscripts();
            Log.d(TAG, "Hangup completed");
        } catch (Exception e) {
            Log.e(TAG, "Error during hangup: " + e.getMessage(), e);
        }
    }

    @Override
    protected void onCleared() {
        super.onCleared();
        RtcManager.leaveChannel();
        RtmManager.logout();
        // Note: RtcEngine.destroy() should be called carefully as it's a global operation
        // Consider managing RTC engine lifecycle at Application level
    }
}
