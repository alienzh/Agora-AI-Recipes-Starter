# Agora Agent Starter Server

Python script to start and stop Agora conversational AI agents via REST API.

## 功能概述

本服务器脚本用于启动和停止 Agora Conversational AI（对话式 AI）Agent，通过调用 Agora REST API 实现 Agent 的生命周期管理。

### 前置条件

- Python 3.6 或更高版本
- 网络连接（用于调用 Agora REST API）
- Agora 开发者账号 [Console](https://console.shengwang.cn/)
- 已创建 Agora 项目并获取 App ID 和 App Certificate
- 已创建 Conversational AI Pipeline 并获取 Pipeline ID [AI Studio](https://console-conversationai.shengwang.cn/product/ConversationAI/studio)
- 已获取 REST API 的 Basic Auth 凭证（Key 和 Secret）

## Configuration

You can configure default values using a `.env` file (recommended) or directly in the script.

### Using .env.local file (Recommended)

**Note**: You need to install `python-dotenv` package first:
```bash
pip install python-dotenv
```

1. **Copy the example file**:
```bash
cp .env.example .env.local
```

2. **Edit `.env.local` file** and fill in your actual values:
```bash
# Agora App ID (Project ID)
AGORA_APP_ID=your_app_id_here

# Agora App Certificate (optional, for token generation)
AGORA_APP_CERT=your_app_cert_here

# Basic Auth credentials (split into two fields)
AGORA_BASIC_KEY=your_key_here
AGORA_BASIC_SECRET=your_secret_here

# Pipeline ID (for starting agents)
AGORA_PIPELINE_ID=your_pipeline_id_here
```

3. **The `.env.local` file is automatically loaded** when you run the script. Make sure to add `.env.local` to `.gitignore` to avoid committing sensitive information.

### Configuration Priority

The configuration priority is:
1. Command line arguments (highest priority)
2. Environment variables or `.env.local` file
3. Default values in script (lowest priority)

If these values are set in `.env.local` file or environment variables, you can run commands without providing these parameters. You can still override them using command line arguments.

## 快速开始

### 环境要求

- **Python 版本**：Python 3.6 或更高版本
- **网络连接**：用于调用 Agora REST API

### 一键安装依赖

在 `server-python` 目录下执行以下命令安装所有依赖：

**macOS/Linux 用户**：
```bash
cd server-python && python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt
```

**Windows 用户**：
```bash
cd server-python && python3 -m venv venv && venv\Scripts\activate && pip install -r requirements.txt
```

这将自动完成以下步骤：
1. 创建虚拟环境 `venv`
2. 激活虚拟环境
3. 安装所有依赖（包括 `requests` 和 `python-dotenv`）

**注意**：安装完成后，虚拟环境会保持激活状态。下次使用时，只需激活虚拟环境：
```bash
# macOS/Linux
source venv/bin/activate

# Windows
venv\Scripts\activate
```

### 依赖安装（详细步骤）

**快速安装（推荐）**：

```bash
# 进入项目目录
cd server-python

# 创建虚拟环境（如果还没有）
python3 -m venv venv

# 激活虚拟环境
# On macOS/Linux:
source venv/bin/activate
# On Windows:
# venv\Scripts\activate

# 安装所有依赖（包括 python-dotenv）
pip install -r requirements.txt
```

或者，如果你想一次性执行所有步骤：

```bash
cd server-python && \
python3 -m venv venv && \
source venv/bin/activate && \
pip install -r requirements.txt
```

**详细步骤**：

1. **克隆项目**（如果尚未克隆）：
```bash
cd server-python
```

2. **创建虚拟环境**：
```bash
python3 -m venv venv
```

3. **激活虚拟环境**：
```bash
# On macOS/Linux
source venv/bin/activate

# On Windows
venv\Scripts\activate
```

4. **安装依赖**：
```bash
pip install -r requirements.txt
```

这将安装以下依赖：
- `requests>=2.31.0` - HTTP 请求库
- `python-dotenv>=1.0.0` - 用于加载 `.env.local` 文件

5. **配置环境变量**（推荐）：
```bash
# 复制示例文件
cp .env.example .env.local

# 编辑 .env.local 文件，填入你的配置信息
# 或者直接设置环境变量
export AGORA_APP_ID="your_app_id"
export AGORA_BASIC_KEY="your_key"
export AGORA_BASIC_SECRET="your_secret"
export AGORA_PIPELINE_ID="your_pipeline_id"
```

**注意**：使用 `.env.local` 文件需要先安装 `python-dotenv`：
```bash
pip install python-dotenv
```

### 配置说明

推荐使用 `.env.local` 文件来配置默认的 App ID、App Certificate、Basic Auth 和 Pipeline ID，这样就不需要在每次运行时都传递这些参数，同时也能避免在代码中硬编码敏感信息。

## Usage

### Activate Virtual Environment

Before running the script, activate the virtual environment:

```bash
source venv/bin/activate
```

### Start an Agent

If you have configured default values in the script, you can simply run:

```bash
python agora_starter_server.py start
```

Or override with command line arguments:

```bash
python agora_starter_server.py start \
  --appid YOUR_APP_ID \
  --basicauth "YOUR_REST_KEY:YOUR_REST_SECRET" \
  --pipeline YOUR_PIPELINE_ID \
  --appcert "YOUR_APP_CERTIFICATE" \
  --channelName "my_channel"
```

### Stop an Agent

If you have configured default values in the script:

```bash
python agora_starter_server.py stop --agent-id "agent_id_here"
```

Or override with command line arguments:

```bash
python agora_starter_server.py stop \
  --appid YOUR_APP_ID \
  --basicauth "YOUR_REST_KEY:YOUR_REST_SECRET" \
  --agent-id "agent_id_here"
```

### Get Help

```bash
# General help
python agora_starter_server.py --help

# Start command help
python agora_starter_server.py start --help

# Stop command help
python agora_starter_server.py stop --help
```

## Parameters

### Common Parameters (for all commands)

- `--appid`: Agora App ID (Project ID) [optional, default: from script config `DEFAULT_APP_ID`]
- `--channelName`: Channel name [optional, default: "default_android_channel"]
- `--appcert`: App certificate [optional, default: from script config `DEFAULT_APP_CERT`]

### Start Command Parameters

- `--basicauth`: Basic auth credentials in format "key:secret" [optional, default: from `.env.local` file (`AGORA_BASIC_KEY` and `AGORA_BASIC_SECRET`)]
- `--pipeline`: Pipeline ID [optional, default: from script config `DEFAULT_PIPELINE_ID`]
- `--expire`: Token expiration time in seconds [optional, default: 86400 (24 hours)]
- `--remote-rtc-uids`: Remote RTC UIDs list [optional, default: "*"]

**Note:** 
- You can set default values in `.env.local` file (`AGORA_APP_ID`, `AGORA_APP_CERT`, `AGORA_BASIC_KEY`, `AGORA_BASIC_SECRET`, `AGORA_PIPELINE_ID`) to avoid passing them as arguments
- Token will be generated automatically before starting the agent (default: RTC and RTM token)
- Agent name will use the channelName value
- Agent RTC UID is fixed to 1009527

### Stop Command Parameters

- `--basicauth`: Basic auth credentials in format "key:secret" [optional, default: from `.env.local` file (`AGORA_BASIC_KEY` and `AGORA_BASIC_SECRET`)]
- `--agent-id`: Agent ID to stop [required]

## Examples

### Start agent (using script config)

If you have set default values in the script:

```bash
python agora_starter_server.py start
```

### Start agent with custom channel

```bash
python agora_starter_server.py start --channelName "my_custom_channel"
```

### Start agent with custom token expiration

```bash
python agora_starter_server.py start --channelName "my_channel" --expire 3600
```

### Start agent (override all parameters)

```bash
python agora_starter_server.py start \
  --appid YOUR_APP_ID \
  --basicauth "YOUR_REST_KEY:YOUR_REST_SECRET" \
  --pipeline YOUR_PIPELINE_ID \
  --appcert "YOUR_APP_CERTIFICATE" \
  --channelName "my_channel"
```

### Stop agent

If you have set default values in the script:

```bash
python agora_starter_server.py stop --agent-id "agent_id_from_start_response"
```

Or override with command line arguments:

```bash
python agora_starter_server.py stop \
  --appid YOUR_APP_ID \
  --basicauth "YOUR_REST_KEY:YOUR_REST_SECRET" \
  --agent-id "agent_id_from_start_response"
```

## 使用示例

### 启动 AI Agent（用于测试 Android 应用）

```bash
cd agent-starter-server
source venv/bin/activate
python agora_starter_server.py start --channelName "test_channel"
```

启动后，Agent 会加入指定的频道，Android 应用可以使用相同的频道名称加入并开始对话。

## Notes

- The virtual environment (`venv`) directory is already created and configured
- Always activate the virtual environment before running the script: `source venv/bin/activate`
- Deactivate the virtual environment when done: `deactivate`
- The script requires Python 3.6 or higher

## 相关资源

- [Agora Conversational AI RESTful API 文档](https://doc.shengwang.cn/doc/convoai/restful/landing-page)
- [Agora 控制台](https://console.shengwang.cn/)
- [Agora AI Studio](https://console-conversationai.shengwang.cn/product/ConversationAI/studio)

