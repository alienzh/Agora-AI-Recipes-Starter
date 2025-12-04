# Agora Agent Starter Server (Lite)

用于启动和停止 Agora 对话式 AI Agent 的轻量级 HTTP 服务器，提供 REST API 供客户端应用调用。

## 适用场景

- Web 应用开发（React、Vue 等）
- 移动应用开发（Android、iOS）
- 需要简化客户端配置的场景
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
- `flask>=3.0.0` - Web 框架
- `flask-cors>=4.0.0` - CORS 支持
- `python-dotenv>=1.0.0` - 用于加载 `.env.local` 文件（可选）

## 配置

### 服务器端配置（必需）

1. 复制示例配置文件：
```bash
cd server-python-lite
cp .env.example .env.local
```

2. 编辑 `.env.local` 文件，填入你的实际配置值：

```bash
# 服务器端配置（从本地环境变量加载，不应暴露给客户端）
AGORA_BASIC_KEY=your_basic_key_here
AGORA_BASIC_SECRET=your_basic_secret_here
AGORA_PIPELINE_ID=your_pipeline_id_here
```

**重要**：
- `.env.local` 文件已添加到 `.gitignore`，不会被提交到版本控制系统
- 这些配置是服务器端的敏感信息，不应暴露给客户端
- 这些配置会在服务器启动时验证，如果缺失会导致启动失败
- 参考 `.env.example` 文件了解需要配置的变量

### 客户端配置（通过 HTTP 请求提供）

客户端需要在请求体中提供以下配置：
- `appid`（必需）：Agora App ID
- `appcert`（可选）：App Certificate
- `channelName`（必需）：频道名称
- `agent_rtc_uid`（必需）：Agent RTC UID

## 启动服务器

### 基本启动

```bash
python server_startup_lite.py
```

服务器默认运行在 `http://0.0.0.0:8080`。

## API 端点

### 启动 Agent

#### 请求信息

- **请求方式**：`POST`
- **接口地址**：`http://localhost:8080/agent/start`
- **请求 Headers**：
  ```
  Content-Type: application/json
  ```

#### 请求参数

| 参数名 | 类型 | 必需 | 说明 | 示例值 |
|--------|------|------|------|--------|
| `appid` | string | 是 | Agora App ID（项目 ID） | `"your_app_id"` |
| `appcert` | string | 否 | App Certificate，用于生成 Token | `"your_app_certificate"` |
| `channelName` | string | 是 | 频道名称 | `"my_channel"` |
| `agent_rtc_uid` | string | 是 | Agent RTC UID | `"1009527"` |

#### 请求示例

**cURL**：
```bash
curl -X POST http://localhost:8080/agent/start \
  -H "Content-Type: application/json" \
  -d '{
    "appid": "YOUR_APP_ID",
    "appcert": "YOUR_APP_CERT",
    "channelName": "my_channel",
    "agent_rtc_uid": "1009527"
  }'
```

#### 返回参数

**统一返回格式**：

| 参数名 | 类型 | 说明 | 示例值 |
|--------|------|------|--------|
| `code` | number | 状态码，0 表示成功，非 0 表示失败 | `0` 或 `1` |
| `msg` | string | 错误消息，成功时为空字符串 | `""` 或 `"create agent failed, code: 400, msg: properties: channel not found"` |
| `data` | object/null | 响应数据，失败时为 null。成功时包含 Agora API 返回的完整数据：`agent_id`（string，Agent ID）、`create_ts`（number，Agent 创建时间戳）、`status`（string，Agent 状态） | `null` 或 `{"agent_id": "1NT29X10YHxxxxxWJOXLYHNYB", "create_ts": 1737111452, "status": "RUNNING"}` |

**成功响应**（HTTP 200，code: 0）：

**成功响应示例**：
```json
{
  "code": 0,
  "msg": "",
  "data": {
    "agent_id": "1NT29X10YHxxxxxWJOXLYHNYB",
    "create_ts": 1737111452,
    "status": "RUNNING"
  }
}
```

---

### 停止 Agent

#### 请求信息

- **请求方式**：`POST`
- **接口地址**：`http://localhost:8080/agent/stop`
- **请求 Headers**：
  ```
  Content-Type: application/json
  ```

#### 请求参数

| 参数名 | 类型 | 必需 | 说明 | 示例值 |
|--------|------|------|------|--------|
| `appid` | string | 是 | Agora App ID（项目 ID） | `"your_app_id"` |
| `agent_id` | string | 是 | 要停止的 Agent ID | `"agent_123456"` |

#### 请求示例

**cURL**：
```bash
curl -X POST http://localhost:8080/agent/stop \
  -H "Content-Type: application/json" \
  -d '{
    "appid": "YOUR_APP_ID",
    "agent_id": "agent_123456"
  }'
```

#### 返回参数

**统一返回格式**：

| 参数名 | 类型 | 说明 | 示例值 |
|--------|------|------|--------|
| `code` | number | 状态码，0 表示成功，非 0 表示失败 | `0` 或 `1` |
| `msg` | string | 错误消息，成功时为空字符串 | `""` 或 `"Leave agent error: ..."` |
| `data` | object/null | 响应数据，失败时为 null | 见下方说明 |

**成功响应**（HTTP 200，code: 0）：

**成功响应示例**：
```json
{
  "code": 0,
  "msg": "",
  "data": null
}
```

## 注意事项

1. **安全性**：
   - 服务器端配置（basic_key, basic_secret, pipeline_id）不应暴露给客户端
   - 建议在生产环境中使用 HTTPS
   - 建议添加身份验证机制（如 API Key）

2. **错误处理**：
   - 所有 API 错误都会返回 JSON 格式的错误信息
   - 建议客户端实现适当的错误处理逻辑

## 许可证

请参考项目根目录的 LICENSE 文件。

