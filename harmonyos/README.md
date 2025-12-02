# Agora Conversational AI - HarmonyOS 示例

## 功能概述

### 解决的问题

本示例项目展示了如何在 HarmonyOS 应用中集成 Agora Conversational AI（对话式 AI）功能，实现与 AI 语音助手的实时对话交互。主要解决以下问题：

- **实时语音交互**：通过 Agora RTC SDK 实现与 AI 代理的实时音频通信
- **消息传递**：通过 RTC DataStream 实现与 AI 代理的消息交互和状态同步
- **实时转录**：支持实时显示用户和 AI 代理的对话转录内容，包括转录状态（进行中、完成、中断等）
- **状态管理**：统一管理连接状态、Agent 启动状态、静音状态、转录状态等 UI 状态
- **自动流程**：自动完成频道加入、消息订阅、Agent 启动、页面跳转等流程

### 适用场景

- 智能客服系统：构建基于 AI 的实时语音客服应用
- 语音助手应用：开发类似 Siri、小爱同学的语音助手功能
- 实时语音转录：实时显示用户和 AI 代理的对话转录内容
- 语音交互游戏：开发需要语音交互的游戏应用
- 教育培训：构建语音交互式教学应用

### 前置条件

- DevEco Studio 5.0 或更高版本
- HarmonyOS SDK API Level 9 或更高
- Agora 开发者账号 [Console](https://console.shengwang.cn/)
- 已创建 Agora 项目并获取 App ID 和 App Certificate
- 已创建 Conversational AI Pipeline 并获取 Pipeline ID [AI Studio](https://console-conversationai.shengwang.cn/product/ConversationAI/studio)

## 快速开始

### 环境要求

- **开发环境**：
  - DevEco Studio 5.0 或更高版本
  - HarmonyOS SDK API Level 9 或更高
  - Node.js 14.0.0 或更高版本

- **运行环境**：
  - HarmonyOS 设备或模拟器（API Level 9 或更高）
  - 支持音频录制和播放的设备

### 依赖安装

1. **克隆项目**：
```bash
git clone https://github.com/alienzh/Agora-AI-Recipes-Starter.git
cd Agora-AI-Recipes-Starter/harmonyos
```

2. **配置 HarmonyOS 项目**：
- 使用 DevEco Studio 打开项目
- 配置 Agora Key：
   
  复制 `env.example.json` 文件为 `env.json`：
  ```bash
  cp env.example.json env.json
  ```
   
  编辑 `env.json` 文件，填入你的实际配置值：
  ```json
  {
    "appId": "your_app_id_here",
    "appCertificate": "your_app_certificate_here",
    "restKey": "your_rest_key_here",
    "restSecret": "your_rest_secret_here",
    "pipelineId": "your_pipeline_id_here"
  }
  ```
   
  **配置项说明**：
  - `appId`：你的 Agora App ID（必需）
  - `appCertificate`：你的 App Certificate（可选，用于 Token 生成）
  - `restKey`：REST API Key（必需，用于启动 Agent）
  - `restSecret`：REST API Secret（必需，用于启动 Agent）
  - `pipelineId`：Pipeline ID（必需，用于启动 Agent）
   
  **获取方式**：
  - 体验声网对话式 AI 引擎前，你需要先在声网控制台创建项目并开通对话式 AI 引擎服务，获取 App ID、客户 ID 和客户密钥等调用 RESTful API 时所需的参数。[开通服务](https://doc.shengwang.cn/doc/convoai/restful/get-started/enable-service)
  - Pipeline ID：在 [AI Studio](https://console-conversationai.shengwang.cn/product/ConversationAI/studio) 中创建 Pipeline 后获取
   
  **注意**：
  - `env.json` 文件包含敏感信息，不会被提交到版本控制系统。请确保不要将你的实际凭证提交到代码仓库。
  - 构建项目时，构建脚本会自动读取 `env.json` 并生成配置文件：
    - 构建脚本（`entry/hvigorfile.ts`）会在构建时读取 `harmonyos/env.json`
    - 自动生成 `entry/src/main/ets/common/KeyCenterConfig.ets`
    - 配置会被编译到应用中
  - 如果 `env.json` 文件不存在或字段缺失，构建时会生成空字符串作为默认值
  - 每次启动时会自动生成随机的 channelName，格式为 `channel_harmonyos_XXXX`（XXXX 为 4 位随机数字），无需手动配置。
  - ⚠️ **重要**：`TokenGenerator.ets` 中的 Token 生成功能仅用于演示和开发测试，**生产环境必须使用自己的服务端生成 Token**。代码中已添加详细警告说明。
   
- 等待依赖同步完成

3. **配置 Agent 启动方式**：
   
   默认配置，无需额外设置。HarmonyOS 应用直接调用 Agora RESTful API 启动 Agent，方便开发者快速体验功能。
   
   **使用前提**：
   - 确保已正确配置 `env.json` 文件中的相关 key。
   
   **适用场景**：
   - 快速体验和功能验证
   - 无需启动额外服务器，开箱即用
   
   ⚠️ **重要说明**：
   - 此方式**仅用于快速体验和开发测试**，**不推荐用于生产环境**
   - 直接在前端调用 Agora RESTful API 会暴露 REST Key 和 REST Secret，存在安全风险
   
   ⚠️ **生产环境要求**：
   - **必须将敏感信息放在后端**：`appCertificate`、`restKey`、`restSecret` 等敏感信息必须存储在服务端，绝对不能暴露在客户端代码中
   - **客户端通过后端获取 Token**：客户端请求自己的业务后台接口，由服务端使用 `appCertificate` 生成 Token 并返回给客户端
   - **客户端通过后端启动 Agent**：客户端请求自己的业务后台接口，由服务端使用 `restKey` 和 `restSecret` 调用 Agora RESTful API 启动 Agent
   - **参考实现**：可参考 `../server-python/agora_http_server.py` 了解如何在服务端实现 Token 生成和 Agent 启动接口

## 测试验证

### 快速体验流程

1. **启动应用**：
   - 运行应用，直接进入 Agent Chat 页面
   - 页面从上到下显示：
     - **日志区域**：显示 Agent 启动相关的状态日志
     - **转录区域**：显示对话转录内容，底部显示 Agent 状态
     - **控制按钮**：初始显示 "Start Agent" 按钮

2. **启动 Agent**：
   - 点击 "Start Agent" 按钮
   - 按钮文本变为 "Starting..."，应用自动：
     - 生成随机 channelName（格式：`channel_harmonyos_XXXX`）
     - 加入 RTC 频道并订阅消息（通过 RTC DataStream）
     - 连接成功后自动启动 AI Agent
   - Agent 启动成功后：
     - "Start Agent" 按钮隐藏
     - 显示 "Mute" 和 "Stop Agent" 按钮

3. **与 Agent 对话**：
   - 实时显示 USER 和 AGENT 的转录内容
   - AGENT 消息左对齐，USER 消息右对齐
   - 转录区域底部显示当前 Agent 状态（idle、listening、thinking、speaking 等）
   - 支持静音/取消静音功能（点击 Mute 按钮）
   - 点击 "Stop Agent" 按钮结束对话并清理资源

### 功能验证清单

- ✅ RTC 频道加入成功（查看日志区域的状态消息）
- ✅ 消息订阅成功（通过 RTC DataStream，查看日志区域的状态消息）
- ✅ Agent 启动成功（按钮从 "Start Agent" 变为 "Mute" 和 "Stop Agent"）
- ✅ 音频传输正常（能够听到 AI 回复）
- ✅ 转录功能正常（显示 USER 和 AGENT 的转录内容及状态）
- ✅ Agent 状态显示正常（转录区域底部显示当前状态）
- ✅ 静音/取消静音功能正常（点击 Mute 按钮）
- ✅ 停止功能正常（点击 "Stop Agent" 按钮，清理资源并重置状态）

## 项目结构

```
harmonyos/
├── entry/
│   └── src/main/ets/
│       ├── api/                   # API 相关代码
│       │   ├── AgentStarter.ets   # Agent 启动 API
│       │   └── TokenGenerator.ets # Token 生成（仅用于开发测试）
│       ├── common/                # 通用工具类
│       │   ├── KeyCenter.ets     # Key 配置中心
│       │   ├── PermissionHelper.ets # 权限管理
│       │   └── TranscriptDataSource.ets # 转录数据源
│       ├── convoaiApi/            # Conversational AI API
│       ├── pages/                 # 页面
│       │   ├── Index.ets          # 应用入口（简单包装 AgentChat）
│       │   ├── AgentChat.ets      # 主页面（单页面架构）
│       │   └── AgentChatController.ets # 业务逻辑控制器
│       └── entryability/          # Ability
├── env.json                       # 环境配置（需要创建）
├── env.example.json               # 环境配置示例
└── README.md                      # 本文档
```

### 核心文件说明

- **`pages/AgentChat.ets`**：主页面，采用单页面架构，包含：
  - 日志显示区域（顶部）
  - 转录列表和 Agent 状态（中间，合并在一个卡片中）
  - 控制按钮（底部：Start/Mute/Stop）
  
- **`pages/AgentChatController.ets`**：业务逻辑控制器，负责：
  - RTC 引擎初始化和频道管理
  - Conversational AI API 集成
  - Agent 启动和停止
  - 状态管理（连接状态、静音状态、日志等）
  - 转录数据管理

- **`api/AgentStarter.ets`**：Agent 启动 API 封装，支持：
  - 直接调用 Agora RESTful API（开发测试）
  - 通过业务后台服务器中转（生产环境）

## 重要说明

### HarmonyOS 版本特性

- **单页面架构**：采用单页面设计，所有功能（日志、状态、转录、控制）集中在一个页面，简化用户体验
- **状态管理**：使用轮询机制（每 100ms）更新 UI 状态，适合单页面架构，无需复杂的回调机制
- **消息传递方式**：HarmonyOS 版本使用 RTC DataStream 进行消息传递，**不需要**单独开通 RTM 功能
- **配置方式**：使用 JSON 格式配置文件（`env.json`），构建时自动生成配置
- **构建时配置**：构建脚本（`entry/hvigorfile.ts`）会在构建时读取 `harmonyos/env.json` 并自动生成 `entry/src/main/ets/common/KeyCenterConfig.ets`
- **字幕渲染模式**：由于 HarmonyOS RTC SDK 能力限制，**仅支持 Text 模式渲染字幕**，不支持 Word 模式（逐词渲染）
- **Token 续期**：自动处理 RTC token 续期，当 token 即将过期时自动更新
- **UI 布局**：
  - 日志区域：显示 Agent 启动相关的状态日志（仅显示 ViewModel 中的状态消息，不显示 IConversationalAIAPIEventHandler 回调的日志）
  - 转录区域：AGENT 消息左对齐，USER 消息右对齐，底部显示 Agent 状态
  - 控制按钮：初始显示 "Start Agent"，启动成功后显示 "Mute" 和 "Stop Agent"

## 相关资源

### API 文档链接

- [Agora RTC HarmonyOS SDK 文档](https://doc.shengwang.cn/doc/rtc/harmonyos/landing-page)
- [Conversational AI RESTful API 文档](https://doc.shengwang.cn/doc/convoai/restful/landing-page)
- [HarmonyOS 开发文档](https://developer.harmonyos.com/)

### 相关 Recipes

- [Agora Recipes 主页](https://github.com/AgoraIO-Community)

### 社区支持

- [Agora 开发者社区](https://github.com/AgoraIO-Community)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/agora)

---