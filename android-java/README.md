# Android Agent Starter

## 功能概述

### 解决的问题

本示例项目展示了如何在 Android 应用中集成 Agora Conversational AI（对话式 AI）功能，实现与 AI 语音助手的实时对话交互。主要解决以下问题：

- **实时语音交互**：通过 Agora RTC SDK 实现与 AI 代理的实时音频通信
- **消息传递**：通过 Agora RTM SDK 实现与 AI 代理的消息交互和状态同步
- **实时转录**：支持实时显示用户和 AI 代理的对话转录内容，包括转录状态（进行中、完成、中断等）
- **状态管理**：统一管理连接状态、Agent 启动状态、静音状态、转录状态等 UI 状态
- **自动流程**：自动完成频道加入、RTM 登录、Agent 启动、页面跳转等流程

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
   cd Agora-AI-Recipes-Starter/android-java
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
         - 每次启动时会自动生成随机的 channelName，格式为 `channel_java_XXXX`（XXXX 为 4 位随机数字），无需手动配置。
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
    
       3. **在 `AgentStarter.java` 中配置本地 Python 服务器的 IP 地址**（用于本地体验测试）：
      ```java
      // Option 1: Agora RESTful API (Default)
      // private static final String AGORA_API_BASE_URL = "https://api.sd-rtn.com/cn/api/conversational-ai-agent/v2/projects";
   
      // Option 2: Local Python Server
      private static final String AGORA_API_BASE_URL = "http://<your-computer-ip>:8080"; 
      ```

      **说明**：
      - `<your-computer-ip>` 替换为你运行 Python 服务器的电脑 IP 地址
      - 查找电脑 IP：
          - macOS/Linux: `ifconfig en0 | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}'`
          - Windows: `ipconfig`（查找 IPv4 地址）
      - 确保 Android 设备和电脑在同一局域网内

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

1. **运行应用**：在 Android Studio 中运行 `android-java` 项目。
2. **AgentHomeFragment**：
   - 应用启动后进入首页。
   - 点击 "Start Agent" 按钮。按钮逻辑：先加入频道并登录 RTM，成功后自动调用 API 启动 Agent。
   - 观察按钮状态变为 "Starting..."。
3. **自动跳转**：
   - 当 Agent 成功启动（收到 `agentStarted` 状态）且 RTC/RTM 连接就绪后，App 会自动跳转到通话页面。
4. **AgentLivingFragment**：
   - 这是一个纯展示页面，负责显示字幕（Transcript）和 Agent 状态。
   - 你可以开始说话，观察字幕实时上屏。
   - 点击 "Hang Up" 结束通话并返回首页。

### 功能验证清单

- [ ] **连接**：App 能成功加入 RTC 频道并登录 RTM。
- [ ] **启动**：点击 Start 后能自动启动 Agent 并跳转页面。
- [ ] **对话**：对着手机说话，能听到 Agent 的回应。
- [ ] **字幕**：说话时能看到实时的文字转录（User 和 Agent 的内容）。
- [ ] **打断**：在 Agent 说话时插话，Agent 能被成功打断并回应新的内容。
- [ ] **挂断**：点击挂断能正确停止 Agent 并释放资源。

## 项目结构

```
android-java/
├── app/
│   ├── src/main/
│   │   ├── java/io/agora/convoai/example/startup/
│   │   │   ├── ui/                    # UI 相关代码
│   │   │   │   └── common/            # 通用 UI 组件
│   │   │   ├── rtc/                   # RTC 管理器
│   │   │   ├── tools/                 # 工具类 (Token, AgentStarter)
│   │   │   └── net/                   # 网络相关
│   │   ├── res/                       # 资源文件
│   │   └── convoaiApi/                # Conversational AI API (Kotlin)
│   └── build.gradle
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