import { ConversationViewModel, ConnectionState } from '../viewmodel/ConversationViewModel';
import { KeyCenter } from '../common/KeyCenter';
import PermissionHelper from '../common/PermissionHelper';
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';

/**
 * Agent configuration page
 * User can input channel name and start the conversation
 */
@Entry
@Preview
@Component
export struct AgentConfig {
  @State viewModel: ConversationViewModel = ConversationViewModel.getInstance();
  @State statusMessage: string = '';
  @State connectionState: ConnectionState = ConnectionState.Idle;
  @State isLoading: boolean = false;
  @State hasNavigated: boolean = false;

  aboutToAppear(): void {
    // Reset navigation flag when page appears (e.g., user returns from VoiceAssistant)
    // This allows navigation to work again when connection state changes to Connected
    this.hasNavigated = false;
    
    // Initialize ViewModel with context
    const uiCtx = this.getUIContext();
    const hostContext = uiCtx.getHostContext()
    if (hostContext == undefined) {
      return;
    }
    this.viewModel.initialize(hostContext);

    // Subscribe to UI state changes
    // Get current state first to avoid missing initial state
    const currentState = this.viewModel.getUiState();
    this.statusMessage = currentState.statusMessage;
    this.connectionState = currentState.connectionState;
    this.isLoading = currentState.connectionState === ConnectionState.Connecting;

    // Store uiCtx for use in callback
    const router = uiCtx.getRouter();

    this.viewModel.subscribeUiState((state) => {
      this.statusMessage = state.statusMessage;
      this.connectionState = state.connectionState;
      this.isLoading = state.connectionState === ConnectionState.Connecting;

      // Reset hasNavigated when connection state changes to Idle (after hangup)
      if (state.connectionState === ConnectionState.Idle && this.hasNavigated) {
        this.hasNavigated = false;
      }

      // Navigate to voice assistant when connected (only once)
      if (state.connectionState === ConnectionState.Connected && !this.hasNavigated) {
        this.hasNavigated = true;
        // Use setTimeout to avoid navigation during render
        setTimeout(() => {
          router.pushUrl({ url: 'pages/VoiceAssistant' }).catch((err: Error) => {
            console.error('AgentConfig', `Failed to navigate: ${err.message || JSON.stringify(err)}`);
            // Reset flag if navigation fails
            this.hasNavigated = false;
          });
        }, 100);
      }
    });
  }

  aboutToDisappear(): void {
    // Cleanup if needed
  }

  build() {
    Column() {
      // Header
      Text('Starter HarmonyOS')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 40, bottom: 10 })
      Text('Start your conversational AI agent')
        .fontSize(16)
        .margin({ bottom: 20 })
      // App ID/Pipeline ID  display
      Column() {
        Text('App ID')
          .fontSize(14)
          .fontColor('#666666')
          .margin({ bottom: 8 })
        Text(KeyCenter.AGORA_APP_ID.substring(0, 5) + '***')
          .fontSize(16)
          .fontColor('#333333')
        Text('Pipeline ID')
          .fontSize(14)
          .fontColor('#666666')
          .margin({ top: 12, bottom: 8 })
        Text(KeyCenter.PIPELINE_ID.substring(0, 5) + '***')
          .fontSize(16)
          .fontColor('#333333')
      }
      .width('100%')
      .padding(16)
      .alignItems(HorizontalAlign.Start)
      .margin({ bottom: 20 })

      // Status message
      if (this.statusMessage) {
        Text(this.statusMessage)
          .fontSize(14)
          .fontColor(this.getStatusColor())
          .width('100%')
          .padding(16)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
          .margin({ bottom: 20 })
      }

      // Start button
      Button(this.isLoading ? 'Connecting...' : 'Start')
        .width('100%')
        .height(48)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .enabled(!this.isLoading)
        .backgroundColor(this.isLoading ? '#CCCCCC' : '#007AFF')
        .fontColor(Color.White)
        .borderRadius(8)
        .onClick(() => {
          this.handleStart();
        })
        .margin({ bottom: 20 })

      // Loading indicator
      if (this.isLoading) {
        LoadingProgress()
          .width(40)
          .height(40)
          .color('#007AFF')
          .margin({ top: 20 })
      }
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .backgroundColor('#FFFFFF')
  }

  /**
   * Handle start button click
   * Generate random channel name each time joining channel
   * Check microphone permission before joining channel
   */
  private async handleStart(): Promise<void> {
    try {
      // Generate random channel name each time joining channel
      const channelName = ConversationViewModel.generateRandomChannelName();

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
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : JSON.stringify(error);
      try {
        promptAction.showToast({
          message: `Error: ${errorMessage}`,
          duration: 2000
        });
      } catch (toastError) {
        // Fallback to console if toast fails
        console.error('AgentConfig', `Failed to show toast: ${errorMessage}`);
      }
    }
  }

  /**
   * Get status text color based on connection state
   */
  private getStatusColor(): ResourceColor {
    switch (this.connectionState) {
      case ConnectionState.Connected:
        return '#4CAF50';
      case ConnectionState.Error:
        return '#F44336';
      case ConnectionState.Connecting:
        return '#FF9800';
      default:
        return '#666666';
    }
  }
}

