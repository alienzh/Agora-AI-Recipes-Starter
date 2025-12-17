# Agora Agent Starter Script (Avatar)

用于启动和停止 Agora 对话式 AI Agent（数字人版本）的命令行脚本。所有配置从本地环境变量加载。

## 适用场景

- 快速测试和体验 Agora 对话式 AI Agent 的数字人功能
- 配合移动端应用使用，通过脚本启动 Agent，然后在应用中加入频道体验数字人对话
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
cd feature-avatar/server-python

# 创建虚拟环境
python3 -m venv venv

# 激活虚拟环境
# Linux/macOS:
source venv/bin/activate
# Windows:
# venv\Scripts\activate

# 安装依赖
pip install -r requirements.txt
```

依赖包：
- `requests>=2.31.0` - HTTP 请求库
- `python-dotenv>=1.0.0` - 用于加载 `.env.local` 文件

## 配置

1. 复制示例配置文件：
```bash
cd feature-avatar/server-python
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

# Current RTC UID（客户端需要使用此 UID 加入频道）
# 启用 Avatar 时，remote_rtc_uids 只能订阅指定的 UID，不能使用 ["*"]
AGORA_CURRENT_RTC_UID=your_current_rtc_uid_here
```

## Pipeline 配置

在 [AI Studio](https://console-conversationai.shengwang.cn/product/ConversationAI/studio) 创建 Pipeline 时，需要额外配置 Avatar 模块：

1. 进入 Pipeline 编辑页面
2. 打开`数字人设置`选项
3. 打开`启用数字人`
4. 配置数字人相关参数
5. 保存并发布 Pipeline

**注意**：只有启用了数字人功能的 Pipeline 才能正常使用此脚本启动数字人 Agent。

## 使用方法

### 启动 Agent（数字人模式）

直接运行命令启动 Agent，将使用固定配置（Agent RTC UID: `1009527`，Avatar RTC UID: `1009528`）：

```bash
python agent_start_avatar.py start
```

### 脚本启动流程

脚本执行 `startAgent` 时的完整流程如下：

1. **生成 Agent RTC UID 和 Token**
   - Agent RTC UID 固定值：`1009527`（客户端写死使用此 UID）
   - 调用 Token 生成服务，生成 Agent 的 RTC/RTM Token
   - API: `POST https://service.apprtc.cn/toolbox/v2/token/generate`

2. **生成数字人 RTC UID 和 Token**
   - 数字人 RTC UID 固定值：`1009528`（客户端写死使用此 UID）
   - 调用 Token 生成服务，生成数字人的 RTC/RTM Token
   - API: `POST https://service.apprtc.cn/toolbox/v2/token/generate`

3. **RESTful 请求启动 Agent**
   - 构建包含 Avatar 配置的请求体
   - 发送 POST 请求到 Agora REST API
   - API: `POST https://api.sd-rtn.com/cn/api/conversational-ai-agent/v2/projects/{app_id}/join/`
   - 请求头包含 Basic Auth 认证信息
   - **重要**：启用 Avatar 时，`remote_rtc_uids` 不能使用 `["*"]`，必须指定具体的 UID（`AGORA_CURRENT_RTC_UID`）
   - 请求体示例：
     ```json
     {
       "name": "<channel_name>",
       "pipeline_id": "<pipeline_id>",
       "properties": {
         "channel": "<channel_name>",
         "agent_rtc_uid": "1009527",
         "remote_rtc_uids": ["<current_rtc_uid>"],
         "token": "<agent_token>",
         "avatar": {
           "params": {
             "agora_uid": "<avatar_rtc_uid>",
             "agora_token": "<avatar_rtc_token>"
           }
         }
       }
     }
     ```

4. **保存 Agent ID**
   - 从响应中获取 `agent_id`
   - 保存到 `.agent_id` 文件，供后续停止 Agent 使用

启动成功后，脚本会输出：
- Agent ID
- Channel 名称
- Agent RTC UID
- Avatar RTC UID
- Current RTC UID（客户端需要使用此 UID 加入频道）

### 停止 Agent

```bash
python agent_start_avatar.py stop
```

可选参数：
- `--agent-id`: Agent ID（可选，如果不提供则使用上一次启动的 Agent ID）

示例：
```bash
# 使用上一次启动的 Agent ID
python agent_start_avatar.py stop

# 或指定 Agent ID
python agent_start_avatar.py stop --agent-id 1NT29X10YHxxxxxWJOXLYHNYB
```

## 数字人功能说明

此脚本默认启用数字人功能。脚本会在启动 Agent 的请求中包含以下 Avatar 配置：

```json
{
  "properties": {
    "avatar": {
      "params": {
        "agora_uid": "<avatar_rtc_uid>",
        "agora_token": "<avatar_rtc_token>"
      }
    }
  }
}
```

- `agent_rtc_uid` 固定值：`1009527`（客户端写死使用此 UID）
- `avatar_rtc_uid` 固定值：`1009528`（客户端写死使用此 UID）
- `avatar_rtc_token` 由服务端自动生成，无需手动配置

Agent 将以数字人模式运行，支持数字人相关的功能。

## 查看效果

启动 Agent 后，可以使用移动端应用查看效果。请参考相关移动端应用的 README 文档。

**重要提示**：
- 移动端应用中使用的频道名称必须与 `.env.local` 中的 `AGORA_CHANNEL_NAME` 一致
- 移动端应用必须使用 `.env.local` 中配置的 `AGORA_CURRENT_RTC_UID` 作为客户端的 RTC UID 加入频道
- 启用 Avatar 时，Agent 只能订阅指定的 `current_rtc_uid`，不能使用 `["*"]` 订阅所有用户

## 许可证

请参考项目根目录的 LICENSE 文件。

