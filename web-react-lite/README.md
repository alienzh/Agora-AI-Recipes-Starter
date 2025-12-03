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

1. 启动项目后，在入口页面填写以下信息：
   - **App ID**: Agora App ID（必填）
   - **App Certificate**: Agora App Certificate（选填）
   - **频道名称**: 频道名称（必填）

2. 点击"连接对话式AI引擎"按钮开始连接

3. 配置会自动保存到浏览器的 localStorage，下次打开页面时会自动填充

4. 连接成功后会自动进入聊天页面

5. 右侧会显示详细的连接状态日志，包括：
   - RTM Client 初始化状态
   - RTC Engine 初始化状态
   - Token 生成状态
   - 频道加入状态
   - 各种事件回调（onJoinChannelSuccess、onUserJoined、onError 等）

**注意**: `web-react-lite` 版本只启动前端开发服务器，不包含后端 API 代理服务器。Agent 的启动和停止应由后端服务处理。

## 配置说明

`web-react-lite` 版本使用页面输入的方式配置 Agora 参数，无需配置 `.env` 文件。

### 配置项说明

- **App ID**: Agora App ID，用于初始化 RTM 和 RTC 引擎（必填）
- **App Certificate**: Agora App Certificate，用于生成用户 Token（选填）
- **频道名称**: 用于加入的频道名称（必填）

### 配置存储

- 配置会自动保存到浏览器的 localStorage
- 下次打开页面时会自动填充已保存的配置
- 可以随时修改配置，新配置会覆盖旧配置

**注意**: Agent 的启动和停止应由后端服务处理，前端不参与

## 功能说明

此版本实现了以下功能：

1. **RTM 连接**: 初始化 RTM 引擎并登录
2. **RTC 连接**: 初始化 RTC 引擎并加入频道
3. **音频处理**: 创建、发布和订阅音频轨道
4. **ConvoAI 消息订阅**: 订阅并显示对话转录内容
5. **Debug 日志**: 实时显示连接状态和事件日志（显示在右侧）

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
│   │   └── env.js              # 环境变量配置（已弃用，保留用于向后兼容）
│   ├── components/
│   │   ├── MainView.jsx         # 主视图组件（合并了配置和聊天功能）
│   │   └── main-view.css        # 主视图样式
│   ├── conversational-ai-api/  # ConvoAI API 封装
│   ├── utils/
│   │   ├── api.js              # Token 生成 API
│   │   └── configStorage.js    # 配置存储工具（localStorage）
│   ├── App.jsx                 # 主应用组件（包含日志管理和两栏布局）
│   ├── App.css                 # 应用样式（包含两栏布局）
│   ├── main.jsx                # 入口文件
│   └── index.css                # 全局样式
├── .env.example                # 环境变量示例文件（已弃用，配置改为页面输入）
├── index.html                   # HTML 模板
├── vite.config.js              # Vite 配置
└── package.json                # 项目配置
```
