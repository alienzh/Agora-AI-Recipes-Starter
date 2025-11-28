import { RtcEngineEx } from '@shengwang/rtc-full';

/**
 * Conversational AI API Version
 */
export const CONVERSATIONAL_AI_API_VERSION = '1.0.0';

/**
 * Message priority levels for AI agent processing.
 *
 * Controls how the AI agent handles incoming messages during ongoing interactions.
 */
export enum Priority {
  /**
   * High priority - Immediately interrupt the current interaction and process this message. Suitable for urgent or time-sensitive content.
   */
  INTERRUPT = 'INTERRUPT',
  /**
   * Medium priority - Queued for processing after the current interaction completes. Suitable for follow-up questions.
   */
  APPEND = 'APPEND',
  /**
   * Low priority - Only processed when the agent is idle. Will be discarded during ongoing interactions. Suitable for optional content.
   */
  IGNORE = 'IGNORE'
}

/**
 * Base class for all message types sent to AI agents.
 *
 * This abstract class provides type-safe message handling for different content types.
 * Each message type contains only the fields relevant to its specific functionality.
 */
export abstract class ChatMessage {
}

/**
 * Text message for sending natural language content to AI agents.
 *
 * Text messages support priority control and interruptable response settings,
 * allowing fine-grained control over how the AI processes and responds to text input.
 *
 * Usage examples:
 * - Basic text: new TextMessage(null, null, "Hello, how are you?")
 * - High priority: new TextMessage(Priority.INTERRUPT, null, "Urgent message")
 * - Non-interruptable: new TextMessage(null, false, "Important question")
 */
export class TextMessage extends ChatMessage {
  /**
   * Message processing priority. Default is INTERRUPT.
   */
  priority?: Priority;
  /**
   * Whether the response to this message can be interrupted by higher priority messages. Default is true.
   */
  responseInterruptable?: boolean;
  /**
   * Text content of the message. Optional.
   */
  text?: string;

  constructor(priority?: Priority, responseInterruptable?: boolean, text?: string) {
    super();
    this.priority = priority;
    this.responseInterruptable = responseInterruptable;
    this.text = text;
  }
}

/**
 * Agent State Enum
 *
 * Represents the current state of the AI agent.
 */
export enum AgentState {
  /** Agent is idle */
  IDLE = 'idle',
  /** Agent is silent */
  SILENT = 'silent',
  /** Agent is listening */
  LISTENING = 'listening',
  /** Agent is processing/thinking */
  THINKING = 'thinking',
  /** Agent is speaking */
  SPEAKING = 'speaking',
  /** Unknown state */
  UNKNOWN = 'unknown'
}

/**
 * Get AgentState from string value
 * @param value String value to convert
 * @returns Corresponding AgentState enum value, or UNKNOWN if not found
 */
export function getAgentStateFromValue(value: string): AgentState {
  switch (value) {
    case AgentState.IDLE:
      return AgentState.IDLE;
    case AgentState.SILENT:
      return AgentState.SILENT;
    case AgentState.LISTENING:
      return AgentState.LISTENING;
    case AgentState.THINKING:
      return AgentState.THINKING;
    case AgentState.SPEAKING:
      return AgentState.SPEAKING;
    default:
      return AgentState.UNKNOWN;
  }
}

/**
 * Agent state change event.
 *
 * Represents an event when the AI agent state changes, containing complete state information and timestamp.
 * Used for tracking conversation flow and updating user interface state indicators.
 */
export interface StateChangeEvent {
  /** Current agent state */
  state: AgentState;

  /** Conversation turn ID */
  turnId: number;

  /** Event occurrence timestamp (milliseconds since epoch, i.e., since January 1, 1970 UTC) */
  timestamp: number;
}

/**
 * Message type enum for different message types in the conversation.
 */
export enum MessageType {
  /** Assistant transcription message */
  ASSISTANT = 'assistant.transcription',
  /** User transcription message */
  USER = 'user.transcription',
  /** Interrupt message */
  INTERRUPT = 'message.interrupt',
  /** Message State*/
  MESSAGE_STATE = 'message.state',
  /** Unknown message type */
  UNKNOWN = 'unknown'
}

/**
 * Get MessageType from string value
 * @param value String value to convert
 * @returns Corresponding MessageType enum value, or UNKNOWN if not found
 */
export function getMessageTypeFromValue(value: string): MessageType {
  switch (value) {
    case MessageType.MESSAGE_STATE:
      return MessageType.MESSAGE_STATE;
    case MessageType.ASSISTANT:
      return MessageType.ASSISTANT;
    case MessageType.USER:
      return MessageType.USER;
    case MessageType.INTERRUPT:
      return MessageType.INTERRUPT;
    default:
      return MessageType.UNKNOWN;
  }
}

/**
 * Transcript type enum.
 */
export enum TranscriptType {
  /** AI assistant transcript */
  AGENT,

  /** User transcript */
  USER
}

/**
 * Represents the current status of a Transcript.
 */
export enum TranscriptStatus {
  /** Transcript is still being generated or spoken */
  IN_PROGRESS,

  /** Transcript has completed normally */
  END,

  /** Transcript was interrupted before completion */
  INTERRUPTED,

  /** Unknown status */
  UNKNOWN
}

/**
 * Data class representing a complete transcript message for UI rendering.
 */
export interface Transcript {
  /** Unique identifier for the conversation turn */
  turnId: number;

  /** User identifier associated with this Transcript */
  userId: String;

  /** The actual Transcript text content */
  text: String;

  /** Current status of the Transcript */
  status: TranscriptStatus;

  /** Transcript type (AGENT/USER) */
  type: TranscriptType;
}

/**
 * Interrupt event.
 *
 * Represents an event when a conversation is interrupted, typically triggered when the user actively
 * interrupts AI speaking or the system detects high-priority messages.
 * Used for recording interrupt behavior and performing corresponding processing.
 */
export interface InterruptEvent {
  /** The conversation turn ID that was interrupted */
  turnId: number;

  /** Interrupt event occurrence timestamp (milliseconds since epoch, i.e., since January 1, 1970 UTC) */
  timestamp: number;
}

/**
 * Conversational AI API Configuration.
 *
 * Contains the necessary configuration parameters to initialize the Conversational AI API.
 * This configuration includes RTC engine for audio communication and Transcript rendering mode settings.
 */
export class ConversationalAIAPIConfig {
  /** RTC engine instance for audio/video communication */
  rtcEngine: RtcEngineEx;
  /** Whether to enable logging, default is true. When true, logs will be written to the RTC SDK log file. */
  enableLog: boolean;

  constructor(rtcEngine: RtcEngineEx, enableLog: boolean = true) {
    this.rtcEngine = rtcEngine;
    this.enableLog = enableLog;
  }
}

/**
 * Unknown error.
 *
 * Represents errors that cannot be categorized as RTC errors.
 */
export class ConversationalAIAPIError extends Error {
  /** Error code from RTC SDK */
  code: number;

  constructor(code: number, msg: string) {
    super(msg);
    this.code = code;
  }
}

/**
 * Conversational AI API event handler interface.
 *
 * Implement this interface to receive AI conversation events such as state changes, transcript, and errors.
 * All callbacks are invoked on the main thread for UI updates.
 *
 * @remarks Some callbacks (such as onTranscriptUpdated) may be triggered at high frequency for reliability. If your business requires deduplication, please handle it at the business layer.
 */
export interface IConversationalAIAPIEventHandler {
  /**
   * Called when the agent state changes (idle, silent, listening, thinking, speaking).
   * @param agentUserId Agent user ID
   * @param event State change event
   */
  onAgentStateChanged(agentUserId: string, event: StateChangeEvent): void;

  /**
   * Called when an interrupt event occurs.
   * @param agentUserId Agent user ID
   * @param event Interrupt event
   */
  onAgentInterrupted(agentUserId: string, event: InterruptEvent): void;

  /**
   * Called when Transcript content is updated.
   * @param agentUserId Agent user ID
   * @param transcript Transcript data
   * @remarks This callback may be triggered at high frequency. If you need to deduplicate, please handle it at the business layer.
   */
  onTranscriptUpdated(agentUserId: string, transcript: Transcript): void;

  /**
   * Called for internal debug logs.
   * @param log Debug log message
   */
  onDebugLog(log: string): void;
}

/**
 * Conversational AI API interface.
 *
 * Provides methods for sending messages, interrupting conversations, managing audio settings, and subscribing to events.
 *
 * Typical usage:
 * const api = createConversationalAIAPI(config);
 * api.addHandler(handler);
 * api.subscribeMessage("channelName", (error) => { ... });
 * api.chat("agentUserId", new TextMessage(null, null, "Hi"), (error) => { ... });
 * api.destroy();
 */
export interface IConversationalAIAPI {
  /**
   * Register an event handler to receive AI conversation events.
   * @param handler Event handler instance
   */
  addHandler(handler: IConversationalAIAPIEventHandler): void;

  /**
   * Remove a registered event handler.
   * @param handler Event handler instance
   */
  removeHandler(handler: IConversationalAIAPIEventHandler): void;

  /**
   * Subscribe to a channel to receive AI conversation events.
   * @param channelName Channel name
   * @param completion Callback, error is null on success, non-null on failure
   */
  subscribeMessage(channelName: string, completion: (error: ConversationalAIAPIError | null) => void): void;

  /**
   * Unsubscribe from a channel and stop receiving events.
   * @param channelName Channel name
   * @param completion Callback, error is null on success, non-null on failure
   */
  unsubscribeMessage(channelName: string, completion: (error: ConversationalAIAPIError | null) => void): void;

  /**
   * Send a message to the AI agent.
   *
   * Supports TextMessage for text content.
   *
   * @param agentUserId Agent user ID
   * @param message Message object (TextMessage)
   * @param completion Callback, error is null on success, non-null on failure
   */
  chat(agentUserId: string, message: ChatMessage, completion: (error: ConversationalAIAPIError | null) => void): void;

  /**
   * Interrupt the AI agent's speaking.
   * @param agentUserId Agent user ID
   * @param completion Callback, error is null on success, non-null on failure
   */
  interrupt(agentUserId: string, completion: (error: ConversationalAIAPIError | null) => void): void;

  /**
   * Set audio parameters for optimal AI conversation performance.
   *
   * WARNING: This method MUST be called BEFORE rtcEngine.joinChannel().
   * If you do not call loadAudioSettings before joining the RTC channel, the audio quality for AI conversation may be suboptimal or incorrect.
   *
   * @param scenario Audio scenario, default is AUDIO_SCENARIO_AI_CLIENT.
   * @remarks This method must be called before each joinChannel call to ensure best audio quality.
   * @example
  * ```typescript
   * const api = createConversationalAIAPI(config);
   * api.loadAudioSettings(Constants.AUDIO_SCENARIO_AI_CLIENT); // <-- MUST be called before joinChannel!
   * rtcEngine.joinChannel(token, channelName, null, userId);
   * ```
   */
  loadAudioSettings(): void;

  /**
   * Register callback for receiving RTC data stream messages.
   *
   * This callback is triggered when a data stream message is received from a remote user.
   * Since HarmonyOS RTC SDK does not support multiple callback registrations, this method
   * allows the API implementation to handle data stream messages internally.
   *
   * @param callback Callback function to handle stream messages. Parameters: uid (User ID of the sender),
   * streamId (Stream ID), data (Message data as Uint8Array). Set to undefined to remove the callback.
   * @remarks This callback should be registered before subscribing to messages. The implementation will forward
   * received messages to the internal message handler.
   */
  setOnStreamMessage(uid: number, streamId: number, data: Uint8Array): void;

  /**
   * Register callback for RTC data stream message errors.
   *
   * This callback is triggered when an error occurs while receiving data stream messages.
   * Since HarmonyOS RTC SDK does not support multiple callback registrations, this method
   * allows the API implementation to handle data stream errors internally.
   *
   * @param callback Callback function to handle stream message errors. Parameters: uid (User ID of the sender),
   * streamId (Stream ID), error (Error code), missed (Number of missed messages), cached (Number of cached messages).
   * Set to undefined to remove the callback.
   * @remarks This callback should be registered before subscribing to messages. The implementation will handle
   * errors and log them appropriately.
   */
  setOnStreamMessageError(uid: number, streamId: number, error: number, missed: number, cached: number): void;

  /**
   * Destroy the API instance and release resources. After calling, this instance cannot be used again.
   * All resources will be released. Call when the API is no longer needed.
   */
  destroy(): void;
}

