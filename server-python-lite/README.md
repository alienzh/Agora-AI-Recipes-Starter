# Agora Agent Starter Script (Lite)

用于启动和停止 Agora 对话式 AI Agent 的命令行脚本。所有配置从本地环境变量加载。

## 适用场景

- 快速测试和体验 Agora 对话式 AI Agent
- 配合 Web 应用使用，通过脚本启动 Agent，然后在 Web 应用中加入频道体验
- 需要保护服务器端认证信息的场景

## 前置条件

- Python 3.6 或更高版本
- 网络连接（用于调用 Agora REST API）
- Agora 开发者账号 [Console](https://console.shengwang.cn/)
- 已创建 Agora 项目并获取 App ID
- 已获取 REST API 的 Basic Auth 凭证（Key 和 Secret）
- 已获取 Pipeline ID

## 安装依赖

```bash
cd server-python-lite
pip install -r requirements.txt
```

依赖包：
- `requests>=2.31.0` - HTTP 请求库
- `python-dotenv>=1.0.0` - 用于加载 `.env.local` 文件

## 配置

1. 复制示例配置文件：
```bash
cd server-python-lite
cp .env.example .env.local
```

2. 编辑 `.env.local` 文件，填入你的实际配置值：

```bash

# App ID（用于生成 Token 和启动 Agent）
AGORA_APP_ID=your_app_id_here

# App Certificate（用于生成 Token，可选）
AGORA_APP_CERT=your_app_certificate_here

# Basic Auth 凭证（用于调用 Agora REST API）
AGORA_BASIC_KEY=your_basic_key_here
AGORA_BASIC_SECRET=your_basic_secret_here

# Pipeline ID（用于启动 Agent）
AGORA_PIPELINE_ID=your_pipeline_id_here

# 频道名称（Agent 将加入的频道）
AGORA_CHANNEL_NAME=your_channel_name_here
```

## 使用方法

### 启动 Agent

```bash
python agora_agent_startup.py start
```

启动成功后，脚本会：
1. 自动生成 Agent Rtc uid Token
2. 启动 Agent
3. 自动保存 Agent ID 到 `.agent_id` 文件（用于后续停止 Agent）

### 停止 Agent

```bash
python agora_agent_startup.py stop
```

可选参数：
- `--agent-id`: Agent ID（可选，如果不提供则使用上一次启动的 Agent ID）

示例：
```bash
# 使用上一次启动的 Agent ID
python agora_agent_startup.py stop

# 或指定 Agent ID
python agora_agent_startup.py stop --agent-id 1NT29X10YHxxxxxWJOXLYHNYB
```

## 查看效果

启动 Agent 后，可以使用 Web 应用查看效果。请参考 [web-react-lite/README.md](../web-react-lite/README.md)。

**注意**：Web 应用中使用的频道名称必须与 `.env.local` 中的 `AGORA_CHANNEL_NAME` 一致。

## 许可证

请参考项目根目录的 LICENSE 文件。
