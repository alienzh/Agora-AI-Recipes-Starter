# Agora Conversational AI - HarmonyOS 示例

## 功能概述

### 解决的问题

本示例项目展示了如何在 HarmonyOS 应用中集成 Agora Conversational AI（对话式 AI）功能，实现与 AI 语音助手的实时对话交互。主要解决以下问题：

- **实时语音交互**：通过 Agora RTC SDK 实现与 AI 代理的实时音频通信
- **消息传递**：通过 RTC DataStream 实现与 AI 代理的消息交互和状态同步
- **实时转录**：支持实时显示用户和 AI 代理的对话转录内容
- **字幕显示/隐藏切换**：支持动态切换字幕显示和隐藏，隐藏时显示 Agent 说话动画
- **Agent 说话状态指示器**：通过动画效果实时显示 AI Agent 的说话状态（仅在 SPEAKING 状态时显示）
- **状态管理**：统一管理连接状态、静音状态、转录状态、Agent 状态等 UI 状态

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
- **注意**：HarmonyOS 版本使用 RTC DataStream 进行消息传递，不需要单独开通 RTM 功能
- 已创建 Conversational AI Pipeline 并获取 Pipeline ID [AI Studio](https://console-conversationai.shengwang.cn/product/ConversationAI/studio)
- 已配置 Agent 启动服务器（参考 [server-python](../Agora-AI-Recipes-Starter/server-python/README.md)）

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
   - 等待依赖同步完成

3. **配置 Agora Key**：
   
   1. 复制 `env.example.json` 文件为 `env.json`：
   ```bash
   cp env.example.json env.json
   ```
   
   2. 编辑 `env.json` 文件，填入你的实际配置值：
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
   - `appCertificate`：你的 App Certificate（必需，用于 Token 生成）
   - `restKey`：REST API Key（必需，用于启动 Agent）
   - `restSecret`：REST API Secret（必需，用于启动 Agent）
   - `pipelineId`：Pipeline ID（必需，用于启动 Agent）
   
   **获取方式**：
   - App ID 和 App Certificate：在 [Agora Console](https://console.shengwang.cn/) 中创建项目后获取
   - REST Key 和 REST Secret：在 Agora Console 的项目设置中获取
   - Pipeline ID：在 [AI Studio](https://console-conversationai.shengwang.cn/product/ConversationAI/studio) 中创建 Pipeline 后获取
   
   **注意**：
   - `env.json` 文件包含敏感信息，已在 `.gitignore` 中，不会被提交到版本控制系统。请确保不要将你的实际凭证提交到代码仓库。
   - 构建项目时，构建脚本会自动读取 `env.json` 并生成配置文件：
     - 构建脚本（`entry/hvigorfile.ts`）会在构建时读取 `harmonyos/env.json`
     - 自动生成 `entry/src/main/ets/common/KeyCenterConfig.ets`
     - 配置会被编译到应用中
   - 如果 `env.json` 文件不存在或字段缺失，构建时会生成空字符串作为默认值
   - 每次启动时会自动生成随机的 channelName，无需手动配置。
   
   **⚠️ 安全说明**：
   - 配置会在构建时从 `env.json` 读取并编译到应用中
   - 生成的 `KeyCenterConfig.ets` 会被编译到应用中，可以通过反编译查看
   - **生产环境建议**：
     - 使用 HarmonyOS HUKS（通用密钥库）安全存储敏感信息
     - 从安全的后端服务器动态获取凭证
     - 使用加密存储，密钥由用户输入或从安全服务器获取

4. **配置 Agent 启动方式**：
   
   有两种方式启动 Agent，在 `AgentStarter.ets` 中直接切换：
   
   **方式一：本地 HTTP 服务器模式**（推荐用于开发测试）
   
   1. 启动 Python HTTP 服务器：
   ```bash
   cd ../server-python
   python agora_http_server.py
   ```
   
   服务器默认运行在 `http://localhost:8080`。
   
   2. 在 `AgentStarter.ets` 中配置本地服务器 URL：
   ```typescript
   export class AgentStarter {
     // Switch between local server and Agora API by commenting/uncommenting the lines below
   //  private static readonly AGORA_API_BASE_URL = 'https://api.sd-rtn.com/cn/api/conversational-ai-agent/v2/projects';
     private static readonly AGORA_API_BASE_URL = 'http://<你的电脑IP>:8080';  // Local server
   }
   ```
   
   **IP 地址说明**：
   - **HarmonyOS 模拟器**：使用 `http://<你的电脑IP>:8080`（查找电脑 IP：`ifconfig en0 | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}'` 或 `ipconfig`）
   - **真机**：使用 `http://<你的电脑IP>:8080`（确保设备和电脑在同一局域网内）
   
   **方式二：直接调用 Agora API 模式**（推荐用于生产环境）
   
   不需要启动 Python 服务器，HarmonyOS 应用直接调用 Agora API。
   
   在 `AgentStarter.ets` 中配置：
   ```typescript
   export class AgentStarter {
     // Switch between local server and Agora API by commenting/uncommenting the lines below
     private static readonly AGORA_API_BASE_URL = 'https://api.sd-rtn.com/cn/api/conversational-ai-agent/v2/projects';
   //  private static readonly AGORA_API_BASE_URL = 'http://<你的电脑IP>:8080';  // Local server
   }
   ```
   
   **注意**：URL 切换在 `AgentStarter.ets` 中完成，不再使用 `env.json` 中的 `agentServerUrl` 配置。

## 测试验证

1. **启动 Python HTTP 服务器**（如果使用 HTTP 服务器模式）：
   
   ```bash
   cd ../server-python
   python agora_http_server.py
   ```
   
   服务器启动后，HarmonyOS 应用会自动通过 `AgentStarter.ets` 中配置的地址调用服务器来启动 Agent。
   
   **注意**：
   - 如果使用虚拟环境，请先激活虚拟环境：
     ```bash
     source venv/bin/activate  # macOS/Linux
     # 或
     venv\Scripts\activate  # Windows
     ```
   - 确保 HarmonyOS 设备和电脑在同一局域网内（真机）或使用正确的电脑 IP 地址
   - 如果端口被占用，可以修改服务器端口和 HarmonyOS 代码中的端口号

2. **运行 HarmonyOS 应用**：
   - 在 DevEco Studio 中运行应用
   - 在 Agent Configuration 页面查看配置信息（App ID 和 Pipeline ID）
   - 点击"Start"按钮开始连接
   - 应用会自动生成随机的 channelName
   - 自动加入 RTC 频道并订阅消息（通过 RTC DataStream）
   - 连接成功后自动导航到 Voice Assistant 页面
   - 自动启动 AI Agent（通过 RESTful API）
   - Agent 启动成功后即可开始对话

3. **验证功能**：
   - ✅ 检查是否成功加入 RTC 频道
   - ✅ 检查是否成功订阅消息（通过 RTC DataStream）
   - ✅ 检查 Agent 是否成功启动（查看状态消息）
   - ✅ 验证音频传输是否正常
   - ✅ 测试静音/取消静音功能
   - ✅ 验证转录功能是否正常显示
   - ✅ 验证 Agent 说话状态指示器（VoiceWaveView）是否正常显示动画
   - ✅ 测试与 AI Agent 的对话交互

## 项目结构

```
harmonyos/
├── entry/
│   └── src/
│       └── main/
│           ├── ets/
│           │   ├── common/                    # 通用工具类
│           │   │   ├── AgentStarter.ets        # Agent 启动器（支持本地服务器和 Agora API）
│           │   │   ├── KeyCenter.ets          # 配置中心（使用构建时生成的配置）
│           │   │   ├── KeyCenterConfig.ets    # 自动生成的配置文件（由 hvigorfile.ts 生成）
│           │   │   ├── PermissionHelper.ets   # 权限助手
│           │   │   └── TokenGenerator.ets     # Token 生成器
│           │   ├── convoaiApi/                # Conversational AI API
│           │   │   ├── ConversationalAIAPIImpl.ets  # API 实现
│           │   │   ├── ConversationalAIUtils.ets    # API 工具类
│           │   │   ├── IConversationalAIAPI.ets     # API 接口定义
│           │   │   ├── MessageParser.ets            # 消息解析器
│           │   │   └── TranscriptController.ets     # 转录控制器
│           │   ├── rtc/                       # RTC 管理
│           │   │   └── RtcManager.ets         # RTC 管理器
│           │   ├── viewmodel/                 # 视图模型
│           │   │   └── ConversationViewModel.ets # 对话视图模型
│           │   ├── pages/                     # 页面
│           │   │   ├── common/                 # 页面通用组件
│           │   │   │   ├── TranscriptDataSource.ets # 转录数据源
│           │   │   │   └── VoiceWaveView.ets        # 语音波形视图
│           │   │   ├── Index.ets              # 入口页面
│           │   │   ├── AgentConfig.ets        # 配置页面
│           │   │   └── VoiceAssistant.ets     # 语音助手页面
│           │   ├── entryability/              # Ability
│           │   │   └── EntryAbility.ets
│           │   └── entrybackupability/         # Backup Ability
│           │       └── EntryBackupAbility.ets
│           ├── module.json5                   # 模块配置
│           └── resources/                     # 资源文件
├── env.json                                    # 环境配置（需要创建）
├── env.example.json                            # 环境配置示例
└── README.md                                   # 本文档
```

## 重要说明

### HarmonyOS 版本特性

- **消息传递方式**：HarmonyOS 版本使用 RTC DataStream 进行消息传递，**不需要**单独开通 RTM 功能
- **配置方式**：使用 JSON 格式配置文件（`env.json`），构建时自动生成配置
- **构建时配置**：构建脚本（`entry/hvigorfile.ts`）会在构建时读取 `harmonyos/env.json` 并自动生成 `entry/src/main/ets/common/KeyCenterConfig.ets`
- **字幕渲染模式**：由于 HarmonyOS RTC SDK 能力限制，**仅支持 Text 模式渲染字幕**，不支持 Word 模式（逐词渲染）

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

**注意**：
- HarmonyOS 版本使用 RTC DataStream 进行消息传递，**不需要**单独开通 RTM 功能
- 配置会在构建时从 `env.json` 读取并编译到应用中，确保构建前已正确配置 `env.json`
- 每次启动时会自动生成随机的 channelName，无需手动配置

