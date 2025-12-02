# Android Agent Starter (Compose)

## 功能概述

### 解决的问题

本示例项目展示了如何在 Android 应用（Jetpack Compose）中集成 Agora Conversational AI（对话式 AI）功能，实现与 AI 语音助手的实时对话交互。主要解决以下问题：

- **实时语音交互**：通过 Agora RTC SDK 实现与 AI 代理的实时音频通信
- **消息传递**：通过 Agora RTM SDK 实现与 AI 代理的消息交互和状态同步
- **实时转录**：支持实时显示用户和 AI 代理的对话转录内容，包括转录状态（进行中、完成、中断等）
- **状态管理**：统一管理连接状态、Agent 启动状态、静音状态、转录状态等 UI 状态
- **自动流程**：自动完成频道加入、RTM 登录、Agent 启动等流程
- **统一界面**：所有功能（日志、状态、转录、控制按钮）集成在同一个页面，移除了页面跳转

### 适用场景

- 智能客服系统：构建基于 AI 的实时语音客服应用
- 语音助手应用：开发类似 Siri、小爱同学的语音助手功能
- 实时语音转录：实时显示用户和 AI 代理的对话转录内容
- 语音交互游戏：开发需要语音交互的游戏应用
- 教育培训：构建语音交互式教学应用

### 前置条件

- Android SDK API Level 26（Android 8.0）或更高
- Agora 开发者账号 [Console](https://console.shengwang.cn/)
- 已在 Agora 控制台开通 **实时消息 RTM** 功能（必需）
- 已创建 Agora 项目并获取 App ID 和 App Certificate
- 已创建 Conversational AI Pipeline 并获取 Pipeline ID [AI Studio](https://console-conversationai.shengwang.cn/product/ConversationAI/studio)

## 快速开始

### 依赖安装

1. **克隆项目**：
   ```bash
   git clone https://github.com/alienzh/Agora-AI-Recipes-Starter.git
   cd Agora-AI-Recipes-Starter/android-compose
   ```

2. **配置 Android 项目**：
   - 使用 Android Studio 打开项目
   - 等待 Gradle 同步完成

3. **配置 Agora Key**：
   
   1. 复制 `env.example.properties` 文件为 `env.properties`：
   ```bash
   cp env.example.properties env.properties
   ```
   
   2. 编辑 `env.properties` 文件，填入你的实际配置值：
   ```properties
   agora.appId=your_app_id
   agora.appCertificate=your_app_certificate
   agora.restKey=your_rest_key
   agora.restSecret=your_rest_secret
   agora.pipelineId=your_pipeline_id
   ```
   
   **配置项说明**：
   - `agora.appId`：你的 Agora App ID（必需）
   - `agora.appCertificate`：你的 App Certificate（可选，用于 Token 生成）
   - `agora.restKey`：REST API Key（必需，用于启动 Agent）
   - `agora.restSecret`：REST API Secret（必需，用于启动 Agent）
   - `agora.pipelineId`：Pipeline ID（必需，用于启动 Agent）
   
   **获取方式**：
   - 体验声网对话式 AI 引擎前，你需要先在声网控制台创建项目并开通对话式 AI 引擎服务，获取 App ID、客户 ID 和客户密钥等调用 RESTful API 时所需的参数。[开通服务](https://doc.shengwang.cn/doc/convoai/restful/get-started/enable-service)
   - Pipeline ID：在 [AI Studio](https://console-conversationai.shengwang.cn/product/ConversationAI/studio) 中创建 Pipeline 后获取
   
   **注意**：
   - `env.properties` 文件包含敏感信息，不会被提交到版本控制系统。请确保不要将你的实际凭证提交到代码仓库。
   - 每次启动时会自动生成随机的 channelName，格式为 `channel_compose_XXXX`（XXXX 为 4 位随机数字），无需手动配置。
   - ⚠️ **重要**：`TokenGenerator.kt` 中的 Token 生成功能仅用于演示和开发测试，**生产环境必须使用自己的服务端生成 Token**。代码中已添加详细警告说明。

4. **配置 Agent 启动方式**：
   
   **方式一：直接调用 Agora RESTful API**（仅用于快速体验，不推荐用于生产）
   
   默认配置，无需额外设置。Android 应用直接调用 Agora RESTful API 启动 Agent，方便开发者快速体验功能。
   
   **使用前提**：
   - 确保已正确配置 `env.properties` 文件中的相关 key。
   
   **适用场景**：
   - 快速体验和功能验证
   - 无需启动额外服务器，开箱即用
   
   ⚠️ **重要说明**：
   - 此方式**仅用于快速体验和开发测试**，**不推荐用于生产环境**
   - 生产环境**必须**使用方式二，通过自己的业务后台中转请求
   - 直接在前端调用 Agora RESTful API 会暴露 REST Key 和 REST Secret，存在安全风险
   
   ⚠️ **生产环境要求**：
   - **必须将敏感信息放在后端**：`appCertificate`、`restKey`、`restSecret` 等敏感信息必须存储在服务端，绝对不能暴露在客户端代码中
   - **客户端通过后端获取 Token**：客户端请求自己的业务后台接口，由服务端使用 `appCertificate` 生成 Token 并返回给客户端
   - **客户端通过后端启动 Agent**：客户端请求自己的业务后台接口，由服务端使用 `restKey` 和 `restSecret` 调用 Agora RESTful API 启动 Agent
   - **参考实现**：可参考 `../server-python/agora_http_server.py` 了解如何在服务端实现 Token 生成和 Agent 启动接口

## 测试验证

### 快速体验流程

1. **运行应用**：
   - 运行应用，进入 `AgentChatScreen` 页面
   - 页面从上到下依次显示：
     - **日志区域**：显示 Agent 启动相关的状态日志
     - **转录列表区域**：实时显示 USER 和 AGENT 的对话转录内容
       - AGENT 的消息靠左对齐
       - USER 的消息靠右对齐
     - **Agent 状态**：显示在转录列表区域的底部，显示当前 Agent 的状态（idle、listening、thinking、speaking 等）
     - **控制按钮**：
       - 未连接时：显示 "Start" 按钮
       - 连接后：显示 "Mute" 和 "Stop Agent" 按钮

2. **启动 Agent**：
   - 点击 "Start" 按钮
   - 按钮文本变为 "Starting..."，应用自动：
     - 生成随机 channelName（格式：`channel_compose_XXXX`）
     - 加入 RTC 频道并登录 RTM
     - 连接成功后自动启动 AI Agent
   - Agent 启动成功后，"Start" 按钮隐藏，显示 "Mute" 和 "Stop Agent" 按钮

3. **与 Agent 对话**：
   - 对着手机说话，能听到 Agent 的回应
   - 实时显示 USER 和 AGENT 的转录内容
   - 支持静音/取消静音功能
   - 点击 "Stop Agent" 按钮停止 Agent 并释放资源
   - 侧滑返回会直接 finish Activity，退出应用

### 功能验证清单

- [ ] **连接**：App 能成功加入 RTC 频道并登录 RTM。
- [ ] **启动**：点击 Start 后能自动启动 Agent，按钮切换为 Mute 和 Stop。
- [ ] **对话**：对着手机说话，能听到 Agent 的回应。
- [ ] **字幕**：说话时能看到实时的文字转录（AGENT 靠左，USER 靠右）。
- [ ] **状态显示**：Agent 状态正确显示在转录列表区域底部。
- [ ] **打断**：在 Agent 说话时插话，Agent 能被成功打断并回应新的内容。
- [ ] **挂断**：点击 Stop Agent 能正确停止 Agent 并释放资源。
- [ ] **返回**：侧滑返回能直接 finish Activity，退出应用。

## 项目结构

```
android-compose/
├── app/
│   ├── src/main/
│   │   ├── java/io/agora/convoai/example/startup/
│   │   │   ├── ui/                    # Compose UI
│   │   │   │   ├── AgentChatScreen.kt # 主界面（合并了 Home 和 Living 功能）
│   │   │   │   ├── AgentChatViewModel.kt # ViewModel（包含 RTC/RTM 逻辑）
│   │   │   │   └── theme/            # 主题配置
│   │   │   ├── api/                   # API (AgentStarter, TokenGenerator)
│   │   │   └── tools/                 # 工具类
│   │   ├── res/                       # 资源文件
│   │   └── convoaiApi/                # Conversational AI API（Kotlin）
│   └── build.gradle.kts
├── env.properties                     # 环境配置（需要创建，不提交到版本控制）
├── env.example.properties             # 环境配置示例
└── README.md                          # 本文档
```

## 相关资源

### API 文档链接

- [Agora RTC Android SDK 文档](https://doc.shengwang.cn/doc/rtc/android/landing-page)
- [Agora RTM Android SDK 文档](https://doc.shengwang.cn/doc/rtm2/android/landing-page)
- [Conversational AI RESTful API 文档](https://doc.shengwang.cn/doc/convoai/restful/landing-page)
- [Conversational AI Android 客户端组件 文档](https://doc.shengwang.cn/api-ref/convoai/android/android-component/overview)

### 相关 Recipes

- [Agora Recipes 主页](https://github.com/AgoraIO-Community)
- 其他 Agora 示例项目

### 社区支持

- [Agora 开发者社区](https://github.com/AgoraIO-Community)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/agora)

---
