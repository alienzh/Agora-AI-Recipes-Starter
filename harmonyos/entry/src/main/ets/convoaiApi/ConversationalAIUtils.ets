/**
 * Utility functions for Conversational AI API
 */
export class ConversationalAIUtils {
  /**
   * Run callback on main thread
   * In HarmonyOS, use taskDispatcher to run on main thread
   * @param callback Callback function to run
   */
  static runOnMainThread(callback: () => void): void {
    // Use setTimeout as a fallback for now
    // In production, should use taskDispatcher from @kit.ArkUI
    setTimeout(() => {
      callback();
    }, 0);
  }
}

/**
 * Observable helper for managing event handlers
 */
export class ObservableHelper<EventHandler> {
  private eventHandlerList: EventHandler[] = [];
  private isNotifying: boolean = false;

  /**
   * Subscribe to events
   * @param eventHandler Event handler to subscribe
   */
  subscribeEvent(eventHandler: EventHandler | null | undefined): void {
    if (!eventHandler) {
      return;
    }
    if (this.eventHandlerList.indexOf(eventHandler) < 0) {
      this.eventHandlerList.push(eventHandler);
    }
  }

  /**
   * Unsubscribe from events
   * @param eventHandler Event handler to unsubscribe
   */
  unSubscribeEvent(eventHandler: EventHandler | null | undefined): void {
    if (!eventHandler) {
      return;
    }
    const index = this.eventHandlerList.indexOf(eventHandler);
    if (index >= 0) {
      this.eventHandlerList.splice(index, 1);
    }
  }

  /**
   * Unsubscribe all event handlers
   */
  unSubscribeAll(): void {
    this.eventHandlerList = [];
  }

  /**
   * Notify all event handlers
   * @param action Action to perform on each handler
   */
  notifyEventHandlers(action: (handler: EventHandler) => void): void {
    // Create a copy to avoid issues during iteration
    const handlers = [...this.eventHandlerList];
    for (const handler of handlers) {
      try {
        ConversationalAIUtils.runOnMainThread(() => {
          action(handler);
        });
      } catch (e) {
        console.error('[ObservableHelper] Error notifying handler:', e);
      }
    }
  }
}

