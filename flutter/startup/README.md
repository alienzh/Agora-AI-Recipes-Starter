# agora-flutter-startup

## 功能概述

### 解决的问题

本示例项目展示了如何在 Flutter 应用中集成 Agora Conversational AI（对话式 AI）功能，实现与 AI 语音助手的实时对话交互。主要解决以下问题：

- 实时语音交互：通过 Agora RTC SDK 实现与 AI 代理的实时音频通信
- 消息传递：通过 Agora RTM SDK 实现与 AI 代理的消息交互和状态同步
- 实时转录：支持实时显示用户和 AI 代理的对话转录内容
- 状态管理：统一管理连接状态、Agent 启动状态、静音状态等 UI 状态
- 自动流程：自动完成频道加入、RTM 登录、Agent 启动等流程
- 统一界面：日志、转录、Agent 状态、控制按钮集成在同一页面

### 适用场景

- 智能客服系统：构建基于 AI 的实时语音客服应用
- 语音助手应用：开发类似 Siri、小爱同学的语音助手功能
- 实时语音转录：实时显示用户和 AI 代理的对话转录内容
- 语音交互游戏：开发需要语音交互的游戏应用
- 教育培训：构建语音交互式教学应用

### 前置条件

- 已安装 Flutter 开发环境（3.x 以上推荐）
- Agora 开发者账号
- 已开通实时消息 RTM（必需）
- 已创建 Agora 项目并获取 App ID 和 App Certificate
- 已创建 Conversational AI Pipeline 并获取 Pipeline ID

## 快速开始

### 依赖安装

1. 克隆项目并进入示例目录：
```bash
git clone https://github.com/alienzh/Agora-AI-Recipes-Starter.git
cd Agora-AI-Recipes-Starter/flutter/startup
```

2. 配置 Flutter 项目：
   - 配置 Agora Key：
     复制 `assets/env.example.properties` 为 `assets/env.properties`：
     ```bash
     cp assets/env.example.properties assets/env.properties
     ```
   - 编辑 `assets/env.properties` 文件，填入你的实际配置值：
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
   - 请在声网控制台创建项目并开通对话式 AI 引擎服务，获取 App ID、客户 ID 和客户密钥等调用 RESTful API 所需参数
   - Pipeline ID：在 AI Studio 中创建 Pipeline 后获取

   **注意**：
   - `env.properties` 文件包含敏感信息，不会被提交到版本控制系统。请确保不要将你的实际凭证提交到代码仓库
   - 每次启动时会自动生成随机的 `channelName`，格式为 `channel_flutter_XXXX`（XXXX 为 4 位随机数字），无需手动配置
   - ⚠️ 重要：`token_generator.dart` 中的 Token 生成功能仅用于演示和开发测试，生产环境必须使用自己的服务端生成 Token

3. 安装依赖并运行：
```bash
flutter pub get
flutter run
```

### 平台支持

- 本项目仅支持移动端（Android/iOS）。

### 配置 Agent 启动方式

默认配置，无需额外设置。Flutter 应用直接调用 Agora RESTful API 启动 Agent，方便快速体验功能。

**使用前提**：
- 确保已正确配置 `assets/env.properties`

**适用场景**：
- 快速体验与功能验证
- 无需启动额外服务器，开箱即用

⚠️ 重要说明：
- 此方式仅用于快速体验和开发测试，不推荐用于生产环境
- 直接在前端调用 Agora RESTful API 会暴露 REST Key 和 REST Secret，存在安全风险

⚠️ 生产环境要求：
- 必须将敏感信息放在后端：`appCertificate`、`restKey`、`restSecret` 不得暴露在客户端
- 客户端通过后端获取 Token：服务器使用 `appCertificate` 生成 Token 后返回客户端
- 客户端通过后端启动 Agent：服务器使用 `restKey/restSecret` 调用 Agora RESTful API
- 参考实现：可参考 `../server-python/agora_http_server.py`

## 测试验证

### 快速体验流程

1. 页面为单页 `AgentChatPage`：
   - 布局从上到下：日志区域 → 转录列表区域 → 底部居中 Agent 状态 → 控制按钮

2. 启动 Agent：
   - 点击“Start Agent”按钮
   - 按钮文案变为“Starting...”并禁用，应用自动：
     - 生成随机 `channelName`（`channel_flutter_XXXX`）
     - 加入 RTC 频道并登录 RTM
     - 连接成功后自动启动 AI Agent
   - Agent 启动成功后：
     - “Start Agent”按钮隐藏
     - 显示“静音”和“停止”按钮
     - 每次 Start 后自动开麦（录音音量 100）

3. 对话交互：
   - 实时显示 USER 与 AGENT 的转录（同 `turn_id` 的更新会替换而非新增）
   - 静音/取消静音：调整录音信号音量为 0/100
   - 点击“停止”结束会话与清理资源

### 功能验证清单

- ✅ RTC 频道加入成功（查看日志区域）
- ✅ RTM 登录成功（查看日志区域）
- ✅ Agent 启动成功（按钮状态变化，显示静音与停止）
- ✅ 音频传输正常（能听到 AI 回复）
- ✅ 转录功能正常（USER/AGENT 字幕更新合并显示）
- ✅ 静音/取消静音功能正常
- ✅ 停止功能正常（断开连接并清理）

## 项目结构

```
flutter/startup/
├── lib/
│   ├── agent_chat_page.dart           # 单页界面与核心流程（RTC/RTM 直接在此初始化与调用）
│   ├── services/
│   │   ├── app_config.dart            # 读取 assets/env.properties（对齐 KeyCenter）
│   │   ├── agent_starter.dart         # Agent 启停（REST API + 日志脱敏）
│   │   ├── token_generator.dart       # 统一 Token（演示用途，仅开发环境）
│   │   └── transcript_manager.dart    # 字幕解析与按 turn_id 替换
│   └── main.dart
├── assets/
│   ├── env.properties                 # 环境配置（需要创建，不提交到版本控制）
│   └── env.example.properties         # 环境配置示例
├── android/                           # Flutter Android 工程（Gradle 配置）
└── README.md                          # 本文档
```

**主要文件说明**：
- `agent_chat_page.dart`：主界面，包含日志显示、转录列表、底部 Agent 状态与控制按钮；内联 RTC/RTM 关键调用
- `transcript_manager.dart`：解析 RTM 消息（assistant/user.transcription），按 `turn_id` 替换更新
- `agent_starter.dart`：Agent 启停 API 封装，日志脱敏并支持 3xx 重定向处理
- `token_generator.dart`：Token 生成工具（仅用于开发测试，生产环境需使用服务端生成）
- `app_config.dart`：从 `assets/env.properties` 加载配置，未配置时回退 `--dart-define`

## 相关资源

### API 文档链接

- Agora RTC Flutter SDK：https://pub.dev/packages/agora_rtc_engine
- Agora RTM Flutter SDK：https://pub.dev/packages/agora_rtm
- Conversational AI RESTful API 文档：https://doc.shengwang.cn/doc/convoai/restful/landing-page

### 相关 Recipes

- Agora Recipes 主页：https://github.com/AgoraIO-Community
- 其他 Agora 示例项目

### 社区支持

- Agora 开发者社区：https://github.com/AgoraIO-Community
- Stack Overflow：https://stackoverflow.com/questions/tagged/agora

---

如需扩展到更复杂的对话能力，可在此“启动脚手架”的基础上接入业务层的对话模块，并复用 RTC/RTM 连接管理与页面框架。