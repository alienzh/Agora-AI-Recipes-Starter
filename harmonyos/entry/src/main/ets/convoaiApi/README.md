# Conversational AI API for HarmonyOS

This directory contains the HarmonyOS (ArkTS) implementation of the Conversational AI API, ported from the Android Kotlin version.

**Note: This version uses RTC datastream for message transmission, not RTM.**

## Directory Structure

```
convoaiApi/
├── IConversationalAIAPI.ets          # Core interfaces and type definitions
├── ConversationalAIAPIImpl.ets        # Main API implementation
├── ConversationalAIUtils.ets          # Utility functions and ObservableHelper
├── subRender/
│   ├── MessageParser.ets              # JSON message parser
│   ├── TranscriptConfig.ets           # Transcript configuration and types
│   └── TranscriptController.ets       # Transcript rendering controller
└── README.md                           # This file
```

## Key Components

### 1. IConversationalAIAPI.ets
Defines all interfaces, enums, and data structures for the Conversational AI API:
- `IConversationalAIAPI`: Main API interface
- `IConversationalAIAPIEventHandler`: Event handler interface with three callbacks:
  - `onAgentStateChanged`: Called when agent state changes (idle, silent, listening, thinking, speaking)
  - `onAgentInterrupted`: Called when an interrupt event occurs
  - `onTranscriptUpdated`: Called when transcript content is updated
- Message types: `TextMessage`, `ImageMessage`
- Event types: `StateChangeEvent`, `InterruptEvent`, `Transcript`, etc.
- Error types: `RtmError`, `RtcError`, `UnknownError`

### 2. ConversationalAIAPIImpl.ets
Main implementation of the Conversational AI API:
- Handles RTC datastream message receiving and sending
- Manages RTC audio configuration
- Coordinates with TranscriptController for transcript rendering
- Processes messages based on `object` field:
  - `message.state`: Agent state changes (idle, silent, listening, thinking, speaking)
  - `message.user`: User transcript messages
  - `message.assistant`: Agent transcript messages
  - `message.interrupt`: Interrupt events
  - `message.error`: Error messages
- Provides thread-safe event notifications

### 3. TranscriptController.ets
Manages transcript rendering:
- **Only supports text-level rendering mode** (Word mode is not supported due to HarmonyOS RTC SDK limitations)
- Handles agent and user messages
- Manages interrupt events
- Updates transcript display with complete message text

### 4. MessageParser.ets
Parses stream messages that may be split into multiple parts:
- Handles message splitting and reassembly (format: `messageId|partIndex|totalParts|base64Content`)
- Decodes Base64 content to UTF-8 string
- Parses JSON strings to `Record<string, Object>` objects
- Manages message parts in memory until all parts are received
- Automatically cleans up expired messages (5 minutes timeout)
- Handles parsing errors gracefully

## Usage Example

```typescript
import { createConversationalAIAPI, IConversationalAIAPIEventHandler } from './convoaiApi/ConversationalAIAPIImpl';
import { ConversationalAIAPIConfig, TextMessage, Priority } from './convoaiApi/IConversationalAIAPI';
import { TranscriptRenderMode } from './convoaiApi/subRender/TranscriptConfig';
// Create API instance
// Note: HarmonyOS version only supports Text mode, Word mode is not supported
// Note: RTC engine should be obtained from AgentChatController
const config: ConversationalAIAPIConfig = {
  rtcEngine: viewModel.getRtcEngine()!,
  renderMode: TranscriptRenderMode.Text, // Only Text mode is supported
  enableLog: true
};

const api = createConversationalAIAPI(config);

// Add event handler
const handler: IConversationalAIAPIEventHandler = {
  onAgentStateChanged: (agentUserId: string, event: StateChangeEvent) => {
    console.log('Agent state changed:', event);
  },
  onTranscriptUpdated: (agentUserId: string, transcript: Transcript) => {
    console.log('Transcript updated:', transcript);
  },
  onAgentInterrupted: (agentUserId: string, event: InterruptEvent) => {
    console.log('Agent interrupted:', event);
  }
};

api.addHandler(handler);

// Subscribe to channel messages (via RTC datastream)
// Note: Messages are automatically received when in channel, no explicit subscription needed
api.subscribeMessage('channelName', (error) => {
  if (error) {
    console.error('Subscribe failed:', error);
  } else {
    console.log('Subscribed successfully - messages will be received via onStreamMessage callback');
  }
});

// Send text message
const textMessage = new TextMessage(Priority.INTERRUPT, true, 'Hello, AI!');
api.chat('agentUserId', textMessage, (error) => {
  if (error) {
    console.error('Send message failed:', error);
  } else {
    console.log('Message sent successfully');
  }
});

// Interrupt agent
api.interrupt('agentUserId', (error) => {
  if (error) {
    console.error('Interrupt failed:', error);
  }
});

// Load audio settings (must be called before joinChannel)
api.loadAudioSettings(Constants.AUDIO_SCENARIO_AI_CLIENT);

// Cleanup
api.destroy();
```

## Important Notes

### 1. RTC Datastream Integration
This implementation uses RTC datastream for message transmission:
- Messages are sent via `sendStreamMessage()` - broadcasts to all users in the channel
- Messages are received via `onStreamMessage()` callback in RTC event handler
- Datastream is created automatically using `createDataStream()` with `ordered: true`
- No explicit subscription needed - messages are received automatically when in channel

**Message Format:**
- **Received messages** may be split into multiple parts due to RTC datastream size limits
- **Format**: `messageId|partIndex|totalParts|base64Content`
  - `messageId`: Unique identifier for the message
  - `partIndex`: Current part index (1-based)
  - `totalParts`: Total number of parts
  - `base64Content`: Base64-encoded content of this part
- **Parsing process**:
  1. Convert received `Uint8Array` to string
  2. Parse message parts using `MessageParser.parseStreamMessage()`
  3. Wait for all parts to be received (stored in memory)
  4. Merge all parts in order
  5. Decode Base64 to bytes, then convert to UTF-8 string
  6. Parse JSON string to `Record<string, Object>`
  7. Process message based on `object` field (message type)

**Sending messages:**
- Convert JSON object to JSON string
- Convert string to `Uint8Array` (UTF-8 encoding)
- Send via `sendStreamMessage(streamId, data)`
- Messages are automatically split if they exceed datastream size limits

**Note:** RTC datastream broadcasts to all users in the channel. If you need point-to-point messaging, you may need to filter messages by UID in the message handler.

### 2. Thread Safety
- Event handlers are notified on the main thread using `ConversationalAIUtils.runOnMainThread()`
- For production use, consider using HarmonyOS TaskDispatcher API instead of `setTimeout`

### 3. Audio Configuration
- `loadAudioSettings()` MUST be called BEFORE `rtcEngine.joinChannel()`
- Audio parameters are automatically adjusted when audio route changes

### 4. Transcript Rendering
- **HarmonyOS version only supports Text mode** - Word mode is not supported due to RTC SDK limitations
- Text-level rendering directly displays complete messages
- The render mode is forced to Text mode regardless of configuration

### 5. Error Handling
- All operations use completion callbacks with error handling
- Errors are wrapped in `ConversationalAIAPIError` subclasses
- Check error types: `RtmError`, `RtcError`, `UnknownError`

## Differences from Android Version

1. **Language**: Kotlin → ArkTS (TypeScript-like)
2. **Threading**: Android Handler → TaskDispatcher (to be implemented)
3. **JSON Parsing**: Gson → Native JSON.parse()
4. **Coroutines**: Kotlin Coroutines → setInterval (for ticker)
5. **Type System**: Kotlin sealed classes → TypeScript classes/interfaces
6. **Transcript Rendering**: **Only Text mode is supported** - Word mode is not available due to HarmonyOS RTC SDK limitations

## Message Types

Messages are identified by the `object` field in the parsed JSON:

- **`message.state`**: Agent state change events
  ```json
  {
    "object": "message.state",
    "state": "speaking",
    "turn_id": 1,
    "ts_ms": 1756550424141,
    "data_type": "message",
    "message_id": "599be49e",
    "send_ts": 1756550424145
  }
  ```

- **`message.user`**: User transcript messages
- **`message.assistant`**: Agent transcript messages
- **`message.interrupt`**: Interrupt events
- **`message.error`**: Error messages

## TODO

- [x] Implement RTC datastream message parsing (split message handling)
- [x] Implement Base64 decoding and UTF-8 conversion
- [x] Handle agent state change events via datastream
- [ ] Replace setTimeout with TaskDispatcher for main thread operations
- [ ] Add message filtering by UID if point-to-point messaging is needed
- [ ] Add unit tests for MessageParser
- [ ] Add message size validation and error handling

## References

- Original Android implementation: [Conversational-AI-Demo](https://github.com/Shengwang-Community/Conversational-AI-Demo/tree/v1.3.1/Android/scenes/convoai/src/main/java/io/agora/scene/convoai/subRender/v2)
- Agora RTC SDK for HarmonyOS: [Documentation](https://doc.shengwang.cn/doc/rtc/harmonyos/landing-page)
- RTC Datastream API: Check RTC SDK documentation for `createDataStream`, `sendStreamMessage`, and `onStreamMessage` callbacks

