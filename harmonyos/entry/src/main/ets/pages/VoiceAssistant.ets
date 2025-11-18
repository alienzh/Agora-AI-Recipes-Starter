import { ConversationViewModel, ConnectionState, ConversationUiState } from '../viewmodel/ConversationViewModel';
import { Transcript, AgentState, TranscriptType, TranscriptStatus } from '../convoaiApi/IConversationalAIAPI';
import { VoiceWaveView } from './common/VoiceWaveView';
import { TranscriptDataSource } from './common/TranscriptDataSource';
import { router } from '@kit.ArkUI';

/**
 * Voice Assistant page
 * Main interface for voice conversation with AI agent
 */
@Entry
@Component
@Preview
export struct VoiceAssistant {
  @State viewModel: ConversationViewModel = ConversationViewModel.getInstance();
  @State uiState: ConversationUiState = {
    statusMessage: '',
    isMuted: false,
    isTranscriptEnabled: false,
    channelName: '',
    userUid: 0,
    agentUid: 0,
    connectionState: ConnectionState.Idle
  };
  @State transcriptList: Transcript[] = [];
  @State agentState: AgentState | null = null;
  @State autoScrollToBottom: boolean = true;
  @State isScrollBottom: boolean = false;
  @State statusHistory: string[] = [];
  @State lastStatusMessage: string = '';
  @State statusDisplayText: string = 'Waiting for conversation...';
  private transcriptListRef: ListScroller = new ListScroller();
  private transcriptDataSource: TranscriptDataSource = new TranscriptDataSource();

  aboutToAppear(): void {
    // Get current state immediately (ViewModel is already initialized in AgentConfig)
    const currentState = this.viewModel.getUiState();
    this.uiState = currentState;
    this.agentState = this.viewModel.getAgentState();
    
    // Set data source to ViewModel - ViewModel will directly update it
    this.viewModel.setTranscriptDataSource(this.transcriptDataSource);
    
    // Initialize data source with existing transcripts
    const initialList = this.viewModel.getTranscriptList();
    for (let i = 0; i < initialList.length; i++) {
      this.transcriptDataSource.pushData(initialList[i]);
    }
    this.transcriptList = initialList;
    
    // Update status display from current state
    this.updateStatusMessage(currentState);

    // Subscribe to UI state changes
    this.viewModel.subscribeUiState((state) => {
      this.uiState = state;
      this.updateStatusMessage(state);
    });

    // Subscribe to agent state changes
    this.viewModel.subscribeAgentState((state) => {
      this.agentState = state;
      // Agent state is always displayed in info card
      // VoiceWaveView animation is shown when transcript is hidden
    });

    // Start agent when page appears (after RTC and RTM are connected)
    // Only start if not already started and connection is established
    if (this.uiState.connectionState === ConnectionState.Connected) {
      this.viewModel.startAgent();
    }
  }

  aboutToDisappear(): void {
    // Cleanup
  }

  build() {
    Column() {
      // Top Info Card
      this.buildInfoCard()

      // Transcript List or Agent Speaking Indicator
      // Show transcript list when enabled, otherwise show agent speaking indicator
      if (this.uiState.isTranscriptEnabled) {
        // Transcript List
        // Always render List to ensure LazyForEach listener is registered
        this.buildTranscriptList()
      } else {
        // Agent Speaking Indicator (shown when transcript is hidden)
        this.buildAgentIndicator()
      }

      // Control Buttons
      this.buildControlButtons()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
    .onAppear(() => {
      console.info('VoiceAssistant', `[Thread] build() onAppear, isTranscriptEnabled:${this.uiState.isTranscriptEnabled}, dataSource totalCount:${this.transcriptDataSource.totalCount()}`);
    })
  }

  /**
   * Build info card with channel info and status
   * Build info card with channel info and status
   */
  @Builder
  buildInfoCard() {
    Column() {
      Text(`Channel: ${this.uiState.channelName || ''}`)
        .fontSize(14)
        .fontColor('#666666')
        .alignSelf(ItemAlign.Start)
      
      Text(`User ID: ${this.uiState.userUid || ''}`)
        .fontSize(14)
        .fontColor('#666666')
        .alignSelf(ItemAlign.Start)
        .margin({ top: 8 })
      
      Text(`Agent UID: ${this.uiState.agentUid || ''}`)
        .fontSize(14)
        .fontColor('#666666')
        .alignSelf(ItemAlign.Start)
        .margin({ top: 8 })
      
      // Agent status (text only in info card)
      Row() {
        Text('Agent Status:')
          .fontSize(14)
          .fontColor('#666666')
          .margin({ right: 8 })
        
        Text(this.getAgentStateText())
          .fontSize(14)
          .fontColor('#666666') // Use same color as other text, no special color
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .margin({ top: 12 })
      
      // Scrollable status message with max height
      Scroll() {
        Text(this.statusDisplayText)
          .fontSize(14)
          .fontColor(this.getStatusTextColor())
          .width('100%')
          .textAlign(TextAlign.Start)
      }
      .height(80) // Approximately 4-5 lines
      .scrollBar(BarState.Auto)
      .margin({ top: 12 })
    }
    .width('100%')
    .padding(16)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .margin(16)
    .shadow({
      radius: 8,
      color: '#1F000000',
      offsetX: 0,
      offsetY: 2
    })
  }

  /**
   * Build transcript list
   */
  @Builder
  buildTranscriptList() {
    List({ space: 0, scroller: this.transcriptListRef }) {
      LazyForEach(this.transcriptDataSource, (transcript: Transcript) => {
        ListItem() {
          Column() {
            Row() {
              // Type badge
              Text(transcript.type === TranscriptType.USER ? 'USER' : 'AGENT')
                .fontSize(12)
                .fontColor(Color.White)
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .backgroundColor(transcript.type === TranscriptType.USER ? '#10B981' : '#6366F1')
                .borderRadius(4)

              // Status badge
              Text(this.getTranscriptStatusText(transcript.status))
                .fontSize(12)
                .fontColor(this.getTranscriptStatusTextColor(transcript.status))
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .margin({ left: 8 })
            }
            .width('100%')
            .justifyContent(FlexAlign.Start)
            .margin({ bottom: 8 })

            // Transcript text
            Text(transcript.text?.toString() || '(empty)')
              .fontSize(16)
              .fontColor('#333333')
              .width('100%')
              .alignSelf(ItemAlign.Start)
          }
          .width('100%')
          .padding(16)
          .alignItems(HorizontalAlign.Start)
        }
      }, (transcript: Transcript) => JSON.stringify(transcript))
    }
    .width('100%')
    .layoutWeight(1)
    .divider({ strokeWidth: 1, color: '#E0E0E0', startMargin: 16, endMargin: 16 })
    .padding({ top: 12, bottom: 12 })
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
    .margin({ left: 16, right: 16, bottom: 16 })
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .shadow({
      radius: 6,
      color: '#1F000000',
      offsetX: 0,
      offsetY: 2
    })
  }

  /**
   * Build agent speaking indicator (shown when transcript is hidden)
   * Always shows VoiceWaveView animation when transcript is hidden
   * This should overlap with the transcript list area, not cover the info card
   */
  @Builder
  buildAgentIndicator() {
    Column() {
      VoiceWaveView()
        .scale({ x: 4.0, y: 4.0 }) // Scale up 4x - apply scale to VoiceWaveView itself, not the container
    }
    .width('100%')
    .layoutWeight(1) // Same as transcript list to occupy the same space
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .margin({ left: 16, right: 16, top: 12, bottom: 16 }) // Add top margin to prevent covering info card
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .clip(true) // Clip content to prevent overflow beyond container bounds
    .shadow({
      radius: 6,
      color: '#1F000000',
      offsetX: 0,
      offsetY: 2
    })
  }

  /**
   * Build control buttons
   */
  @Builder
  buildControlButtons() {
    Row() {
      // Mute button
      Button() {
        Text(this.uiState.isMuted ? '🔇' : '🎤')
          .fontSize(24)
          .fontColor(Color.White)
      }
      .width(64)
      .height(64)
      .borderRadius(32)
      .backgroundColor(this.uiState.isMuted ? '#F44336' : '#4CAF50')
      .onClick(() => {
        this.viewModel.toggleMute();
      })

      Blank()

      // Transcript toggle button
      Button() {
        Text(this.uiState.isTranscriptEnabled ? '📝' : '📄')
          .fontSize(24)
          .fontColor(Color.White)
      }
      .width(64)
      .height(64)
      .borderRadius(32)
      .backgroundColor('#2196F3')
      .onClick(() => {
        this.viewModel.toggleTranscript();
      })

      Blank()

      // Hangup button
      Button() {
        Text('📞')
          .fontSize(24)
          .fontColor(Color.White)
      }
      .width(64)
      .height(64)
      .borderRadius(32)
      .backgroundColor('#F44336')
      .onClick(() => {
        this.handleHangup();
      })
    }
    .width('100%')
    .height(80)
    .justifyContent(FlexAlign.SpaceEvenly)
    .padding({ left: 32, right: 32, top: 16, bottom: 16 })
    .backgroundColor('#FFFFFF')
    .borderRadius(32)
    .margin({ left: 16, right: 16, bottom: 32 })
    .shadow({
      radius: 8,
      color: '#1F000000',
      offsetX: 0,
      offsetY: 2
    })
  }

  /**
   * Handle hangup
   */
  private async handleHangup(): Promise<void> {
    await this.viewModel.hangup();
    // Navigate back to AgentConfig page
    router.back();
  }

  /**
   * Update status message - accumulate status messages for history
   * Only show important connection/agent status, hide operational messages
   */
  private updateStatusMessage(state: ConversationUiState): void {
    // Filter out operational messages (mute, transcript, etc.)
    const shouldShowMessage = !state.statusMessage.toLowerCase().includes('muted') &&
      !state.statusMessage.toLowerCase().includes('unmuted') &&
      !state.statusMessage.toLowerCase().includes('transcript');

    // Add new status message to history if it should be shown and is different from the last one
    if (shouldShowMessage &&
      state.statusMessage.length > 0 &&
      state.statusMessage !== this.lastStatusMessage) {
      this.statusHistory.push(state.statusMessage);
      this.lastStatusMessage = state.statusMessage;
    }

    // Clear history when disconnected or idle
    if (state.connectionState === ConnectionState.Idle) {
      this.statusHistory = [];
      this.lastStatusMessage = '';
      this.statusDisplayText = 'Waiting for conversation...';
    } else {
      this.statusDisplayText = this.statusHistory.join('\n') || 'Waiting for conversation...';
    }
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
   * Get status text color based on message content
   */
  private getStatusTextColor(): ResourceColor {
    const displayMessage = this.statusDisplayText.toLowerCase();
    if (displayMessage.includes('successfully') ||
      displayMessage.includes('initialized') ||
      displayMessage.includes('joined')) {
      return '#4CAF50';
    } else if (displayMessage.includes('error') ||
      displayMessage.includes('failed') ||
      displayMessage.includes('left')) {
      return '#F44336';
    } else {
      return '#666666';
    }
  }

  /**
   * Get status text for transcript item
   */
  private getTranscriptStatusText(status: TranscriptStatus): string {
    switch (status) {
      case TranscriptStatus.IN_PROGRESS:
        return 'IN_PROGRESS';
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
        return 'Idle';
      case AgentState.SILENT:
        return 'Silent';
      case AgentState.LISTENING:
        return 'Listening';
      case AgentState.THINKING:
        return 'Thinking';
      case AgentState.SPEAKING:
        return 'Speaking';
      default:
        return 'Unknown';
    }
  }

}

