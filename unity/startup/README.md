# Unity Agent Starter

## 功能概述

### 解决的问题

在 Unity 应用中集成 Agora Conversational AI（对话式 AI），实现与 AI 语音助手的实时对话：
- 实时语音交互（RTC）
- 消息传递与转录展示（RTM）
- 单页 UI：顶部日志、中部字幕、底部 Agent 状态与控制按钮

### 适用场景
- 智能客服、语音助手、实时转录、语音交互游戏、教育培训

### 前置条件
- 已开通 Agora 服务，获取 App ID/App Certificate
- 已开通 RTM 服务
- 已创建 Conversational AI Pipeline 并获得 Pipeline ID

## 快速开始

### 1. 导入 Agora SDK

本项目依赖 Agora Unity SDK，但 SDK 文件不包含在仓库中，需要手动导入：

1. **下载 Agora Unity SDK**
   - [Agora Video SDK for Unity](https://docs.agora.io/cn/video-calling/get-started/get-started-sdk?platform=unity)
   - [Agora RTM SDK for Unity](https://docs.agora.io/cn/signaling/get-started/get-started-sdk?platform=unity)

2. **导入到项目**
   - 将 `Agora-RTC-Plugin` 文件夹放入 `Assets/` 目录
   - 将 `Agora-RTM-Plugin` 文件夹放入 `Assets/` 目录

3. **验证导入**
   - 确保 `Assets/Agora-RTC-Plugin/` 和 `Assets/Agora-RTM-Plugin/` 存在
   - Unity 会自动识别并编译这些插件

> **注意**：这两个 SDK 文件夹已在 `.gitignore` 中，不会被提交到版本控制

### 2. 配置环境变量

将配置写入 `Assets/Resources/env.txt`（复制示例）：
```bash
cp Assets/Resources/env.example.txt Assets/Resources/env.txt
```
编辑内容：
```properties
agora.appId=your_app_id
agora.appCertificate=your_app_certificate
agora.restKey=your_rest_key
agora.restSecret=your_rest_secret
agora.pipelineId=your_pipeline_id
```

> **注意**：`env.txt` 包含敏感信息，已在 `.gitignore` 中忽略，不会被提交到版本控制

### 3. 打开示例场景

双击打开 `Assets/Scenes/SampleScene.unity`，场景中已配置好 UI 和脚本绑定。

### 4. 运行测试

运行场景，点击 "启动 Agent" 按钮开始对话。

### 配置项说明
- `agora.appId`：Agora App ID（必需）
- `agora.appCertificate`：App Certificate（用于生成 Token，仅开发场景）
- `agora.restKey/restSecret`：用于 REST 调用启动/停止 Agent（必需）
- `agora.pipelineId`：Pipeline ID（必需）

### 重要说明（安全）
- 示例中 Token 生成与 REST 直连仅用于演示/开发，生产必须由服务端生成 Token 并代调用 REST API。

## 测试验证

1. 启动流程：
   - 随机生成 `channelName`
   - RTC 初始化并入房
   - RTM 创建、登录并订阅频道
   - 启动 Agent（REST）

2. 对话展示：
   - `assistant.transcription` 与 `user.transcription` 显示在字幕列表，同一 `turn_id` 的更新会替换而非新增
   - 静音/取消静音：调整录音信号音量 0/100

3. 停止：
   - 退订与登出 RTM、离开 RTC、REST 停止 Agent、清理 UI 状态

### 功能验证清单
- ✅ RTC 入房成功（日志显示）
- ✅ RTM 登录成功（日志显示）
- ✅ Agent 启动成功（日志显示）
- ✅ 转录展示正常（USER/AGENT）
- ✅ 静音/取消静音正常
- ✅ 停止清理正常

## 文件结构

```
unity/startup/
├── Assets/
│   ├── Agora-RTC-Plugin/                # Agora RTC SDK（需手动导入，已在 .gitignore 中）
│   ├── Agora-RTM-Plugin/                # Agora RTM SDK（需手动导入，已在 .gitignore 中）
│   ├── Resources/
│   │   ├── env.txt                      # 环境配置（需要创建，已在 .gitignore 中）
│   │   └── env.example.txt              # 环境配置示例
│   ├── Scenes/                          # Unity 场景文件
│   └── Scripts/Startup/
│       ├── EnvConfig.cs                 # 加载配置（Resources/env）
│       ├── TokenGenerator.cs            # 统一 Token（仅开发）
│       ├── AgentStarter.cs              # Agent 启停（REST + 3xx 重定向）
│       ├── AgentStartup.cs              # 主启动脚本（UI 绑定与流程控制）
│       └── TranscriptManager.cs         # 转录解析与替换（turn_id）
└── README.md
```

> 说明：`AgentStartup` 示例脚本需根据你导入的 Agora Unity RTC/RTM SDK 接口进行绑定与调用；静音/开麦建议使用 `AdjustRecordingSignalVolume(0/100)`。

## 相关资源
- [Agora Unity RTC SDK 文档](https://docs.agora.io/cn/video-calling/overview/product-overview?platform=unity)
- [Agora Unity RTM SDK 文档](https://docs.agora.io/cn/signaling/overview/product-overview?platform=unity)
- [Conversational AI RESTful API 文档](https://docs.agora.io/cn/conversational-ai/develop/restful-api)
- Agora 社区与示例仓库
