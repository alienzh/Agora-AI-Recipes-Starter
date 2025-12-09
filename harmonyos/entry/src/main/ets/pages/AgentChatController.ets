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
import { KeyCenter } from '../config/KeyCenter';
import { Context } from '@kit.AbilityKit';
import { TranscriptDataSource } from './components/TranscriptDataSource';
import { MessageParser } from '../utils/MessageParser';

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

/**
 * Agent State Enum
 */
export enum AgentState {
  IDLE = 'idle',
  SILENT = 'silent',
  LISTENING = 'listening',
  THINKING = 'thinking',
  SPEAKING = 'speaking',
  UNKNOWN = 'unknown'
}

/**
 * Message type enum for different message types in the conversation
 */
enum MessageType {
  ASSISTANT = 'assistant.transcription',
  USER = 'user.transcription',
  INTERRUPT = 'message.interrupt',
  MESSAGE_STATE = 'message.state',
  UNKNOWN = 'unknown'
}

/**
 * Transcript type enum
 */
export enum TranscriptType {
  AGENT,
  USER
}

/**
 * Transcript status enum
 */
export enum TranscriptStatus {
  IN_PROGRESS,
  END,
  INTERRUPTED,
  UNKNOWN
}

/**
 * Transcript data class
 */
export interface Transcript {
  turnId: number;
  userId: string;
  text: string;
  status: TranscriptStatus;
  type: TranscriptType;
}

/**
 * State change event interface
 */
interface StateChangeEventInfo {
  turnId: number;
  timestamp: number;
}

/**
 * Interrupt event interface
 */
interface InterruptEventInfo {
  turnId: number;
  timestamp: number;
}

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
  private rtcEngine: RtcEngineEx | null = null;
  private rtcContext: Context | null = null;
  private agentId: string | null = null;
  private dataStreamId: number = 0;
  private messageParser: MessageParser = new MessageParser();
  private lastStateChangeEvent: StateChangeEventInfo | null = null;
  private lastInterruptEvent: InterruptEventInfo | null = null;
  // Transcript data source (set by AgentChat)
  private transcriptDataSource: TranscriptDataSource | undefined;

  constructor() {
    // Note: Context should be set via initialize() method before using
    // This allows context to be passed from UIAbility or page

    // Set message parser error callback
    this.messageParser.setOnError((message: string) => {
      console.error(AgentChatController.TAG, message);
    });
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
    console.info(AgentChatController.TAG, 'RTC engine initialized successfully');
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
        // Handle datastream message directly
        this.handleStreamMessage(uid, streamId, data);
      },
      onStreamMessageError: (uid: number, streamId: number, error: number, missed: number, cached: number) => {
        console.error(AgentChatController.TAG, `RTC stream message error: uid=${uid}, streamId=${streamId}, error=${error}, missed=${missed}, cached=${cached}`);
      }
    };
  }

  /**
   * Check if RTC is connected and create DataStream
   * Similar to React Native: onJoinChannelSuccess creates DataStream
   */
  private checkConnectionComplete(): void {
    if (this.rtcJoined && this.rtcEngine && this.dataStreamId === 0) {
      // Create DataStream after RTC is connected
      try {
        const streamId = this.rtcEngine.createDataStream({
          syncWithAudio: false,
          ordered: true
        });
        if (streamId > 0) {
          this.dataStreamId = streamId;
          console.info(AgentChatController.TAG, `RTC DataStream created, streamId: ${streamId}`);
          this.addStatusLog(`RTC DataStream created, streamId: ${streamId}`);
          
          // Start agent after DataStream is created
      this.startAgent();
        } else {
          console.error(AgentChatController.TAG, `Failed to create DataStream, ret: ${streamId}`);
          this.addStatusLog(`Failed to create DataStream, ret: ${streamId}`);
        }
      } catch (error) {
        console.error(AgentChatController.TAG, `createDataStream error: ${JSON.stringify(error)}`);
        this.addStatusLog(`createDataStream error`);
      }
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

    // Load audio settings before joining channel
    this.loadAudioSettings();
    
    // Join RTC channel
    this.joinRtcChannel(token, channelName, AgentChatController.userId);
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
    const existingIndex = this._transcriptList.findIndex((t: Transcript): boolean => {
      return t.turnId === transcript.turnId && t.type === transcript.type;
    });
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

      // Reset DataStream
      this.dataStreamId = 0;
      this.lastStateChangeEvent = null;
      this.lastInterruptEvent = null;

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
    this.leaveRtcChannel();
    this.transcriptDataSource = undefined;
    this.dataStreamId = 0;
    this.lastStateChangeEvent = null;
    this.lastInterruptEvent = null;
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

  /**
   * Handle RTC datastream message
   * Similar to React Native: onStreamMessage handler
   */
  private handleStreamMessage(uid: number, streamId: number, data: Uint8Array): void {
    if (!data || data.length <= 0) {
      return;
    }

    try {
      // Convert Uint8Array to string
      let messageString = '';
      for (let i = 0; i < data.length; i++) {
        messageString += String.fromCharCode(data[i]);
      }

      // Parse message (may be split into multiple parts)
      const parsedMessage = this.messageParser.parseStreamMessage(messageString);

      if (parsedMessage) {
        console.log(`[handleStreamMessage] Message parsed successfully: ${JSON.stringify(parsedMessage)}`);
        // Handle parsed message on main thread
        setTimeout(() => {
          this.handleParsedMessage(uid.toString(), parsedMessage);
        }, 0);
      } else {
        // Message is incomplete (split into multiple parts), this is normal
        console.log(`[handleStreamMessage] Message parsing returned null (message may be incomplete or split into multiple parts)`);
      }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      console.error(AgentChatController.TAG, `[handleStreamMessage] error: ${errorMessage}`);
  }
}

/**
   * Handle parsed message
   * Similar to React Native: handleParsedMessage
   * Reference: reactnative/src/stores/AgentChatStore.ts:65-177
   */
  private handleParsedMessage(publisherId: string, message: Record<string, Object>): void {
    try {
      // Get message type from 'object' field
      const messageTypeStr = message['object'] as string | undefined;

      if (!messageTypeStr) {
        console.log(`[handleParsedMessage] Message without 'object' key: ${JSON.stringify(message)}`);
        return;
      }

      // Convert string to MessageType enum
      let messageType: MessageType;
      switch (messageTypeStr) {
        case 'assistant.transcription':
          messageType = MessageType.ASSISTANT;
          break;
        case 'user.transcription':
          messageType = MessageType.USER;
          break;
        case 'message.interrupt':
          messageType = MessageType.INTERRUPT;
          break;
        case 'message.state':
          messageType = MessageType.MESSAGE_STATE;
          break;
        default:
          messageType = MessageType.UNKNOWN;
      }

      console.log(`[handleParsedMessage] Received message type: ${messageTypeStr}`);

      // Handle different message types
      switch (messageType) {
        case MessageType.ASSISTANT:
          this.handleAssistantMessage(publisherId, message);
          break;
        case MessageType.USER:
          this.handleUserMessage(publisherId, message);
          break;
        case MessageType.INTERRUPT:
          this.handleInterruptMessage(publisherId, message);
          break;
        case MessageType.MESSAGE_STATE:
          this.handleStateMessage(publisherId, message);
          break;
        default:
          console.log(`[handleParsedMessage] Unknown message type: ${messageTypeStr}, full message: ${JSON.stringify(message)}`);
      }
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      console.error(AgentChatController.TAG, `[handleParsedMessage] error: ${errorMessage}`);
    }
  }

  /**
   * Handle assistant transcription message
   */
  private handleAssistantMessage(publisherId: string, msg: Record<string, Object>): void {
    const text = (msg['text'] as string) || '';
    if (text.length === 0) {
      console.log(`[handleParsedMessage] assistant.transcription: empty text, ignored`);
      return;
    }

    const turnId = (msg['turn_id'] as number) ?? 0;
    const userId = (msg['user_id'] as string) || '';
    const turnStatusInt = (msg['turn_status'] as number) ?? 0;
    
    // 0: in-progress, 1: end gracefully, 2: interrupted
    let status: TranscriptStatus;
    switch (turnStatusInt) {
      case 0:
        status = TranscriptStatus.IN_PROGRESS;
        break;
      case 1:
        status = TranscriptStatus.END;
        break;
      case 2:
        status = TranscriptStatus.INTERRUPTED;
        break;
      default:
        status = TranscriptStatus.UNKNOWN;
    }

    // Discard messages with Unknown status
    if (status === TranscriptStatus.UNKNOWN) {
      console.log(`[handleParsedMessage] assistant.transcription: unknown turn_status:${turnStatusInt}`);
      return;
    }

    // Check if this turn was interrupted
    if (this.lastInterruptEvent && this.lastInterruptEvent.turnId === turnId) {
      console.log(`[handleParsedMessage] assistant.transcription: turn ${turnId} was interrupted, ignored`);
      return;
    }

    console.log(`[handleParsedMessage] assistant.transcription: turnId=${turnId}, text="${text}", status=${status}, turnStatus=${turnStatusInt}`);

    const transcript: Transcript = {
      turnId: turnId,
      userId: userId,
      text: text,
      status: status,
      type: TranscriptType.AGENT,
    };
    this.addOrUpdateTranscript(transcript);
  }

  /**
   * Handle user transcription message
   */
  private handleUserMessage(publisherId: string, msg: Record<string, Object>): void {
    const text = (msg['text'] as string) || '';
    if (text.length === 0) {
      console.log(`[handleParsedMessage] user.transcription: empty text, ignored`);
      return;
    }

    const turnId = (msg['turn_id'] as number) ?? 0;
    const userId = (msg['user_id'] as string) || '';
    const isFinal = (msg['final'] as boolean) || false;
    const status = isFinal ? TranscriptStatus.END : TranscriptStatus.IN_PROGRESS;

    console.log(`[handleParsedMessage] user.transcription: turnId=${turnId}, text="${text}", status=${status}, isFinal=${isFinal}`);

    const transcript: Transcript = {
      turnId: turnId,
      userId: userId,
      text: text,
      status: status,
      type: TranscriptType.USER,
    };
    this.addOrUpdateTranscript(transcript);
  }

  /**
   * Handle interrupt message
   */
  private handleInterruptMessage(publisherId: string, msg: Record<string, Object>): void {
    const turnId = (msg['turn_id'] as number) ?? 0;
    const startMs = (msg['start_ms'] as number) ?? 0;

    const interruptEvent: InterruptEventInfo = {
      turnId: turnId,
      timestamp: startMs
    };
    this.lastInterruptEvent = interruptEvent;

    console.log(`[handleParsedMessage] message.interrupt: turnId=${turnId}, timestamp=${startMs}`);
    // TODO: Handle interrupt event, update interrupted transcript status
  }

  /**
   * Handle agent state change message
   */
  private handleStateMessage(publisherId: string, msg: Record<string, Object>): void {
    const state = (msg['state'] as string) || '';
    const turnId = (msg['turn_id'] as number) || 0;
    const ts = (msg['ts_ms'] as number) || 0;

    // Check if turnId is less than current stateChangeEvent turnId, if so return
    if (turnId < (this.lastStateChangeEvent?.turnId || 0)) {
      return;
    }

    // Check if ts is less than or equal to current stateChangeEvent timestamp, if so return
    if (ts <= (this.lastStateChangeEvent?.timestamp || 0)) {
      return;
    }

    // Update lastStateChangeEvent
    const stateChangeEvent: StateChangeEventInfo = {
      turnId: turnId,
      timestamp: ts
    };
    this.lastStateChangeEvent = stateChangeEvent;

    console.log(`[handleParsedMessage] message.state: state=${state}, turnId=${turnId}, timestamp=${ts}`);

    // Convert state string to AgentState enum
    let agentState: AgentState;
    switch (state) {
      case 'idle':
        agentState = AgentState.IDLE;
        break;
      case 'silent':
        agentState = AgentState.SILENT;
        break;
      case 'listening':
        agentState = AgentState.LISTENING;
        break;
      case 'thinking':
        agentState = AgentState.THINKING;
        break;
      case 'speaking':
        agentState = AgentState.SPEAKING;
        break;
      default:
        agentState = AgentState.UNKNOWN;
        console.log(`[handleParsedMessage] message.state: unknown state value: ${state}`);
    }

    this.setAgentState(agentState);
  }

  /**
   * Load audio settings for optimal AI conversation performance
   * Must be called before joinChannel
   */
  private loadAudioSettings(): void {
    if (!this.rtcEngine) {
      console.warn(AgentChatController.TAG, 'RTC engine not initialized, cannot load audio settings');
      return;
    }

    try {
      // Set audio scenario for AI client
      this.rtcEngine.setAudioScenario(Constants.AudioScenarioType.CHORUS);
      
      // Set audio config parameters
      this.rtcEngine.setParameters('{"che.audio.aec.split_srate_for_48k":16000}');
      this.rtcEngine.setParameters('{"che.audio.sf.enabled":true}');
      this.rtcEngine.setParameters('{"che.audio.sf.stftType":6}');
      this.rtcEngine.setParameters('{"che.audio.sf.ainlpLowLatencyFlag":1}');
      this.rtcEngine.setParameters('{"che.audio.sf.ainsLowLatencyFlag":1}');
      this.rtcEngine.setParameters('{"che.audio.sf.procChainMode":1}');
      this.rtcEngine.setParameters('{"che.audio.sf.nlpDynamicMode":1}');
      this.rtcEngine.setParameters('{"che.audio.sf.nlpAlgRoute":1}');
      this.rtcEngine.setParameters('{"che.audio.sf.ainlpModelPref":10}');
      this.rtcEngine.setParameters('{"che.audio.sf.nsngAlgRoute":12}');
      this.rtcEngine.setParameters('{"che.audio.sf.ainsModelPref":10}');
      this.rtcEngine.setParameters('{"che.audio.sf.nsngPredefAgg":11}');
      this.rtcEngine.setParameters('{"che.audio.agc.enable":false}');

      console.info(AgentChatController.TAG, `Audio settings loaded, SDK version: ${RtcEngine.getSdkVersion()}`);
    } catch (error) {
      console.error(AgentChatController.TAG, `loadAudioSettings error: ${JSON.stringify(error)}`);
  }
}
}