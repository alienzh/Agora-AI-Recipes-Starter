# Startup Guide for Agora Conversational AI

> 供 AI Agent 使用的多平台项目生成指南，通过流程和规则指导代码生成，具体实现细节通过 Agora MCP 工具获取

---

## 📋 目录

1. [项目元信息](#项目元信息)
2. [平台 SDK 支持检测](#平台-sdk-支持检测)
3. [核心功能映射](#核心功能映射)
4. [平台适配规则](#平台适配规则)
5. [目录结构规范](#目录结构规范)
6. [核心开发流程](#核心开发流程)
7. [UI 组件规范](#ui-组件规范)
8. [Agora MCP 工具使用指南](#agora-mcp-工具使用指南)
9. [生成规则](#生成规则)
10. [Agent 使用说明](#agent-使用说明)

---

## 项目元信息

```yaml
project:
  name: "Agora Conversational AI Starter"
  platforms:
    - react-native    # React Native
    - flutter         # Flutter
    - android         # Android (Kotlin/Java)
    - ios             # iOS (Swift/Objective-C)
    - harmonyos       # HarmonyOS (ArkTS)
    - web             # Web (JavaScript/TypeScript)
    - unity           # Unity (C#)
    - electron        # Electron
  
  core_features:
    - rtc_channel_management    # RTC 频道管理
    - message_sync              # 消息同步（RTM 或 RTC DataStream）
    - agent_lifecycle           # Agent 启动/停止
    - realtime_transcription    # 实时转录（通过消息解析）
    - audio_mute_control        # 音频静音控制
    - log_display               # 日志展示
  
  required_config:
    - agora.appId
    - agora.restKey
    - agora.restSecret
    - agora.pipelineId
    - agora.appCertificate  # 可选，用于 Token 生成
```

---

## 平台 SDK 支持检测

**重要**: AI Agent 在生成代码前，必须先查询 Agora 官方文档，确定目标平台支持的 SDK。

### 检测流程

1. **查询 RTC SDK 支持**：
   - 使用 MCP 工具：`list-docs` 或 `search-docs` 查询 RTC SDK 文档
   - 检查目标平台是否在支持列表中
   - 参考文档：https://doc.shengwang.cn/doc/rtc/homepage

2. **查询 RTM SDK 支持**：
   - 使用 MCP 工具：`list-docs` 或 `search-docs` 查询 RTM SDK 文档
   - 检查目标平台是否在支持列表中
   - 参考文档：https://doc.shengwang.cn/doc/rtm2/homepage

3. **根据支持情况决定集成方案**：
   - **只支持 RTC**：使用 RTC + RTC DataStream 方案
   - **支持 RTC + RTM**：使用 RTC + RTM 方案
   - **都不支持**：提示用户该平台暂不支持

### 平台支持示例（仅供参考，需实际查询）

| 平台 | RTC SDK | RTM SDK | 集成方案 |
|------|---------|---------|----------|
| React Native | ✅ | ❌ | RTC + RTC DataStream |
| Flutter | ✅ | ✅ | RTC + RTM |
| Android (Kotlin) | ✅ | ✅ | RTC + RTM |
| iOS (Swift) | ✅ | ✅ | RTC + RTM |
| HarmonyOS | ✅ | ❌ | RTC + RTC DataStream |
| Web | ✅ | ✅ | RTC + RTM |
| Unity | ✅ | ✅ | RTC + RTM |

**注意**：上表仅供参考，实际生成时必须通过 MCP 工具查询最新支持情况。

---

## 核心功能映射

### 功能模块对照表（通用）

| 功能模块 | 实现位置 | 说明 |
|---------|----------|------|
| **RTC 管理** | 业务逻辑层（Store/ViewModel/Controller） | 直接在业务逻辑层管理，不单独封装 |
| **消息同步** | 业务逻辑层 | 根据平台支持使用 RTM 或 RTC DataStream |
| **Agent API** | API 层（AgentStarter） | RESTful API 调用，RTC+DataStream 和 RTC+RTM 版本请求体不同（见下方说明） |
| **状态管理** | 业务逻辑层 | 使用平台特定的状态管理方案 |
| **UI 页面** | UI 层 | 统一参考 Kotlin 版本的 UI 设计 |

### Token 生成差异

**重要**：RTC+DataStream 和 RTC+RTM 两种集成方案在 Token 生成时需要不同的 Token 类型。

#### RTC+DataStream 版本

**用户 Token**：
- Token 类型：**只需要 RTC Token**（`['rtc']`）
- 用途：用于用户加入 RTC 频道
- 调用示例：`TokenGenerator.generateTokenAsync(channelName, userId, ['rtc'])`

**Agent Token**：
- Token 类型：**只需要 RTC Token**（`['rtc']`）
- 用途：用于 Agent 启动 RESTful API
- 调用示例：`TokenGenerator.generateTokenAsync(channelName, agentRtcUid, ['rtc'])`

#### RTC+RTM 版本

**用户 Token**：
- Token 类型：**需要 RTC 和 RTM Token**（`['rtc', 'rtm']`）
- 用途：用于用户加入 RTC 频道和登录 RTM
- 调用示例：`TokenGenerator.generateTokenAsync(channelName, userId, ['rtc', 'rtm'])`

**Agent Token**：
- Token 类型：**需要 RTC 和 RTM Token**（`['rtc', 'rtm']`）
- 用途：用于 Agent 启动 RESTful API（Agent 也需要使用 RTM 进行消息传递）
- 调用示例：`TokenGenerator.generateTokenAsync(channelName, agentRtcUid, ['rtc', 'rtm'])`
- **参考实现**：`android-kotlin/app/src/main/java/io/agora/convoai/example/startup/ui/AgentChatViewModel.kt:469-472`

**注意**：
- Token 生成服务会根据 `tokenTypes` 参数返回对应的 Token
- 如果 `tokenTypes` 包含多个类型，返回的是统一 Token（同时支持 RTC 和 RTM）
- 如果 `tokenTypes` 只包含一个类型，返回的是单一类型 Token
- 请求体格式：单个类型使用 `type` 字段，多个类型使用 `types` 数组字段

### Agent 启动 RESTful API 请求体差异

**重要**：RTC+DataStream 和 RTC+RTM 两种集成方案在启动 Agent 的 RESTful API 请求体中需要不同的配置。

#### RTC+DataStream 版本

请求体**必须**包含以下配置：

```json
{
  "name": "channel_name",
  "pipeline_id": "pipeline_id",
  "properties": {
    "channel": "channel_name",
    "agent_rtc_uid": "1009527",
    "remote_rtc_uids": ["*"],
    "token": "token_string",
    "parameters": {
      "data_channel": "datastream",
      "transcript": {
        "enable_words": false
      }
    },
    "advanced_features": {
      "enable_rtm": false
    }
  }
}
```

**关键配置说明**：
- `parameters.data_channel = "datastream"`：指定使用 RTC DataStream 进行消息传递
- `parameters.transcript.enable_words = false`：禁用单词级别转录，只使用文本级别
- `advanced_features.enable_rtm = false`：禁用 RTM，使用 DataStream 替代

**参考实现**：`harmonyos/entry/src/main/ets/api/AgentStarter.ets:113-133`

#### RTC+RTM 版本

请求体**不需要**包含 `parameters` 和 `advanced_features` 字段（使用默认的 RTM 模式）：

```json
{
  "name": "channel_name",
  "pipeline_id": "pipeline_id",
  "properties": {
    "channel": "channel_name",
    "agent_rtc_uid": "1009527",
    "remote_rtc_uids": ["*"],
    "token": "token_string"
  }
}
```

**参考实现**：`android-kotlin/app/src/main/java/io/agora/convoai/example/startup/api/AgentStarter.kt`

---

## 平台适配规则

### 通用规则

所有平台都应遵循以下规则：

1. **RTC 初始化**：所有平台都需要初始化 RTC
2. **消息处理**：
   - 支持 RTM 的平台：使用 RTM 进行消息传递
   - 不支持 RTM 的平台：使用 RTC DataStream 进行消息传递
3. **UI 模板**：统一参考 Kotlin 版本的 UI 设计
4. **日志展示**：所有平台都需要展示 RTC 相关日志
5. **代码组织**：RTC 和消息管理直接在业务逻辑层处理，不单独封装成服务类

### 平台特定规则

#### React Native
- 状态管理：使用 Zustand
- 导航：使用 React Navigation
- SDK 查询：使用 MCP 工具查询 `react-native-agora` 的 RTC API

#### Flutter
- 状态管理：使用 Provider/Riverpod/Bloc
- SDK 查询：使用 MCP 工具查询 `agora_rtc_engine` 和 `agora_rtm` 的 API

#### Android (Kotlin)
- 状态管理：使用 ViewModel + StateFlow
- SDK 查询：使用 MCP 工具查询 Android RTC 和 RTM SDK 的 API

#### iOS (Swift)
- 状态管理：使用 ObservableObject/@Published 或 Combine
- SDK 查询：使用 MCP 工具查询 iOS RTC 和 RTM SDK 的 API

#### HarmonyOS
- 状态管理：使用 @State/@ObservedV2
- SDK 查询：使用 MCP 工具查询 HarmonyOS RTC SDK 的 API

---

## 目录结构规范

### 通用目录结构

```
project_root/
├── src/                    # 或 lib/、app/（根据平台调整）
│   ├── screens/            # 或 pages/、ui/
│   │   └── AgentChatScreen.{ext}      # 主页面
│   ├── api/               # 或 services/
│   │   ├── AgentStarter.{ext}          # Agent 启动/停止 API
│   │   └── TokenGenerator.{ext}        # Token 生成（仅开发测试）
│   ├── store/             # 或 viewmodel/、controller/
│   │   └── AgentChatStore.{ext}        # 业务逻辑管理（包含 RTC/消息管理）
│   ├── components/         # 或 widgets/
│   │   ├── LogView.{ext}               # 日志展示组件
│   │   ├── TranscriptList.{ext}        # 转录列表组件
│   │   └── ControlButtons.{ext}        # 控制按钮组件
│   └── utils/             # 或 helpers/
│       ├── KeyCenter.{ext}             # 配置中心
│       ├── ChannelNameGenerator.{ext}  # Channel 名称生成
│       ├── PermissionHelper.{ext}      # 权限处理
│       └── MessageParser.{ext}          # 消息解析（仅在项目未包含 SDK 代码时需要，占位，需开发者实现）
│   └── convoaiApi/        # 或 ConversationalAIAPI/（如果项目中已包含 SDK 代码）
│       ├── IConversationalAIAPI.{ext}  # SDK 接口定义
│       ├── ConversationalAIAPIImpl.{ext} # SDK 主要实现
│       ├── ConversationalAIUtils.{ext}  # SDK 工具类
│       ├── subRender/                   # SDK 字幕渲染模块
│       │   ├── MessageParser.{ext}
│       │   └── TranscriptController.{ext}
│       └── README.md                    # SDK 使用说明
├── .env.example           # 环境变量模板
└── README.md              # 项目说明
```

**文件扩展名说明**：
- React Native: `.ts` / `.tsx`
- Flutter: `.dart`
- Android: `.kt` / `.java`
- iOS: `.swift` / `.m`
- HarmonyOS: `.ets`
- Web: `.ts` / `.js`
- Unity: `.cs`

---

## 核心开发流程

### 流程概览

```
1. 初始化阶段
   ├── 初始化 RTC 引擎
   ├── （如果支持 RTM）初始化 RTM 客户端
   └── 注册事件处理器

2. 连接阶段
   ├── 生成 Channel Name
   ├── 生成 Token
   ├── 加入 RTC 频道
   ├── （如果使用 RTM）登录 RTM 并订阅消息
   ├── （如果使用 RTC DataStream）创建 DataStream
   └── 启动 Agent（RESTful API）
       - **RTC+DataStream 版本**：请求体需包含 `parameters` 和 `advanced_features` 配置
       - **RTC+RTM 版本**：请求体不需要 `parameters` 和 `advanced_features` 字段

3. 运行阶段
   ├── 监听 RTC 事件
   ├── 监听消息（RTM 或 RTC DataStream）
   ├── 解析消息并更新 UI
   └── 处理用户操作（静音、停止等）

4. 清理阶段
   ├── 停止 Agent
   ├── （如果使用 RTM）登出 RTM
   └── 离开 RTC 频道
```

### 详细流程说明

#### 1. 初始化阶段

**目标**：创建 RTC 引擎和（如果支持）RTM 客户端

**步骤**：
1. 使用 MCP 工具查询目标平台的 RTC SDK 初始化 API
   - 搜索关键词：`[平台] RTC initialize create engine`
   - 获取初始化方法和配置参数
2. 初始化 RTC 引擎
   - 设置 App ID
   - 注册事件处理器（onJoinChannelSuccess, onUserJoined, onError 等）
   - 启用音频
3. （如果平台支持 RTM）使用 MCP 工具查询 RTM SDK 初始化 API
   - 搜索关键词：`[平台] RTM create client initialize`
   - 获取初始化方法和配置参数
4. （如果平台支持 RTM）初始化 RTM 客户端
   - 设置 User ID 和 App ID
   - 注册事件监听器（onConnectionStateChanged, onMessageEvent 等）

**MCP 工具使用示例**：
```
# 查询 React Native RTC 初始化
search-docs: "React Native RTC create engine initialize"

# 查询 Flutter RTM 初始化
search-docs: "Flutter RTM create client initialize"
```

#### 2. 连接阶段（RTC 版本 - 适用于只支持 RTC 的平台）

**目标**：建立 RTC 连接并创建 DataStream

**步骤**：
1. 生成随机 Channel Name
   - 格式：`channel_{platform}_{random}`
   - 随机数范围：1000-9999
2. 生成 Token
   - **Token 类型**：**只需要 RTC Token**（`['rtc']`）
   - **用户 Token**：用于加入 RTC 频道，调用 `TokenGenerator.generateTokenAsync(channelName, userId, ['rtc'])`
   - **Agent Token**：用于启动 Agent，调用 `TokenGenerator.generateTokenAsync(channelName, agentRtcUid, ['rtc'])`
   - 开发环境：使用 TokenGenerator（仅用于测试）
   - 生产环境：必须使用服务端生成
   - Token 类型：只生成 RTC Token（`['rtc']`）
3. 使用 MCP 工具查询 RTC joinChannel API
   - 搜索关键词：`[平台] RTC joinChannel`
   - 获取参数：token, channelName, uid, options
4. 加入 RTC 频道
   - 设置 clientRoleType 为 BROADCASTER
   - 启用麦克风发布
   - 禁用摄像头发布
5. 使用 MCP 工具查询 RTC DataStream 创建 API
   - 搜索关键词：`[平台] RTC createDataStream`
   - 获取参数：syncWithAudio, ordered
6. 创建 RTC DataStream
   - syncWithAudio: false
   - ordered: true
   - 保存返回的 streamId
7. 在 RTC 事件处理器中监听 onStreamMessage
   - 使用 MCP 工具查询 onStreamMessage 事件格式
8. 启动 Agent（RESTful API - RTC+DataStream 版本）
   - 调用 AgentStarter.startAgentAsync()
   - 参数：channelName, agentRtcUid, token
   - **重要**：请求体必须包含以下配置（用于指定使用 DataStream 模式）：
     - `properties.parameters.data_channel = "datastream"`
     - `properties.parameters.transcript.enable_words = false`（禁用单词级别转录，只使用文本级别）
     - `properties.advanced_features.enable_rtm = false`（禁用 RTM，使用 DataStream 替代）
   - 保存返回的 agentId
   - **参考实现**：`harmonyos/entry/src/main/ets/api/AgentStarter.ets:113-133`

**MCP 工具使用示例**：
```
# 查询 React Native RTC joinChannel
search-docs: "React Native RTC joinChannel"

# 查询 React Native RTC createDataStream
search-docs: "React Native RTC createDataStream onStreamMessage"
```

#### 3. 连接阶段（RTC + RTM 版本 - 适用于支持 RTM 的平台）

**目标**：建立 RTC 和 RTM 连接

**步骤**：
1. 生成随机 Channel Name（同 RTC 版本）
2. 生成 Token
   - **Token 类型**：**需要 RTC 和 RTM Token**（`['rtc', 'rtm']`）
   - **用户 Token**：用于加入 RTC 频道和登录 RTM，调用 `TokenGenerator.generateTokenAsync(channelName, userId, ['rtc', 'rtm'])`
   - **Agent Token**：用于启动 Agent（Agent 也需要使用 RTM 进行消息传递），调用 `TokenGenerator.generateTokenAsync(channelName, agentRtcUid, ['rtc', 'rtm'])`
   - **注意**：用户和 Agent 都需要同时使用 RTC 和 RTM，所以两种 Token 都必须包含 RTC 和 RTM 类型
3. 加入 RTC 频道（同 RTC 版本）
4. 使用 MCP 工具查询 RTM login API
   - 搜索关键词：`[平台] RTM login`
5. 登录 RTM
   - 使用生成的 Token
6. 使用 MCP 工具查询 RTM 订阅消息 API
   - 搜索关键词：`[平台] RTM subscribe message channel`
7. 订阅 RTM 消息
   - 订阅指定的 channelName
8. 在 RTM 事件监听器中监听 onMessageEvent
   - 使用 MCP 工具查询 onMessageEvent 事件格式
9. 在 RTM 事件监听器中监听 onPresenceEvent（用于获取 Agent 状态）
   - 使用 MCP 工具查询 onPresenceEvent 事件格式
   - 监听 `REMOTE_STATE_CHANGED` 事件类型
   - 从 `event.stateItems["state"]` 获取 Agent 状态值
10. 启动 Agent（RESTful API - RTC+RTM 版本）
   - 调用 AgentStarter.startAgentAsync()
   - 参数：channelName, agentRtcUid, token
   - **重要**：请求体**不需要**包含 `parameters` 和 `advanced_features` 字段（使用默认的 RTM 模式）
   - 保存返回的 agentId
   - **参考实现**：`android-kotlin/app/src/main/java/io/agora/convoai/example/startup/api/AgentStarter.kt`

**MCP 工具使用示例**：
```
# 查询 Flutter RTM login
search-docs: "Flutter RTM login"

# 查询 Android RTM subscribe message
search-docs: "Android RTM subscribe message channel"

# 查询 RTM onPresenceEvent
search-docs: "[平台] RTM onPresenceEvent REMOTE_STATE_CHANGED"
```

#### 4. 消息处理阶段

**目标**：接收并解析消息，更新 UI

**重要**：优先使用 Conversational AI API SDK

在实现消息处理逻辑前，AI Agent 需要先检查项目中是否已包含 Conversational AI API SDK 代码：

1. **检查项目中是否已有 SDK 代码**：
   - 检查项目中是否存在 `convoaiApi/` 或 `ConversationalAIAPI/` 目录
   - 检查目录中是否包含 `IConversationalAIAPI.{ext}` 文件（这是对外提供的接口文件）
   - 如果存在该文件，说明项目中已包含 SDK 代码

2. **如果项目中已包含 SDK 代码**：
   - **优先使用 SDK**：按照 SDK 代码中的 README 文档使用 SDK 提供的 API
   - SDK 通常会提供事件处理器（如 `onTranscriptUpdated`、`onAgentStateChanged`）
   - 不需要手动解析消息，SDK 会自动处理消息解析
   - 参考 Android Kotlin 版本的 `ConversationalAIAPIImpl.kt` 和 `TranscriptController.kt` 实现方式
   - **注意**：SDK 代码需要开发者手动拷贝到项目中，不是通过包管理器安装

3. **如果项目中没有 SDK 代码**：
   - 才需要根据以下解析规则手动实现消息解析逻辑
   - 参考 HarmonyOS 或 Android Kotlin 版本的 MessageParser 实现思路
   - 在代码中标记为 TODO，提示开发者参考文档实现

**RTC DataStream 版本**（仅在平台未提供 SDK 时使用）：
1. 在 onStreamMessage 回调中接收消息
2. 使用 MCP 工具查询消息格式
   - 搜索关键词：`RTC DataStream message format split parts`
3. 实现消息解析逻辑（参考 HarmonyOS 版本的 MessageParser）
   - 消息可能被分割成多个部分
   - 消息格式：`messageId|partIndex|totalParts|base64Content`
   - 需要合并多个部分、解码 Base64、解析 JSON
4. 根据消息类型处理：

   **消息类型枚举**：
   - `assistant.transcription`：Agent 转录消息
   - `user.transcription`：用户转录消息
   - `message.interrupt`：中断消息
   - `message.state`：消息状态（Agent 状态更新）
   - `unknown`：未知消息类型

   **处理逻辑**：
   - `assistant.transcription`：解析转录内容，更新转录列表（role: 'assistant'）
   - `user.transcription`：解析转录内容，更新转录列表（role: 'user'）
   - `message.interrupt`：处理中断事件，更新 UI 状态
   - `message.state`：解析 Agent 状态，更新 agentState（IDLE、SILENT、LISTENING、THINKING、SPEAKING）
   - `unknown`：记录日志，忽略处理

   **Transcript 更新规则**（重要）：
   - 在更新转录列表时，需要根据 `turnId` 和 `type` 判断是更新还是新增：
     - **同一句话的更新**：如果收到相同 `turnId` 和 `type` 的消息（例如文本内容更新、状态从 `IN_PROGRESS` 变为 `END`），应该**更新现有 transcript**，而不是添加新的
     - **新的一句话**：如果 `turnId` 或 `type` 不同，应该**添加新的 transcript**
   - 参考实现：HarmonyOS 版本的 `AgentChatController.ets` 中的 `addOrUpdateTranscript` 方法

**RTM 版本**（仅在平台未提供 SDK 时使用）：
1. 在 onMessageEvent 回调中接收消息
2. 使用 MCP 工具查询消息格式
   - 搜索关键词：`RTM message format JSON`
3. 实现消息解析逻辑（参考 Android Kotlin 版本的 TranscriptController）
   - RTM 消息可能是 BINARY 或 String 类型
   - BINARY 类型：将 ByteArray 转换为 UTF-8 字符串
   - String 类型：直接使用
   - 解析 JSON 字符串为 Map/Object
   - 不需要处理分片
4. 从解析后的消息中获取消息类型：
   - 从 `messageMap["object"]` 获取消息类型字符串
   - 根据消息类型字符串匹配 MessageType 枚举
5. 根据消息类型处理（参考 Android Kotlin 版本的 TranscriptController，**只处理 Text 模式**）：

   **`assistant.transcription`（Agent 转录消息）**：
   - 从 `msg["text"]` 获取转录文本
   - 从 `msg["turn_id"]` 获取 turnId
   - 从 `msg["turn_status"]` 获取状态：
     - `0`：IN_PROGRESS（进行中）
     - `1`：END（完成）
     - `2`：INTERRUPTED（中断）
   - 从 `msg["user_id"]` 获取 userId（可选）
   - 创建 Transcript 对象（role: 'assistant'，renderMode: Text）
   - 更新转录列表

   **`user.transcription`（用户转录消息）**：
   - 从 `msg["text"]` 获取转录文本
   - 从 `msg["turn_id"]` 获取 turnId
   - 从 `msg["final"]` 获取是否完成（boolean）
   - 从 `msg["user_id"]` 获取 userId（可选）
   - 创建 Transcript 对象（role: 'user'，status: 根据 final 判断）
   - 更新转录列表

   **Transcript 更新规则**（重要）：
   - 在更新转录列表时，需要根据 `turnId` 和 `type` 判断是更新还是新增：
     - **同一句话的更新**：如果收到相同 `turnId` 和 `type` 的消息（例如文本内容更新、状态从 `IN_PROGRESS` 变为 `END`），应该**更新现有 transcript**，而不是添加新的
     - **新的一句话**：如果 `turnId` 或 `type` 不同，应该**添加新的 transcript**
   - 参考实现：Android Kotlin 版本的 `AgentChatViewModel.kt` 中的 `addTranscript` 方法

   **`message.interrupt`（中断消息）**：
   - 从 `msg["turn_id"]` 获取被中断的 turnId
   - 处理中断事件，更新 UI 状态
   - 将被中断的转录状态更新为 INTERRUPTED

   **注意**：
   - RTM 版本中**不使用** `message.state` 消息类型
   - **只处理 Text 模式**，不需要处理 Word 模式（逐词渲染）
   - 参考 Android Kotlin 版本的 `TranscriptController.kt` 中的 `handleAgentTextMessage` 和 `handleUserMessage` 实现

6. **Agent 状态处理**（RTM 特有）：
   - 使用 MCP 工具查询：`search-docs: "[平台] RTM onPresenceEvent REMOTE_STATE_CHANGED"`
   - 在 `onPresenceEvent` 回调中监听 `REMOTE_STATE_CHANGED` 事件
   - 从 `event.stateItems["state"]` 获取 Agent 状态值
   - 更新 agentState（IDLE、SILENT、LISTENING、THINKING、SPEAKING）
   - 参考 Android Kotlin 版本的 `ConversationalAIAPIImpl.kt` 中的 `onPresenceEvent` 实现

**重要提示**：
- 消息解析逻辑应标记为 TODO，提示开发者参考文档实现
- 可以使用 HarmonyOS 或 Android Kotlin 版本的 MessageParser 作为参考

**MCP 工具使用示例**：
```
# 查询 RTC DataStream 消息格式
search-docs: "RTC DataStream message format split parts base64"

# 查询 RTM 消息格式
search-docs: "RTM message format JSON structure"
```

#### 5. 清理阶段

**目标**：停止 Agent 并清理资源

**步骤**：
1. 调用 AgentStarter.stopAgentAsync(agentId)
2. （如果使用 RTM）使用 MCP 工具查询 RTM logout API
   - 搜索关键词：`[平台] RTM logout`
3. （如果使用 RTM）登出 RTM
4. 使用 MCP 工具查询 RTC leaveChannel API
   - 搜索关键词：`[平台] RTC leaveChannel`
5. 离开 RTC 频道
6. 重置状态（connectionState, agentId, dataStreamId 等）

---

## UI 组件规范

### 统一 UI 设计（参考 Kotlin 版本）

所有平台都应实现以下 UI 组件，布局和功能保持一致：

#### 1. AgentChatScreen（主页面）

**功能**：
- 日志展示区域（可滚动）
- 转录列表区域（可滚动）
- 控制按钮区域（Start Agent、静音、停止）

**重要说明**：
- **不显示标题**：页面不需要显示项目标题或页面标题
- **不显示配置信息**：不需要显示 App ID、Pipeline ID 等配置信息
- **单页面设计**：只有一个 AgentChatScreen，没有启动页面或首页

**布局结构**：
```
┌─────────────────────────┐
│  ┌───────────────────┐  │
│  │   Log View        │  │
│  │   (Scrollable)    │  │
│  │   Auto-scroll     │  │
│  └───────────────────┘  │
│  ┌───────────────────┐  │
│  │  Transcript List  │  │
│  │   (Scrollable)    │  │
│  │   Auto-scroll     │  │
│  └───────────────────┘  │
│  ┌───────────────────┐  │
│  │ [Start] [Mute] [Stop]│ │
│  └───────────────────┘  │
└─────────────────────────┘
```

**交互逻辑**：
- 未连接时：显示 "Start Agent" 按钮，点击后调用 `store.startConnection()`
- 连接中：按钮禁用，显示 "Starting..."
- 已连接：显示 "Mute/Unmute" 和 "Stop Agent" 按钮
- 日志区域：显示所有 RTC/RTM 相关日志，自动滚动到底部
- 转录列表：显示用户和 Agent 的对话，自动滚动到底部
- 静音按钮：切换静音状态，按钮图标变化
- 停止按钮：弹出确认对话框，确认后调用 `store.stopAgent()` 并重置状态

#### 3. LogView 组件

**功能**：
- 显示 RTC/RTM 相关日志
- 自动滚动到底部

**实现要点**：
- 使用平台特定的滚动视图组件
- 日志直接展示，不需要添加时间戳或级别标识
- 新日志到达时自动滚动到底部

**日志信息列表**：

根据平台支持的 SDK 方案，需要展示以下日志：

##### RTC + DataStream 版本日志

以下日志信息必须在 LogView 中展示：

**初始化阶段**：
- `RtcEngine init successfully` - RTC 引擎初始化成功
- `RtcEngine init failed` - RTC 引擎初始化失败

**Token 生成阶段**：
- `Generate user token successfully` - 用户 Token 生成成功（用于用户加入 RTC 频道）
- `Generate user token failed` - 用户 Token 生成失败
- `Generate agent token successfully` - Agent Token 生成成功（用于 Agent 启动）
- `Generate agent token failed` - Agent Token 生成失败

**RTC 连接阶段**：
- `Rtc joinChannel failed ret: $ret` - RTC 加入频道失败（$ret 为错误码）
- `Rtc onJoinChannelSuccess, channel:${channel} uid:$uid` - RTC 当前用户加入频道成功（${channel} 为频道名，$uid 为用户 ID）
- `Rtc onLeaveChannel` - RTC 当前用户离开频道
- `Rtc onUserJoined, uid:$uid` - 其他用户加入频道（$uid 为用户 ID）
- `Rtc onUserOffline, uid:$uid` - 其他用户离开频道（$uid 为用户 ID）
- `Rtc onError: $err` - RTC 错误（$err 为错误码）

**Agent 管理阶段**：
- `Agent start successfully` - Agent 启动成功
- `Agent start failed` - Agent 启动失败
- `Agent stop successfully` - Agent 停止成功
- `Agent stop failed` - Agent 停止失败

##### RTC + RTM 版本日志

RTC + RTM 版本需要包含上述所有 RTC + DataStream 版本的日志，并额外添加以下 RTM 相关日志：

**RTM 初始化阶段**：
- `RtmClient init successfully` - RTM 客户端初始化成功
- `RtmClient init failed` - RTM 客户端初始化失败

**RTM 连接阶段**：
- `Rtm login successful` - RTM 登录成功
- `Rtm login failed, code: ${errorInfo?.errorCode}` - RTM 登录失败（${errorInfo?.errorCode} 为错误码）
- `Rtm connected successfully` - RTM 连接成功
- `Rtm connected failed` - RTM 连接失败

**注意事项**：
- 日志直接展示在 LogView 上，不需要添加时间戳
- 日志中的变量（如 $ret、$uid、${channel}、${errorInfo?.errorCode}）应替换为实际值
- 日志按到达顺序显示即可，不需要特殊排序

#### 4. TranscriptList 组件

**功能**：
- 显示用户和 Agent 的对话转录
- 区分用户和 Agent 的消息
- 显示消息状态（进行中、完成、中断）
- 在列表底部展示 Agent 状态

**实现要点**：
- 用户消息：
  - 背景色：绿色（#10B981）
  - 对齐方式：右侧对齐
  - 标签：`USER`
- Agent 消息：
  - 背景色：蓝色（#6366F1）
  - 对齐方式：左侧对齐
  - 标签：`AGENT`
- 状态标签：
  - 进行中（IN_PROGRESS）：橙色（#FF9800）
  - 完成（END）：绿色（#4CAF50）
  - 中断（INTERRUPTED）：红色（#F44336）
- Agent 状态显示（固定在列表底部）：
  - IDLE：空闲状态
  - SILENT：静默状态
  - LISTENING：正在聆听
  - THINKING：正在思考
  - SPEAKING：正在说话
- 新消息到达时自动滚动到底部（Agent 状态始终可见）

#### 5. ControlButtons 组件

**功能**：
- Start Agent 按钮（未连接时显示）
- 静音/取消静音按钮（已连接时显示）
- 停止 Agent 按钮（已连接时显示）
- 按钮状态根据连接状态变化

**实现要点**：
- 未连接时：只显示 "Start Agent" 按钮
- 连接中：按钮禁用，显示 "Starting..."
- 已连接：
  - 静音按钮：显示当前静音状态（🔇/🎤），点击切换
  - 停止按钮：显示停止图标，点击弹出确认对话框
- 错误状态：显示错误提示，按钮保持可用状态

---

## Agora MCP 工具使用指南

### 工具说明

Agora MCP 服务器提供三个工具用于查询文档：

1. **search-docs**：搜索文档内容
2. **list-docs**：列出文档列表
3. **get-doc-content**：获取文档具体内容

### 使用场景

#### 场景 1：查询平台 SDK 支持情况

**步骤**：
1. 使用 `list-docs` 列出所有 RTC SDK 文档
2. 查找目标平台的文档（如：`React Native RTC SDK`）
3. 使用 `list-docs` 列出所有 RTM SDK 文档
4. 查找目标平台的文档（如：`Flutter RTM SDK`）
5. **重要**：检查项目中是否已包含 Conversational AI API SDK 代码
   - 检查项目中是否存在 `convoaiApi/` 或 `ConversationalAIAPI/` 目录
   - 检查目录中是否包含 `IConversationalAIAPI.{ext}` 文件（这是对外提供的接口文件）
   - **注意**：Conversational AI API SDK 目前只提供代码，没有上传到包管理器
   - SDK 代码需要开发者手动拷贝到项目中
   - 如果项目中已包含 SDK 代码，查看 SDK 代码中的 README 文档，优先使用 SDK 处理字幕和 Agent 状态
   - 如果项目中没有 SDK 代码，提示开发者可以从其他项目（如 `android-kotlin/`）拷贝 SDK 代码

**示例**：
```
# 列出所有 RTC SDK 文档
list-docs: category="RTC SDK"

# 列出所有 RTM SDK 文档
list-docs: category="RTM SDK"

# 检查项目中是否包含 SDK 代码（需要检查项目目录结构）
# 如果包含，查看 SDK 代码中的 README 文档
```

#### 场景 2：查询具体 API 使用方法

**步骤**：
1. 使用 `search-docs` 搜索相关 API
2. 根据搜索结果，使用 `get-doc-content` 获取详细文档

**示例**：
```
# 搜索 React Native RTC joinChannel
search-docs: "React Native RTC joinChannel"

# 获取具体文档内容
get-doc-content: uri="doc/rtc/react-native/joinChannel"
```

#### 场景 3：查询事件处理器格式

**步骤**：
1. 使用 `search-docs` 搜索事件名称
2. 获取事件参数和回调格式

**示例**：
```
# 搜索 RTC onJoinChannelSuccess 事件
search-docs: "RTC onJoinChannelSuccess event handler"

# 搜索 RTM onMessageEvent 事件
search-docs: "RTM onMessageEvent event handler"
```

#### 场景 4：查询消息格式

**步骤**：
1. 使用 `search-docs` 搜索消息格式相关文档
2. 获取消息结构说明

**示例**：
```
# 搜索 RTC DataStream 消息格式
search-docs: "RTC DataStream message format split parts"

# 搜索 RTM 消息格式
search-docs: "RTM message format JSON structure"

# 搜索 RTM 字幕消息字段（text, turn_id, turn_status 等）
search-docs: "RTM message transcription text turn_id turn_status"

# 搜索 RTM onPresenceEvent 事件格式
search-docs: "RTM onPresenceEvent REMOTE_STATE_CHANGED stateItems"
```

### 常用查询关键词

**RTC 相关**：
- `[平台] RTC initialize create engine`
- `[平台] RTC joinChannel`
- `[平台] RTC leaveChannel`
- `[平台] RTC createDataStream`
- `[平台] RTC onStreamMessage`
- `[平台] RTC onJoinChannelSuccess`
- `[平台] RTC enableAudio`
- `[平台] RTC adjustRecordingSignalVolume`

**RTM 相关**：
- `[平台] RTM create client initialize`
- `[平台] RTM login`
- `[平台] RTM logout`
- `[平台] RTM subscribe message channel`
- `[平台] RTM onConnectionStateChanged`
- `[平台] RTM onMessageEvent`
- `[平台] RTM onPresenceEvent REMOTE_STATE_CHANGED`
- `[平台] RTM message transcription text turn_id turn_status`
- `[平台] RTM message BINARY String type conversion`

**Conversational AI API SDK**（检查项目中是否包含 SDK 代码）：
- 检查项目中是否存在 `convoaiApi/` 或 `ConversationalAIAPI/` 目录
- 检查目录中是否包含 `IConversationalAIAPI.{ext}` 文件（这是对外提供的接口文件）
- 如果包含，查看 SDK 代码中的 README 文档
- **注意**：SDK 不是通过包管理器安装的，而是需要开发者手动拷贝代码

**消息格式**（仅在平台未提供 SDK 时使用）：
- `RTC DataStream message format split parts base64`
- `RTM message format JSON structure`
- `Conversational AI message format transcript agentState`

**消息类型**：
- `assistant.transcription`：Agent 转录消息（RTC DataStream 和 RTM 通用）
- `user.transcription`：用户转录消息（RTC DataStream 和 RTM 通用）
- `message.interrupt`：中断消息（RTC DataStream 和 RTM 通用）
- `message.state`：消息状态（**仅 RTC DataStream 版本**，用于 Agent 状态更新，包含 IDLE、SILENT、LISTENING、THINKING、SPEAKING）
- `unknown`：未知消息类型（RTC DataStream 和 RTM 通用）

**Agent 状态获取方式**：
- **RTC DataStream 版本**：通过 `message.state` 消息类型解析 Agent 状态
- **RTM 版本**：通过 RTM 的 `onPresenceEvent` 回调中的 `REMOTE_STATE_CHANGED` 事件获取 Agent 状态（不使用 `message.state` 消息类型）

**注意**：`[平台]` 需要替换为实际平台名称，如：`React Native`、`Flutter`、`Android`、`iOS`、`HarmonyOS` 等。

---

## 生成规则

### 变量替换规则

```yaml
variable_replacement:
  "{{PROJECT_NAME}}": "从 project.name 获取"
  "{{PLATFORM}}": "从目标平台获取"
  "{{APP_ID}}": "从环境变量 AGORA_APP_ID 获取"
  "{{PIPELINE_ID}}": "从环境变量 AGORA_PIPELINE_ID 获取"
  "{{SDK_INTEGRATION}}": "根据平台 SDK 支持情况：'RTC' 或 'RTC+RTM'"
  "{{FILE_EXTENSION}}": "根据平台：.ts/.tsx/.dart/.kt/.swift/.ets/.cs"
```

### 生成顺序

```yaml
generation_order:
  1. 查询平台 SDK 支持情况（使用 MCP list-docs/search-docs）
     - 查询 RTC SDK 支持
     - 查询 RTM SDK 支持
   - **检查项目中是否已包含 Conversational AI API SDK 代码**：
     - 检查项目中是否存在 `convoaiApi/` 或 `ConversationalAIAPI/` 目录
     - 检查目录中是否包含 `IConversationalAIAPI.{ext}` 文件（这是对外提供的接口文件）
     - **注意**：SDK 不是通过包管理器安装的，而是需要开发者手动拷贝代码
  2. 确定集成方案（RTC 或 RTC+RTM）
  3. 确定消息处理方式：
     - 如果项目中已包含 Conversational AI API SDK 代码：使用 SDK 处理字幕和 Agent 状态
     - 如果项目中没有 SDK 代码：使用手动解析规则（参考 HarmonyOS 或 Android Kotlin 版本的 MessageParser）
  4. 生成配置文件（package.json/pubspec.yaml/build.gradle 等）
     - 如果使用 SDK，添加 SDK 依赖
  5. 生成环境变量文件（.env.example）
  6. 创建目录结构
  7. 生成工具类（KeyCenter, ChannelNameGenerator, PermissionHelper）
  8. 生成 API 层（AgentStarter, TokenGenerator）
     - **TokenGenerator.generateTokenAsync()** 实现：
       - **RTC+DataStream 版本**：
         - 用户 Token：`generateTokenAsync(channelName, userId, ['rtc'])`
         - Agent Token：`generateTokenAsync(channelName, agentRtcUid, ['rtc'])`
       - **RTC+RTM 版本**：
         - 用户 Token：`generateTokenAsync(channelName, userId, ['rtc', 'rtm'])`
         - Agent Token：`generateTokenAsync(channelName, agentRtcUid, ['rtc', 'rtm'])`
         - **注意**：Agent 也需要使用 RTM 进行消息传递，所以 Agent Token 也必须包含 RTM 类型
       - 请求体格式：单个类型使用 `type` 字段，多个类型使用 `types` 数组字段
       - 参考实现：
         - RTC+RTM Agent Token：`android-kotlin/app/src/main/java/io/agora/convoai/example/startup/ui/AgentChatViewModel.kt:469-472`
     - **AgentStarter.startAgentAsync()** 实现：
       - **RTC+DataStream 版本**：请求体必须包含 `properties.parameters` 和 `properties.advanced_features` 字段
         - `parameters.data_channel = "datastream"`
         - `parameters.transcript.enable_words = false`
         - `advanced_features.enable_rtm = false`
       - **RTC+RTM 版本**：请求体不需要 `parameters` 和 `advanced_features` 字段（使用默认 RTM 模式）
       - 参考实现：
         - RTC+DataStream：`harmonyos/entry/src/main/ets/api/AgentStarter.ets:113-133`
         - RTC+RTM：`android-kotlin/app/src/main/java/io/agora/convoai/example/startup/api/AgentStarter.kt`
  9. 生成业务逻辑层（AgentChatStore）：
     - 使用 MCP 工具查询 RTC 初始化 API
     - 使用 MCP 工具查询 RTM 初始化 API（如果支持）
     - 使用 MCP 工具查询事件处理器格式
     - 如果使用 SDK：按照 SDK 代码中的 README 集成 SDK 并注册事件处理器
     - 如果未使用 SDK：根据集成方案选择对应的手动解析流程
     - **注意**：如果项目中没有 SDK 代码，提示开发者可以从其他项目（如 `android-kotlin/`）拷贝 SDK 代码
  10. 生成 UI 组件（LogView, TranscriptList, ControlButtons）
  11. 生成页面组件（AgentChatScreen）
  12. 生成 README.md：
     - README 内容应包含项目说明、环境配置、依赖安装、运行步骤等
     - 如果集成方案是 RTC+RTM，参考 `android-kotlin/` 目录下的 README.md（RTC+RTM 版本）
     - 如果集成方案是 RTC+DataStream，参考 `harmonyos/` 目录下的 README.md（RTC+DataStream 版本）
     - 根据目标平台调整 SDK 安装步骤和配置说明
```

### 验证规则

```yaml
validation:
  - 检查平台 SDK 支持情况是否已查询（通过 MCP 工具）
  - 检查是否已检查项目中是否包含 Conversational AI API SDK 代码
  - 检查集成方案是否正确（RTC 或 RTC+RTM）
  - 检查消息处理方式是否正确（使用 SDK 或手动解析）
  - 如果使用 SDK，检查是否按照 SDK 代码中的 README 正确集成
  - 如果未使用 SDK，检查消息解析逻辑是否标记为 TODO
  - 如果未使用 SDK，检查是否提示开发者可以从其他项目拷贝 SDK 代码
  - 检查所有模板变量是否已替换
  - 检查目录结构是否完整
  - 检查配置文件语法是否正确
  - 检查依赖版本是否有效（包括 SDK 依赖，如果使用）
  - 检查环境变量是否定义
  - 检查是否使用了正确的 MCP 工具查询 API
```

---

## Agent 使用说明

### 输入参数

```yaml
agent_input:
  platform: "react-native" | "flutter" | "android" | "ios" | "harmonyos" | "web" | "unity"
  project_name: "Agora Conversational AI Starter"
  custom_config: {}  # 可选的自定义配置
```

### 生成流程

1. **查询平台 SDK 支持**
   - 使用 `list-docs` 或 `search-docs` 查询 RTC SDK 支持
   - 使用 `list-docs` 或 `search-docs` 查询 RTM SDK 支持
   - **检查项目中是否已包含 Conversational AI API SDK 代码**：
     - 检查项目中是否存在 `convoaiApi/` 或 `ConversationalAIAPI/` 目录
     - 检查目录中是否包含 `IConversationalAIAPI.{ext}` 文件（这是对外提供的接口文件）
     - **注意**：SDK 不是通过包管理器安装的，而是需要开发者手动拷贝代码
   - 确定集成方案（RTC 或 RTC+RTM）
   - 确定消息处理方式（使用 SDK 或手动解析）

2. **生成项目结构**
   - 根据平台创建目录结构
   - 生成配置文件
   - 如果使用 SDK，在配置文件中添加 SDK 依赖

3. **生成代码文件**
   - 如果项目中使用 SDK：按照 SDK 代码中的 README 集成 SDK 并注册事件处理器
   - 如果项目中没有 SDK 代码：
     - 对于每个需要实现的 API 调用，使用 MCP 工具查询具体用法
     - 根据查询结果生成代码
     - 标记消息解析逻辑为 TODO
     - 提示开发者：如果需要使用 SDK，可以从其他项目（如 `android-kotlin/`）拷贝 SDK 代码到当前项目

4. **验证生成结果**
   - 检查集成方案是否正确
   - 检查代码完整性
   - 检查 TODO 标记

### 输出结构

```
generated-project/
├── [配置文件]
├── src/
│   ├── screens/
│   │   └── AgentChatScreen.{ext}
│   ├── api/
│   │   ├── AgentStarter.{ext}
│   │   └── TokenGenerator.{ext}
│   ├── store/
│   │   └── AgentChatStore.{ext}  # RTC 或 RTC+RTM 版本
│   ├── components/
│   │   ├── LogView.{ext}
│   │   ├── TranscriptList.{ext}
│   │   └── ControlButtons.{ext}
│   └── utils/
│       ├── KeyCenter.{ext}
│       ├── ChannelNameGenerator.{ext}
│       ├── PermissionHelper.{ext}
│       └── MessageParser.{ext}  # TODO: 仅在项目未包含 SDK 代码时需要，需要开发者实现
│   └── convoaiApi/        # 或 ConversationalAIAPI/（如果项目中已包含 SDK 代码）
│       ├── IConversationalAIAPI.{ext}  # SDK 接口定义
│       ├── ConversationalAIAPIImpl.{ext} # SDK 主要实现
│       ├── ConversationalAIUtils.{ext}  # SDK 工具类
│       ├── subRender/                   # SDK 字幕渲染模块
│       │   ├── MessageParser.{ext}
│       │   └── TranscriptController.{ext}
│       └── README.md                    # SDK 使用说明
├── .env.example
└── README.md
```

---

## 重要提示

### 1. 消息解析逻辑

**重要原则**：优先使用 Conversational AI API SDK

在实现消息解析逻辑前，AI Agent 必须：

1. **检查项目中是否已包含 SDK 代码**：
   - 检查项目中是否存在 `convoaiApi/` 或 `ConversationalAIAPI/` 目录
   - 检查目录中是否包含 `IConversationalAIAPI.{ext}` 文件（这是对外提供的接口文件）
   - **注意**：Conversational AI API SDK 目前只提供代码，没有上传到包管理器（maven/npm/pub 等）
   - SDK 代码需要开发者手动拷贝到项目中，不是通过包管理器安装

2. **如果项目中已包含 SDK 代码**：
   - **优先使用 SDK**：按照 SDK 代码中的 README 文档使用 SDK 提供的 API
   - SDK 会自动处理消息解析，提供事件处理器（如 `onTranscriptUpdated`、`onAgentStateChanged`）
   - 不需要手动实现消息解析逻辑
   - 参考 Android Kotlin 版本的实现方式（使用 `ConversationalAIAPIImpl` 和 `TranscriptController`）

3. **如果项目中没有 SDK 代码**：
   - 才需要根据以下规则手动实现消息解析逻辑
   - 在代码中标记为 TODO，提示开发者参考文档实现
   - 提示开发者：如果需要使用 SDK，需要从其他项目（如 `android-kotlin/`）拷贝 SDK 代码到当前项目

**手动解析规则**（仅在平台未提供 SDK 时使用）：

- **RTC DataStream 版本**：
  - 使用 MCP 工具查询：`search-docs: "RTC DataStream message format split parts base64"`
  - 参考 HarmonyOS 版本的 MessageParser 实现思路
  - 消息可能被分割成多个部分，需要合并
  - 消息格式：`messageId|partIndex|totalParts|base64Content`
  - 需要处理 Base64 解码和 JSON 解析
  - **消息类型**：
    - `assistant.transcription`：Agent 转录消息
    - `user.transcription`：用户转录消息
    - `message.interrupt`：中断消息
    - `message.state`：消息状态（Agent 状态更新）
    - `unknown`：未知消息类型
  - 在代码中标记为 TODO，提示开发者实现

- **RTM 版本**（仅在平台未提供 SDK 时使用）：
  - 使用 MCP 工具查询：`search-docs: "RTM message format JSON structure"`
  - 参考 Android Kotlin 版本的 `TranscriptController.kt` 实现思路（注意：Android Kotlin 版本使用了 SDK，这里仅作为消息格式参考）
  - 消息可能是 BINARY 或 String 类型，都需要转换为 JSON Map
  - 不需要处理分片
  - **消息类型**：
    - `assistant.transcription`：Agent 转录消息
    - `user.transcription`：用户转录消息
    - `message.interrupt`：中断消息
    - **注意**：RTM 版本中**不使用** `message.state` 消息类型
  - **字幕消息处理**（RTM 特有，**只处理 Text 模式**）：
    - 参考 Android Kotlin 版本的 `TranscriptController.kt` 中的 `onMessageEvent` 实现
    - 从 `messageMap["object"]` 获取消息类型字符串
    - 对于 `assistant.transcription`：
      - 从 `msg["text"]` 获取文本
      - 从 `msg["turn_id"]` 获取 turnId
      - 从 `msg["turn_status"]` 获取状态（0: IN_PROGRESS, 1: END, 2: INTERRUPTED）
    - 对于 `user.transcription`：
      - 从 `msg["text"]` 获取文本
      - 从 `msg["turn_id"]` 获取 turnId
      - 从 `msg["final"]` 获取是否完成
    - 对于 `message.interrupt`：
      - 从 `msg["turn_id"]` 获取被中断的 turnId
      - 更新被中断转录的状态为 INTERRUPTED
    - **只处理 Text 模式**，不需要处理 Word 模式（逐词渲染）
  - **Agent 状态获取**（RTM 特有）：
    - 使用 MCP 工具查询：`search-docs: "[平台] RTM onPresenceEvent REMOTE_STATE_CHANGED"`
    - 在 `onPresenceEvent` 回调中监听 `REMOTE_STATE_CHANGED` 事件
    - 从 `event.stateItems["state"]` 获取 Agent 状态值
    - 参考 Android Kotlin 版本的 `ConversationalAIAPIImpl.kt` 中的 `onPresenceEvent` 实现
  - **Transcript 更新规则**（重要）：
    - 在更新转录列表时，需要根据 `turnId` 和 `type` 判断是更新还是新增：
      - **同一句话的更新**：如果收到相同 `turnId` 和 `type` 的消息（例如文本内容更新、状态从 `IN_PROGRESS` 变为 `END`），应该**更新现有 transcript**，而不是添加新的
      - **新的一句话**：如果 `turnId` 或 `type` 不同，应该**添加新的 transcript**
    - **RTC DataStream 版本**：参考 HarmonyOS 版本的 `AgentChatController.ets` 中的 `addOrUpdateTranscript` 方法
    - **RTM 版本**：参考 Android Kotlin 版本的 `AgentChatViewModel.kt` 中的 `addTranscript` 方法
  - 在代码中标记为 TODO，提示开发者实现

### 2. SDK API 差异

不同平台的 SDK API 可能有差异，生成代码时必须：
- 使用 MCP 工具查询对应平台的具体 API
- 不要假设 API 名称或参数格式
- 参考官方文档的示例代码

### 3. 生产环境注意事项

- **Token 生成**：生产环境必须使用服务端生成 Token，不要在前端生成
- **敏感信息**：不要在前端代码中暴露 `appCertificate`、`restKey`、`restSecret`
- **错误处理**：实现完善的错误处理和用户提示
- **权限处理**：根据平台要求处理音频权限

### 4. UI 一致性

- 所有平台的 UI 应保持一致，参考 Kotlin 版本的设计
- 日志展示、转录列表、控制按钮的功能和布局应统一
- 颜色方案、图标、文字应保持一致

---

## 参考资源

### 官方文档

- **RTC SDK 文档首页**：https://doc.shengwang.cn/doc/rtc/homepage
- **RTM SDK 文档首页**：https://doc.shengwang.cn/doc/rtm2/homepage
- **Conversational AI API 文档**：https://doc.shengwang.cn/doc/convoai/restful/landing-page

### 参考实现

- **Android Kotlin 版本**：`android-kotlin/` 目录
  - 参考 UI 设计和业务逻辑组织方式
  - 参考 RTM 消息处理方式
  - **参考 README.md**：RTC+RTM 版本的 README 内容结构
- **HarmonyOS 版本**：`harmonyos/` 目录
  - 参考 RTC DataStream 消息处理方式
  - 参考 MessageParser 实现思路
  - **参考 README.md**：RTC+DataStream 版本的 README 内容结构

---

**维护说明**：本 guide 随 Agora SDK 更新持续维护，新增平台或 SDK 更新时需要同步更新。AI Agent 应始终通过 MCP 工具查询最新的 API 文档，而不是依赖本 guide 中的示例。
