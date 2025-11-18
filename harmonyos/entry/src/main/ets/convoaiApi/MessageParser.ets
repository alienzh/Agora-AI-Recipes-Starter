import util from '@ohos.util';

/**
 * Message Parser for stream messages
 * Parses stream messages that may be split into multiple parts
 * Uses Map structure for more intuitive partIndex and content storage
 */
export class MessageParser {
  private onErrorCallback?: (message: string) => void;
  // Change message storage structure to Map<string, Map<number, string>> for more intuitive partIndex and content storage
  private messageMap: Map<string, Map<number, string>> = new Map();
  private maxMessageAge: number = 5 * 60 * 1000; // 5 minutes
  private lastAccessMap: Map<string, number> = new Map();

  /**
   * Set error callback
   * @param callback Error callback function
   */
  setOnError(callback: (message: string) => void): void {
    this.onErrorCallback = callback;
  }

  /**
   * Parse stream message that may be split into multiple parts
   * Message format: messageId|partIndex|totalParts|base64Content
   * @param string Message string to parse
   * @returns Parsed Map or null if parsing fails or message is incomplete
   */
  parseStreamMessage(string: string): Record<string, Object> | null {
    try {
      // Clean up expired messages
      this.cleanExpiredMessages();

      const parts = string.split('|');
      if (parts.length !== 4) {
        throw new Error('Invalid message format');
      }

      const messageId = parts[0];
      const partIndex = parseInt(parts[1], 10);
      const totalParts = parseInt(parts[2], 10);
      const base64Content = parts[3];

      // Validate partIndex and totalParts
      if (isNaN(partIndex) || isNaN(totalParts)) {
        throw new Error('Invalid partIndex or totalParts');
      }

      if (partIndex < 1 || partIndex > totalParts) {
        throw new Error('partIndex out of range');
      }

      // Update last access time
      this.lastAccessMap.set(messageId, Date.now());

      // Use Map to store message parts for more intuitive partIndex and content management
      let messageParts = this.messageMap.get(messageId);
      if (!messageParts) {
        messageParts = new Map<number, string>();
        this.messageMap.set(messageId, messageParts);
      }
      messageParts.set(partIndex, base64Content);

      // Check if all parts are received
      if (messageParts.size === totalParts) {
        // All parts received, merge in order and decode
        let completeMessage = '';
        for (let i = 1; i <= totalParts; i++) {
          const part = messageParts.get(i);
          if (!part) {
            throw new Error(`Missing part ${i}`);
          }
          completeMessage += part;
        }

        // Decode Base64 to bytes and convert to string
        let jsonString: string;
        try {
          const base64Helper = new util.Base64Helper();
          const decodedBytes = base64Helper.decodeSync(completeMessage);
          // Use TextDecoder.create() static method to create decoder instance
          const decoder = util.TextDecoder.create('utf-8', { ignoreBOM: true });
          // Directly convert bytes to string using decodeToString
          jsonString = decoder.decodeToString(decodedBytes);
        } catch (e) {
          const errorMessage = e instanceof Error ? e.message : 'Unknown error';
          throw new Error(`Failed to decode Base64 or UTF-8 string: ${errorMessage}`);
        }
        console.debug(`alien parser ${jsonString}`)

        // Parse JSON using parseJsonToMap method
        const result = this.parseJsonToMap(jsonString);
        if (!result) {
          throw new Error('Failed to parse JSON or result is not an object');
        }

        // Clean up processed message
        this.messageMap.delete(messageId);
        this.lastAccessMap.delete(messageId);

        return result;
      }

      // Message is incomplete, return null
      return null;
    } catch (e) {
      const errorMessage = e instanceof Error ? e.message : 'Unknown error';
      const errorMsg = `[MessageParser] parseStreamMessage: ${errorMessage}`;
      if (this.onErrorCallback) {
        this.onErrorCallback(errorMsg);
      }
      return null;
    }
  }

  /**
   * Parse JSON string directly to Record (for RTM messages or complete messages)
   * Always returns Record<string, Object> regardless of whether 'object' field exists
   * @param jsonString JSON string to parse
   * @returns Parsed Record or null if parsing fails
   */
  private parseJsonToMap(jsonString: string): Record<string, Object> | null {
    try {
      const parsed: Object = JSON.parse(jsonString) as Object;
      // Always convert to Record<string, Object> type
      // JSON.parse can return object, array, or primitive, but we only accept objects
      if (parsed !== null && typeof parsed === 'object' && !Array.isArray(parsed)) {
        return parsed as Record<string, Object>;
      }
      // If parsed result is not an object (e.g., string, number, boolean, array, null), return null
      return null;
    } catch (e) {
      const errorMessage = e instanceof Error ? e.message : 'Unknown error';
      const errorMsg = `[MessageParser] parseJsonToMap: ${errorMessage}`;
      if (this.onErrorCallback) {
        this.onErrorCallback(errorMsg);
      }
      return null;
    }
  }

  /**
   * Clean up expired messages
   */
  private cleanExpiredMessages(): void {
    const currentTime = Date.now();
    const expiredIds: string[] = [];

    this.lastAccessMap.forEach((lastAccess, messageId) => {
      if (currentTime - lastAccess > this.maxMessageAge) {
        expiredIds.push(messageId);
      }
    });

    expiredIds.forEach((id) => {
      this.messageMap.delete(id);
      this.lastAccessMap.delete(id);
    });
  }
}