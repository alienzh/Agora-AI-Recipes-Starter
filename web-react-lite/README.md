# Web React Lite

一个基于 React 和 Vite 的前端项目，专注于 RTM、RTC 和 ConvoAI 的连接功能。

**注意**: 此版本不包含 Agent 启动功能，Agent 的启动和停止应由后端服务处理。

## 开始使用

### 安装依赖

```bash
npm install
```

### 开发模式

```bash
npm run dev
```

**注意**: `web-react-lite` 版本只启动前端开发服务器，不包含后端 API 代理服务器。Agent 的启动和停止应由后端服务处理。

### 构建生产版本

```bash
npm run build
```

### 预览生产构建

```bash
npm run preview
```

### 使用说明

启动后，填入频道号，点击开始，等待 Agent 加入。

## 环境变量配置

`web-react-lite` 版本只负责 RTM、RTC 和 ConvoAI 的连接，不包含 Agent 启动功能，因此只需要以下配置：

1. 复制 `.env.example` 文件为 `.env`：

```bash
cp .env.example .env
```

2. 在 `.env` 文件中填写相应的配置值：

```
VITE_AG_APP_ID=your_app_id
VITE_AG_APP_CERTIFICATE=your_certificate
```

**配置说明**：

- `VITE_AG_APP_ID`: Agora App ID，用于初始化 RTM 和 RTC 引擎
- `VITE_AG_APP_CERTIFICATE`: Agora App Certificate，用于生成用户 Token

3. 在代码中使用环境变量：

```javascript
import { env } from "./config/env";

// 使用配置
const appId = env.AG_APP_ID;
const certificate = env.AG_APP_CERTIFICATE;
```

**注意**:

- Vite 要求环境变量必须以 `VITE_` 开头才能暴露给客户端代码
- Agent 的启动和停止应由后端服务处理，前端不参与

## 功能说明

此版本实现了以下功能：

1. **RTM 连接**: 初始化 RTM 引擎并登录
2. **RTC 连接**: 初始化 RTC 引擎并加入频道
3. **音频处理**: 创建、发布和订阅音频轨道
4. **ConvoAI 消息订阅**: 订阅并显示对话转录内容

**不包含的功能**：

- Agent 启动（由后端处理）
- Agent Token 生成（由后端处理）
- Agent 停止（由后端处理）

## 如何启动 Agent

`web-react-lite` 版本不包含 Agent 启动功能，需要通过后端服务来启动 Agent。

### 使用 Python 后端服务

我们提供了一个 Python 后端服务示例，具体使用方法请参考：

📁 [server-python/README.md](../server-python/README.md)

该服务提供了 Agent 启动和停止的 API 接口，前端可以通过调用这些接口来控制 Agent。

### 其他后端服务

你也可以使用其他语言（如 Node.js、Java 等）实现后端服务，只要提供以下 API 接口即可：

- `POST /api/agent` - 启动 Agent
- `POST /api/agent/stop` - 停止 Agent

具体的 API 参数和返回值格式，请参考 `server-python` 中的实现。

## 项目结构

```
web-react-lite/
├── src/
│   ├── config/
│   │   └── env.js       # 环境变量配置（仅 RTM/RTC）
│   ├── components/
│   │   ├── ChatView.jsx # 聊天视图组件（RTM/RTC/ConvoAI）
│   │   └── EntranceView.jsx # 入口视图组件
│   ├── conversational-ai-api/ # ConvoAI API 封装
│   ├── utils/
│   │   └── api.js       # Token 生成 API
│   ├── App.jsx          # 主应用组件
│   ├── main.jsx         # 入口文件
│   └── index.css        # 全局样式
├── .env.example         # 环境变量示例文件（仅包含 RTM/RTC 配置）
├── index.html           # HTML 模板
├── vite.config.js       # Vite 配置
└── package.json         # 项目配置
```
