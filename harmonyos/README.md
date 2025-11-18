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

3. **配置 Agent 启动方式**：
   
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

### 配置说明

1. **配置 App ID 和 App Certificate**：
   
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
   
   3. 构建项目时，构建脚本会自动读取 `env.json` 并生成配置文件：
      - 构建脚本（`entry/hvigorfile.ts`）会在构建时读取 `harmonyos/env.json`
      - 自动生成 `entry/src/main/ets/common/KeyCenterConfig.ets`
      - 配置会被编译到应用中
   
   **注意**：
   - `appId`：你的 Agora App ID
   - `appCertificate`：你的 App Certificate（可选，用于 Token 生成）
   - `restKey`：REST API Key（直接 API 模式必需，HTTP 服务器模式也需要）
   - `restSecret`：REST API Secret（直接 API 模式必需，HTTP 服务器模式也需要）
   - `pipelineId`：Pipeline ID（直接 API 模式必需，HTTP 服务器模式也需要）
   - URL 切换在 `AgentStarter.ets` 中完成
   - `env.json` 文件已在 `.gitignore` 中，不会被提交到代码仓库
   - 如果 `env.json` 文件不存在或字段缺失，构建时会生成空字符串作为默认值
   - 使用 JSON 格式是 HarmonyOS 推荐的方式
   - 构建时会自动生成 `KeyCenterConfig.ets`，该文件也在 `.gitignore` 中
   
   **⚠️ 安全说明**：
   - 配置会在构建时从 `env.json` 读取并编译到应用中
   - `env.json` 文件已在 `.gitignore` 中，不会被提交到代码仓库
   - 生成的 `KeyCenterConfig.ets` 会被编译到应用中，可以通过反编译查看
   - **生产环境建议**：
     - 使用 HarmonyOS HUKS（通用密钥库）安全存储敏感信息
     - 从安全的后端服务器动态获取凭证
     - 使用加密存储，密钥由用户输入或从安全服务器获取

2. **权限配置**：
   
   确保 `module.json5` 中包含以下权限（已配置）：
   ```json
   {
     "requestPermissions": [
       {
         "name": "ohos.permission.INTERNET"
       },
       {
         "name": "ohos.permission.MICROPHONE"
       },
       {
         "name": "ohos.permission.MODIFY_AUDIO_SETTINGS"
       }
     ]
   }
   ```

## 实现步骤

### 步骤1：基础设置

1. **初始化 RTC Engine**：
   
   在 `RtcManager.ets` 中创建 RTC Engine 实例：
   ```typescript
   import { RtcEngineEx, RtcEngineConfig, IRtcEngineEventHandler } from '@shengwang/rtc-full';
   
   static createRtcEngine(context: Context, appId: string, rtcEventHandler: IRtcEngineEventHandler): RtcEngineEx {
     const config = new RtcEngineConfig();
     config.appId = appId;
     config.context = context;
     config.eventHandler = rtcEventHandler;
     return RtcEngineEx.create(config) as RtcEngineEx;
   }
   ```

2. **配置 ConversationalAI API**：
   
   在 `ConversationViewModel.ets` 中初始化 API：
   ```typescript
   import { ConversationalAIAPIConfig, TranscriptRenderMode, createConversationalAIAPI } from '../convoaiApi/IConversationalAIAPI';
   
   // Create ConversationalAI API
   const apiConfig = new ConversationalAIAPIConfig(
     rtcEngine,
     TranscriptRenderMode.Word,  // or TranscriptRenderMode.Text
     true  // enableLog
   );
   conversationalAIAPI = createConversationalAIAPI(apiConfig);
   
   // Add event handler
   conversationalAIAPI.addHandler(eventHandler);
   ```
   
   **注意**：HarmonyOS 版本的 ConversationalAI API 使用 RTC DataStream 进行消息传递，不需要单独的 RTM Client。

### 步骤2：核心实现

1. **加入频道**：
   
   实现 `joinChannelAndLogin()` 方法，加入 RTC 频道：
   ```typescript
   async joinChannelAndLogin(channelName: string): Promise<void> {
     // Generate token for RTC
     const token = await TokenGenerator.generateTokensAsync(channelName, userId.toString());
     
     // Join RTC channel
     RtcManager.joinChannel(token, channelName, userId);
     
     // Subscribe to messages via ConversationalAI API (uses RTC DataStream internally)
     this.conversationalAIAPI?.subscribeMessage(channelName);
   }
   ```
   
   **注意**：HarmonyOS 版本使用 RTC DataStream 进行消息传递，不需要单独的 RTM 登录。

2. **订阅消息**：
   
   订阅频道消息以接收 AI Agent 的状态和转录（通过 RTC DataStream）：
   ```typescript
   conversationalAIAPI?.subscribeMessage(channelName, (result) => {
     if (result.isSuccess) {
       // Handle subscription success
     }
   });
   ```
   
   **注意**：消息通过 RTC DataStream 传递，在加入频道后会自动接收消息。

3. **注册事件处理器**：
   
   实现 `IConversationalAIAPIEventHandler` 接口，处理各种事件：
   ```typescript
   conversationalAIAPI?.addHandler({
     onTranscript: (transcript: Transcript) => {
       // Update transcript list
       this._transcriptList = [...this._transcriptList, transcript];
       this.notifyTranscriptListChanged();
     },
     
     onStateChange: (event: StateChangeEvent) => {
       // Update agent state
       this._agentState = event.state;
       this.notifyAgentStateChanged();
     },
     
     onError: (error: ModuleError) => {
       // Handle errors
       console.error('ConversationalAIAPI Error:', error);
     }
   });
   ```

4. **实现 UI 状态观察**：
   
   在 `VoiceAssistant.ets` 中观察 Agent 状态和 UI 状态：
   ```typescript
   @State agentState: AgentState | null = null;
   @State uiState: ConversationUiState;
   
   aboutToAppear() {
     // Subscribe to agent state changes
     this.viewModel.subscribeAgentState((state) => {
       this.agentState = state;
       // Agent state is always displayed in info card
       // VoiceWaveView animation is shown when transcript is hidden
     });
     
     // Subscribe to UI state changes (including transcript enabled state)
     this.viewModel.subscribeUiState((state) => {
       this.uiState = state;
       // UI will automatically switch between transcript list and animation based on isTranscriptEnabled
     });
   }
   ```
   
   实现字幕显示/隐藏切换：
   ```typescript
   build() {
     Column() {
       this.buildInfoCard()  // Always show info card at top
       
       // Conditionally show transcript list or agent animation
       if (this.uiState.isTranscriptEnabled) {
         this.buildTranscriptList()  // Show transcript list
       } else {
         this.buildAgentIndicator()  // Show VoiceWaveView animation (only when SPEAKING)
       }
       
       this.buildControlButtons()
     }
   }
   ```
   
   **注意**：
   - 字幕显示时：显示转录列表，Agent 状态在 info card 中显示
   - 字幕隐藏时：显示 VoiceWaveView 动画（仅在 Agent 状态为 SPEAKING 时），Agent 状态仍在 info card 中显示
   - 动画区域与字幕区域完全重叠，不会遮挡头部信息

### 步骤3：测试验证

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
   - 输入频道名称
   - 点击"Start"按钮
   - 应用会自动启动 Agent 并加入频道

3. **验证功能**：
   - ✅ 检查是否成功加入 RTC 频道
   - ✅ 检查是否成功订阅消息（通过 RTC DataStream）
   - ✅ 验证音频传输是否正常
   - ✅ 测试静音/取消静音功能
   - ✅ 验证转录功能是否正常显示
   - ✅ 验证 Agent 说话状态指示器是否正常显示动画
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
└── README.md                                  # 本文档
```

## 重要说明

### ⚠️ 当前状态

本项目是 HarmonyOS 平台的完整实现，包含：
- ✅ 完整的业务逻辑和 UI 实现
- ✅ Agora RTC HarmonyOS SDK 集成
- ✅ Conversational AI API 适配实现（使用 RTC DataStream 进行消息传递）
- ✅ Agent 启动功能（支持本地服务器和 Agora API 两种模式）
- ✅ 权限管理
- ✅ 页面导航
- ✅ 构建时配置生成（从 env.json 自动生成配置）

### 已实现的功能

1. **Agora RTC HarmonyOS SDK 集成**：
   - ✅ 在 `RtcManager.ets` 中实现了 RTC Engine 初始化和管理
   - ✅ 支持加入/离开频道、音频控制等功能

2. **消息传递**：
   - ✅ 通过 RTC DataStream 实现消息传递（在 `ConversationalAIAPIImpl.ets` 中实现）
   - ✅ 支持消息订阅、转录接收等功能
   - ✅ **注意**：HarmonyOS 版本使用 RTC DataStream，不需要单独的 RTM SDK

3. **ConversationalAI API 适配**：
   - ✅ 已实现完整的 ConversationalAI API 适配
   - ✅ 支持转录、状态变化、错误处理等事件
   - ✅ 位置：`entry/src/main/ets/convoaiApi/`

4. **权限管理**：
   - ✅ 在 `PermissionHelper.ets` 中实现了权限请求逻辑
   - ✅ 在 `AgentConfig.ets` 中集成了权限请求

5. **页面导航**：
   - ✅ 实现了从 `AgentConfig` 到 `VoiceAssistant` 的页面导航
   - ✅ 使用 HarmonyOS 的路由 API

6. **UI 功能**：
   - ✅ 实现了字幕显示/隐藏切换功能
   - ✅ 实现了 Agent 状态实时显示（在 info card 中）
   - ✅ 实现了 VoiceWaveView 动画显示（字幕隐藏时，仅在 SPEAKING 状态）
   - ✅ 实现了静音/取消静音功能
   - ✅ 实现了转录列表自动滚动功能

## 扩展功能

### 高级配置

本示例展示了基础的 Conversational AI 集成方式。更多高级功能包括：

- **自定义音频参数**：配置不同的音频场景（标准模式、数字人模式等）
- **自定义转录渲染模式**：支持文本模式和逐词模式
- **发送消息给 AI Agent**：发送文本消息、图片消息，支持优先级控制
- **打断 Agent**：实现打断 AI Agent 的功能
- **消息状态跟踪**：处理消息发送成功/失败的回调
- **事件处理**：处理 Agent 状态变化、错误、指标等事件

### 性能优化

- 使用 `AUDIO_SCENARIO_AI_CLIENT` 场景以获得最佳 AI 对话质量
- 根据网络状况调整音频编码参数
- 及时清理不再使用的 Transcript 数据
- 实现 Token 自动刷新机制
- 处理网络断开重连逻辑

### 最佳实践

- 实现完善的错误处理机制，包括网络错误、Token 过期等
- 使用状态管理统一管理 UI 状态
- 将业务逻辑与 UI 分离，使用 ViewModel 管理状态
- 在加入频道前检查并请求麦克风权限
- 正确管理 RTC Engine 的生命周期
- 在页面销毁时清理资源
- 启用 API 日志以便调试

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

