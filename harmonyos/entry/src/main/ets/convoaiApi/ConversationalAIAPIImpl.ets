import {
  RtcEngineEx, Constants, RtcEngine
} from '@shengwang/rtc-full';
import {
  IConversationalAIAPI,
  IConversationalAIAPIEventHandler,
  ConversationalAIAPIConfig,
  ChatMessage,
  TextMessage,
  Priority,
  MessageType,
  StateChangeEvent,
  getMessageTypeFromValue,
  getAgentStateFromValue,
  ConversationalAIAPIError
} from './IConversationalAIAPI';
import { TranscriptConfig, TranscriptController } from './TranscriptController';
import { TranscriptRenderMode, Transcript, InterruptEvent } from './IConversationalAIAPI';
import { MessageParser } from './MessageParser';
import { ConversationalAIUtils, ObservableHelper } from './ConversationalAIUtils';
import util from '@ohos.util';


const TAG = '[ConvoAPI]';

/**
 * Implementation of ConversationalAI API
 */
export class ConversationalAIAPIImpl implements IConversationalAIAPI {
  private config: ConversationalAIAPIConfig;
  private messageParser: MessageParser;
  private transcriptController: TranscriptController;
  private conversationalAIHandlerHelper: ObservableHelper<IConversationalAIAPIEventHandler>;
  private audioRouting: number = Constants.AudioRouteTypes.AUDIO_ROUTE_DEFAULT;
  private stateChangeEvent: StateChangeEvent | null = null;
  private dataStreamId: number = 0; // RTC datastream ID

  constructor(config: ConversationalAIAPIConfig) {
    this.config = config;
    this.messageParser = new MessageParser();
    this.messageParser.setOnError((message: string) => {
      this.callMessagePrint(TAG, message);
    });
    this.conversationalAIHandlerHelper = new ObservableHelper<IConversationalAIAPIEventHandler>();

    // Initialize transcript controller
    // Note: HarmonyOS RTC SDK does not fully support word-level rendering,
    // so we only support Text mode
    const transcriptConfig = new TranscriptConfig(
      config.rtcEngine,
      TranscriptRenderMode.Text, // Force Text mode for HarmonyOS
      {
        onTranscriptUpdated: (agentUserId: string, transcript: Transcript) => {
          this.conversationalAIHandlerHelper.notifyEventHandlers((handler) => {
            handler.onTranscriptUpdated(agentUserId, transcript);
          });
        },
        onDebugLog: (tag: string, msg: string) => {
          this.callMessagePrint(tag, msg);
        },
        onAgentInterrupted: (agentUserId: string, event: InterruptEvent) => {
          this.conversationalAIHandlerHelper.notifyEventHandlers((handler) => {
            handler.onAgentInterrupted(agentUserId, event);
          });
        }
      }
    );

    this.transcriptController = new TranscriptController(transcriptConfig);


    // Create RTC datastream
    this.createDataStream();

    // Enable writing logs to SDK log file
    config.rtcEngine.setParameters('{"rtc.log_external_input": true}');

    this.messageParser.setOnError((message: string) => {
      this.callMessagePrint(TAG, message);
    });
  }

  /**
   * Create RTC datastream
   */
  private createDataStream(): void {
    // Create reliable and ordered datastream
    // Note: Adjust parameters based on actual RTC SDK API
    // Typically: createDataStream(config: DataStreamConfig): number
    // For now, using a placeholder - adjust based on actual SDK
    const ret = this.config.rtcEngine.createDataStream({
      syncWithAudio: false,
      ordered: true
    });

    if (ret > 0) {
      this.dataStreamId = ret;
      this.callMessagePrint(TAG, `createDataStream success, streamId:${this.dataStreamId}`);
    } else {
      this.callMessagePrint(TAG, `createDataStream failed, ret:${ret}`);
    }

  }

  /**
   * Handle RTC datastream message
   */
  private handleStreamMessage(uid: number, streamId: number, data: Uint8Array, length: number): void {
    if (!data || length <= 0) {
      return;
    }

    // Parse message data
    let messageMap: Record<string, Object> | null = null;

    try {
      // Convert Uint8Array to string
      let rawString = '';
      for (let i = 0; i < length; i++) {
        rawString += String.fromCharCode(data[i]);
      }
      messageMap = this.messageParser.parseStreamMessage(rawString);
    } catch (e) {
      const errorMessage = e instanceof Error ? e.message : 'Unknown error';
      this.callMessagePrint(TAG, `[!] Failed to decode stream message: ${errorMessage}`);
      return;
    }

    if (messageMap) {
      const publisherId = uid.toString();
      this.dealMessageWithMap(publisherId, messageMap);
    }
  }

  /**
   * Deal with message map
   */
  private dealMessageWithMap(publisherId: string, msg: Record<string, Object>): void {
    // Check if message has 'object' key
    if (msg['object'] !== undefined && msg['object'] !== null) {
      // Message has 'object' key, forward to transcript controller for processing
      const transcriptObj = msg['object'] as string;
      const objectType = getMessageTypeFromValue(transcriptObj);

      switch (objectType) {
        case MessageType.MESSAGE_STATE:
          this.handleAgentState(publisherId, msg);
          break;
        case MessageType.INTERRUPT:
        case MessageType.USER:
        case MessageType.ASSISTANT:
          // Forward to transcript controller for processing
          this.transcriptController.setOnStreamMessage(publisherId, objectType, msg);
          break;
        default:
          break;
      }
    } else {
      // Message doesn't have 'object' key, print it out
      this.callMessagePrint(TAG,
        `[Message without 'object' key] publisherId:${publisherId}, message:${JSON.stringify(msg)}`);
    }
  }

  /**
   * Handle agent state change message
   * @param publisherId Publisher user ID
   * @param msg Message map containing state information
   */
  private handleAgentState(publisherId: string, msg: Record<string, Object>): void {
    // Get state string from message
    const state = (msg['state'] as string) || '';
    
    // Get turn_id
    const turnId = (msg['turn_id'] as number) || 0;
    // Check if turnId is less than current stateChangeEvent turnId, if so return
    if (turnId < (this.stateChangeEvent?.turnId || 0)) {
      return;
    }
    
    // Get timestamp (ts_ms)
    const ts = (msg['ts_ms'] as number) || 0;
    // Check if ts is less than or equal to current stateChangeEvent timestamp, if so return
    if (ts <= (this.stateChangeEvent?.timestamp || 0)) {
      return;
    }
    
    // Convert state string to AgentState enum
    const aiState = getAgentStateFromValue(state);
    
    // Create StateChangeEvent
    const changeEvent: StateChangeEvent = {
      state: aiState,
      turnId: turnId,
      timestamp: ts
    };
    
    // Update stateChangeEvent
    this.stateChangeEvent = changeEvent;
    
    // Log the state change
    this.callMessagePrint(TAG, `<<< [onAgentStateChanged] ${publisherId} ${JSON.stringify(changeEvent)}`);
    
    // Notify all event handlers
    this.conversationalAIHandlerHelper.notifyEventHandlers((handler) => {
      handler.onAgentStateChanged(publisherId, changeEvent);
    });
  }

  /**
   * Call message print
   */
  private callMessagePrint(tag: string, message: string): void {
    this.conversationalAIHandlerHelper.notifyEventHandlers((handler) => {
      handler.onDebugLog(`${tag} ${message}`);
    });

    if (this.config.enableLog !== false) {
      ConversationalAIUtils.runOnMainThread(() => {
        try {
          // Note: Adjust based on actual RTC SDK API
          // this.config.rtcEngine.writeLog(Constants.LogLevel.LOG_LEVEL_INFO, `${tag} ${message}`);
        } catch (error) {
          console.error(TAG, `rtcEngine writeLog error: ${error}`);
        }
      });
    }
  }

  /**
   * Generate trace ID
   * Similar to Kotlin: UUID.randomUUID().toString().replace("-", "").substring(0, 8)
   * Uses HarmonyOS util.generateRandomUUID() for RFC 4122 version 4 UUID
   */
  private genTraceId(): string {
    // Generate UUID using HarmonyOS util module
    const uuid = util.generateRandomUUID();
    // Remove dashes and take first 8 characters
    return uuid.replace(/-/g, '').substring(0, 8);
  }

  // IConversationalAIAPI implementation

  addHandler(eventHandler: IConversationalAIAPIEventHandler): void {
    this.callMessagePrint(
      TAG,
      `>>> [addHandler] eventHandler:0x${eventHandler.toString()}`
    );
    this.conversationalAIHandlerHelper.subscribeEvent(eventHandler);
  }

  removeHandler(eventHandler: IConversationalAIAPIEventHandler): void {
    this.callMessagePrint(
      TAG,
      `>>> [removeHandler] eventHandler:0x${eventHandler.toString()}`
    );
    this.conversationalAIHandlerHelper.unSubscribeEvent(eventHandler);
  }

  subscribeMessage(channelName: string, completion: (error: ConversationalAIAPIError | null) => void): void {
    const traceId = this.genTraceId();
    this.callMessagePrint(
      TAG,
      `>>> [traceId:${traceId}] [subscribeMessage] ${channelName}`
    );

    this.transcriptController.reset();
    this.stateChangeEvent = null;

    // RTC datastream messages are automatically received via onStreamMessage callback
    // No explicit subscription needed - just ensure datastream is created
    // Note: This is kept for compatibility with future RTM implementation
    if (this.dataStreamId === 0) {
      this.createDataStream();
      if (this.dataStreamId === 0) {
        // Failed to create datastream
        this.stateChangeEvent = null;
        ConversationalAIUtils.runOnMainThread(() => {
          completion(new ConversationalAIAPIError(-1, 'Failed to create datastream'));
        });
        return;
      }
    }

    // Success - RTC datastream is ready
    this.callMessagePrint(TAG, `<<< [traceId:${traceId}] subscribeMessage success (using RTC datastream)`);

    ConversationalAIUtils.runOnMainThread(() => {
      completion(null);
    });
  }

  unsubscribeMessage(channelName: string, completion: (error: ConversationalAIAPIError | null) => void): void {
    const traceId = this.genTraceId();
    this.callMessagePrint(
      TAG,
      `>>> [traceId:${traceId}] [unsubscribeMessage] ${channelName}`
    );

    this.transcriptController.reset();
    this.stateChangeEvent = null;
    this.dataStreamId = 0; // Reset datastream ID when unsubscribing

    // RTC datastream doesn't require explicit unsubscribe
    // Messages will stop when leaving channel
    // Note: This is kept for compatibility with future RTM implementation
    this.callMessagePrint(
      TAG,
      `<<< [traceId:${traceId}] unsubscribeMessage success (using RTC datastream)`
    );

    ConversationalAIUtils.runOnMainThread(() => {
      completion(null);
    });
  }

  chat(agentUserId: string, message: ChatMessage, completion: (error: ConversationalAIAPIError | null) => void): void {
    if (message instanceof TextMessage) {
      this.sendText(agentUserId, message, completion);
    } else {
      completion(new ConversationalAIAPIError(-1, 'Only TextMessage is supported'));
    }
  }

  private sendText(agentUserId: string, message: TextMessage,
    completion: (error: ConversationalAIAPIError | null) => void): void {
    const traceId = this.genTraceId();
    this.callMessagePrint(TAG, `>>> [traceId:${traceId}] [sendText] ${agentUserId} ${JSON.stringify(message)}`);

    // Build receipt map similar to Kotlin: mutableMapOf<String, Any>().apply { ... }
    const receipt: Record<string, Object> = {};
    receipt['priority'] = (message.priority?.toString() || Priority.INTERRUPT.toString());
    receipt['interruptable'] = message.responseInterruptable !== undefined ? message.responseInterruptable : true;
    if (message.text) {
      receipt['message'] = message.text;
    }

    try {
      // Convert message object to JSON string
      const jsonMessage = JSON.stringify(receipt);
      this.callMessagePrint(TAG, `[traceId:${traceId}] sendStreamMessage ${jsonMessage}`);

      // Convert string to Uint8Array
      const messageBytes = new Uint8Array(jsonMessage.length);
      for (let i = 0; i < jsonMessage.length; i++) {
        messageBytes[i] = jsonMessage.charCodeAt(i);
      }

      // Send via RTC datastream (replacing RTM publish)
      // Note: RTC datastream broadcasts to all users in the channel
      if (this.dataStreamId === 0) {
        this.createDataStream();
        if (this.dataStreamId === 0) {
          ConversationalAIUtils.runOnMainThread(() => {
            completion(new ConversationalAIAPIError(-1, 'Failed to create datastream'));
          });
        }
      }

      const ret = this.config.rtcEngine.sendStreamMessage(
        this.dataStreamId,
        messageBytes
      );

      if (ret === Constants.ErrorCode.ERR_OK) {
        this.callMessagePrint(TAG, `<<< [traceId:${traceId}] sendStreamMessage onSuccess`);
        ConversationalAIUtils.runOnMainThread(() => {
          completion(null);
        });
      } else {
        const errorDesc = RtcEngineEx.getErrorDescription?.(ret) || `Error code: ${ret}`;
        this.callMessagePrint(TAG, `<<< [traceId:${traceId}] sendStreamMessage onFailure ${errorDesc}`);
        ConversationalAIUtils.runOnMainThread(() => {
          completion(new ConversationalAIAPIError(ret, errorDesc));
        });
      }
    } catch (e) {
      const errorMessage = e instanceof Error ? e.message : 'Unknown error';
      this.callMessagePrint(TAG, `[traceId:${traceId}] [!] ${errorMessage}`);
      ConversationalAIUtils.runOnMainThread(() => {
        completion(new ConversationalAIAPIError(-1, `Message serialization failed: ${errorMessage}`));
      });
    }
  }


  interrupt(agentUserId: string, completion: (error: ConversationalAIAPIError | null) => void): void {
    const traceId = this.genTraceId();
    this.callMessagePrint(TAG, `>>> [traceId:${traceId}] [interrupt] ${agentUserId}`);

    const receipt: Record<string, Object> = {};
    receipt['customType'] = MessageType.INTERRUPT;

    try {
      const jsonMessage = JSON.stringify(receipt);
      // Convert string to Uint8Array
      const messageBytes = new Uint8Array(jsonMessage.length);
      for (let i = 0; i < jsonMessage.length; i++) {
        messageBytes[i] = jsonMessage.charCodeAt(i);
      }

      // Send via RTC datastream
      // Note: RTC datastream broadcasts to all users in the channel
      if (this.dataStreamId === 0) {
        this.createDataStream();
        if (this.dataStreamId === 0) {
          throw new Error('Failed to create datastream');
        }
      }

      const ret = this.config.rtcEngine.sendStreamMessage(
        this.dataStreamId,
        messageBytes
      );

      if (ret === Constants.ErrorCode.ERR_OK) {
        this.callMessagePrint(TAG, `<<< [traceId:${traceId}] sendStreamMessage onSuccess`);
        ConversationalAIUtils.runOnMainThread(() => {
          completion(null);
        });
      } else {
        const errorDesc = RtcEngineEx.getErrorDescription?.(ret) || `Error code: ${ret}`;
        this.callMessagePrint(TAG, `<<< [traceId:${traceId}] sendStreamMessage onFailure ${errorDesc}`);
        ConversationalAIUtils.runOnMainThread(() => {
          completion(new ConversationalAIAPIError(ret, errorDesc));
        });
      }
    } catch (e) {
      const errorMessage = e instanceof Error ? e.message : 'Unknown error';
      this.callMessagePrint(TAG, `[traceId:${traceId}] [!] ${errorMessage}`);
      ConversationalAIUtils.runOnMainThread(() => {
        completion(new ConversationalAIAPIError(-1, `Message serialization failed: ${errorMessage}`));
      });
    }
  }

  loadAudioSettings(): void {
    // Default audio scenario for AI client, adjust based on actual SDK constants
    const defaultScenario = Constants.AudioScenarioType.CHORUS;
    this.callMessagePrint(TAG, `>>> [loadAudioSettings] scenario:${defaultScenario} ${RtcEngine.getSdkVersion()}}`);
    this.config.rtcEngine.setAudioScenario(Constants.AudioScenarioType.CHORUS);
    this.setAudioConfigParameters(this.audioRouting);
  }

  setOnStreamMessage(uid: number, streamId: number, data: Uint8Array): void {
    this.handleStreamMessage(uid, streamId, data, data.length);
  }

  setOnStreamMessageError(uid: number, streamId: number, error: number, missed: number, cached: number): void {
    this.callMessagePrint(TAG, `>>> [setOnStreamMessageError] uid:${uid}, streamId:${streamId}, error:${error}`);
  }

  destroy(): void {
    this.callMessagePrint(TAG, '>>> [destroy]');
    this.conversationalAIHandlerHelper.unSubscribeAll();
    this.transcriptController.reset();
    this.dataStreamId = 0;
  }

  /**
   * Set audio config parameters
   * You should set it before joinChannel and when audio route changed
   */
  private setAudioConfigParameters(routing: number): void {
    this.callMessagePrint(TAG, `setAudioConfigParameters routing:${routing}`);
    this.audioRouting = routing;

    const rtcEngine = this.config.rtcEngine;
    rtcEngine.setParameters('{"che.audio.aec.split_srate_for_48k":16000}');
    rtcEngine.setParameters('{"che.audio.sf.enabled":true}');
    rtcEngine.setParameters('{"che.audio.sf.stftType":6}');
    rtcEngine.setParameters('{"che.audio.sf.ainlpLowLatencyFlag":1}');
    rtcEngine.setParameters('{"che.audio.sf.ainsLowLatencyFlag":1}');
    rtcEngine.setParameters('{"che.audio.sf.procChainMode":1}');
    rtcEngine.setParameters('{"che.audio.sf.nlpDynamicMode":1}');

    // Audio routing constants - adjust based on actual SDK
    // Common values: 0=Default, 1=Headset, 2=Earpiece, 3=HeadsetNoMic, 4=Speakerphone, 5=BluetoothHFP, 6=BluetoothA2DP
    if (
      routing === 1 || // AUDIO_ROUTE_HEADSET
        routing === 2 || // AUDIO_ROUTE_EARPIECE
        routing === 3 || // AUDIO_ROUTE_HEADSETNOMIC
        routing === 5 || // AUDIO_ROUTE_BLUETOOTH_DEVICE_HFP
        routing === 6   // AUDIO_ROUTE_BLUETOOTH_DEVICE_A2DP
    ) {
      rtcEngine.setParameters('{"che.audio.sf.nlpAlgRoute":0}');
    } else {
      rtcEngine.setParameters('{"che.audio.sf.nlpAlgRoute":1}');
    }

    rtcEngine.setParameters('{"che.audio.sf.ainlpModelPref":10}');
    rtcEngine.setParameters('{"che.audio.sf.nsngAlgRoute":12}');
    rtcEngine.setParameters('{"che.audio.sf.ainsModelPref":10}');
    rtcEngine.setParameters('{"che.audio.sf.nsngPredefAgg":11}');
    rtcEngine.setParameters('{"che.audio.agc.enable":false}');
  }
}

/**
 * Factory function to create ConversationalAIAPI instance
 */
export function createConversationalAIAPI(
  config: ConversationalAIAPIConfig
): IConversationalAIAPI {
  return new ConversationalAIAPIImpl(config);
}

