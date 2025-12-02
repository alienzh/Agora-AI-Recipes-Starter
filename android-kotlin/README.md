# Android Agent Starter

## 功能概述

### 解决的问题

本示例项目展示了如何在 Android 应用中集成 Agora Conversational AI（对话式 AI）功能，实现与 AI 语音助手的实时对话交互。主要解决以下问题：

- **实时语音交互**：通过 Agora RTC SDK 实现与 AI 代理的实时音频通信
- **消息传递**：通过 Agora RTM SDK 实现与 AI 代理的消息交互和状态同步
- **实时转录**：支持实时显示用户和 AI 代理的对话转录内容，包括转录状态（进行中、完成、中断等）
- **状态管理**：统一管理连接状态、Agent 启动状态、静音状态、转录状态等 UI 状态
- **自动流程**：自动完成频道加入、RTM 登录、Agent 启动等流程
- **统一界面**：所有功能（日志、状态、转录、控制按钮）集成在同一个页面

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
cd Agora-AI-Recipes-Starter/android-kotlin
```

2. **配置 Android 项目**：
    - 使用 Android Studio 打开项目
    - 配置 Agora Key：

      复制 `env.example.properties` 文件为 `env.properties`：
         ```bash
         cp env.example.properties env.properties
         ```

   编辑 `env.properties` 文件，填入你的实际配置值：
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
    - 每次启动时会自动生成随机的 channelName，格式为 `channel_kotlin_XXXX`（XXXX 为 4 位随机数字），无需手动配置。
    - ⚠️ **重要**：`TokenGenerator.kt` 中的 Token 生成功能仅用于演示和开发测试，**生产环境必须使用自己的服务端生成 Token**。代码中已添加详细警告说明。
      - 等待 Gradle 同步完成

3. **配置 Agent 启动方式**：
   
   **方式一：直接调用 Agora RESTful API**（仅用于快速体验，不推荐用于生产）
   
   默认配置，无需额外设置。Android 应用直接调用 Agora RESTful API 启动 Agent，方便开发者快速体验功能。
   
   **使用前提**：
   - 确保已正确配置 `env.properties` 文件中的相关 key。
   
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

1. **Agent Chat 页面**（`AgentChatActivity`）：
   - 运行应用，进入 Agent Chat 页面
   - 页面布局从上到下依次为：
     - **日志区域**：显示 Agent 启动相关的状态消息（RTC 连接、RTM 登录、Agent 启动等）
     - **转录列表区域**：
       - **转录列表**：实时显示 USER 和 AGENT 的对话转录内容及状态
       - **Agent 状态**：显示在转录列表底部，显示当前 Agent 的连接状态
     - **控制按钮**：初始显示"Start Agent"按钮
   
2. **启动 Agent**：
   - 点击"Start Agent"按钮
   - 按钮文本变为"Starting..."并禁用，应用自动：
     - 生成随机 channelName（格式：`channel_kotlin_XXXX`）
     - 加入 RTC 频道并登录 RTM
     - 连接成功后自动启动 AI Agent
   - Agent 启动成功后：
     - "Start Agent"按钮隐藏
     - 显示"静音"和"停止"按钮
     - 可以开始与 AI Agent 对话

3. **对话交互**：
   - 实时显示 USER 和 AGENT 的转录内容
   - 支持静音/取消静音功能
   - 点击"停止"按钮结束对话并断开连接

### 功能验证清单

- ✅ RTC 频道加入成功（查看日志区域的状态消息）
- ✅ RTM 登录成功（查看日志区域的状态消息）
- ✅ Agent 启动成功（按钮状态变化，显示静音和停止按钮）
- ✅ 音频传输正常（能够听到 AI 回复）
- ✅ 转录功能正常（显示 USER 和 AGENT 的转录内容及状态）
- ✅ 静音/取消静音功能正常
- ✅ 停止功能正常（断开连接，按钮恢复为 Start Agent）

## 项目结构

```
android-kotlin/
├── app/
│   ├── src/main/
│   │   ├── java/io/agora/convoai/example/startup/
│   │   │   ├── ui/                    # UI 相关代码
│   │   │   │   ├── AgentChatActivity.kt      # 主界面 Activity（合并了原 Home 和 Living 页面）
│   │   │   │   ├── AgentChatViewModel.kt     # ViewModel（包含 RTC 和 RTM 逻辑）
│   │   │   │   ├── CommonDialog.kt           # 通用对话框
│   │   │   │   └── common/            # 通用 UI 组件
│   │   │   ├── api/                   # API 相关代码
│   │   │   │   ├── AgentStarter.kt           # Agent 启动 API
│   │   │   │   ├── TokenGenerator.kt         # Token 生成（仅用于测试）
│   │   │   │   └── net/               # 网络相关
│   │   │   ├── tools/                 # 工具类
│   │   │   │   ├── PermissionHelp.kt         # 权限处理
│   │   │   │   └── Base64Encoding.kt         # Base64 编码工具
│   │   │   ├── KeyCenter.kt           # 配置中心（读取 env.properties）
│   │   │   └── AgentApp.kt            # Application 类
│   │   ├── res/                       # 资源文件
│   │   │   └── layout/
│   │   │       └── activity_agent_chat.xml   # Agent Chat 页面布局
│   │   └── convoaiApi/                # Conversational AI API（Kotlin）
│   └── build.gradle.kts
├── env.properties                     # 环境配置（需要创建，不提交到版本控制）
├── env.example.properties             # 环境配置示例
└── README.md                          # 本文档
```

**主要文件说明**：
- `AgentChatActivity.kt`：主界面，包含日志显示、Agent 状态、转录列表和控制按钮
- `AgentChatViewModel.kt`：业务逻辑层，包含 RTC 引擎、RTM 客户端的管理和 Agent 启动逻辑
- `AgentStarter.kt`：Agent 启动 API 封装，支持直接调用 Agora API 或通过业务后台中转
- `TokenGenerator.kt`：Token 生成工具（仅用于开发测试，生产环境需使用服务端生成）

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