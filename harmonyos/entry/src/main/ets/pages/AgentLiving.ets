import { ConversationViewModel, ConnectionState, ConversationUiState } from './ConversationViewModel';
import { Transcript, AgentState, TranscriptType, TranscriptStatus } from '../convoaiApi/IConversationalAIAPI';
import { TranscriptDataSource } from './common/TranscriptDataSource';
import { router, promptAction } from '@kit.ArkUI';

/**
 * Agent Living page
 * Fragment for displaying voice assistant UI and transcript list
 * This fragment only handles UI display, agent is started in AgentHome
 */
@Entry
@Component
@Preview
export struct AgentLiving {
  @State viewModel: ConversationViewModel = ConversationViewModel.getInstance();
  @State uiState: ConversationUiState = {
    statusMessage: '',
    isMuted: false,
    channelName: '',
    userUid: 0,
    agentUid: 0,
    connectionState: ConnectionState.Idle,
    agentStarted: false
  };
  @State transcriptList: Transcript[] = [];
  @State agentState: AgentState | null = null;
  @State autoScrollToBottom: boolean = true;
  @State isScrollBottom: boolean = false;
  private transcriptListRef: ListScroller = new ListScroller();
  private transcriptDataSource: TranscriptDataSource = new TranscriptDataSource();

  aboutToAppear(): void {
    // Get current state immediately (ViewModel is already initialized in AgentHome)
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
    
    // Subscribe to UI state changes
    this.viewModel.subscribeUiState((state) => {
      this.uiState = state;
      
      // Show error message if connection failed (similar to Kotlin Snackbar)
      if (state.connectionState === ConnectionState.Error && state.statusMessage) {
        promptAction.showToast({
          message: state.statusMessage,
          duration: 3000
        });
      }
      
      // Auto scroll to bottom when new transcript is added
      if (this.autoScrollToBottom) {
        this.scrollToBottom();
      }
    });

    // Subscribe to agent state changes
    this.viewModel.subscribeAgentState((state) => {
      this.agentState = state;
      // Agent state is always displayed in info card
      // VoiceWaveView animation is shown when transcript is hidden
    });

    // Note: Agent is automatically started in ConversationViewModel after RTC connection
    // No need to manually start agent here (similar to Kotlin AgentLivingFragment)
  }

  aboutToDisappear(): void {
    // Cleanup
  }

  build() {
    Column() {
      // Top Info Card
      this.buildInfoCard()

      this.buildTranscriptList()

      // Control Buttons
      this.buildControlButtons()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
    .onAppear(() => {
      console.info('AgentLiving', `[Thread] build() onAppear, dataSource totalCount:${this.transcriptDataSource.totalCount()}`);
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
   * Build control buttons
   */
  @Builder
  buildControlButtons() {
    Row() {
      // Mute button
      Column() {
        Stack({ alignContent: Alignment.Center }) {
          Circle({ width: 72, height: 72 })
            .fill('#4CAF50')

          // Microphone icon
          Image(this.uiState.isMuted ? $r('app.media.icon_mic_off') : $r('app.media.icon_mic_on'))
            .width(32)
            .height(32)
            .fillColor(Color.White)
        }
        .width(72)
        .height(72)
        .onClick(() => {
          this.viewModel.toggleMute();
        })
        .transition(TransitionEffect.OPACITY.animation({ duration: 200, curve: Curve.EaseInOut }))
        
        Text(this.uiState.isMuted ? '静音' : '麦克风')
          .fontSize(12)
          .fontColor('#666666')
          .margin({ top: 8 })
      }
      .alignItems(HorizontalAlign.Center)
      .layoutWeight(1)

      // Hangup button
      Column() {
        Stack({ alignContent: Alignment.Center }) {
          Circle({ width: 72, height: 72 })
            .fill('#F44336')

          // Phone hangup icon
          Image($r('app.media.icon_hangup'))
            .width(32)
            .height(32)
            .fillColor(Color.White)
        }
        .width(72)
        .height(72)
        .onClick(() => {
          this.handleHangup();
        })
        .transition(TransitionEffect.OPACITY.animation({ duration: 200, curve: Curve.EaseInOut }))
        
        Text('挂断')
          .fontSize(12)
          .fontColor('#666666')
          .margin({ top: 8 })
      }
      .alignItems(HorizontalAlign.Center)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 24, bottom: 24 })
    .margin({ left: 16, right: 16, bottom: 32 })
  }

  /**
   * Handle hangup
   */
  private async handleHangup(): Promise<void> {
    await this.viewModel.hangup();
    // Navigate back to AgentHome page
    router.back();
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
   * Match Kotlin version format: "IN PROGRESS", "END", "INTERRUPTED", "UNKNOWN"
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

