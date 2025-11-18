import { RtcEngineEx } from '@shengwang/rtc-full';
import {
  MessageType,
  TranscriptRenderMode,
  TranscriptStatus,
  TranscriptType,
  Transcript,
  InterruptEvent,
  getMessageTypeFromValue
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
  /** Transcript rendering mode */
  renderMode: TranscriptRenderMode;
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
    renderMode: TranscriptRenderMode,
    callback: IConversationTranscriptCallback
  ) {
    this.rtcEngine = rtcEngine;
    this.renderMode = renderMode;
    this.callback = callback;
  }
}

/**
 * Internal data class representing individual word information
 * Used by the producer side of the subtitle pipeline
 */
class TurnWordInfo {
  /** The actual word text */
  word: string;
  /** Timestamp when the word started (in milliseconds) */
  startMs: number;
  /** Current status of the word */
  status: TranscriptStatus;

  constructor(word: string, startMs: number, status: TranscriptStatus = TranscriptStatus.IN_PROGRESS) {
    this.word = word;
    this.startMs = startMs;
    this.status = status;
  }
}

/**
 * Internal data class representing a complete turn message
 * Used by the producer side of the subtitle pipeline
 */
class TurnMessageInfo {
  /** Agent user ID */
  agentUserId: string;
  /** User identifier for this turn */
  userId: string;
  /** Unique identifier for this turn */
  turnId: number;
  /** Start timestamp of the turn (in milliseconds) */
  startMs: number;
  /** Complete text of the turn */
  text: string;
  /** Current status of the turn */
  status: TranscriptStatus;
  /** List of individual words in the turn */
  words: TurnWordInfo[];

  constructor(agentUserId: string, userId: string, turnId: number, startMs: number, text: string,
    status: TranscriptStatus, words: TurnWordInfo[]) {
    this.agentUserId = agentUserId;
    this.userId = userId;
    this.turnId = turnId;
    this.startMs = startMs;
    this.text = text;
    this.status = status;
    this.words = words;
  }
}

const TAG = '[Transcript]';
const TAG_UI = '[Transcript-UI]';

/**
 * Type alias for available turn with filtered words
 */
interface AvailableTurn {
  turn: TurnMessageInfo;
  words: TurnWordInfo[];
}

/**
 * Transcript Rendering Controller
 * Manages the processing and rendering of transcripts in conversation
 */
export class TranscriptController {
  private config: TranscriptConfig;
  private renderMode: TranscriptRenderMode | null = null;
  private presentationMs: number = 0;
  private agentTurnQueue: TurnMessageInfo[] = [];
  private lastInterruptEvent: InterruptEvent | null = null;
  private currentTranscript: Transcript | null = null;
  private lastDequeuedTurn: TurnMessageInfo | null = null;
  private tickerTimer: number | null = null;

  constructor(config: TranscriptConfig) {
    this.config = config;

    config.rtcEngine.setPlaybackAudioFrameBeforeMixingParameters(44100, 1);

    this.callMessagePrint(TAG, `init RenderMode:${config.renderMode}`);
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
    this.renderMode = null;
    this.stopSubtitleTicker();
  }

  /**
   * Release transcript controller
   */
  release(): void {
    this.reset();
    this.callMessagePrint(TAG, '>>> [release]');
    if (this.tickerTimer !== null) {
      clearInterval(this.tickerTimer);
      this.tickerTimer = null;
    }
  }

  /**
   * Start subtitle ticker for word-level rendering
   */
  private startSubtitleTicker(): void {
    this.callMessagePrint(TAG, 'startSubtitleTicker');
    this.lastDequeuedTurn = null;
    this.currentTranscript = null;
    this.lastInterruptEvent = null;

    if (this.tickerTimer !== null) {
      clearInterval(this.tickerTimer);
    }

    // Use setInterval to simulate ticker (200ms interval)
    this.tickerTimer = setInterval(() => {
      this.updateSubtitleDisplay();
    }, 200);
  }

  /**
   * Stop subtitle ticker
   */
  private stopSubtitleTicker(): void {
    this.callMessagePrint(TAG, 'stopSubtitleTicker');
    this.currentTranscript = null;
    this.lastDequeuedTurn = null;
    this.lastInterruptEvent = null;
    this.agentTurnQueue = [];

    if (this.tickerTimer !== null) {
      clearInterval(this.tickerTimer);
      this.tickerTimer = null;
    }
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

    if (this.renderMode === TranscriptRenderMode.Word) {
      this.handleAgentWordMessage(
        agentUserId,
        '',
        turnId,
        startMs,
        '',
        null,
        TranscriptStatus.INTERRUPTED
      );
    }
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
      renderMode: this.renderMode || this.config.renderMode
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

    // Parse words array
    // words is a list where each element is a Map<String, Any>
    const wordsValue = msg['words'];
    const wordsArray = Array.isArray(wordsValue)
      ? wordsValue as Record<string, Object>[]
      : null;
    const words = this.parseWords(wordsArray);
    this.autoTranscriptRenderMode(words);

    if (this.renderMode === TranscriptRenderMode.Text) {
      this.handleAgentTextMessage(agentUserId, userId, turnId, text, status);
    } else {
      this.handleAgentWordMessage(agentUserId, userId, turnId, startMs, text, words, status);
    }
  }

  /**
   * Parse words array
   * Convert words array (List<Map<String, Any>>) to TurnWordInfo list
   * Each element in the array is a Map containing word information
   */
  private parseWords(wordsArray: Record<string, Object>[] | null | undefined): TurnWordInfo[] | null {
    if (!wordsArray || wordsArray.length === 0) {
      return null;
    }

    // Convert words array to TurnWordInfo list
    // Each wordMap is a Map<String, Any> from the list
    const wordsList: TurnWordInfo[] = wordsArray.map((wordMap: Record<string, Object>) => {
      const word = (wordMap['word'] as string) || '';
      const startMs = (wordMap['start_ms'] ?? 0) as number;
      return new TurnWordInfo(word, startMs);
    });

    // Return immutable array (arrays in ArkTS are already immutable in terms of length)
    return wordsList;
  }

  /**
   * Auto-detect transcript render mode
   */
  private autoTranscriptRenderMode(words: TurnWordInfo[] | null): void {
    if (this.renderMode === null) {
      this.agentTurnQueue = [];
      this.renderMode =
        this.config.renderMode === TranscriptRenderMode.Word
          ? words !== null
          ? TranscriptRenderMode.Word
          : TranscriptRenderMode.Text
          : TranscriptRenderMode.Text;

      this.callMessagePrint(
        TAG,
        `RenderMode:${this.renderMode}`
      );

      if (this.renderMode === TranscriptRenderMode.Word) {
        this.startSubtitleTicker();
      }
    }
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
      type: TranscriptType.AGENT,
      renderMode: TranscriptRenderMode.Text
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
   * Handle agent word message
   */
  private handleAgentWordMessage(
    agentUserId: string,
    userId: string,
    turnId: number,
    startMs: number,
    text: string,
    words: TurnWordInfo[] | null,
    status: TranscriptStatus
  ): void {
    // Word mode processing
    const newWords = words ? [...words] : [];

    // Thread-safe queue operations (simulated with array operations)
    // Check if this turn is older than the latest turn in queue
    const lastTurn = this.agentTurnQueue.length > 0
      ? this.agentTurnQueue[this.agentTurnQueue.length - 1]
      : null;

    if (lastTurn !== null && turnId < lastTurn.turnId) {
      this.callMessagePrint(TAG, `Discarding old turn: received=${turnId} latest=${lastTurn.turnId}`);
      return;
    }

    // The last turn to be dequeued
    if (this.lastDequeuedTurn !== null) {
      if (turnId <= this.lastDequeuedTurn.turnId) {
        this.callMessagePrint(
          TAG,
          `Discarding the turn has already been processed: received=${turnId} latest=${this.lastDequeuedTurn.turnId}`
        );
        return;
      }
    }

    // Remove and get existing info in one operation
    const existingInfoIndex = this.agentTurnQueue.findIndex((info) => info.turnId === turnId);
    const existingInfo = existingInfoIndex >= 0 ? this.agentTurnQueue[existingInfoIndex] : null;

    if (existingInfo !== null) {
      if (status === TranscriptStatus.INTERRUPTED && existingInfo.status === TranscriptStatus.INTERRUPTED) {
        return;
      }

      // Remove existing info
      this.agentTurnQueue.splice(existingInfoIndex, 1);

      if (status === TranscriptStatus.INTERRUPTED) {
        // The actual effective timestamp for interruption, using the minimum of startMs and mPresentationMs
        const interruptMarkMs = Math.min(startMs, this.presentationMs);
        this.callMessagePrint(
          TAG,
          `interruptMarkMs:${interruptMarkMs} startMs:${startMs} mPresentationMs:${this.presentationMs}`
        );

        // Interrupt all words from the last one before interruptMarkMs to the end of the word list
        let lastBeforeStartMs: TurnWordInfo | null = null;
        const mergedWords: TurnWordInfo[] = [...existingInfo.words];

        for (const word of mergedWords) {
          if (word.startMs <= interruptMarkMs) {
            lastBeforeStartMs = word;
          }
          if (word.startMs >= interruptMarkMs) {
            word.status = TranscriptStatus.INTERRUPTED;
          }
        }

        if (lastBeforeStartMs !== null) {
          lastBeforeStartMs.status = TranscriptStatus.INTERRUPTED;
        }

        const newInfo = new TurnMessageInfo(
          agentUserId,
          userId,
          turnId,
          existingInfo.startMs,
          existingInfo.text,
          status,
          mergedWords
        );
        this.agentTurnQueue.push(newInfo);
      } else {
        // Reset end flag of existing words if needed
        const lastWord = existingInfo.words.length > 0
          ? existingInfo.words[existingInfo.words.length - 1]
          : null;
        if (lastWord !== null && lastWord.status === TranscriptStatus.END) {
          lastWord.status = TranscriptStatus.IN_PROGRESS;
        }

        // Use new data if the new message has a later timestamp
        const useNewData = startMs >= existingInfo.startMs;

        // Merge words and sort by timestamp
        const mergedWords = [...existingInfo.words];
        newWords.forEach((newWord) => {
          // Check if a word with the same startMs already exists
          if (existingInfo.words.every((w) => w.startMs !== newWord.startMs)) {
            mergedWords.push(newWord);
          }
        });

        const sortedMergedWords = mergedWords.sort((a, b) => a.startMs - b.startMs);

        // Traverse sortedMergedWords, set the status of the word after the first Interrupted word to Interrupted
        let foundInterrupted = false;
        sortedMergedWords.forEach((word) => {
          if (foundInterrupted || word.status === TranscriptStatus.INTERRUPTED) {
            word.status = TranscriptStatus.INTERRUPTED;
            foundInterrupted = true;
          }
        });

        const newInfo = new TurnMessageInfo(
          useNewData ? agentUserId : existingInfo.agentUserId,
          userId,
          turnId,
          useNewData ? startMs : existingInfo.startMs,
          useNewData ? text : existingInfo.text,
          useNewData ? status : existingInfo.status,
          sortedMergedWords
        );

        // Mark the last word as end if this is the final message
        if (newInfo.status === TranscriptStatus.END && sortedMergedWords.length > 0) {
          sortedMergedWords[sortedMergedWords.length - 1].status = TranscriptStatus.END;
        }

        this.agentTurnQueue.push(newInfo);
      }
    } else {
      // No existing message, use new message directly
      const newInfo = new TurnMessageInfo(
        agentUserId,
        userId,
        turnId,
        startMs,
        text,
        status,
        newWords
      );

      if (status === TranscriptStatus.END && newWords.length > 0) {
        newWords[newWords.length - 1].status = TranscriptStatus.END;
      }

      this.agentTurnQueue.push(newInfo);
    }

    // Cleanup old turns
    while (this.agentTurnQueue.length > 5) {
      const removed = this.agentTurnQueue.shift();
      if (removed) {
        this.callMessagePrint(TAG, `Removed old turn: ${removed.turnId}`);
      }
    }
  }

  /**
   * Update subtitle display
   */
  private updateSubtitleDisplay(): void {
    // Audio callback PTS is not assigned
    if (this.presentationMs <= 0) {
      return;
    }
    if (this.renderMode !== TranscriptRenderMode.Word) {
      return;
    }

    // Thread-safe queue operations (simulated with array operations)
    // Get all turns that meet display conditions
    const availableTurns: AvailableTurn[] = [];

    for (const turn of this.agentTurnQueue) {
      const words = turn.words.filter((w) => w.startMs <= this.presentationMs);

      if (words.length > 0 && words[words.length - 1].status === TranscriptStatus.INTERRUPTED) {
        // Handle interrupted turn
        const interruptedText = words.map((w) => w.word).join('');
        const interruptedTranscript: Transcript = {
          turnId: turn.turnId,
          userId: turn.userId,
          text: interruptedText,
          status: TranscriptStatus.INTERRUPTED,
          type: TranscriptType.AGENT,
          renderMode: TranscriptRenderMode.Word
        };

        const agentUserId = turn.agentUserId;
        this.callMessagePrint(
          TAG_UI,
          `<<< [interrupt1] pts:${this.presentationMs} ${agentUserId} ${JSON.stringify(interruptedTranscript)}`
        );

        this.runOnMainThread(() => {
          this.config.callback?.onTranscriptUpdated?.(agentUserId, interruptedTranscript);
        });

        // Remove the turn if interrupt condition is met
        this.lastDequeuedTurn = turn;
        const index = this.agentTurnQueue.indexOf(turn);
        if (index >= 0) {
          this.agentTurnQueue.splice(index, 1);
        }
        this.currentTranscript = null;
        this.callMessagePrint(TAG, `Removed interrupted turn:${turn.turnId}`);
      } else {
        if (words.length > 0) {
          const availableTurn: AvailableTurn = {
            turn: turn,
            words: words
          };
          availableTurns.push(availableTurn);
        }
      }
    }

    if (availableTurns.length === 0) {
      return;
    }

    // Find the latest turn to display
    const latestValidTurn = availableTurns[availableTurns.length - 1];
    const targetTurn = latestValidTurn.turn;
    const targetWords = latestValidTurn.words;
    const targetIsEnd = targetWords[targetWords.length - 1].status === TranscriptStatus.END;

    // Interrupt all previous turns
    if (availableTurns.length > 1) {
      // Iterate through all turns except the last one
      for (let i = 0; i < availableTurns.length - 1; i++) {
        const turn = availableTurns[i].turn;
        if (this.currentTranscript && this.currentTranscript.turnId === turn.turnId) {
          const agentUserId = turn.agentUserId;
          const interruptedTranscript: Transcript = {
            turnId: this.currentTranscript.turnId,
            userId: this.currentTranscript.userId,
            text: this.currentTranscript.text,
            status: TranscriptStatus.INTERRUPTED,
            type: this.currentTranscript.type,
            renderMode: this.currentTranscript.renderMode
          };

          this.callMessagePrint(
            TAG_UI,
            `<<< [interrupt2] pts:${this.presentationMs} ${agentUserId} ${JSON.stringify(interruptedTranscript)}`
          );

          this.runOnMainThread(() => {
            this.config.callback?.onTranscriptUpdated?.(agentUserId, interruptedTranscript);
          });
        }

        this.lastDequeuedTurn = turn;
        // Remove the interrupted turn from queue
        const index = this.agentTurnQueue.indexOf(turn);
        if (index >= 0) {
          this.agentTurnQueue.splice(index, 1);
        }
      }
      this.currentTranscript = null;
    }

    const agentUserId = targetTurn.agentUserId;

    // Display the latest turn
    const newTranscript: Transcript = {
      turnId: targetTurn.turnId,
      userId: targetTurn.userId,
      text: targetIsEnd
        ? targetTurn.text
        : targetWords.map((w) => w.word).join(''),
      status: targetIsEnd ? TranscriptStatus.END : TranscriptStatus.IN_PROGRESS,
      type: TranscriptType.AGENT,
      renderMode: TranscriptRenderMode.Word
    };

    if (targetIsEnd) {
      this.callMessagePrint(
        TAG_UI,
        `<<< [end] pts:${this.presentationMs} ${agentUserId} ${JSON.stringify(newTranscript)}`
      );
    } else {
      this.callMessagePrint(
        TAG_UI,
        `<<< [progress] pts:${this.presentationMs} ${agentUserId} ${JSON.stringify(newTranscript)}`
      );
    }

    this.runOnMainThread(() => {
      this.config.callback?.onTranscriptUpdated?.(agentUserId, newTranscript);
    });

    if (targetIsEnd) {
      this.lastDequeuedTurn = targetTurn;
      const index = this.agentTurnQueue.indexOf(targetTurn);
      if (index >= 0) {
        this.agentTurnQueue.splice(index, 1);
      }
      this.currentTranscript = null;
    } else {
      this.currentTranscript = newTranscript;
    }
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

