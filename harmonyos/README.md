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

3**配置 Agent 启动方式**：
   
   **方式一：直接调用 Agora RESTful API**（仅用于快速体验，不推荐用于生产）
   
   默认配置，无需额外设置。HarmonyOS 应用直接调用 Agora RESTful API 启动 Agent，方便开发者快速体验功能。
   
   **使用前提**：
   - 确保已正确配置 `env.json` 文件中的相关 key。
   
   **适用场景**：
   - 快速体验和功能验证
   - 无需启动额外服务器，开箱即用
   
   ⚠️ **重要说明**：
   - 此方式**仅用于快速体验和开发测试**，**不推荐用于生产环境**
   - 生产环境**必须**使用方式二，通过自己的业务后台中转请求
   - 直接在前端调用 Agora RESTful API 会暴露 REST Key 和 REST Secret，存在安全风险
   
   **方式二：通过业务后台服务器中转**（生产环境必需）
   
   真实业务场景中，**不应该**直接在前端请求 Agora RESTful API，而应该通过自己的业务后台服务器中转。
   
   **核心要求**：
   
   - **REST Key 和 REST Secret 必须放在服务端**，绝对不能暴露在客户端代码中
   - 客户端只请求自己的业务后台接口，业务后台再调用 Agora RESTful API
   - 业务后台负责保管和管理 REST Key、REST Secret 等敏感信息
   
   **实现方式**：
   
   1. **参考实现**：`../server-python/agora_http_server.py` 展示了如何在服务端调用 Agora RESTful API
      ```bash
      cd ../server-python
      python agora_http_server.py
      ```
      - Python 服务器从环境变量或配置文件读取 REST Key 和 REST Secret
      - 服务端使用这些密钥调用 Agora API，客户端无需知道这些密钥
   
   2. **在自己的业务后台实现**：
      - 参考 Python 服务器的实现逻辑，在你的业务后台（Java、Node.js、Python 等）实现 Agent 启动接口
      - 将 REST Key 和 REST Secret 存储在服务端环境变量或配置文件中
      - 客户端请求你的业务后台接口，业务后台使用 REST Key 和 REST Secret 调用 Agora API
   
   3. **在 `api/AgentStarter.ets` 中配置本地 Python 服务器的 IP 地址**（用于本地体验测试）：
   ```typescript
   export class AgentStarter {
     // Switch between local server and Agora API by commenting/uncommenting the lines below
   //    private static readonly AGORA_API_BASE_URL = 'https://api.sd-rtn.com/cn/api/conversational-ai-agent/v2/projects';
     private static readonly AGORA_API_BASE_URL = 'http://<your-computer-ip>:8080';  // Local Python server IP (for local testing)
   }
   ```
   
   **说明**：
   - `<your-computer-ip>` 替换为你运行 Python 服务器的电脑 IP 地址
   - 查找电脑 IP：
     - macOS/Linux: `ifconfig en0 | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}'`
     - Windows: `ipconfig`（查找 IPv4 地址）
   - 确保 HarmonyOS 设备和电脑在同一局域网内
   
   **为什么必须使用业务后台中转**：
   - **安全性**：REST Key 和 REST Secret 绝对不能暴露在客户端代码中，必须由服务端保管
   - **业务逻辑**：可以在后台实现权限验证、计费、日志记录等业务逻辑
   - **稳定性**：统一管理 API 调用，便于监控和错误处理
   - **灵活性**：可以添加缓存、限流、重试等机制
   - **合规性**：符合安全最佳实践，避免敏感信息泄露
   
   **注意**：
   - 生产环境必须使用自己的服务端生成 Token，不要使用 `TokenGenerator`（详见代码中的警告）

## 测试验证

### 快速体验流程

1. **Agent Home 页面**（`AgentHome`）：
   - 运行应用，进入 Agent Home 页面
   - 点击"Start Agent"按钮
   - 按钮文本变为"Starting..."，应用自动：
     - 生成随机 channelName（格式：`channel_harmonyos_XXXX`）
     - 加入 RTC 频道并订阅消息（通过 RTC DataStream）
     - 连接成功后自动启动 AI Agent
   - Agent 启动成功后，自动跳转到 Agent Living 页面

2. **Agent Living 页面**（`AgentLiving`）：
   - 显示 Channel、UserId、AgentUid 信息
   - 显示 Agent 状态
   - 实时显示 USER 和 AGENT 的转录内容
   - 可以开始与 AI Agent 对话
   - 支持静音/取消静音功能
   - 点击挂断按钮返回 Agent Home 页面

### 功能验证清单

- ✅ RTC 频道加入成功（查看状态消息）
- ✅ 消息订阅成功（通过 RTC DataStream，查看状态消息）
- ✅ Agent 启动成功（页面自动跳转）
- ✅ 音频传输正常（能够听到 AI 回复）
- ✅ 转录功能正常（显示 USER 和 AGENT 的转录内容及状态）
- ✅ 静音/取消静音功能正常
- ✅ 挂断功能正常（返回 Agent Home 页面）

## 项目结构

```
harmonyos/
├── entry/
│   └── src/main/ets/
│       ├── api/                   # API 相关代码
│       ├── common/                # 通用工具类
│       ├── convoaiApi/            # Conversational AI API
│       ├── rtc/                   # RTC 管理
│       ├── pages/                 # 页面
│       └── entryability/          # Ability
├── env.json                       # 环境配置（需要创建）
├── env.example.json               # 环境配置示例
└── README.md                      # 本文档
```

## 重要说明

### HarmonyOS 版本特性

- **消息传递方式**：HarmonyOS 版本使用 RTC DataStream 进行消息传递，**不需要**单独开通 RTM 功能
- **配置方式**：使用 JSON 格式配置文件（`env.json`），构建时自动生成配置
- **构建时配置**：构建脚本（`entry/hvigorfile.ts`）会在构建时读取 `harmonyos/env.json` 并自动生成 `entry/src/main/ets/common/KeyCenterConfig.ets`
- **字幕渲染模式**：由于 HarmonyOS RTC SDK 能力限制，**仅支持 Text 模式渲染字幕**，不支持 Word 模式（逐词渲染）
- **Token 续期**：自动处理 RTC token 续期，当 token 即将过期时自动更新

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