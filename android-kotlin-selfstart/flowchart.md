# Agent 自启动流程图

本文档描述了 Agent 自启动的完整流程，包括 Token 生成、RTC/RTM 连接和 Agent 生命周期管理。

```mermaid
flowchart TD
    Start([启动应用]) --> GenerateUserToken[获取用户 RTC/RTM 融合 Token]
    
    GenerateUserToken --> TokenSuccess{Token<br/>生成<br/>成功?}
    
    TokenSuccess -->|否| UserTokenError[显示错误信息<br/>ConnectionState: Error]
    UserTokenError --> End([结束])
    
    TokenSuccess -->|是| JoinRTC[加入 RTC 频道]
    
    JoinRTC --> LoginRTM[登录 RTM]
    
    LoginRTM --> RTMLoginSuccess{RTM 登录<br/>成功?}
    
    RTMLoginSuccess -->|否| RTMLoginError[显示错误信息<br/>ConnectionState: Error]
    RTMLoginError --> End
    
    RTMLoginSuccess -->|是| SubscribeMessage[订阅 RTM 消息<br/>conversationalAIAPI.subscribeMessage]
    
    SubscribeMessage --> CheckConnection[检查连接完成<br/>RTC Joined && RTM Logged In]
    
    CheckConnection --> ConnectionComplete{连接<br/>完成?}
    
    ConnectionComplete -->|否| WaitConnection[等待连接]
    WaitConnection --> CheckConnection
    
    ConnectionComplete -->|是| GenerateAgentToken[获取 Agent RTC/RTM 融合 Token]
    
    GenerateAgentToken --> AgentTokenSuccess{Agent Token<br/>生成<br/>成功?}
    
    AgentTokenSuccess -->|否| AgentTokenError[显示错误信息<br/>ConnectionState: Error]
    AgentTokenError --> End
    
    AgentTokenSuccess -->|是| StartAgent[调用 Start 接口启动 Agent]
    
    StartAgent --> AgentStartSuccess{Agent 启动<br/>成功?}
    
    AgentStartSuccess -->|否| AgentStartError[显示错误信息<br/>ConnectionState: Error]
    AgentStartError --> End
    
    AgentStartSuccess -->|是| AgentRunning[Agent 运行中<br/>ConnectionState: Connected]
    
    AgentRunning --> UserInteraction[用户交互<br/>语音/文本通信]
    
    UserInteraction --> StopTrigger{触发<br/>停止?}
    
    StopTrigger -->|否| UserInteraction
    
    StopTrigger -->|是| StopAgent[调用 Stop 接口停止 Agent]
    
    StopAgent --> AgentStopSuccess{Agent 停止<br/>成功?}
    
    AgentStopSuccess -->|否| AgentStopError[记录错误<br/>isLoadingAgent: false]
    AgentStopError --> Cleanup
    
    AgentStopSuccess -->|是| Cleanup[清理资源<br/>取消订阅 RTM 消息<br/>离开 RTC 频道<br/>登出 RTM<br/>清除转录记录]
    
    Cleanup --> End
```

## 流程说明

### 阶段 1: 用户连接设置
1. **获取用户 Token**: 使用 `userId` 和空的 `channelName` 为用户生成统一的 RTC/RTM Token
2. **加入 RTC 频道**: 使用生成的 Token 加入 RTC 频道
3. **登录 RTM**: 使用相同的 Token 登录 RTM 服务
4. **订阅消息**: 订阅 RTM 频道消息以接收 Agent 状态和转录内容

### 阶段 2: Agent 启动
1. **获取 Agent Token**: 使用 `agentUid` 和 `channelName` 为 Agent 生成统一的 RTC/RTM Token
2. **启动 Agent**: 使用 Agent 配置（name, pipelineId, channel, agentRtcUid, token）调用启动 Agent 接口
3. **保存 Agent ID**: 存储返回的 `agentId` 供后续使用

### 阶段 3: Agent 运行
- Agent 处于活动状态，准备进行通信
- 用户可以通过语音/文本与 Agent 交互
- 实时显示转录内容
- 监控 Agent 状态变化

### 阶段 4: Agent 停止
1. **停止 Agent**: 使用存储的 `agentId` 调用停止 Agent 接口
2. **清理资源**: 取消订阅 RTM 消息、离开 RTC 频道、登出 RTM 并清除转录记录

## 关键要点

- **Token 生成**: 生成两个独立的 Token - 一个用于用户，一个用于 Agent
- **顺序操作**: RTC 加入和 RTM 登录按顺序进行，但可以并行化
- **错误处理**: 每个步骤都包含错误处理，并更新相应的状态
- **状态管理**: 在整个过程中更新 UI 状态以反映连接状态
- **资源清理**: 停止 Agent 时执行适当的清理操作，防止资源泄漏

---

## 时序图

以下时序图展示了各个组件之间的交互顺序，包括页面跳转的时机。

```mermaid
sequenceDiagram
    participant User as 用户
    participant ConfigPage as 配置页面
    participant Server as Server
    participant RTC as Rtc
    participant RTM as Rtm
    participant VoicePage as 通话页面

    User->>ConfigPage: 点击启动按钮
    
    Note over ConfigPage: 阶段 1: 用户连接设置
    
    ConfigPage->>Server: 获取用户 RTC/RTM 融合 Token
    Server-->>ConfigPage: 返回用户 Token
    ConfigPage->>RTC: 加入 RTC 频道
    ConfigPage->>RTM: 登录 RTM
    
    Note over ConfigPage: RTC 和 RTM 连接成功后<br/>跳转到通话页面
    
    ConfigPage->>VoicePage: 页面跳转
    
    Note over VoicePage: 阶段 2: Agent 启动
    
    VoicePage->>Server: 获取 Agent RTC/RTM 融合 Token
    Server-->>VoicePage: 返回 Agent Token
    VoicePage->>Server: 调用 Start 接口启动 Agent
    Server-->>VoicePage: 返回 agentId
    
    Note over VoicePage: Agent 运行中
    
    User->>VoicePage: 点击挂断按钮
    VoicePage->>Server: 调用 Stop 接口停止 Agent
    VoicePage->>ConfigPage: 返回配置页面
```

### 时序图说明

#### 关键步骤
1. **获取用户 Token**: 生成用户 RTC/RTM 融合 Token
2. **加入 RTC 频道**: 使用 Token 加入 RTC 频道
3. **登录 RTM**: 使用 Token 登录 RTM 服务
4. **页面跳转**: RTC 和 RTM 连接成功后，从第一个页面跳转到第二个页面
5. **获取 Agent Token**: 生成 Agent RTC/RTM 融合 Token
6. **启动 Agent**: 调用 Start 接口启动 Agent
7. **停止 Agent**: 调用 Stop 接口停止 Agent

