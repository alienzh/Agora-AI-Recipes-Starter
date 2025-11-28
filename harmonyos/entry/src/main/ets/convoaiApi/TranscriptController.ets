import { RtcEngineEx } from '@shengwang/rtc-full';
import {
  MessageType,
  TranscriptStatus,
  TranscriptType,
  Transcript,
  InterruptEvent,
} from './IConversationalAIAPI';

/**
 * Callback interface for transcript-related events
 */
export interface IConversationTranscriptCallback {
  /**
   * Called when transcript content is updated
   * @param agentUserId Agent user ID
   * @param transcript Transcript data
   */
  onTranscriptUpdated?: (agentUserId: string, transcript: Transcript) => void;

  /**
   * Called for debug logs
   * @param tag Log tag
   * @param msg Log message
   */
  onDebugLog?: (tag: string, msg: string) => void;

  /**
   * Called when agent is interrupted
   * @param agentUserId Agent user ID
   * @param event Interrupt event
   */
  onAgentInterrupted?: (agentUserId: string, event: InterruptEvent) => void;
}

/**
 * Configuration for TranscriptController
 */
export class TranscriptConfig {
  /** RTC engine instance */
  rtcEngine: RtcEngineEx;
  /** Callback for transcript events */
  callback: IConversationTranscriptCallback;

  /**
   * Constructor for TranscriptConfig
   * @param rtcEngine RTC engine instance
   * @param renderMode Transcript rendering mode
   * @param callback Optional callback for transcript events
   */
  constructor(
    rtcEngine: RtcEngineEx,
    callback: IConversationTranscriptCallback
  ) {
    this.rtcEngine = rtcEngine;
    this.callback = callback;
  }
}

const TAG = '[Transcript]';
const TAG_UI = '[Transcript-UI]';

/**
 * Transcript Rendering Controller
 * Manages the processing and rendering of transcripts in conversation
 */
export class TranscriptController {
  private config: TranscriptConfig;
  private presentationMs: number = 0;
  private lastInterruptEvent: InterruptEvent | null = null;

  constructor(config: TranscriptConfig) {
    this.config = config;
    config.rtcEngine.setPlaybackAudioFrameBeforeMixingParameters(44100, 1);

    this.callMessagePrint(TAG, `init TranscriptController`);
  }


  /**
   * Handle parsed stream message
   *
   * This method processes already parsed message map data and routes it to appropriate handlers
   * based on the message type.
   *
   * @param agentUserId Agent user ID (publisher ID)
   * @param messageType Message State
   * @param messageMap Parsed message data as Record<string, Object>
   */
  setOnStreamMessage(agentUserId: string, messageType: MessageType, messageMap: Record<string, Object>): void {
    this.callMessagePrint(TAG, `<<< [onStreamMessage] agentUserId:${agentUserId}, ${JSON.stringify(messageMap)}`);

    try {
      switch (messageType) {
        case MessageType.INTERRUPT:
          this.handleInterruptMessage(agentUserId, messageMap);
          break;
        case MessageType.USER:
          this.handleUserMessage(agentUserId, messageMap);
          break;
        case MessageType.ASSISTANT:
          this.handleAgentMessage(agentUserId, messageMap);
          break;
        default:
          break;
      }
    } catch (e) {
      const errorMessage = e instanceof Error ? e.message : 'Unknown error';
      this.callMessagePrint(TAG, `[!] setOnStreamMessage Exception: ${errorMessage}`);
    }
  }

  /**
   * Reset transcript controller
   */
  reset(): void {
    this.callMessagePrint(TAG, '>>> [reset]');
    this.lastInterruptEvent = null;
    this.presentationMs = 0;
  }

  /**
   * Handle interrupt message
   */
  private handleInterruptMessage(agentUserId: string, msg: Record<string, Object>): void {
    const turnId = (msg['turn_id'] as number) || 0;
    const startMs = (msg['start_ms'] as number) || 0;

    const interruptEvent: InterruptEvent = {
      turnId: turnId,
      timestamp: startMs
    };
    this.lastInterruptEvent = interruptEvent;

    const callback = this.config.callback;
    this.runOnMainThread(() => {
      callback?.onAgentInterrupted?.(agentUserId, interruptEvent);
    });

    this.callMessagePrint(
      TAG,
      `<<< [onInterrupted] pts:${this.presentationMs} ${agentUserId} ${JSON.stringify(interruptEvent)}`
    );
  }

  /**
   * Handle user message
   */
  private handleUserMessage(agentUserId: string, msg: Record<string, Object>): void {
    const text = (msg['text'] as string) || '';
    if (text.length === 0) {
      this.callMessagePrint(TAG, 'user message but text is null');
      return;
    }

    const turnId = (msg['turn_id'] as number) || 0;
    const userId = (msg['user_id'] as string) || '';
    const isFinal = (msg['final'] as boolean) || false;

    let transcript: Transcript = {
      turnId: turnId,
      userId: userId,
      text: text,
      status: isFinal ? TranscriptStatus.END : TranscriptStatus.IN_PROGRESS,
      type: TranscriptType.USER,
    };

    this.callMessagePrint(
      TAG_UI,
      `<<< [onTranscriptUpdated] pts:${this.presentationMs} ${agentUserId} ${JSON.stringify(transcript)}`
    );

    const callback = this.config.callback;
    this.runOnMainThread(() => {
      callback?.onTranscriptUpdated?.(agentUserId, transcript);
    });
  }

  /**
   * Handle agent message
   */
  private handleAgentMessage(agentUserId: string, msg: Record<string, Object>): void {
    const text = (msg['text'] as string) || '';
    if (text.length === 0) {
      this.callMessagePrint(TAG, 'agent message but text is null');
      return;
    }

    const turnId = (msg['turn_id'] as number) || 0;
    const startMs = (msg['start_ms'] as number) || 0;
    const userId = (msg['user_id'] as string) || '';

    // 0: in-progress, 1: end gracefully, 2: interrupted, otherwise undefined
    const turnStatusInt = (msg['turn_status'] as number) || 0;
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
      this.callMessagePrint(TAG, `unknown turn_status:${turnStatusInt}`);
      return;
    }

    this.handleAgentTextMessage(agentUserId, userId, turnId, text, status);
  }

  /**
   * Handle agent text message
   */
  private handleAgentTextMessage(
    agentUserId: string,
    userId: string,
    turnId: number,
    text: string,
    status: TranscriptStatus
  ): void {
    if (this.lastInterruptEvent?.turnId === turnId) {
      this.callMessagePrint(TAG, `agent message but turn:${turnId} is Interrupted`);
      return;
    }

    const transcript: Transcript = {
      turnId: turnId,
      userId: userId,
      text: text,
      status: status,
      type: TranscriptType.AGENT
    };

    this.callMessagePrint(
      TAG_UI,
      `<<< [Text Mode] pts:${this.presentationMs} ${agentUserId} ${JSON.stringify(transcript)}`
    );

    const callback = this.config.callback;
    this.runOnMainThread(() => {
      callback?.onTranscriptUpdated?.(agentUserId, transcript);
    });
  }

  /**
   * Run on main thread
   * Uses setTimeout as a simple way to execute on main thread
   */
  private runOnMainThread(callback: () => void): void {
    setTimeout(() => {
      callback();
    }, 0);
  }

  /**
   * Call message print
   */
  private callMessagePrint(tag: string, message: string): void {
    this.config.callback?.onDebugLog?.(tag, message);
  }
}

