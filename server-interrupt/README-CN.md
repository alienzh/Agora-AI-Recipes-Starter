# Agora Agent Starter Script (Interrupt Features)

中文 | [English](README.md)

用于启动和停止 Agora 对话式 AI Agent（打断功能版本）的命令行脚本集合。本目录包含两个脚本，分别支持**关键词打断**和**优雅打断（AIVAD）**功能。

## 脚本说明

- **`agent_interrupt_keyword.py`** - 关键词打断脚本
- **`agent_interrupt_aivad.py`** - 优雅打断（AIVAD）脚本

**重要提示**：关键词打断和优雅打断（AIVAD）功能互斥，不可同时开启。

## 前置条件

- Python 3.6 或更高版本
- Agora 开发者账号 [Console](https://console.shengwang.cn/)
- 已创建 Agora 项目并获取 App ID、Basic Auth 凭证、Pipeline ID

## 安装依赖

```bash
cd server-interrupt

# 创建虚拟环境
python3 -m venv venv

# 激活虚拟环境
# Linux/macOS: source venv/bin/activate
# Windows: venv\Scripts\activate

# 安装依赖
pip install -r requirements.txt
```

## 配置

1. 复制示例配置文件：

```bash
cp .env.example .env.local
```

2. 编辑 `.env.local` 文件，填入配置值：

```bash
AGORA_APP_ID=your_app_id_here
AGORA_APP_CERT=your_app_certificate_here  # 可选
AGORA_BASIC_KEY=your_basic_key_here
AGORA_BASIC_SECRET=your_basic_secret_here
AGORA_PIPELINE_ID=your_pipeline_id_here
AGORA_CHANNEL_NAME=your_channel_name_here

# 仅关键词打断脚本需要
AGORA_INTERRUPT_KEYWORDS=停止,暂停,结束,不要说了
```

## Pipeline 配置

在 [AI Studio](https://console-conversationai.shengwang.cn/product/ConversationAI/studio) 创建 Pipeline 时，**不需要**在 Pipeline 配置中启用打断功能。打断功能通过启动 Agent 时的 RESTful API 请求参数启用，脚本会自动添加相应参数。

## 使用方法

### 启动 Agent

**关键词打断：**

```bash
python agent_interrupt_keyword.py start
```

**优雅打断（AIVAD）：**

```bash
python agent_interrupt_aivad.py start
```

脚本启动流程：
1. 生成 Agent Token（Agent RTC UID 固定值：`1009527`）
2. 发送 RESTful 请求启动 Agent，自动添加打断功能配置
3. 保存 Agent ID 到 `.agent_id` 文件

**请求体差异：**

关键词打断：

```json
{
  "properties": {
    "turn_detection": {
      "interrupt_mode": "keywords",
      "interrupt_keywords": ["停止", "暂停", "结束"]
    }
  }
}
```

优雅打断（AIVAD）：

```json
{
  "properties": {
    "advanced_features": {
      "enable_aivad": true
    }
  }
}
```

**注意**：使用 AIVAD 时，`turn_detection.interrupt_mode` 默认值为 `"interrupt"`（打断模式）。

### 停止 Agent

```bash
# 关键词打断
python agent_interrupt_keyword.py stop

# 优雅打断（AIVAD）
python agent_interrupt_aivad.py stop
```

可选参数：`--agent-id`（不提供则使用上一次启动的 Agent ID）

## 功能说明

### 关键词打断

- **功能**：用户说出预设关键词时打断智能体
- **配置**：通过 `AGORA_INTERRUPT_KEYWORDS` 设置关键词（逗号分隔，最多 128 个）
- **限制**：与 AIVAD 互斥；关键词识别能力取决于 ASR 供应商

### 优雅打断（AIVAD）

- **功能**：AI Voice Activity Detection，智能检测和处理语音活动
- **配置**：无需额外配置，脚本自动启用
- **限制**：与关键词打断互斥；默认使用 `interrupt` 模式

## 技术参数

- `agent_rtc_uid` 固定值：`1009527`
- Agent Token 由服务端自动生成

## 相关文档

- [创建对话式智能体 API 文档](https://doc.shengwang.cn/doc/convoai/restful/convoai/operations/start-agent)
- [AI Studio 控制台](https://console-conversationai.shengwang.cn/product/ConversationAI/studio)

## 查看效果

启动 Agent 后，可以使用 Web 应用查看效果。请参考 [web-react-lite/README.md](../web-react-lite/README.md)。

**注意**：Web 应用中使用的频道名称必须与 `.env.local` 中的 `AGORA_CHANNEL_NAME` 一致。
