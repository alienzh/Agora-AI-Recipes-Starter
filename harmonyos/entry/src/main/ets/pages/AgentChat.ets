import { AgentChatController, ConnectionState, ConversationUiState, Transcript, AgentState, TranscriptType, TranscriptStatus } from './AgentChatController';
import { TranscriptDataSource } from './components/TranscriptDataSource';
import PermissionHelper from '../utils/PermissionHelper';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';

/**
 * Agent Chat page
 * Combined page for agent initialization, display, and control
 * Layout: log, agent status, transcript, start/control buttons
 */
@Entry
@Component
export struct AgentChat {
  @State viewModel: AgentChatController = AgentChatController.getInstance();
  @State uiState: ConversationUiState = {
    isMuted: false,
    connectionState: ConnectionState.Idle
  };
  @State transcriptList: Transcript[] = [];
  @State agentState: AgentState | null = null;
  @State autoScrollToBottom: boolean = true;
  @State isScrollBottom: boolean = false;
  @State debugLogList: string[] = [];
  private transcriptListRef: ListScroller = new ListScroller();
  private transcriptDataSource: TranscriptDataSource = new TranscriptDataSource();

  aboutToAppear(): void {
    // Initialize ViewModel with context
    const uiCtx = this.getUIContext();
    const hostContext = uiCtx.getHostContext();
    if (hostContext == undefined) {
      return;
    }
    this.viewModel.initialize(hostContext);

    // Get current state immediately
    const currentState = this.viewModel.getUiState();
    this.uiState = currentState;
    this.agentState = this.viewModel.getAgentState();
    this.debugLogList = this.viewModel.getDebugLogList();

    // Set data source to ViewModel - ViewModel will directly update it
    this.viewModel.setTranscriptDataSource(this.transcriptDataSource);

    // Initialize data source with existing transcripts
    const initialList = this.viewModel.getTranscriptList();
    for (let i = 0; i < initialList.length; i++) {
      this.transcriptDataSource.pushData(initialList[i]);
    }
    this.transcriptList = initialList;

    // Start polling for state updates (since we removed callbacks for single-page architecture)
    this.startStatePolling();
  }

  private statePollingTimer: number | null = null;

  aboutToDisappear(): void {
    // Stop polling timer
    if (this.statePollingTimer !== null) {
      clearInterval(this.statePollingTimer);
      this.statePollingTimer = null;
    }
  }

  /**
   * Start polling for state updates
   * Since we removed callbacks for single-page architecture, we poll periodically
   */
  private startStatePolling(): void {
    // Poll every 100ms for state updates
    this.statePollingTimer = setInterval(() => {
      // Update UI state
      const currentState = this.viewModel.getUiState();
      if (currentState.isMuted !== this.uiState.isMuted ||
        currentState.connectionState !== this.uiState.connectionState) {
        this.uiState = currentState;

        // Auto scroll to bottom when new transcript is added
        if (this.autoScrollToBottom) {
          this.scrollToBottom();
        }
      }

      // Update agent state
      const currentAgentState = this.viewModel.getAgentState();
      if (currentAgentState !== this.agentState) {
        this.agentState = currentAgentState;
      }

      // Update debug log list
      const currentLogs = this.viewModel.getDebugLogList();
      if (currentLogs.length !== this.debugLogList.length ||
        (currentLogs.length > 0 &&
          currentLogs[currentLogs.length - 1] !== this.debugLogList[this.debugLogList.length - 1])) {
        this.debugLogList = currentLogs;
      }
    }, 100);
  }

  build() {
    Column() {
      // Log Section
      this.buildLogSection()

      // Transcript List and Agent Status (combined in one card)
      this.buildTranscriptCard()

      // Control Buttons
      this.buildControlButtons()
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .backgroundColor('#F5F5F5')
  }

  /**
   * Build log section
   */
  @Builder
  buildLogSection() {
    Scroll() {
      Text(this.debugLogList.length > 0 ? this.debugLogList.join('\n') : 'log')
        .fontSize(12)
        .fontColor('#666666')
        .width('100%')
    }
    .width('100%')
    .height(120)
    .scrollBar(BarState.Auto)
    .padding(12)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .shadow({
      radius: 4,
      color: '#1F000000',
      offsetX: 0,
      offsetY: 2
    })
    .margin({ bottom: 12 })
  }

  /**
   * Build transcript card with agent status at bottom
   */
  @Builder
  buildTranscriptCard() {
    Column() {
      // Transcript List
      this.buildTranscriptList()

      // Agent Status Section (at bottom of transcript area)
      Row() {
        Text('Agent Status:')
          .fontSize(14)
          .fontColor('#666666')
        Text(this.getAgentStateText())
          .fontSize(14)
          .fontColor('#666666')
          .margin({ left: 8 })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .padding(16)
    }
    .width('100%')
    .layoutWeight(1)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .shadow({
      radius: 4,
      color: '#1F000000',
      offsetX: 0,
      offsetY: 2
    })
    .margin({ top: 8, bottom: 16 })
  }

  /**
   * Build transcript list
   */
  @Builder
  buildTranscriptList() {
    List({ space: 0, scroller: this.transcriptListRef }) {
      LazyForEach(this.transcriptDataSource, (transcript: Transcript) => {
        ListItem() {
          this.buildTranscriptItem(transcript)
        }
      }, (transcript: Transcript) => JSON.stringify(transcript))
    }
    .width('100%')
    .layoutWeight(1)
    .padding({
      top: 12,
      bottom: 12,
      left: 12,
      right: 12
    })
    .scrollBar(BarState.Auto)
    .onReachEnd(() => {
      this.isScrollBottom = true;
      this.autoScrollToBottom = true;
    })
    .onScroll((scrollOffset: number, scrollState: ScrollState) => {
      // Check if user is scrolling up
      if (scrollState === ScrollState.Scroll) {
        // When user actively scrolls, disable auto-scroll
        if (scrollOffset < 0) {
          this.autoScrollToBottom = false;
        }
      }
    })
  }

  /**
   * Build transcript item
   * AGENT messages align left, USER messages align right
   */
  @Builder
  buildTranscriptItem(transcript: Transcript) {
    Row() {
      Column() {
        Row() {
          if (transcript.type !== TranscriptType.USER) {
            // Type badge for AGENT (on the left)
            Text('AGENT')
              .fontSize(12)
              .fontColor(Color.White)
              .fontWeight(FontWeight.Bold)
              .padding({
                left: 8,
                right: 8,
                top: 4,
                bottom: 4
              })
              .backgroundColor('#6366F1')
              .borderRadius(4)
          }

          // Status badge
          Text(this.getTranscriptStatusText(transcript.status))
            .fontSize(12)
            .fontColor(this.getTranscriptStatusTextColor(transcript.status))
            .fontWeight(FontWeight.Bold)
            .margin({ left: transcript.type === TranscriptType.USER ? 0 : 8 })

          if (transcript.type === TranscriptType.USER) {
            // Type badge for USER (on the right)
            Text('USER')
              .fontSize(12)
              .fontColor(Color.White)
              .fontWeight(FontWeight.Bold)
              .padding({
                left: 8,
                right: 8,
                top: 4,
                bottom: 4
              })
              .backgroundColor('#10B981')
              .borderRadius(4)
              .margin({ left: 8 })
          }
        }
        .width('100%')
        .justifyContent(transcript.type === TranscriptType.USER ? FlexAlign.End : FlexAlign.Start)

        // Transcript text
        Text(transcript.text?.toString() || '(empty)')
          .fontSize(14)
          .fontColor('#333333')
          .width('100%')
          .margin({ top: 8 })
          .textAlign(transcript.type === TranscriptType.USER ? TextAlign.End : TextAlign.Start)
      }
      .width('100%')
      .padding(12)
      .alignItems(transcript.type === TranscriptType.USER ? HorizontalAlign.End : HorizontalAlign.Start)
      .backgroundColor('#F3F4F6')
      .borderRadius(8)
    }
    .width('100%')
    .justifyContent(transcript.type === TranscriptType.USER ? FlexAlign.End : FlexAlign.Start)
    .margin({ bottom: 8 })
  }

  /**
   * Build control buttons
   */
  @Builder
  buildControlButtons() {
    Row() {
      // Mute button (shown when connected)
      if (this.uiState.connectionState === ConnectionState.Connected) {
        Stack({ alignContent: Alignment.Center }) {
          Circle({ width: 64, height: 64 })
            .fill('#4CAF50')

          Text(this.uiState.isMuted ? '🔇' : '🎤')
            .fontSize(24)
        }
        .width(64)
        .height(64)
        .onClick(() => {
          this.viewModel.toggleMute();
        })
        .margin({ right: 24 })
      }

      // Start Button (shown when not connected, hidden when connected)
      if (this.uiState.connectionState !== ConnectionState.Connected) {
        Button(this.uiState.connectionState === ConnectionState.Connecting ? 'Starting...' : 'Start Agent')
          .width('100%')
          .height(64)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .enabled(this.uiState.connectionState !== ConnectionState.Connecting)
          .backgroundColor('#007AFF')
          .borderRadius(16)
          .onClick(() => {
            this.handleStart();
          })
      }

      // Stop button (shown when connected)
      if (this.uiState.connectionState === ConnectionState.Connected) {
        Button('Stop Agent')
          .layoutWeight(2)
          .height(64)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .backgroundColor('#F44336')
          .borderRadius(16)
          .onClick(() => {
            this.viewModel.hangup();
          })
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .margin({ bottom: 16 })
  }

  /**
   * Handle start button click
   * Generate random channel name each time joining channel
   * Check microphone permission before joining channel
   */
  private async handleStart(): Promise<void> {
    // Generate random channel name each time joining channel
    const channelName = AgentChatController.generateRandomChannelName();

    // Get UIAbilityContext for permission check
    const uiCtx = this.getUIContext();
    const hostContext = uiCtx.getHostContext();

    // Check microphone permission before joining channel
    if (!(await PermissionHelper.checkPermissions(
      hostContext as common.UIAbilityContext,
      ['ohos.permission.MICROPHONE']
    ))) {
      promptAction.showToast({
        message: 'Microphone permission is required to join channel',
        duration: 2000
      });
      return;
    }

    // Permission granted, join channel
    this.viewModel.joinChannel(channelName);
  }

  /**
   * Scroll to bottom of transcript list
   */
  private scrollToBottom(): void {
    if (this.transcriptListRef && this.transcriptDataSource.totalCount() > 0) {
      setTimeout(() => {
        this.transcriptListRef?.scrollToIndex(this.transcriptDataSource.totalCount() - 1);
        this.isScrollBottom = true;
      }, 100);
    }
  }

  /**
   * Get status text for transcript item
   */
  private getTranscriptStatusText(status: TranscriptStatus): string {
    switch (status) {
      case TranscriptStatus.IN_PROGRESS:
        return 'IN PROGRESS';
      case TranscriptStatus.END:
        return 'END';
      case TranscriptStatus.INTERRUPTED:
        return 'INTERRUPTED';
      default:
        return 'UNKNOWN';
    }
  }

  /**
   * Get status text color for transcript item
   */
  private getTranscriptStatusTextColor(status: TranscriptStatus): ResourceColor {
    switch (status) {
      case TranscriptStatus.IN_PROGRESS:
        return '#FF9800';
      case TranscriptStatus.END:
        return '#4CAF50';
      case TranscriptStatus.INTERRUPTED:
        return '#F44336';
      default:
        return '#9E9E9E';
    }
  }

  /**
   * Get agent state text
   */
  private getAgentStateText(): string {
    if (!this.agentState) {
      return 'Unknown';
    }
    switch (this.agentState) {
      case AgentState.IDLE:
        return 'idle';
      case AgentState.SILENT:
        return 'silent';
      case AgentState.LISTENING:
        return 'listening';
      case AgentState.THINKING:
        return 'thinking';
      case AgentState.SPEAKING:
        return 'speaking';
      default:
        return 'unknown';
    }
  }
}

