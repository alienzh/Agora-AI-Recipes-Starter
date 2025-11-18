import { RtcManager } from '../rtc/RtcManager';
import { TokenGenerator } from '../common/TokenGenerator';
import { KeyCenter } from '../common/KeyCenter';
import { AgentStarter } from '../common/AgentStarter';
import { IRtcEngineEventHandler, RtcEngineEx } from '@shengwang/rtc-full';
import {
  IConversationalAIAPI,
  IConversationalAIAPIEventHandler,
  ConversationalAIAPIConfig,
  TranscriptRenderMode,
  TranscriptType,
  Transcript,
  AgentState,
  StateChangeEvent,
  InterruptEvent
} from '../convoaiApi/IConversationalAIAPI';
import { createConversationalAIAPI } from '../convoaiApi/ConversationalAIAPIImpl';
import { TranscriptDataSource } from '../pages/common/TranscriptDataSource';

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
  statusMessage: string;
  isMuted: boolean;
  isTranscriptEnabled: boolean;
  channelName: string;
  userUid: number;
  agentUid: number;
  connectionState: ConnectionState;
}

// Transcript and AgentState are now imported from IConversationalAIAPI.ets

/**
 * ViewModel for managing conversation-related business logic
 * Singleton instance for sharing between pages
 */
export class ConversationViewModel {
  static readonly TAG = 'ConversationViewModel';
  static readonly userId = 1001086;
  static readonly agentUid = 1009527;
  // Singleton instance for sharing between pages
  private static instance: ConversationViewModel | null = null;

  /**
   * Get singleton instance
   */
  static getInstance(): ConversationViewModel {
    if (!ConversationViewModel.instance) {
      ConversationViewModel.instance = new ConversationViewModel();
    }
    return ConversationViewModel.instance;
  }

  /**
   * Reset singleton instance (for testing or cleanup)
   */
  static resetInstance(): void {
    ConversationViewModel.instance = null;
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
    statusMessage: '',
    isMuted: false,
    isTranscriptEnabled: false,
    channelName: '',
    userUid: 0,
    agentUid: 0,
    connectionState: ConnectionState.Idle
  };
  // Transcript list
  private _transcriptList: Transcript[] = [];
  // Agent state
  private _agentState: AgentState | null = null;
  private unifiedToken: string | null = null;
  private channelName: string = '';
  private rtcJoined: boolean = false;
  private conversationalAIAPI: IConversationalAIAPI | null = null;
  private rtcEngine: RtcEngineEx | null = null;
  private conversationalAIEventHandler: IConversationalAIAPIEventHandler;
  private agentId: string | null = null;
  // Event handlers
  private uiStateChangeCallbacks: ((state: ConversationUiState) => void)[] = [];
  private agentStateChangeCallbacks: ((state: AgentState | null) => void)[] = [];
  
  // Transcript data source (set by VoiceAssistant)
  private transcriptDataSource: TranscriptDataSource | undefined;

  /**
   * Initialize RTC engine with context
   * @param context UIAbilityContext or Context for RTC engine initialization
   */
  initialize(context: Context): void {
    try {
      console.info(ConversationViewModel.TAG, 'Initializing RTC engine...');

      // Create RTC engine
      this.rtcEngine = RtcManager.createRtcEngine(context, this.createRtcEventHandler());
      if (!this.rtcEngine) {
        throw new Error('Failed to create RTC engine');
      }

      // Create ConversationalAI API
      const apiConfig = new ConversationalAIAPIConfig(
        this.rtcEngine,
        TranscriptRenderMode.Word,
        true
      );
      this.conversationalAIAPI = createConversationalAIAPI(apiConfig);

      // Add event handler for ConversationalAI API
      this.conversationalAIAPI.addHandler(this.conversationalAIEventHandler);

      console.info(ConversationViewModel.TAG, 'RTC engine and ConversationalAI API created successfully');
    } catch (error) {
      console.error(ConversationViewModel.TAG, `Error creating RTC instances: ${JSON.stringify(error)}`);
      this.updateUiState({
        statusMessage: `Error creating RTC: ${JSON.stringify(error)}`
      });
    }
  }

  constructor() {
    // Note: Context should be set via initialize() method before using
    // This allows context to be passed from UIAbility or page

    // Create ConversationalAI API event handler
    this.conversationalAIEventHandler = new ConversationalAIEventHandler(this);
  }


  /**
   * Create RTC event handler
   */
  private createRtcEventHandler(): IRtcEngineEventHandler {
    return {
      onJoinChannelSuccess: (cid: string, uid: number, elapsed: number) => {
        this.rtcJoined = true;
        this.updateUiState({
          statusMessage: 'Joined RTC channel successfully'
        });
        console.info(ConversationViewModel.TAG, `RTC joined channel: ${cid}, uid: ${uid}, elapsed: ${elapsed}`);
        this.checkConnectionComplete();
      },
      onLeaveChannel: () => {
        this.rtcJoined = false;
        console.info(ConversationViewModel.TAG, 'RTC left channel');
      },
      onUserJoined: (uid: number, collapse: number) => {
        if (uid === ConversationViewModel.agentUid) {
          this.updateUiState({
            statusMessage: 'Agent joined the channel',
            agentUid: uid
          });
          console.info(ConversationViewModel.TAG, `Agent joined the channel, uid: ${uid}, collapse: ${collapse}`);
        } else {
          console.info(ConversationViewModel.TAG, `User joined the channel, uid: ${uid}, collapse: ${collapse}`);
        }
      },
      onUserOffline: (uid: number, reason: number) => {
        if (uid === ConversationViewModel.agentUid) {
          this.updateUiState({
            statusMessage: 'Agent left the channel'
          });
          console.info(ConversationViewModel.TAG, `Agent left the channel, uid: ${uid}, reason: ${reason}`);
        } else {
          console.info(ConversationViewModel.TAG, `User left the channel, uid: ${uid}, reason: ${reason}`);
        }
      },
      onError: (err: number, message: string) => {
        // TODO: Get error description from RtcEngine if available
        // const errorDesc = RtcEngine.getErrorDescription(err);
        this.updateUiState({
          connectionState: ConnectionState.Error,
          statusMessage: `RTC error: ${err}, message: ${message}`
        });
        console.error(ConversationViewModel.TAG, `RTC error: ${err}, message: ${message}`);
      },
      onTokenPrivilegeWillExpire: (token: string) => {
        // Handle token expiration
        console.info(ConversationViewModel.TAG, 'RTC token will expire');
        // TODO: Implement token renewal logic
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
   * Check if RTC is connected
   */
  private checkConnectionComplete(): void {
    if (this.rtcJoined) {
      this.updateUiState({
        connectionState: ConnectionState.Connected,
        statusMessage: 'RTC initialized successfully'
      });
    }
  }

  /**
   * Start agent after RTC and RTM are connected
   * Similar to Kotlin: viewModel.startAgent()
   */
  async startAgent(): Promise<void> {
    try {
      if (!this.channelName || this.channelName.trim().length === 0) {
        this.updateUiState({
          connectionState: ConnectionState.Error,
          statusMessage: 'Channel name is empty, cannot start agent'
        });
        console.error(ConversationViewModel.TAG, 'Channel name is empty, cannot start agent');
        return;
      }

      // Generate token for agentUid (not unifiedToken which is for userId)
      this.updateUiState({
        statusMessage: 'Getting agent token...'
      });

      let agentToken: string;
      try {
        agentToken = await TokenGenerator.generateTokensAsync(
          this.channelName,
          ConversationViewModel.agentUid.toString()
        );
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : JSON.stringify(error);
        this.updateUiState({
          connectionState: ConnectionState.Error,
          statusMessage: `Failed to generate agent token: ${errorMessage}`
        });
        console.error(ConversationViewModel.TAG, `Failed to generate agent token: ${errorMessage}`, error);
        return;
      }

      // Start agent using AgentStarter with agent token
      const agentId = await AgentStarter.startAgentAsync(
        this.channelName,
        ConversationViewModel.agentUid.toString(),
        agentToken
      );

      this.agentId = agentId;
      this.updateUiState({
        statusMessage: `Agent started successfully: ${agentId}`
      });
      console.info(ConversationViewModel.TAG, `Agent started successfully: ${agentId}`);
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : JSON.stringify(error);
      this.updateUiState({
        connectionState: ConnectionState.Error,
        statusMessage: `Failed to start agent: ${errorMessage}`
      });
      console.error(ConversationViewModel.TAG, `Failed to start agent: ${errorMessage}`);
    }
  }

  /**
   * Join RTC channel
   * @param channelName Channel name to join
   */
  async joinChannel(channelName: string): Promise<void> {
    try {
      if (!channelName || channelName.trim().length === 0) {
        this.updateUiState({
          connectionState: ConnectionState.Error,
          statusMessage: 'Channel name cannot be empty'
        });
        console.error(ConversationViewModel.TAG, 'Channel name is empty, cannot join channel');
        return;
      }

      this.channelName = channelName;
      this.rtcJoined = false;

      this.updateUiState({
        channelName: channelName,
        userUid: ConversationViewModel.userId,
        connectionState: ConnectionState.Connecting,
        statusMessage: 'Joining channel...'
      });

      // Get token if not available
      const token = this.unifiedToken || await this.fetchToken();

      // Join RTC channel
      RtcManager.joinChannel(token, channelName, ConversationViewModel.userId);

      // Subscribe to messages for ConversationalAI API
      if (this.conversationalAIAPI) {
        this.conversationalAIAPI.subscribeMessage(channelName, (error) => {
          if (error) {
            console.error(ConversationViewModel.TAG, `Failed to subscribe message: ${error.message}`);
            this.updateUiState({
              statusMessage: `Failed to subscribe message: ${error.message}`
            });
          } else {
            console.info(ConversationViewModel.TAG, 'Subscribed to ConversationalAI messages');
            this.updateUiState({
              statusMessage: 'RTC channel joined successfully'
            });
          }
        });
      }

      this.checkConnectionComplete();
    } catch (error) {
      this.updateUiState({
        connectionState: ConnectionState.Error,
        statusMessage: `Error: ${JSON.stringify(error)}`
      });
      console.error(ConversationViewModel.TAG, `Error joining channel: ${JSON.stringify(error)}`);
    }
  }

  /**
   * Fetch token from server
   */
  private async fetchToken(): Promise<string> {
    this.updateUiState({
      statusMessage: 'Getting token...'
    });

    try {
      const token = await TokenGenerator.generateTokensAsync(
        '',
        ConversationViewModel.userId.toString()
      );
      this.unifiedToken = token;
      return token;
    } catch (error) {
      this.updateUiState({
        connectionState: ConnectionState.Error,
        statusMessage: `Failed to get token: ${JSON.stringify(error)}`
      });
      console.error(ConversationViewModel.TAG, `Failed to get token: ${JSON.stringify(error)}`);
      throw new Error(`Failed to get token: ${JSON.stringify(error)}`);
    }
  }

  /**
   * Toggle microphone mute state
   */
  toggleMute(): void {
    const newMuteState = !this._uiState.isMuted;
    this.updateUiState({
      isMuted: newMuteState,
      statusMessage: newMuteState ? 'Microphone muted' : 'Microphone unmuted'
    });
    RtcManager.muteLocalAudio(newMuteState);
    console.info(ConversationViewModel.TAG, `Microphone muted: ${newMuteState}`);
  }

  /**
   * Toggle transcript display
   */
  toggleTranscript(): void {
    const newTranscriptState = !this._uiState.isTranscriptEnabled;
    this.updateUiState({
      isTranscriptEnabled: newTranscriptState,
      statusMessage: newTranscriptState ? 'Transcript enabled' : 'Transcript disabled'
    });
    console.info(ConversationViewModel.TAG, `Transcript enabled: ${newTranscriptState}`);
  }

  /**
   * Set transcript data source (called by VoiceAssistant)
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
    console.info(ConversationViewModel.TAG, `[Thread] addOrUpdateTranscript called at ${timestamp}`);
    
    // Update internal list for getTranscriptList()
    const existingIndex = this._transcriptList.findIndex(
      t => t.turnId === transcript.turnId && t.type === transcript.type
    );
    if (existingIndex >= 0) {
      this._transcriptList[existingIndex] = transcript;
      console.info(ConversationViewModel.TAG, `[Thread] Updating transcript turnId:${transcript.turnId}, type:${transcript.type}, timestamp:${timestamp}`);
    } else {
      this._transcriptList.push(transcript);
      console.info(ConversationViewModel.TAG, `[Thread] Adding new transcript turnId:${transcript.turnId}, type:${transcript.type}, timestamp:${timestamp}`);
    }

    // Directly update data source - it will notify UI automatically
    if (this.transcriptDataSource) {
      console.info(ConversationViewModel.TAG, `[Thread] Calling addOrUpdateData, timestamp:${timestamp}`);
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
    console.info(ConversationViewModel.TAG, 'Transcripts cleared');
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
          console.info(ConversationViewModel.TAG, `Agent stopped: ${this.agentId}`);
        } catch (error) {
          console.error(ConversationViewModel.TAG, `Failed to stop agent: ${JSON.stringify(error)}`);
        }
        this.agentId = null;
      }

      // Unsubscribe from ConversationalAI messages
      if (this.conversationalAIAPI && this.channelName) {
        this.conversationalAIAPI.unsubscribeMessage(this.channelName, (error) => {
          if (error) {
            console.error(ConversationViewModel.TAG, `Failed to unsubscribe message: ${error.message}`);
          } else {
            console.info(ConversationViewModel.TAG, 'Unsubscribed from ConversationalAI messages');
          }
        });
      }

      RtcManager.leaveChannel();

      this.rtcJoined = false;
      this.channelName = ''; // Reset channel name
      this.agentId = null; // Already set above, but ensure it's null

      this.updateUiState({
        statusMessage: '',
        connectionState: ConnectionState.Idle,
        channelName: '',
        userUid: 0,
        agentUid: 0
      });

      this.clearTranscripts();
      console.info(ConversationViewModel.TAG, 'Hangup completed');
    } catch (error) {
      console.error(ConversationViewModel.TAG, `Error during hangup: ${JSON.stringify(error)}`);
    }
  }

  /**
   * Update UI state and notify listeners
   */
  private updateUiState(updates: Partial<ConversationUiState>): void {
    // Manually merge updates into state (ArkTS doesn't support object spread)
    if (updates.statusMessage !== undefined) {
      this._uiState.statusMessage = updates.statusMessage;
    }
    if (updates.isMuted !== undefined) {
      this._uiState.isMuted = updates.isMuted;
    }
    if (updates.isTranscriptEnabled !== undefined) {
      this._uiState.isTranscriptEnabled = updates.isTranscriptEnabled;
    }
    if (updates.channelName !== undefined) {
      this._uiState.channelName = updates.channelName;
    }
    if (updates.userUid !== undefined) {
      this._uiState.userUid = updates.userUid;
    }
    if (updates.agentUid !== undefined) {
      this._uiState.agentUid = updates.agentUid;
    }
    if (updates.connectionState !== undefined) {
      this._uiState.connectionState = updates.connectionState;
    }
    this.notifyUiStateChange();
  }

  /**
   * Notify UI state change listeners
   */
  private notifyUiStateChange(): void {
    this.uiStateChangeCallbacks.forEach(callback => callback(this._uiState));
  }


  /**
   * Notify agent state change listeners
   */
  private notifyAgentStateChange(): void {
    this.agentStateChangeCallbacks.forEach(callback => callback(this._agentState));
  }

  /**
   * Subscribe to UI state changes
   */
  subscribeUiState(callback: (state: ConversationUiState) => void): () => void {
    this.uiStateChangeCallbacks.push(callback);
    // Immediately call with current state
    callback(this._uiState);
    // Return unsubscribe function
    return () => {
      const index = this.uiStateChangeCallbacks.indexOf(callback);
      if (index >= 0) {
        this.uiStateChangeCallbacks.splice(index, 1);
      }
    };
  }


  /**
   * Subscribe to agent state changes
   */
  subscribeAgentState(callback: (state: AgentState | null) => void): () => void {
    this.agentStateChangeCallbacks.push(callback);
    // Immediately call with current state
    callback(this._agentState);
    // Return unsubscribe function
    return () => {
      const index = this.agentStateChangeCallbacks.indexOf(callback);
      if (index >= 0) {
        this.agentStateChangeCallbacks.splice(index, 1);
      }
    };
  }

  /**
   * Set agent state
   */
  setAgentState(state: AgentState | null): void {
    this._agentState = state;
    this.notifyAgentStateChange();
  }

  /**
   * Get current UI state
   */
  getUiState(): ConversationUiState {
    return {
      statusMessage: this._uiState.statusMessage,
      isMuted: this._uiState.isMuted,
      isTranscriptEnabled: this._uiState.isTranscriptEnabled,
      channelName: this._uiState.channelName,
      userUid: this._uiState.userUid,
      agentUid: this._uiState.agentUid,
      connectionState: this._uiState.connectionState
    };
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

    RtcManager.leaveChannel();
    this.uiStateChangeCallbacks = [];
    this.agentStateChangeCallbacks = [];
    this.transcriptDataSource = undefined;
  }
}

/**
 * ConversationalAI API event handler class
 * Implements IConversationalAIAPIEventHandler to handle ConversationalAI events
 */
class ConversationalAIEventHandler implements IConversationalAIAPIEventHandler {
  private viewModel: ConversationViewModel;

  constructor(viewModel: ConversationViewModel) {
    this.viewModel = viewModel;
  }

  onAgentStateChanged(agentUserId: string, event: StateChangeEvent): void {
    console.info(ConversationViewModel.TAG, `Agent state changed: ${agentUserId}, state: ${event.state}`);
    // Use AgentState directly from IConversationalAIAPI, no mapping needed
    this.viewModel.setAgentState(event.state);
  }

  onAgentInterrupted(agentUserId: string, event: InterruptEvent): void {
    console.info(ConversationViewModel.TAG, `Agent interrupted: ${agentUserId}, turnId: ${event.turnId}`);
  }

  onTranscriptUpdated(agentUserId: string, transcript: Transcript): void {
    // Use Transcript directly from IConversationalAIAPI, no mapping needed
    this.viewModel.addOrUpdateTranscript(transcript);
  }

  onDebugLog(message: string): void {
    console.info(ConversationViewModel.TAG, `[ConvoAI] ${message}`);
  }
}

