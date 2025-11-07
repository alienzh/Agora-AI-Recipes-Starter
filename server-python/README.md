# Agora Agent Starter Server

用于启动和停止 Agora 对话式 AI Agent 的 Python 脚本，通过 REST API 实现。

## 前置条件

- Python 3.6 或更高版本
- 网络连接（用于调用 Agora REST API）
- Agora 开发者账号 [Console](https://console.shengwang.cn/)
- 已创建 Agora 项目并获取 App ID 和 App Certificate
- 已创建 Conversational AI Pipeline 并获取 Pipeline ID [AI Studio](https://console-conversationai.shengwang.cn/product/ConversationAI/studio)
- 已获取 REST API 的 Basic Auth 凭证（Key 和 Secret）

## 快速开始

### 安装依赖

```bash
cd server-python
pip install -r requirements.txt
```

依赖包：
- `requests>=2.31.0` - HTTP 请求库
- `python-dotenv>=1.0.0` - 用于加载 `.env.local` 文件

### 配置

推荐使用 `.env.local` 文件来配置默认值：

1. **复制示例文件**：
```bash
cp .env.example .env.local
```

2. **编辑 `.env.local` 文件**，填入你的实际配置值：
```bash
# Agora App ID (Project ID)
AGORA_APP_ID=your_app_id_here

# Agora App Certificate (可选，用于 Token 生成)
AGORA_APP_CERT=your_app_cert_here

# Basic Auth 凭证（分为两个字段）
AGORA_BASIC_KEY=your_key_here
AGORA_BASIC_SECRET=your_secret_here

# Pipeline ID (用于启动 Agent)
AGORA_PIPELINE_ID=your_pipeline_id_here
```

## 使用方法

### 启动 Agent

如果已配置 `.env.local` 文件，可以直接运行：

```bash
python agora_starter_server.py start
```

或使用命令行参数覆盖：

```bash
python agora_starter_server.py start \
  --appid YOUR_APP_ID \
  --appcert "YOUR_APP_CERTIFICATE" \
  --basic-key YOUR_REST_KEY \
  --basic-secret YOUR_REST_SECRET \
  --pipeline YOUR_PIPELINE_ID \
  --channelName "my_channel"
```

**常用示例**：

```bash
# 使用自定义频道
python agora_starter_server.py start --channelName "my_custom_channel"
```

### 停止 Agent

```bash
python agora_starter_server.py stop --agent-id "agent_id_here"
```

或使用命令行参数覆盖：

```bash
python agora_starter_server.py stop \
  --appid YOUR_APP_ID \
  --basic-key YOUR_REST_KEY \
  --basic-secret YOUR_REST_SECRET \
  --agent-id "agent_id_here"
```

### 获取帮助

```bash
python agora_starter_server.py --help
python agora_starter_server.py start --help
python agora_starter_server.py stop --help
```

## 参数说明

### Start 命令参数

- `--appid`: Agora App ID (Project ID) [可选，默认值：从环境变量或 `.env.local` 文件读取]
- `--appcert`: App Certificate [可选，默认值：从环境变量或 `.env.local` 文件读取]
- `--basic-key`: Basic Auth Key [可选，默认值：从 `.env.local` 文件读取 (`AGORA_BASIC_KEY`)]
- `--basic-secret`: Basic Auth Secret [可选，默认值：从 `.env.local` 文件读取 (`AGORA_BASIC_SECRET`)]
- `--pipeline`: Pipeline ID [可选，默认值：从环境变量或 `.env.local` 文件读取]
- `--channelName`: 频道名称 [可选，默认值："default_android_channel"]

### Stop 命令参数

- `--appid`: Agora App ID (Project ID) [可选，默认值：从环境变量或 `.env.local` 文件读取]
- `--basic-key`: Basic Auth Key [可选，默认值：从 `.env.local` 文件读取 (`AGORA_BASIC_KEY`)]
- `--basic-secret`: Basic Auth Secret [可选，默认值：从 `.env.local` 文件读取 (`AGORA_BASIC_SECRET`)]
- `--agent-id`: 要停止的 Agent ID [必需]

**注意**：
- Token 会在启动 Agent 前自动生成（默认：RTC 和 RTM token）
- Agent 名称将使用 channelName 的值
- Agent RTC UID 固定为 1009527

## 虚拟环境（可选）

如果你希望使用虚拟环境来隔离项目依赖：

```bash
# 创建虚拟环境
python3 -m venv venv

# 激活虚拟环境
source venv/bin/activate  # macOS/Linux
# 或
venv\Scripts\activate  # Windows

# 安装依赖
pip install -r requirements.txt

# 退出虚拟环境
deactivate
```

## 相关资源

- [Agora Conversational AI RESTful API 文档](https://doc.shengwang.cn/doc/convoai/restful/landing-page)
- [Agora 控制台](https://console.shengwang.cn/)
- [Agora AI Studio](https://console-conversationai.shengwang.cn/product/ConversationAI/studio)
