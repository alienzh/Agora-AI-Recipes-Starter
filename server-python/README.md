# Agora Agent Starter HTTP Server

用于启动和停止 Agora 对话式 AI Agent 的 HTTP 服务器，提供 REST API 供客户端应用调用。

## 功能特点

- **透传模式**：完全透传客户端请求，不修改任何数据
- **统一接口**：与 Agora RESTful API 格式完全一致
- **简单配置**：只需配置 App ID，其他参数由客户端提供
- **跨域支持**：支持跨域访问，适用于各种客户端

## 适用场景

- 移动应用开发（Android、iOS）
- Web 应用开发
- 桌面应用开发
- 需要本地代理服务器的场景
- 需要统一的 API 接口

## 前置条件

- Python 3.6 或更高版本
- 网络连接（用于调用 Agora REST API）
- Agora 开发者账号 [Console](https://console.shengwang.cn/)
- 已创建 Agora 项目并获取 App ID
- 已获取 REST API 的 Basic Auth 凭证（Key 和 Secret）

## 安装依赖

```bash
cd server-python
pip install -r requirements.txt
```

依赖包：
- `requests>=2.31.0` - HTTP 请求库
- `flask>=3.0.0` - Web 框架
- `flask-cors>=4.0.0` - CORS 支持
- `python-dotenv>=1.0.0` - 用于加载 `.env.local` 文件（可选）

## 配置

**注意**：HTTP 服务器采用透传模式，服务器本身不需要配置任何 Agora 相关参数（如 App ID、Pipeline ID 等）。所有参数（包括 `pipeline_id`、`channel_name`、`token`、`Authorization` header 等）都由客户端在请求中提供，服务器直接透传给 Agora RESTful API。

## 启动服务器

### 基本启动

```bash
python agora_http_server.py
```

服务器默认运行在 `http://0.0.0.0:8080`。

### 自定义端口和主机

服务器默认运行在 `http://0.0.0.0:8080`。如需修改，请直接编辑 `agora_http_server.py` 文件中的 `host` 和 `port` 变量。

### 使用虚拟环境（推荐）

```bash
# 创建虚拟环境
python3 -m venv venv

# 激活虚拟环境
source venv/bin/activate  # macOS/Linux
# 或
venv\Scripts\activate  # Windows

# 安装依赖
pip install -r requirements.txt

# 启动服务器
python agora_http_server.py

# 退出虚拟环境
deactivate
```

## API 端点

### 健康检查

```http
GET /health
```

**响应**：
```json
{
  "status": "ok",
  "message": "Agora Agent Starter Server is running"
}
```

### 启动 Agent

```http
POST /{project_id}/join/
```

**请求头**：
```
Content-Type: application/json; charset=utf-8
Authorization: Basic <base64_encoded_credentials>
```

**请求体**（与 Agora API 格式一致）：
```json
{
  "name": "agent_name",
  "pipeline_id": "pipeline_id",
  "properties": {
    "channel": "channel_name",
    "agent_rtc_uid": "1009527",
    "remote_rtc_uids": ["*"],
    "token": "token_string"
  }
}
```

**DataStream 模式**（可选）：
如果使用 RTC DataStream 进行消息传递（如 HarmonyOS），需要在 `properties` 中添加以下配置：
```json
{
  "name": "agent_name",
  "pipeline_id": "pipeline_id",
  "properties": {
    "channel": "channel_name",
    "agent_rtc_uid": "1009527",
    "remote_rtc_uids": ["*"],
    "token": "token_string",
    "parameters": {
      "data_channel": "datastream"
    },
    "advanced_features": {
      "enable_rtm": false
    }
  }
}
```

**注意**：
- 服务器采用透传模式，所有参数（包括 dataStream 配置）都需要客户端在请求体中提供
- 服务器不做任何修改，直接透传给 Agora RESTful API
- 对于使用 RTM 的场景（如 Android、iOS），不需要添加 `parameters` 和 `advanced_features` 字段

**响应**（与 Agora API 格式一致）：
```json
{
  "agent_id": "agent_id",
  "create_ts": 1234567890,
  "status": "active"
}
```

### 停止 Agent

```http
POST /{project_id}/agents/{agent_id}/leave
```

**请求头**：
```
Content-Type: application/json; charset=utf-8
Authorization: Basic <base64_encoded_credentials>
```

**请求体**：空（POST with empty body）

**响应**：HTTP 200 OK（无响应体）

### 列出所有活跃的 Agent（遗留端点）

```http
GET /agents
```

**响应**：
```json
{
  "success": true,
  "agents": [
    {
      "channelName": "channel_name",
      "agentId": "agent_id"
    }
  ]
}
```

## 客户端配置

### 在代码中切换 URL

服务器启动时会自动显示连接信息，包括：
- Localhost 地址（同一台机器）
- 网络地址（其他设备）
- 特殊情况的说明（Android 模拟器、iOS 模拟器等）

示例输出：
```
============================================================
🔗 Client Configuration
============================================================

💻 For Localhost (same machine):
   http://localhost:8080
   http://127.0.0.1:8080

🌐 For Network Access (other devices):
   http://10.103.1.61:8080

   Use this URL in your client code, for example:
   const BASE_URL = "http://10.103.1.61:8080"

📝 Special Cases:
   - Android Emulator: Use http://10.0.2.2:8080
   - iOS Simulator: Use http://localhost:8080 or http://127.0.0.1:8080

============================================================
```

### IP 地址说明

- **Localhost**：适用于同一台机器上的客户端（Web 应用、桌面应用等）
- **网络访问**：适用于其他设备（手机、平板、其他电脑等）
- **Android 模拟器**：使用 `http://10.0.2.2:8080`（`10.0.2.2` 是模拟器访问主机 localhost 的特殊 IP）
- **iOS 模拟器**：使用 `http://localhost:8080` 或 `http://127.0.0.1:8080`
- **真机**：使用 `http://<你的电脑IP>:8080`
  - 查找电脑 IP 地址：
    ```bash
    # macOS/Linux: 查找 Wi-Fi/以太网 IP（通常是 en0）
    ifconfig en0 | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}'
    
    # Windows: 使用 ipconfig
    ipconfig
    ```
  - 确保设备和电脑在同一局域网内

### 注意事项

1. **防火墙**：确保电脑防火墙允许端口的入站连接
2. **网络**：设备和电脑必须在同一局域网内（真机）
3. **端口冲突**：如果端口被占用，可以使用其他端口：
   ```bash
   python agora_http_server.py --port 9000
   ```
   并在客户端代码中相应修改端口号

## 工作原理

HTTP 服务器采用**透传模式**：

1. 客户端发送请求（包含完整的请求体和 headers）
2. 服务器提取客户端的 headers（特别是 `Authorization`）和 request body
3. 服务器直接转发给 Agora RESTful API，不做任何修改
4. 服务器返回 Agora API 的原始响应

这种设计的好处：
- **简单**：服务器不需要知道业务逻辑
- **灵活**：客户端可以完全控制请求参数
- **统一**：与直接调用 Agora API 的格式完全一致

## 调试

服务器会输出详细的调试日志：

```
[DEBUG] Calling Agora API: https://api.sd-rtn.com/cn/api/conversational-ai-agent/v2/projects/{project_id}/join/
[DEBUG] Request payload: {
  "name": "channel_name",
  "pipeline_id": "pipeline_id",
  ...
}
[DEBUG] Request headers: {'Authorization': 'Basic ...', 'Content-Type': 'application/json; charset=utf-8'}
[DEBUG] Response status: 200
[DEBUG] Response body: {"agent_id": "...", ...}
```

## 常见问题

### 端口被占用

如果遇到 "Address already in use" 错误：

```bash
# 查找占用端口的进程
lsof -ti:8080

# 杀死进程
lsof -ti:8080 | xargs kill -9

# 或使用其他端口
python agora_http_server.py --port 9000
```

### 连接失败

1. **检查服务器是否启动**：
   ```bash
   curl http://localhost:8080/health
   ```

2. **检查 IP 地址**：
   - 模拟器：使用 `10.0.2.2`
   - 真机：使用电脑的实际 IP 地址（不是 `127.0.0.1`）

3. **检查防火墙**：确保允许端口的入站连接

4. **检查网络**：确保设备和电脑在同一局域网

## 项目结构

```
server-python/
├── agora_http_server.py      # HTTP 服务器
├── agora_api_client.py       # Agora API 客户端（内部使用）
├── requirements.txt           # Python 依赖
└── README.md                  # 本文档
```

## 相关资源

- [Agora Conversational AI RESTful API 文档](https://doc.shengwang.cn/doc/convoai/restful/landing-page)
- [Agora 控制台](https://console.shengwang.cn/)
- [Agora AI Studio](https://console-conversationai.shengwang.cn/product/ConversationAI/studio)
