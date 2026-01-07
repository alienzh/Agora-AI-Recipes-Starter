# Web React Lite

[English Documentation](./README.md) | [中文文档](./README-CN.md)

一个基于 React 和 Vite 的前端项目，专注于 RTM、RTC 和 ConvoAI 连接功能。

这是一个**独立的前端应用**，不需要任何后端服务器。所有功能都在浏览器中运行。

## 开始使用

### 安装依赖

```bash
npm install --legacy-peer-deps
```

### 开发模式

```bash
npm run dev
```

这将启动前端开发服务器。不需要后端服务器。

### 构建生产版本

```bash
npm run build
```

### 预览生产构建

```bash
npm run preview
```

## 使用说明

1. 启动项目后，在入口页面填写以下信息：
   - **App ID**: Agora App ID（必填）
   - **App Certificate**: Agora App Certificate（选填）
   - **Channel Name**: 频道名称（必填）

2. 点击"Connect Conversational AI Engine"按钮开始连接

### 配置说明

- **App ID**: Agora App ID，用于初始化 RTM 和 RTC 引擎（必填）
- **App Certificate**: Agora App Certificate，用于生成用户 Token（选填）
- **Channel Name**: 要加入的频道名称（必填）

## 功能特性

此版本实现了以下功能：

1. **RTM 连接**: 初始化 RTM 引擎并登录
2. **RTC 连接**: 初始化 RTC 引擎并加入频道
3. **音频处理**: 创建、发布和订阅音频轨道
4. **ConvoAI 消息订阅**: 订阅并显示对话转录内容
5. **调试日志**: 实时显示连接状态和事件日志（显示在右侧）

## 工作原理

此应用直接连接到 Agora 的服务：

- **Token 生成**: 当提供 App Certificate 时，使用 Agora 的公共 token 生成服务（`https://service.apprtc.cn/toolbox/v2/token/generate`）
- **RTM/RTC**: 直接连接到 Agora RTM 和 RTC 服务
- **ConvoAI**: 通过 RTM 频道订阅对话式 AI 消息

**注意**: Agent（AI 助手）必须通过 Agora 平台或其他方式单独启动。此前端应用仅处理客户端连接和消息显示。

## 项目结构

```text
web-react-lite/
├── src/
│   ├── components/
│   │   ├── MainView.jsx         # 主视图组件（合并了配置和聊天功能）
│   │   └── main-view.css        # 主视图样式
│   ├── conversational-ai-api/  # ConvoAI API 封装
│   ├── utils/
│   │   ├── api.js              # Token 生成 API
│   │   └── configStorage.js     # 配置存储工具（localStorage）
│   ├── App.jsx                 # 主应用组件（包含日志管理和两栏布局）
│   ├── App.css                 # 应用样式（包含两栏布局）
│   ├── main.jsx                # 入口文件
│   └── index.css               # 全局样式
├── index.html                   # HTML 模板
├── vite.config.js              # Vite 配置
└── package.json                # 项目配置
```

## 技术细节

- **框架**: React 18
- **构建工具**: Vite
- **SDK**:
  - `agora-rtc-sdk-ng`: Agora RTC SDK
  - `agora-rtm`: Agora RTM SDK
- **存储**: 使用 `localStorage` 持久化配置
- **Token 服务**: 使用 Agora 的公共 token 生成服务（不需要后端）

## 注意事项

- 这是一个**纯前端应用** - 不需要后端服务器
- 配置直接在 UI 中输入，并存储在浏览器的 localStorage 中
- Token 生成（如果提供了 App Certificate）使用 Agora 的公共服务
- Agent 必须通过 Agora 平台或其他外部方式单独启动
