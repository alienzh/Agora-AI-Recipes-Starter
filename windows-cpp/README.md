# Windows Agent Starter

## 功能概述

### 解决的问题

本示例项目展示了如何在 Windows 应用中集成 Agora Conversational AI（对话式 AI）功能，实现与 AI 语音助手的实时对话交互。主要解决以下问题：

- **实时语音交互**：通过 Agora RTC SDK 实现与 AI 代理的实时音频通信
- **消息传递**：通过 Agora RTM SDK 实现与 AI 代理的消息交互和状态同步
- **实时转录**：支持实时显示用户和 AI 代理的对话转录内容，包括转录状态（进行中、完成、中断等）
- **状态管理**：统一管理连接状态、Agent 启动状态、静音状态、转录状态等 UI 状态
- **自动流程**：自动完成频道加入、RTM 登录、Agent 启动等流程
- **统一界面**：所有功能（日志、状态、转录、控制按钮）集成在同一个页面

### 适用场景

- 智能客服系统：构建基于 AI 的实时语音客服应用
- 语音助手应用：开发桌面语音助手功能
- 实时语音转录：实时显示用户和 AI 代理的对话转录内容
- 语音交互游戏：开发需要语音交互的游戏应用
- 教育培训：构建语音交互式教学应用

### 前置条件

- Windows 10 或更高版本
- Visual Studio 2019 或更高版本（需安装 C++ 桌面开发工作负载）
- vcpkg 包管理器
- Agora 开发者账号 [Console](https://console.shengwang.cn/)
- 已在 Agora 控制台开通 **实时消息 RTM** 功能（必需）
- 已创建 Agora 项目并获取 App ID 和 App Certificate
- 已创建 Conversational AI Pipeline 并获取 Pipeline ID [AI Studio](https://console-conversationai.shengwang.cn/product/ConversationAI/studio)

## 快速开始

### 依赖安装

1. **克隆项目**：
```bash
git clone https://github.com/AgoraIO-Community/Agora-AI-Recipes-Starter.git
cd Agora-AI-Recipes-Starter/windows-cpp
```

2. **安装 vcpkg 依赖**：
```powershell
# 进入项目目录
cd VoiceAgent

# 运行依赖安装脚本
.\install_dependencies.ps1
```

3. **配置 Agora Key**：

   复制 `KeyCenter.h.example` 文件为 `KeyCenter.h`：
   ```powershell
   copy KeyCenter.h.example VoiceAgent\src\KeyCenter.h
   ```

   编辑 `VoiceAgent\src\KeyCenter.h` 文件，填入你的实际配置值：
   ```cpp
   struct KeyCenter {
       static constexpr const char* AGORA_APP_ID = "your_app_id";
       static constexpr const char* AGORA_APP_CERTIFICATE = "your_app_certificate";
       static constexpr const char* REST_KEY = "your_rest_key";
       static constexpr const char* REST_SECRET = "your_rest_secret";
       static constexpr const char* PIPELINE_ID = "your_pipeline_id";
   };
   ```

   **配置项说明**：
   - `AGORA_APP_ID`：你的 Agora App ID（必需）
   - `AGORA_APP_CERTIFICATE`：你的 App Certificate（可选，用于 Token 生成）
   - `REST_KEY`：REST API Key（必需，用于启动 Agent）
   - `REST_SECRET`：REST API Secret（必需，用于启动 Agent）
   - `PIPELINE_ID`：Pipeline ID（必需，用于启动 Agent）

   **获取方式**：
   - 体验声网对话式 AI 引擎前，你需要先在声网控制台创建项目并开通对话式 AI 引擎服务，获取 App ID、客户 ID 和客户密钥等调用 RESTful API 时所需的参数。[开通服务](https://doc.shengwang.cn/doc/convoai/restful/get-started/enable-service)
   - Pipeline ID：在 [AI Studio](https://console-conversationai.shengwang.cn/product/ConversationAI/studio) 中创建 Pipeline 后获取

   **注意**：
   - `KeyCenter.h` 文件包含敏感信息，不会被提交到版本控制系统。请确保不要将你的实际凭证提交到代码仓库。
   - 每次启动时会自动生成随机的 channelName，格式为 `channel_windows_XXXX`（XXXX 为 4 位随机数字），无需手动配置。
   - ⚠️ **重要**：`TokenGenerator.cpp` 中的 Token 生成功能仅用于演示和开发测试，**生产环境必须使用自己的服务端生成 Token**。

4. **打开 Visual Studio 解决方案**：
```powershell
# 使用 Visual Studio 打开解决方案
start VoiceAgent.sln
```

5. **配置 Agent 启动方式**：
   
   **方式一：直接调用 Agora RESTful API**（仅用于快速体验，不推荐用于生产）
   
   默认配置，无需额外设置。Windows 应用直接调用 Agora RESTful API 启动 Agent，方便开发者快速体验功能。
   
   **使用前提**：
   - 确保已正确配置 `KeyCenter.h` 文件中的相关 key。
   
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

1. **Agent Chat 页面**：
   - 在 Visual Studio 中按 `F5` 运行应用
   - 页面布局从左到右依次为：
     - **消息区域**：显示 USER 和 AGENT 的对话转录内容
     - **Agent 状态**：显示在消息列表右下角，显示当前 Agent 的状态
     - **日志区域**：右侧固定宽度区域，显示 Agent 启动相关的状态消息
   - **控制按钮**：底部初始显示"Start Agent"按钮
   
2. **启动 Agent**：
   - 点击"Start Agent"按钮
   - 按钮禁用，应用自动：
     - 生成随机 channelName（格式：`channel_windows_XXXX`）
     - 加入 RTC 频道并登录 RTM
     - 连接成功后自动启动 AI Agent
   - Agent 启动成功后：
     - "Start Agent"按钮隐藏
     - 显示"Mute"和"Stop Agent"按钮
     - 可以开始与 AI Agent 对话

3. **对话交互**：
   - 实时显示 USER 和 AGENT 的转录内容
   - 支持静音/取消静音功能
   - 点击"Stop Agent"按钮结束对话并断开连接

### 功能验证清单

- ✅ RTC 频道加入成功（查看日志区域的状态消息）
- ✅ RTM 登录成功（查看日志区域的状态消息）
- ✅ Agent 启动成功（按钮状态变化，显示 Mute 和 Stop Agent 按钮）
- ✅ 音频传输正常（能够听到 AI 回复）
- ✅ 转录功能正常（显示 USER 和 AGENT 的转录内容及状态）
- ✅ 静音/取消静音功能正常
- ✅ 停止功能正常（断开连接，按钮恢复为 Start Agent）

## 项目结构

```
windows-cpp/
├── VoiceAgent/
│   ├── src/
│   │   ├── ui/                           # UI 相关代码
│   │   │   ├── MainFrm.h                        # 主界面头文件
│   │   │   └── MainFrm.cpp                      # 主界面（包含 RTC 和 RTM 逻辑）
│   │   ├── api/                          # API 相关代码
│   │   │   ├── AgentManager.h/cpp               # Agent 启动/停止 API
│   │   │   ├── TokenGenerator.h/cpp             # Token 生成（仅用于测试）
│   │   │   └── HttpClient.h/cpp                 # HTTP 请求封装
│   │   ├── ConversationalAIAPI/          # 实时字幕组件
│   │   ├── general/                      # 通用代码
│   │   │   ├── pch.h/cpp                        # 预编译头
│   │   │   └── VoiceAgent.h/cpp                 # 应用入口
│   │   ├── tools/                        # 工具类
│   │   │   ├── Logger.h/cpp                     # 日志工具
│   │   │   └── StringUtils.h                    # 字符串工具
│   │   └── KeyCenter.h                   # 配置中心（需要创建，不提交到版本控制）
│   ├── project/
│   │   └── VoiceAgent.vcxproj            # Visual Studio 项目文件
│   ├── resources/                        # 资源文件
│   ├── rtcLib/                           # Agora RTC SDK
│   └── rtmLib/                           # Agora RTM SDK
├── VoiceAgent.sln                        # Visual Studio 解决方案
├── KeyCenter.h.example                   # 配置文件示例
└── README.md                             # 本文档
```

**主要文件说明**：
- `MainFrm.cpp`：主界面，包含日志显示、Agent 状态、转录列表和控制按钮，直接管理 RTC/RTM SDK
- `AgentManager.cpp`：Agent 启动 API 封装，支持直接调用 Agora API 或通过业务后台中转
- `TokenGenerator.cpp`：Token 生成工具（仅用于开发测试，生产环境需使用服务端生成）

## 相关资源

### API 文档链接

- [Agora RTC Windows SDK 文档](https://doc.shengwang.cn/doc/rtc/windows/landing-page)
- [Agora RTM Windows SDK 文档](https://doc.shengwang.cn/doc/rtm2/windows/landing-page)
- [Conversational AI RESTful API 文档](https://doc.shengwang.cn/doc/convoai/restful/landing-page)

### 相关 Recipes

- [Agora Recipes 主页](https://github.com/AgoraIO-Community)
- 其他 Agora 示例项目

### 社区支持

- [Agora 开发者社区](https://github.com/AgoraIO-Community)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/agora)

---

