# Agora Agent Starter Script (Vision)

用于启动和停止 Agora 对话式 AI Agent（视觉版本）的命令行脚本。所有配置从本地环境变量加载。

## 适用场景

- 快速测试和体验 Agora 对话式 AI Agent 的视觉功能
- 配合移动端应用使用，通过脚本启动 Agent，然后在应用中加入频道体验视觉对话
- Agent 可以通过视频获取摄像头画面数据，支持图像输入模态
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
cd feature-vison/server-python
pip install -r requirements.txt
```

依赖包：
- `requests>=2.31.0` - HTTP 请求库
- `python-dotenv>=1.0.0` - 用于加载 `.env.local` 文件

## 配置

1. 复制示例配置文件：
```bash
cd feature-vison/server-python
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

## Pipeline 配置

在 [AI Studio](https://console-conversationai.shengwang.cn/product/ConversationAI/studio) 创建 Pipeline 时，需要确保 Pipeline 支持视觉功能。

**注意**：Pipeline 需要支持图像输入模态才能正常使用此脚本启动视觉 Agent。

## 使用方法

### 启动 Agent（视觉模式）

直接运行命令启动 Agent，将使用固定配置（Agent RTC UID: `1009527`）：

```bash
python agent_start_vision.py start
```

### 脚本启动流程

脚本执行 `startAgent` 时的完整流程如下：

1. **生成 Agent RTC UID 和 Token**
   - Agent RTC UID 固定值：`1009527`
   - 调用 Token 生成服务，生成 Agent 的 RTC/RTM Token
   - API: `POST https://service.apprtc.cn/toolbox/v2/token/generate`

2. **RESTful 请求启动 Agent**
   - 构建包含 LLM 配置的请求体
   - 发送 POST 请求到 Agora REST API
   - API: `POST https://api.sd-rtn.com/cn/api/conversational-ai-agent/v2/projects/{app_id}/join/`
   - 请求头包含 Basic Auth 认证信息
   - 请求体示例：
     ```json
     {
       "name": "<channel_name>",
       "pipeline_id": "<pipeline_id>",
       "properties": {
         "channel": "<channel_name>",
         "agent_rtc_uid": "1009527",
         "remote_rtc_uids": ["*"],
         "token": "<agent_token>",
         "llm": {
           "input_modalities": ["text", "image"]
         }
       }
     }
     ```

3. **保存 Agent ID**
   - 从响应中获取 `agent_id`
   - 保存到 `.agent_id` 文件，供后续停止 Agent 使用

启动成功后，脚本会输出：
- Agent ID
- Channel 名称
- Agent RTC UID
- LLM 输入模态

### 停止 Agent

```bash
python agent_start_vision.py stop
```

可选参数：
- `--agent-id`: Agent ID（可选，如果不提供则使用上一次启动的 Agent ID）

示例：
```bash
# 使用上一次启动的 Agent ID
python agent_start_vision.py stop

# 或指定 Agent ID
python agent_start_vision.py stop --agent-id 1NT29X10YHxxxxxWJOXLYHNYB
```

## 视觉功能说明

此脚本默认启用视觉功能。脚本会在启动 Agent 的请求中包含以下 LLM 配置：

```json
{
  "properties": {
    "llm": {
      "input_modalities": ["text", "image"]
    }
  }
}
```

- `agent_rtc_uid` 固定值：`1009527`
- `input_modalities` 设置为 `["text", "image"]`，使 Agent 能够通过视频获取摄像头画面数据
- Agent Token 由服务端自动生成，无需手动配置

Agent 将以视觉模式运行，支持文本和图像输入，可以通过视频流获取摄像头画面数据。

## 查看效果

启动 Agent 后，可以使用移动端应用查看效果。请参考相关移动端应用的 README 文档。

**注意**：移动端应用中使用的频道名称必须与 `.env.local` 中的 `AGORA_CHANNEL_NAME` 一致。

## 许可证

请参考项目根目录的 LICENSE 文件。

