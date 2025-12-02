import { TokenGenerator } from '../api/TokenGenerator';
import { AgentStarter } from '../api/AgentStarter';
import {
  RtcEngine,
  Constants,
  IRtcEngineEventHandler,
  RtcEngineEx,
  RtcEngineConfig,
  ChannelMediaOptions
} from '@shengwang/rtc-full';
import { KeyCenter } from '../common/KeyCenter';
import { Context } from '@kit.AbilityKit';
import {
  IConversationalAIAPI,
  IConversationalAIAPIEventHandler,
  ConversationalAIAPIConfig,
  Transcript,
  AgentState,
  StateChangeEvent,
  InterruptEvent
} from '../convoaiApi/IConversationalAIAPI';
import { createConversationalAIAPI } from '../convoaiApi/ConversationalAIAPIImpl';
import { TranscriptDataSource } from './common/TranscriptDataSource';

/**
 * Connection state enum
 */
export enum ConnectionState {
  Idle = 'Idle',
  Connecting = 'Connecting',
  Connected = 'Connected',
  Error = 'Error'
}

/**
 * UI State for conversation
 */
export interface ConversationUiState {
  isMuted: boolean;
  connectionState: ConnectionState;
}

// Transcript and AgentState are now imported from IConversationalAIAPI.ets

/**
 * Controller for managing agent chat business logic
 * Singleton instance for sharing between pages
 */
export class AgentChatController {
  static readonly TAG = 'AgentChatController';
  static readonly userId = 1001086;
  static readonly agentUid = 1009527;
  // Singleton instance for sharing between pages
  private static instance: AgentChatController | null = null;

  /**
   * Get singleton instance
   */
  static getInstance(): AgentChatController {
    if (!AgentChatController.instance) {
      AgentChatController.instance = new AgentChatController();
    }
    return AgentChatController.instance;
  }

  /**
   * Reset singleton instance (for testing or cleanup)
   */
  static resetInstance(): void {
    AgentChatController.instance = null;
  }

  /**
   * Generate random channel name
   * Format: "channel_harmonyos_RRRR" where RRRR is random 4-digit number (1000-9999)
   * @returns Random channel name string
   */
  static generateRandomChannelName(): string {
    // Generate random 4-digit number (1000-9999)
    const random = Math.floor(Math.random() * 9000) + 1000;

    return `channel_harmonyos_${random}`;
  }

  // UI State
  private _uiState: ConversationUiState = {
    isMuted: false,
    connectionState: ConnectionState.Idle
  };
  // Transcript list
  private _transcriptList: Transcript[] = [];
  // Agent state
  private _agentState: AgentState = AgentState.IDLE;
  // Debug log list - for displaying logs in UI
  private _debugLogList: string[] = [];
  private unifiedToken: string | null = null;
  private channelName: string = '';
  private rtcJoined: boolean = false;
  private conversationalAIAPI: IConversationalAIAPI | null = null;
  private rtcEngine: RtcEngineEx | null = null;
  private rtcContext: Context | null = null;
  private conversationalAIEventHandler: IConversationalAIAPIEventHandler;
  private agentId: string | null = null;
  // Transcript data source (set by AgentChat)
  private transcriptDataSource: TranscriptDataSource | undefined;

  constructor() {
    // Note: Context should be set via initialize() method before using
    // This allows context to be passed from UIAbility or page

    // Create ConversationalAI API event handler
    this.conversationalAIEventHandler = new ConversationalAIEventHandler(this);
  }


  /**
   * Initialize RTC engine with context
   * @param context UIAbilityContext or Context for RTC engine initialization
   */
  initialize(context: Context): void {
    console.info(AgentChatController.TAG, 'Initializing RTC engine...');

    // Store context
    this.rtcContext = context;

    // Init RTC engine
    this.initRtcEngine(context, this.createRtcEventHandler());
    // Create ConversationalAI API
    if (this.rtcEngine != null) {
      const apiConfig = new ConversationalAIAPIConfig(this.rtcEngine, true);
      this.conversationalAIAPI = createConversationalAIAPI(apiConfig);
      // Add event handler for ConversationalAI API
      this.conversationalAIAPI.addHandler(this.conversationalAIEventHandler);
      console.info(AgentChatController.TAG, 'RTC engine and ConversationalAI API created successfully');
    } else {
      console.error(AgentChatController.TAG, `Error creating RTC instances`);
    }
  }

  /**
   * Create RTC engine instance
   * @param context Context for RTC engine initialization
   * @param rtcEventHandler Event handler object with callback methods
   * @returns RTC Engine instance
   */
  private initRtcEngine(context: Context, rtcEventHandler: IRtcEngineEventHandler): void {
    if (this.rtcEngine) {
      console.info(AgentChatController.TAG, 'RTC engine already exists, returning existing instance');
      return;
    }
    this.rtcContext = context;
    try {
      // Create RTC engine config
      const config: RtcEngineConfig = new RtcEngineConfig();
      config.mContext = this.rtcContext!;
      config.mAppId = KeyCenter.AGORA_APP_ID;
      config.mEventHandler = rtcEventHandler;

      // Create RTC engine
      this.rtcEngine = RtcEngine.create(config) as RtcEngineEx;
      // Log SDK version
      const sdkVersion = RtcEngine.getSdkVersion();
      console.info(AgentChatController.TAG, `Current SDK version: ${sdkVersion}`);
      console.info(AgentChatController.TAG, 'createRtcEngine success');
      this.addStatusLog('RtcEngine init successfully');
    } catch (error) {
      console.error(AgentChatController.TAG, `createRtcEngine error: ${JSON.stringify(error)}`);
      this.addStatusLog('RtcEngine init failed');
    }
  }

  /**
   * Create RTC event handler
   */
  private createRtcEventHandler(): IRtcEngineEventHandler {
    return {
      onJoinChannelSuccess: (cid: string, uid: number, elapsed: number) => {
        this.rtcJoined = true;
        this.addStatusLog(`Rtc onJoinChannelSuccess, channel:${cid} uid:${uid}`);
        console.info(AgentChatController.TAG, `RTC joined channel: ${cid}, uid: ${uid}, elapsed: ${elapsed}`);
        this.checkConnectionComplete();
      },
      onLeaveChannel: () => {
        this.rtcJoined = false;
        this.addStatusLog('Rtc onLeaveChannel');
        console.info(AgentChatController.TAG, 'RTC left channel');
      },
      onUserJoined: (uid: number, collapse: number) => {
        this.addStatusLog(`Rtc onUserJoined, uid:${uid}`);
        if (uid === AgentChatController.agentUid) {
          console.info(AgentChatController.TAG, `Agent joined the channel, uid: ${uid}, collapse: ${collapse}`);
        } else {
          console.info(AgentChatController.TAG, `User joined the channel, uid: ${uid}, collapse: ${collapse}`);
        }
      },
      onUserOffline: (uid: number, reason: number) => {
        this.addStatusLog(`Rtc onUserOffline, uid:${uid}`);
        if (uid === AgentChatController.agentUid) {
          console.info(AgentChatController.TAG, `Agent left the channel, uid: ${uid}, reason: ${reason}`);
        } else {
          console.info(AgentChatController.TAG, `User left the channel, uid: ${uid}, reason: ${reason}`);
        }
      },
      onError: (err: number, message: string) => {
        this.addStatusLog(`Rtc onError: ${err}`);
        this.updateUiState({
          connectionState: ConnectionState.Error
        });
        console.error(AgentChatController.TAG, `RTC error: ${err}, message: ${message}`);
      },
      onTokenPrivilegeWillExpire: (token: string) => {
        // Handle token expiration
        console.info(AgentChatController.TAG, 'RTC token will expire');
      },

      onStreamMessage: (uid: number, streamId: number, data: Uint8Array) => {
        // Forward datastream message to ConversationalAI API
        if (this.conversationalAIAPI) {
          this.conversationalAIAPI.setOnStreamMessage(uid, streamId, data);
        }
      },
      onStreamMessageError: (uid: number, streamId: number, error: number, missed: number, cached: number) => {
        // Forward datastream error to ConversationalAI API
        if (this.conversationalAIAPI) {
          this.conversationalAIAPI.setOnStreamMessageError(uid, streamId, error, missed, cached);
        }
      }
    };
  }

  /**
   * Check if RTC is connected and message subscription is complete
   * Similar to Kotlin: checkJoinAndLoginComplete()
   * Note: HarmonyOS uses RTC DataStream instead of RTM
   * This method may be called multiple times (from onJoinChannelSuccess and subscribeMessage callback),
   * but startAgent() has guard to prevent duplicate calls
   */
  private checkConnectionComplete(): void {
    if (this.rtcJoined) {
      // Automatically start agent after RTC is connected and message subscription is complete
      // startAgent() has guard (agentStarted check) to prevent duplicate calls
      this.startAgent();
    }
  }

  /**
   * Start agent after RTC is connected and message subscription is complete
   * Similar to Kotlin: viewModel.startAgent()
   * Note: HarmonyOS uses RTC DataStream instead of RTM
   */
  async startAgent(): Promise<void> {
    try {
      if (this.agentId != null) {
        console.info(AgentChatController.TAG, `Agent already started, agentId: ${this.agentId}`);
        return;
      }

      // Generate token for agentUid (not unifiedToken which is for userId)
      let agentToken: string;
      try {
        agentToken = await TokenGenerator.generateTokensAsync(
          this.channelName,
          AgentChatController.agentUid.toString()
        );
        this.addStatusLog('Generate agent token successfully');
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : JSON.stringify(error);
        this.updateUiState({
          connectionState: ConnectionState.Error
        });
        this.addStatusLog('Generate agent token failed');
        console.error(AgentChatController.TAG, `Failed to generate agent token: ${errorMessage}`, error);
        return;
      }

      // Start agent using AgentStarter with agent token
      const agentId = await AgentStarter.startAgentAsync(
        this.channelName,
        AgentChatController.agentUid.toString(),
        agentToken
      );

      this.agentId = agentId;
      this.updateUiState({
        connectionState: ConnectionState.Connected
      });
      this.addStatusLog('Agent start successfully');
      console.info(AgentChatController.TAG, `Agent started successfully, agentId: ${agentId}`);
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : JSON.stringify(error);
      this.updateUiState({
        connectionState: ConnectionState.Error
      });
      this.addStatusLog('Agent start failed');
      console.error(AgentChatController.TAG, `Failed to start agent: ${errorMessage}`);
    }
  }

  /**
   * Join RTC channel
   * @param channelName Channel name to join
   */
  async joinChannel(channelName: string): Promise<void> {
    this.channelName = channelName;
    this.rtcJoined = false;

    this.updateUiState({
      connectionState: ConnectionState.Connecting
    });

    // Get token if not available
    const token = this.unifiedToken || await this.generateUnifiedToken();

    if (!token) {
      this.updateUiState({
        connectionState: ConnectionState.Error
      });
      console.error(AgentChatController.TAG, 'Failed to get token, cannot join channel');
      return;
    }

    if (this.conversationalAIAPI) {
      this.conversationalAIAPI.loadAudioSettings()
    }
    // Join RTC channel
    this.joinRtcChannel(token, channelName, AgentChatController.userId);

    // Subscribe to messages for ConversationalAI API (via RTC DataStream)
    if (this.conversationalAIAPI) {
      this.conversationalAIAPI.subscribeMessage(channelName, (error) => {
        if (error) {
          console.error(AgentChatController.TAG, `Failed to subscribe message: ${error.message}`);
          this.updateUiState({
            connectionState: ConnectionState.Error
          });
        } else {
          console.info(AgentChatController.TAG, 'Subscribed to ConversationalAI messages (via RTC DataStream)');
        }
      });
    }
  }

  /**
   * Generate unified token for RTC
   * Similar to Kotlin: generateUnifiedToken(isSilent)
   * @returns Token string on success, null on failure
   */
  private async generateUnifiedToken(): Promise<string | null> {
    try {
      const token = await TokenGenerator.generateTokensAsync(
        '',
        AgentChatController.userId.toString()
      );
      this.unifiedToken = token;
      this.addStatusLog('Generate user token successfully');
      return token;
    } catch (error) {
      this.updateUiState({
        connectionState: ConnectionState.Error
      });
      this.addStatusLog('Generate user token failed');
      console.error(AgentChatController.TAG, `Failed to get token: ${JSON.stringify(error)}`);
      return null;
    }
  }

  /**
   * Join RTC channel
   * @param rtcToken RTC token
   * @param channelName Channel name
   * @param uid User ID
   */
  private joinRtcChannel(rtcToken: string, channelName: string, uid: number): void {
    console.info(AgentChatController.TAG, `joinChannel channelName: ${channelName}, localUid: ${uid}`);

    if (!this.rtcEngine) {
      console.error(AgentChatController.TAG, 'RTC engine not initialized');
      throw new Error('RTC engine not initialized. Call initialize() first.');
    }

    try {
      // Enable audio volume indication for volume animation (optional)
      this.rtcEngine.enableAudioVolumeIndication(100, 3, true);

      // Configure channel media options
      const options: ChannelMediaOptions = new ChannelMediaOptions();
      options.clientRoleType = Constants.ClientRole.BROADCASTER;
      options.publishMicrophoneTrack = true;
      options.publishCameraTrack = false;
      options.autoSubscribeAudio = true;
      options.autoSubscribeVideo = false;

      // Join channel
      const ret = this.rtcEngine.joinChannelWithOptions(rtcToken, channelName, uid, options);
      if (ret === Constants.ErrorCode.ERR_OK) {
        console.info(AgentChatController.TAG, 'Join RTC channel success');
      } else {
        const errorDesc = RtcEngine.getErrorDescription(ret);
        console.error(AgentChatController.TAG, `Join RTC channel failed, ret: ${ret}, desc: ${errorDesc}`);
        this.addStatusLog(`Rtc joinChannel failed ret: ${ret}`);
      }
    } catch (error) {
      console.error(AgentChatController.TAG, `joinChannel error: ${JSON.stringify(error)}`);
    }
  }

  /**
   * Toggle microphone mute state
   */
  toggleMute(): void {
    const newMuteState = !this._uiState.isMuted;
    this.updateUiState({
      isMuted: newMuteState
    });
    this.muteLocalAudio(newMuteState);
    console.info(AgentChatController.TAG, `Microphone muted: ${newMuteState}`);
  }

  /**
   * Mute or unmute local audio
   * @param mute Mute state
   */
  private muteLocalAudio(mute: boolean): void {
    console.info(AgentChatController.TAG, `muteLocalAudio ${mute}`);

    if (!this.rtcEngine) {
      console.warn(AgentChatController.TAG, 'RTC engine not initialized, cannot mute audio');
      return;
    }

    try {
      // Adjust recording signal volume: 0 for mute, 100 for unmute
      const ret = this.rtcEngine.adjustRecordingSignalVolume(mute ? 0 : 100);
      if (ret === Constants.ErrorCode.ERR_OK) {
        console.info(AgentChatController.TAG, `Audio ${mute ? 'muted' : 'unmuted'}`);
      } else {
        console.error(AgentChatController.TAG, `Failed to ${mute ? 'mute' : 'unmute'} audio, error code: ${ret}`);
      }
    } catch (error) {
      console.error(AgentChatController.TAG, `muteLocalAudio error: ${JSON.stringify(error)}`);
    }
  }

  /**
   * Set transcript data source (called by AgentChat)
   */
  setTranscriptDataSource(dataSource: TranscriptDataSource): void {
    this.transcriptDataSource = dataSource;
  }

  /**
   * Add or update a transcript in the list
   * If a transcript with the same turnId and type exists, it will be updated
   * Note: User and agent transcripts share the same turnId, so only turnId and type are used for matching
   */
  addOrUpdateTranscript(transcript: Transcript): void {
    // Print thread information with timestamp
    const timestamp = Date.now();
    console.info(AgentChatController.TAG, `[Thread] addOrUpdateTranscript called at ${timestamp}`);

    // Update internal list for getTranscriptList()
    const existingIndex = this._transcriptList.findIndex(
      t => t.turnId === transcript.turnId && t.type === transcript.type
    );
    if (existingIndex >= 0) {
      this._transcriptList[existingIndex] = transcript;
      console.info(AgentChatController.TAG,
        `[Thread] Updating transcript turnId:${transcript.turnId}, type:${transcript.type}, timestamp:${timestamp}`);
    } else {
      this._transcriptList.push(transcript);
      console.info(AgentChatController.TAG,
        `[Thread] Adding new transcript turnId:${transcript.turnId}, type:${transcript.type}, timestamp:${timestamp}`);
    }

    // Directly update data source - it will notify UI automatically
    if (this.transcriptDataSource) {
      console.info(AgentChatController.TAG, `[Thread] Calling addOrUpdateData, timestamp:${timestamp}`);
      this.transcriptDataSource.addOrUpdateData(transcript);
    }
  }

  /**
   * Clear all transcripts
   */
  clearTranscripts(): void {
    this._transcriptList = [];
    // Directly clear data source - it will notify UI automatically
    if (this.transcriptDataSource) {
      this.transcriptDataSource.clearData();
    }
    console.info(AgentChatController.TAG, 'Transcripts cleared');
  }

  /**
   * Hang up and cleanup connections
   */
  async hangup(): Promise<void> {
    try {
      // Stop agent if started
      if (this.agentId) {
        try {
          await AgentStarter.stopAgentAsync(this.agentId);
          console.info(AgentChatController.TAG, `Agent stopped: ${this.agentId}`);
        } catch (error) {
          console.error(AgentChatController.TAG, `Failed to stop agent: ${JSON.stringify(error)}`);
        }
        this.agentId = null;
      }

      // Unsubscribe from ConversationalAI messages
      if (this.conversationalAIAPI && this.channelName) {
        this.conversationalAIAPI.unsubscribeMessage(this.channelName, (error) => {
          if (error) {
            console.error(AgentChatController.TAG, `Failed to unsubscribe message: ${error.message}`);
          } else {
            console.info(AgentChatController.TAG, 'Unsubscribed from ConversationalAI messages');
          }
        });
      }

      this.leaveRtcChannel();

      this.rtcJoined = false;
      this.channelName = ''; // Reset channel name
      this.agentId = null; // Already set above, but ensure it's null
      this._agentState = AgentState.IDLE

      this.updateUiState({
        connectionState: ConnectionState.Idle
      });

      this.clearTranscripts();
      console.info(AgentChatController.TAG, 'Hangup completed');
    } catch (error) {
      console.error(AgentChatController.TAG, `Error during hangup: ${JSON.stringify(error)}`);
    }
  }

  /**
   * Update UI state
   */
  private updateUiState(updates: Partial<ConversationUiState>): void {
    // Manually merge updates into state (ArkTS doesn't support object spread)
    if (updates.isMuted !== undefined) {
      this._uiState.isMuted = updates.isMuted;
    }
    if (updates.connectionState !== undefined) {
      this._uiState.connectionState = updates.connectionState;
    }
  }

  /**
   * Add status log message
   * Similar to Kotlin: addStatusLog()
   */
  private addStatusLog(message: string): void {
    if (message.length === 0) {
      return;
    }
    const currentLogs = [...this._debugLogList];
    currentLogs.push(message);
    // Keep only last 100 logs to avoid memory issues
    if (currentLogs.length > 100) {
      currentLogs.shift();
    }
    this._debugLogList = currentLogs;
  }

  /**
   * Set agent state
   */
  setAgentState(state: AgentState): void {
    this._agentState = state;
  }

  /**
   * Get current UI state
   */
  getUiState(): ConversationUiState {
    return {
      isMuted: this._uiState.isMuted,
      connectionState: this._uiState.connectionState
    };
  }

  /**
   * Get current debug log list
   */
  getDebugLogList(): string[] {
    return [...this._debugLogList];
  }

  /**
   * Get current transcript list
   */
  getTranscriptList(): Transcript[] {
    return [...this._transcriptList];
  }

  /**
   * Get current agent state
   */
  getAgentState(): AgentState | null {
    return this._agentState;
  }

  /**
   * Cleanup resources
   */
  cleanup(): void {
    // Destroy ConversationalAI API
    if (this.conversationalAIAPI) {
      this.conversationalAIAPI.destroy();
      this.conversationalAIAPI = null;
    }

    this.leaveRtcChannel();
    this.transcriptDataSource = undefined;
  }

  /**
   * Leave RTC channel
   */
  private leaveRtcChannel(): void {
    console.info(AgentChatController.TAG, 'leaveChannel');

    if (!this.rtcEngine) {
      console.warn(AgentChatController.TAG, 'RTC engine not initialized, cannot leave channel');
      return;
    }

    try {
      this.rtcEngine.leaveChannel();
      console.info(AgentChatController.TAG, 'Leave RTC channel success');
    } catch (error) {
      console.error(AgentChatController.TAG, `leaveChannel error: ${JSON.stringify(error)}`);
    }
  }
}

/**
 * ConversationalAI API event handler class
 * Implements IConversationalAIAPIEventHandler to handle ConversationalAI events
 */
class ConversationalAIEventHandler implements IConversationalAIAPIEventHandler {
  private viewModel: AgentChatController;

  constructor(viewModel: AgentChatController) {
    this.viewModel = viewModel;
  }

  onAgentStateChanged(agentUserId: string, event: StateChangeEvent): void {
    console.info(AgentChatController.TAG, `Agent state changed: ${agentUserId}, state: ${event.state}`);
    // Use AgentState directly from IConversationalAIAPI, no mapping needed
    this.viewModel.setAgentState(event.state);
  }

  onAgentInterrupted(agentUserId: string, event: InterruptEvent): void {
    console.info(AgentChatController.TAG, `Agent interrupted: ${agentUserId}, turnId: ${event.turnId}`);
  }

  onTranscriptUpdated(agentUserId: string, transcript: Transcript): void {
    // Use Transcript directly from IConversationalAIAPI, no mapping needed
    this.viewModel.addOrUpdateTranscript(transcript);
  }

  onDebugLog(message: string): void {
    console.info(AgentChatController.TAG, `${message}`);
  }
}

