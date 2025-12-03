# Agora Conversational AI - React Native 示例

## 功能概述

### 解决的问题

本示例项目展示了如何在 React Native 应用中集成 Agora Conversational AI（对话式 AI）功能，实现与 AI 语音助手的实时对话交互。主要解决以下问题：

- **实时语音交互**：通过 Agora RTC SDK 实现与 AI 代理的实时音频通信
- **消息传递**：通过 RTC DataStream 实现与 AI 代理的消息交互和状态同步
- **实时转录**：支持实时显示用户和 AI 代理的对话转录内容，包括转录状态（进行中、完成、中断等）
- **状态管理**：统一管理连接状态、Agent 启动状态、静音状态、转录状态等 UI 状态
- **自动流程**：自动完成频道加入、DataStream 创建、Agent 启动等流程

### 适用场景

- 智能客服系统：构建基于 AI 的实时语音客服应用
- 语音助手应用：开发类似 Siri、小爱同学的语音助手功能
- 实时语音转录：实时显示用户和 AI 代理的对话转录内容
- 语音交互游戏：开发需要语音交互的游戏应用
- 教育培训：构建语音交互式教学应用

### 前置条件

- React Native 开发环境（Node.js >= 20.0.0）
- React Native CLI 或 Expo CLI
- Agora 开发者账号 [Console](https://console.shengwang.cn/)
- 已创建 Agora 项目并获取 App ID 和 App Certificate
- 已创建 Conversational AI Pipeline 并获取 Pipeline ID [AI Studio](https://console-conversationai.shengwang.cn/product/ConversationAI/studio)

## 快速开始

### 环境要求

- **开发环境**：
  - Node.js >= 20.0.0
  - React Native CLI 或 Expo CLI
  - Android Studio（Android 开发）
  - Xcode（iOS 开发，仅 macOS）

- **运行环境**：
  - Android 设备或模拟器（API Level 26 或更高）
  - iOS 设备或模拟器（iOS 13.0 或更高）
  - 支持音频录制和播放的设备

### 依赖安装

1. **克隆项目**：
```bash
git clone https://github.com/alienzh/Agora-AI-Recipes-Starter.git
cd Agora-AI-Recipes-Starter/reactnative
```

2. **安装依赖**：
```bash
npm install
# 或
yarn install
```

3. **配置环境变量**：
   
   复制 `.env.example` 文件为 `.env`：
   ```bash
   cp .env.example .env
   ```
   
   编辑 `.env` 文件，填入你的实际配置值：
   ```env
   AGORA_APP_ID=your_app_id_here
   AGORA_APP_CERTIFICATE=your_app_certificate_here
   AGORA_REST_KEY=your_rest_key_here
   AGORA_REST_SECRET=your_rest_secret_here
   AGORA_PIPELINE_ID=your_pipeline_id_here
   ```
   
   **配置项说明**：
   - `AGORA_APP_ID`：你的 Agora App ID（必需）
   - `AGORA_APP_CERTIFICATE`：你的 App Certificate（可选，用于 Token 生成）
   - `AGORA_REST_KEY`：REST API Key（必需，用于启动 Agent）
   - `AGORA_REST_SECRET`：REST API Secret（必需，用于启动 Agent）
   - `AGORA_PIPELINE_ID`：Pipeline ID（必需，用于启动 Agent）
   
   **获取方式**：
   - 体验声网对话式 AI 引擎前，你需要先在声网控制台创建项目并开通对话式 AI 引擎服务，获取 App ID、客户 ID 和客户密钥等调用 RESTful API 时所需的参数。[开通服务](https://doc.shengwang.cn/doc/convoai/restful/get-started/enable-service)
   - Pipeline ID：在 [AI Studio](https://console-conversationai.shengwang.cn/product/ConversationAI/studio) 中创建 Pipeline 后获取
   
   **配置生成机制**：
   - 项目使用构建时配置生成机制，在编译时读取 `.env` 文件并生成 `src/utils/KeyCenterConfig.ts`
   - 运行 `npm start`、`npm run android` 或 `npm run ios` 时会自动运行 `npm run generate-config` 生成配置文件
   - 也可以手动运行 `npm run generate-config` 来生成配置文件
   - 如果 `.env` 文件不存在或字段缺失，会生成空字符串作为默认值
   - **文件结构**：
     - `KeyCenterConfig.ts`：自动生成的配置文件，包含敏感信息，**不会被提交到 git**（已在 `.gitignore` 中配置）
     - `KeyCenter.ts`：公开接口文件，通过 getter 访问 KeyCenterConfig，**可以提交到 git**
   
   **注意**：
   - `.env` 文件包含敏感信息，不会被提交到版本控制系统。请确保不要将你的实际凭证提交到代码仓库。
   - `src/utils/KeyCenterConfig.ts` 是自动生成的文件，**包含敏感信息，不会被提交到 git**（已在 `.gitignore` 中配置）
   - 不要手动编辑 `src/utils/KeyCenterConfig.ts`，修改配置请编辑 `.env` 文件后重新运行 `npm run generate-config`
   - `src/utils/KeyCenter.ts` 是公开接口文件，可以提交到 git，它只是访问 KeyCenterConfig 的接口
   - 每次启动时会自动生成随机的 channelName，格式为 `channel_rn_XXXX`（XXXX 为 4 位随机数字），无需手动配置。
   - ⚠️ **重要**：`TokenGenerator.ts` 中的 Token 生成功能仅用于演示和开发测试，**生产环境必须使用自己的服务端生成 Token**。代码中已添加详细警告说明。

4. **iOS 依赖安装**（仅 iOS 开发需要）：
```bash
cd ios
pod install
cd ..
```

5. **配置 Agent 启动方式**：
   
   默认配置，无需额外设置。React Native 应用直接调用 Agora RESTful API 启动 Agent，方便开发者快速体验功能。
   
   **使用前提**：
   - 确保已正确配置 `.env` 文件中的相关 key。
   
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

## 运行项目

### Android

```bash
npm run android
# 或
yarn android
```

### iOS

```bash
npm run ios
# 或
yarn ios
```

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
   - 按钮文本变为 "连接中..."，应用自动：
     - 生成随机 channelName（格式：`channel_rn_XXXX`）
     - 加入 RTC 频道并创建 DataStream
     - 连接成功后自动启动 AI Agent
   - Agent 启动成功后：
     - "Start Agent" 按钮隐藏
     - 显示 "静音" 和 "停止 Agent" 按钮

3. **与 Agent 对话**：
   - 实时显示 USER 和 AGENT 的转录内容
   - AGENT 消息左对齐，USER 消息右对齐
   - 转录区域底部显示当前 Agent 状态（IDLE、SILENT、LISTENING、THINKING、SPEAKING）
   - 支持静音/取消静音功能（点击静音按钮，按钮文字和图标会变化，但背景色保持不变）
   - 点击 "停止 Agent" 按钮直接结束对话并清理资源（无确认弹框）

### 功能验证清单

- ✅ RTC 引擎初始化成功（查看日志区域的状态消息）
- ✅ RTC 频道加入成功（查看日志区域的状态消息）
- ✅ DataStream 创建成功（查看日志区域的状态消息）
- ✅ Agent 启动成功（按钮从 "Start Agent" 变为 "静音" 和 "停止 Agent"）
- ✅ 音频传输正常（能够听到 AI 回复）
- ✅ 转录功能正常（显示 USER 和 AGENT 的转录内容及状态）
- ✅ Agent 状态显示正常（转录区域底部显示当前状态）
- ✅ 静音/取消静音功能正常（点击静音按钮）
- ✅ 停止功能正常（点击 "停止 Agent" 按钮，清理资源并重置状态）

## 项目结构

```
reactnative/
├── src/
│   ├── api/                    # API 层
│   │   ├── AgentStarter.ts     # Agent 启动 API
│   │   └── TokenGenerator.ts   # Token 生成（仅用于开发测试）
│   ├── stores/                 # 状态管理
│   │   └── AgentChatStore.ts   # Agent Chat 状态管理（包含 RTC 和 DataStream 管理）
│   ├── components/             # UI 组件
│   │   ├── AgentChatScreen.tsx # 主页面
│   │   ├── LogView.tsx         # 日志显示
│   │   ├── TranscriptList.tsx  # 转录列表
│   │   └── ControlButtons.tsx  # 控制按钮
│   ├── utils/                  # 工具类
│   │   ├── KeyCenter.ts        # 配置中心
│   │   ├── PermissionHelper.ts # 权限处理
│   │   ├── ChannelNameGenerator.ts # Channel 名称生成
│   │   └── MessageParser.ts   # 消息解析（已实现完整逻辑）
│   └── types/                  # 类型定义
│       └── index.ts
├── .env                        # 环境配置（需要创建）
├── .env.example                # 环境配置示例
└── README.md                   # 本文档
```

### 核心文件说明

- **`src/components/AgentChatScreen.tsx`**：主页面，采用单页面架构，包含：
  - 日志显示区域（顶部）
  - 转录列表和 Agent 状态（中间）
  - 控制按钮（底部：Start/Mute/Stop）
  
- **`src/stores/AgentChatStore.ts`**：业务逻辑管理，负责：
  - RTC 引擎初始化和频道管理
  - DataStream 创建和消息监听
  - Agent 启动和停止
  - 状态管理（连接状态、静音状态、日志等）
  - 转录数据管理

- **`src/api/AgentStarter.ts`**：Agent 启动 API 封装，支持：
  - 直接调用 Agora RESTful API（开发测试）
  - 通过业务后台服务器中转（生产环境）

- **`src/utils/MessageParser.ts`**：消息解析工具类（已实现）
  - 解析 RTC DataStream 消息
  - 处理分片消息合并（支持多部分消息自动合并）
  - Base64 解码和 JSON 解析
  - 消息过期清理机制（5 分钟）
  - 错误处理和日志记录
  - **参考实现**：参考 HarmonyOS 版本的 `MessageParser.ets` 实现

## 重要说明

### React Native 版本特性

- **单页面架构**：采用单页面设计，所有功能（日志、状态、转录、控制）集中在一个页面，简化用户体验
- **状态管理**：使用 Zustand 进行状态管理，统一管理连接状态、Agent 状态、转录数据等
- **消息传递方式**：React Native 版本使用 RTC DataStream 进行消息传递，**不需要**单独开通 RTM 功能
- **配置方式**：使用 `.env` 文件管理环境变量，通过编译时脚本生成 `KeyCenterConfig.ts`（不依赖 `react-native-config`）
- **Token 生成**：开发环境使用客户端 TokenGenerator，生产环境必须使用服务端生成
- **UI 布局**：
  - 日志区域：显示 Agent 启动相关的状态日志（无时间戳，直接展示），自动滚动到底部
  - 转录区域：AGENT 消息左对齐，USER 消息右对齐，底部显示 Agent 状态（IDLE、SILENT、LISTENING、THINKING、SPEAKING）
  - 控制按钮：初始显示 "Start Agent"，启动成功后显示 "静音" 和 "停止 Agent"
  - 静音按钮：点击后文字和图标会变化（🎤 静音 / 🔇 取消静音）
  - 停止按钮：点击后直接执行停止操作，无确认弹框

## 常见问题

### iOS 相关问题

#### CocoaPods 安装问题

如果遇到 `pod: command not found` 错误：

1. 确保已安装 CocoaPods：
   ```bash
   sudo gem install cocoapods
   ```

2. 如果使用 Homebrew 管理的 Ruby：
   ```bash
   gem install cocoapods
   ```

3. 确保 gem bin 目录在 PATH 中：
   ```bash
   export PATH="$HOME/.gem/ruby/$(ruby -e 'puts RUBY_VERSION')/bin:$PATH"
   ```

#### Xcode 路径问题

如果遇到 `xcode-select: error: tool 'xcodebuild' requires Xcode` 错误：

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

### Android 相关问题

#### 权限问题

确保在 `AndroidManifest.xml` 中添加了必要的权限：
- `android.permission.RECORD_AUDIO`
- `android.permission.INTERNET`

### 通用问题

#### Token 生成失败

- 检查 `.env` 文件中的 `AGORA_APP_CERTIFICATE` 是否正确
- 确保 App Certificate 与 App ID 匹配

#### Agent 启动失败

- 检查 `.env` 文件中的 `AGORA_REST_KEY`、`AGORA_REST_SECRET`、`AGORA_PIPELINE_ID` 是否正确
- 确保已开通 Conversational AI 服务
- 查看日志区域的具体错误信息

## 相关资源

### API 文档链接

- [Agora RTC React Native SDK 文档](https://doc.shengwang.cn/doc/rtc/react-native/landing-page)
- [Agora RTC React Native SDK GitHub](https://github.com/AgoraIO-Extensions/react-native-agora)
- [Conversational AI RESTful API 文档](https://doc.shengwang.cn/doc/convoai/restful/landing-page)

### 相关 Recipes

- [Agora Recipes 主页](https://github.com/AgoraIO-Community)

### 社区支持

- [Agora 开发者社区](https://github.com/AgoraIO-Community)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/agora)

---
