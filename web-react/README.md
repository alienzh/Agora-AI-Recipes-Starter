# Web React

一个基于 React 和 Vite 的前端项目，实现了完整的 RTM、RTC、ConvoAI 连接和 Agent 启动功能。

## 开始使用

### 安装依赖

```bash
npm install
```

### 开发模式

```bash
npm run dev
```

**注意**: 开发模式下会启动前端开发服务器。Agent 的启动和停止通过前端直接调用后端 API 实现。

### 构建生产版本

```bash
npm run build
```

### 预览生产构建

```bash
npm run preview
```

### 使用说明

1. 配置环境变量（见下方"环境变量配置"部分）

2. 启动项目后，在入口页面填写频道名称

3. 点击"连接对话式AI引擎"按钮开始连接

4. 连接成功后会自动进入聊天页面，Agent 会自动启动

5. 右侧会显示详细的连接状态日志，包括：
   - RTM Client 初始化状态
   - RTC Engine 初始化状态
   - Token 生成状态
   - 频道加入状态
   - Agent 启动状态
   - 各种事件回调（onJoinChannelSuccess、onUserJoined、onError 等）

## 环境变量配置

1. 复制 `.env.example` 文件为 `.env`：

```bash
cp .env.example .env
```

2. 在 `.env` 文件中填写相应的配置值：

```
VITE_AG_APP_ID=your_app_id
VITE_AG_APP_CERTIFICATE=your_certificate
VITE_AG_BASIC_AUTH_KEY=your_auth_key
VITE_AG_BASIC_AUTH_SECRET=your_auth_secret
VITE_AG_PIPELINE_ID=your_pipeline_id
```

3. 在代码中使用环境变量：

```javascript
import { env } from "./config/env";

// 使用配置
const appId = env.AG_APP_ID;
```

**注意**: Vite 要求环境变量必须以 `VITE_` 开头才能暴露给客户端代码。

### 配置项说明

- **VITE_AG_APP_ID**: Agora App ID，用于初始化 RTM 和 RTC 引擎（必填）
- **VITE_AG_APP_CERTIFICATE**: Agora App Certificate，用于生成用户 Token（必填）
- **VITE_AG_BASIC_AUTH_KEY**: Basic Auth Key，用于生成 Agent Token（必填）
- **VITE_AG_BASIC_AUTH_SECRET**: Basic Auth Secret，用于生成 Agent Token（必填）
- **VITE_AG_PIPELINE_ID**: Pipeline ID，用于启动 Agent（必填）

## 功能说明

此版本实现了以下完整功能：

1. **RTM 连接**: 初始化 RTM 引擎并登录
2. **RTC 连接**: 初始化 RTC 引擎并加入频道
3. **音频处理**: 创建、发布和订阅音频轨道
4. **ConvoAI 消息订阅**: 订阅并显示对话转录内容
5. **Agent 启动**: 自动生成 Agent Token 并启动 Agent
6. **Agent 停止**: 挂断时自动停止 Agent
7. **Debug 日志**: 实时显示连接状态和事件日志

## 项目结构

```
web-react/
├── src/
│   ├── config/
│   │   └── env.js              # 环境变量配置
│   ├── components/
│   │   ├── MainView.jsx         # 主视图组件（合并了配置和聊天功能）
│   │   ├── entrance-view.css    # 配置视图样式
│   │   └── chat-view.css        # 聊天视图样式
│   ├── conversational-ai-api/   # ConvoAI API 封装
│   ├── utils/
│   │   ├── api.js              # Token 生成 API
│   │   └── AgentManager.js     # Agent 管理工具
│   ├── App.jsx                 # 主应用组件（包含日志管理）
│   ├── App.css                 # 应用样式（包含两栏布局）
│   ├── main.jsx                # 入口文件
│   └── index.css               # 全局样式
├── .env.example                # 环境变量示例文件
├── index.html                  # HTML 模板
├── vite.config.js              # Vite 配置
└── package.json                # 项目配置
```

## 与 web-react-lite 的区别

- **web-react**: 包含完整的 Agent 启动功能，使用 `.env` 文件配置
- **web-react-lite**: 不包含 Agent 启动功能，使用页面输入配置，Agent 由后端服务处理
