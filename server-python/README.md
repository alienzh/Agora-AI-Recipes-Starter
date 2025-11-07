# Agora Agent Starter Server

用于启动和停止 Agora 对话式 AI Agent 的 Python 脚本，通过 REST API 实现。

## 功能概述

本服务器脚本用于启动和停止 Agora Conversational AI（对话式 AI）Agent，通过调用 Agora REST API 实现 Agent 的生命周期管理。

### 前置条件

- Python 3.6 或更高版本
- 网络连接（用于调用 Agora REST API）
- Agora 开发者账号 [Console](https://console.shengwang.cn/)
- 已创建 Agora 项目并获取 App ID 和 App Certificate
- 已创建 Conversational AI Pipeline 并获取 Pipeline ID [AI Studio](https://console-conversationai.shengwang.cn/product/ConversationAI/studio)
- 已获取 REST API 的 Basic Auth 凭证（Key 和 Secret）

## 配置说明

你可以使用 `.env.local` 文件（推荐）或在脚本中直接配置默认值。

### 使用 .env.local 文件（推荐）

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

3. **`.env.local` 文件会在运行脚本时自动加载**。请确保将 `.env.local` 添加到 `.gitignore` 中，以避免提交敏感信息。

### 配置优先级

配置优先级如下：
1. 命令行参数（最高优先级）
2. 环境变量或 `.env.local` 文件
3. 脚本中的默认值（最低优先级）

如果这些值在 `.env.local` 文件或环境变量中已设置，你可以在运行命令时不提供这些参数。你仍然可以使用命令行参数覆盖它们。

## 快速开始

### 环境要求

- **Python 版本**：Python 3.6 或更高版本
- **网络连接**：用于调用 Agora REST API

### 安装依赖

在 `server-python` 目录下执行以下命令安装所有依赖：

```bash
cd server-python
pip install -r requirements.txt
```

这将安装以下依赖：
- `requests>=2.31.0` - HTTP 请求库
- `python-dotenv>=1.0.0` - 用于加载 `.env.local` 文件

### 配置环境变量（推荐）

```bash
# 复制示例文件
cp .env.example .env.local

# 编辑 .env.local 文件，填入你的配置信息
# 或者直接设置环境变量
export AGORA_APP_ID="your_app_id"
export AGORA_APP_CERT="your_app_cert"
export AGORA_BASIC_KEY="your_key"
export AGORA_BASIC_SECRET="your_secret"
export AGORA_PIPELINE_ID="your_pipeline_id"
```

## 虚拟环境（可选）

如果你希望使用虚拟环境来隔离项目依赖，可以按照以下步骤操作：

### 创建虚拟环境

```bash
# 进入项目目录
cd server-python

# 创建虚拟环境
python3 -m venv venv
```

### 激活虚拟环境

**macOS/Linux**：
```bash
source venv/bin/activate
```

**Windows**：
```bash
venv\Scripts\activate
```

### 在虚拟环境中安装依赖

激活虚拟环境后，执行：
```bash
pip install -r requirements.txt
```

### 退出虚拟环境

使用完毕后，可以退出虚拟环境：
```bash
deactivate
```

**注意**：虚拟环境是可选的。如果你不使用虚拟环境，可以直接在系统 Python 环境中安装依赖。

### 配置说明

推荐使用 `.env.local` 文件来配置默认的 App ID、App Certificate、Basic Auth 和 Pipeline ID，这样就不需要在每次运行时都传递这些参数，同时也能避免在代码中硬编码敏感信息。

## 使用方法

### 启动 Agent

如果你已在脚本中配置了默认值，可以直接运行：

```bash
python agora_starter_server.py start
```

或者使用命令行参数覆盖：

```bash
python agora_starter_server.py start \
  --appid YOUR_APP_ID \
  --basicauth "YOUR_REST_KEY:YOUR_REST_SECRET" \
  --pipeline YOUR_PIPELINE_ID \
  --appcert "YOUR_APP_CERTIFICATE" \
  --channelName "my_channel"
```

### 停止 Agent

如果你已在脚本中配置了默认值：

```bash
python agora_starter_server.py stop --agent-id "agent_id_here"
```

或者使用命令行参数覆盖：

```bash
python agora_starter_server.py stop \
  --appid YOUR_APP_ID \
  --basicauth "YOUR_REST_KEY:YOUR_REST_SECRET" \
  --agent-id "agent_id_here"
```

### 获取帮助

```bash
# 通用帮助
python agora_starter_server.py --help

# Start 命令帮助
python agora_starter_server.py start --help

# Stop 命令帮助
python agora_starter_server.py stop --help
```

## 参数说明

### 通用参数（适用于所有命令）

- `--appid`: Agora App ID (Project ID) [可选，默认值：从脚本配置 `DEFAULT_APP_ID`]
- `--channelName`: 频道名称 [可选，默认值："default_android_channel"]
- `--appcert`: App Certificate [可选，默认值：从脚本配置 `DEFAULT_APP_CERT`]

### Start 命令参数

- `--basicauth`: Basic Auth 凭证，格式为 "key:secret" [可选，默认值：从 `.env.local` 文件读取 (`AGORA_BASIC_KEY` 和 `AGORA_BASIC_SECRET`)]
- `--pipeline`: Pipeline ID [可选，默认值：从脚本配置 `DEFAULT_PIPELINE_ID`]
- `--expire`: Token 过期时间（秒）[可选，默认值：86400（24小时）]
- `--remote-rtc-uids`: 远程 RTC UIDs 列表 [可选，默认值："*"]

**注意：** 
- 你可以在 `.env.local` 文件中设置默认值 (`AGORA_APP_ID`, `AGORA_APP_CERT`, `AGORA_BASIC_KEY`, `AGORA_BASIC_SECRET`, `AGORA_PIPELINE_ID`) 以避免在命令行中传递这些参数
- Token 会在启动 Agent 前自动生成（默认：RTC 和 RTM token）
- Agent 名称将使用 channelName 的值
- Agent RTC UID 固定为 1009527

### Stop 命令参数

- `--basicauth`: Basic Auth 凭证，格式为 "key:secret" [可选，默认值：从 `.env.local` 文件读取 (`AGORA_BASIC_KEY` 和 `AGORA_BASIC_SECRET`)]
- `--agent-id`: 要停止的 Agent ID [必需]

## 使用示例

### 启动 Agent（使用脚本配置）

如果你已在脚本中设置了默认值：

```bash
python agora_starter_server.py start
```

### 使用自定义频道启动 Agent

```bash
python agora_starter_server.py start --channelName "my_custom_channel"
```

### 使用自定义 Token 过期时间启动 Agent

```bash
python agora_starter_server.py start --channelName "my_channel" --expire 3600
```

### 启动 Agent（覆盖所有参数）

```bash
python agora_starter_server.py start \
  --appid YOUR_APP_ID \
  --basicauth "YOUR_REST_KEY:YOUR_REST_SECRET" \
  --pipeline YOUR_PIPELINE_ID \
  --appcert "YOUR_APP_CERTIFICATE" \
  --channelName "my_channel"
```

### 停止 Agent

如果你已在脚本中设置了默认值：

```bash
python agora_starter_server.py stop --agent-id "agent_id_from_start_response"
```

或者使用命令行参数覆盖：

```bash
python agora_starter_server.py stop \
  --appid YOUR_APP_ID \
  --basicauth "YOUR_REST_KEY:YOUR_REST_SECRET" \
  --agent-id "agent_id_from_start_response"
```

### 启动 AI Agent（用于测试 Android 应用）

```bash
cd server-python
python agora_starter_server.py start --channelName "test_channel"
```

**注意**：如果使用虚拟环境，请先激活虚拟环境：
```bash
source venv/bin/activate  # macOS/Linux
# 或
venv\Scripts\activate  # Windows
```

启动后，Agent 会加入指定的频道，Android 应用可以使用相同的频道名称加入并开始对话。

## 注意事项

- 脚本需要 Python 3.6 或更高版本
- 虚拟环境是可选的。如果使用虚拟环境，请在运行脚本前先激活它
- 虚拟环境设置说明请参考上方的"虚拟环境（可选）"章节

## 相关资源

- [Agora Conversational AI RESTful API 文档](https://doc.shengwang.cn/doc/convoai/restful/landing-page)
- [Agora 控制台](https://console.shengwang.cn/)
- [Agora AI Studio](https://console-conversationai.shengwang.cn/product/ConversationAI/studio)

