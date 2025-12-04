#!/usr/bin/env python3
"""
Agora Agent Starter Server (Lite)
基于 Flask 的 HTTP 服务器，用于启动和停止 Agora 对话式 AI Agent
服务器端配置（basic_key, basic_secret, pipeline_id）从本地环境变量加载
客户端配置（appid, appcert）通过 HTTP 请求提供
"""
import base64
import json
import os
import socket
import sys
import time
from typing import Optional, Dict, Any, List
import requests
from flask import Flask, request, jsonify
from flask_cors import CORS

# 加载 .env.local 文件以获取配置
# 注意：需要 python-dotenv 包，安装命令：pip install python-dotenv
try:
    from dotenv import load_dotenv
    load_dotenv(".env.local")
except ImportError:
    # dotenv 未安装，跳过加载 .env.local 文件
    # 仍可使用环境变量
    pass


class AgoraStarterServer:
    """
    Agora Agent Starter Server 实现类
    用于管理 Agora 对话式 AI Agent 的启动、停止和 Token 生成
    """
    
    # API 端点配置
    API_BASE_URL = "https://api.sd-rtn.com/cn/api/conversational-ai-agent/v2/projects"
    TOOLBOX_SERVER_HOST = "https://service.apprtc.cn/toolbox"
    JSON_MEDIA_TYPE = "application/json; charset=utf-8"
    DEFAULT_EXPIRE_SECONDS = 60 * 60 * 24  # 默认 Token 过期时间：24 小时（秒）
    DEFAULT_TIMEOUT = 30  # 默认 HTTP 请求超时时间（秒）
    
    def __init__(
        self,
        app_id: str,
        basic_key: str,
        basic_secret: str,
        pipeline_id: str,
        channel_name: str,
        app_cert: Optional[str] = None
    ):
        """
        初始化 Agora Starter Server
        
        参数:
            app_id: Agora App ID（项目 ID）
            basic_key: Basic Auth Key
            basic_secret: Basic Auth Secret
            pipeline_id: Pipeline ID（用于启动 Agent）
            channel_name: 频道名称
            app_cert: App Certificate（可选，用于生成 Token）
        """
        # 保存配置信息
        self.app_id = app_id
        self.pipeline_id = pipeline_id
        self.channel_name = channel_name
        self.app_cert = app_cert
        
        # 保存 Basic Auth 认证信息
        self.rest_key = basic_key
        self.rest_secret = basic_secret
        
        # 创建 HTTP 会话并配置 Basic Auth 认证
        # 参考 Android 代码中的 Base64Encoding.gen() 方法
        self.session = requests.Session()
        credentials = f"{self.rest_key}:{self.rest_secret}"
        encoded_credentials = base64.b64encode(credentials.encode()).decode()
        self.session.headers.update({
            "Authorization": f"Basic {encoded_credentials}",
            "Content-Type": self.JSON_MEDIA_TYPE
        })
    
    def _build_json_payload(
        self,
        name: str,
        channel: str,
        agent_rtc_uid: str,
        token: str,
        remote_rtc_uids: List[str]
    ) -> Dict[str, Any]:
        """
        构建启动 Agent 的 JSON 请求体
        参考 Android 代码中的 buildJsonPayload() 方法
        
        参数:
            name: Agent 名称
            channel: 频道名称
            agent_rtc_uid: Agent 的 RTC UID
            token: Token 字符串
            remote_rtc_uids: 远程 RTC UIDs 列表
            
        返回:
            表示 JSON 请求体的字典
        """
        payload = {
            "name": name,
            "pipeline_id": self.pipeline_id,
            "properties": {
                "channel": channel,
                "agent_rtc_uid": agent_rtc_uid,
                "remote_rtc_uids": remote_rtc_uids,  # ["*"] 表示所有用户
                "token": token
            }
        }
        return payload
    
    def _execute_join_request(
        self,
        name: str,
        channel: str,
        agent_rtc_uid: str,
        token: str,
        remote_rtc_uids: List[str]
    ) -> str:
        """
        执行启动 Agent 的 HTTP 请求
        参考 Android 代码中的 executeJoinRequest() 方法
        
        参数:
            name: Agent 名称
            channel: 频道名称
            agent_rtc_uid: Agent 的 RTC UID
            token: Token 字符串
            remote_rtc_uids: 远程 RTC UIDs 列表
            
        返回:
            响应文本（JSON 格式）
            
        抛出:
            RuntimeError: 如果请求失败
        """
        # 构建 API URL：POST /api/conversational-ai-agent/v2/projects/{project_id}/join/
        url = f"{self.API_BASE_URL}/{self.app_id}/join/"
        payload = self._build_json_payload(name, channel, agent_rtc_uid, token, remote_rtc_uids)
        
        try:
            response = self.session.post(url, json=payload, timeout=self.DEFAULT_TIMEOUT)
        except requests.exceptions.Timeout:
            raise RuntimeError(
                f"Join agent error: Request timeout after {self.DEFAULT_TIMEOUT} seconds. "
                f"Please check your network connection or try again later."
            )
        except requests.exceptions.ConnectionError as e:
            raise RuntimeError(
                f"Join agent error: Connection failed. Please check your network connection. "
                f"Details: {str(e)}"
            )
        except requests.exceptions.RequestException as e:
            raise RuntimeError(
                f"Join agent error: Request failed. Details: {str(e)}"
            )
        
        # 检查响应状态码
        if not response.ok:
            # 尝试解析错误响应中的 detail
            error_detail = None
            try:
                error_body = response.json()
                if "detail" in error_body:
                    error_detail = error_body["detail"]
            except:
                pass
            
            error_msg = f"Join agent error: httpCode={response.status_code}, httpMsg={response.reason}"
            if error_detail:
                error_msg = error_detail
            else:
                error_msg += f", body={response.text}"
            
            raise RuntimeError(error_msg)
        
        # 返回响应文本（应该是 JSON 格式，包含 agent_id, create_ts, status）
        return response.text
    
    def _execute_leave_request(self, agent_id: str) -> None:
        """
        执行停止 Agent 的 HTTP 请求
        参考 Android 代码中的 executeLeaveRequest() 方法
        
        参数:
            agent_id: 要停止的 Agent ID
            
        抛出:
            RuntimeError: 如果请求失败
        """
        # 构建 API URL：POST /api/conversational-ai-agent/v2/projects/{project_id}/agents/{agent_id}/leave
        url = f"{self.API_BASE_URL}/{self.app_id}/agents/{agent_id}/leave"
        
        # 发送 POST 请求，请求体为空 JSON 对象（参考 Android 代码）
        try:
            response = self.session.post(url, json={}, timeout=self.DEFAULT_TIMEOUT)
        except requests.exceptions.Timeout:
            raise RuntimeError(
                f"Leave agent error: Request timeout after {self.DEFAULT_TIMEOUT} seconds. "
                f"Please check your network connection or try again later."
            )
        except requests.exceptions.ConnectionError as e:
            raise RuntimeError(
                f"Leave agent error: Connection failed. Please check your network connection. "
                f"Details: {str(e)}"
            )
        except requests.exceptions.RequestException as e:
            raise RuntimeError(
                f"Leave agent error: Request failed. Details: {str(e)}"
            )
        
        # 检查响应状态码
        if not response.ok:
            # 尝试解析错误响应中的 detail
            error_detail = None
            try:
                error_body = response.json()
                if "detail" in error_body:
                    error_detail = error_body["detail"]
            except:
                pass
            
            error_msg = f"Leave agent error: httpCode={response.status_code}, httpMsg={response.reason}"
            if error_detail:
                error_msg = error_detail
            else:
                error_msg += f", body={response.text}"
            
            raise RuntimeError(error_msg)
        
        # 关闭响应（释放资源）
        response.close()
    
    def start_agent(
        self,
        name: str,
        agent_rtc_uid: str,
        token: str,
        channel: Optional[str] = None,
        remote_rtc_uids: Optional[List[str]] = None
    ) -> Dict[str, Any]:
        """
        启动一个 Agent
        参考 Android 代码中的 startAgentAsync() 方法
        
        参数:
            name: Agent 名称
            agent_rtc_uid: Agent 的 RTC UID
            token: Token 字符串
            channel: 频道名称（可选，如果不提供则使用实例默认值）
            remote_rtc_uids: 远程 RTC UIDs 列表（可选，默认为 ["*"] 表示所有用户）
            
        返回:
            Agora API 返回的完整响应（包含 agent_id, create_ts, status）
        """
        # 使用传入的频道名或实例默认频道名
        channel = channel or self.channel_name
        # 使用传入的远程 UIDs 或默认值 ["*"]
        remote_rtc_uids = remote_rtc_uids or ["*"]
        
        # 执行启动请求
        response_text = self._execute_join_request(
            name, channel, agent_rtc_uid, token, remote_rtc_uids
        )
        
        # 解析 JSON 响应并返回完整数据
        response_json = json.loads(response_text)
        
        # 验证 agent_id 是否存在
        agent_id = response_json.get("agent_id", "")
        if not agent_id:
            raise RuntimeError(
                f"Failed to parse agent_id from response: {response_text}"
            )
        
        return response_json
    
    def stop_agent(self, agent_id: str) -> None:
        """
        停止一个 Agent
        参考 Android 代码中的 stopAgentAsync() 方法
        
        参数:
            agent_id: 要停止的 Agent ID
        """
        # 执行停止请求
        self._execute_leave_request(agent_id)
    
    def generate_token(
        self,
        channel_name: str,
        uid: str,
        token_types: List[int],
        expire_seconds: Optional[int] = None
    ) -> str:
        """
        生成 RTC/RTM/Chat Token
        参考 Android 代码中的 TokenGenerator.fetchToken() 方法
        
        参数:
            channel_name: 频道名称
            uid: 用户 ID（Agent RTC UID）
            token_types: Token 类型列表（1=Rtc, 2=Rtm, 3=Chat）
            expire_seconds: 过期时间（秒）（可选，默认 24 小时）
            
        返回:
            Token 字符串
            
        抛出:
            RuntimeError: 如果 Token 生成失败
        """
        # 使用传入的过期时间或默认值（24 小时）
        expire = expire_seconds if expire_seconds and expire_seconds > 0 else self.DEFAULT_EXPIRE_SECONDS
        
        # 构建请求体（参考 Android 代码中的 buildJsonRequest() 方法）
        payload = {
            "appId": self.app_id,
            "appCertificate": self.app_cert or "",  # App Certificate（可选）
            "channelName": channel_name,
            "expire": expire,  # 过期时间（秒）
            "src": "Python",  # 来源标识（Android 代码中是 "Android"）
            "ts": str(int(time.time() * 1000)),  # 当前时间戳（毫秒）
            "uid": uid
        }
        
        # 添加 Token 类型（参考 Android 代码的逻辑）
        # 如果只有一个类型，使用 "type" 字段；多个类型使用 "types" 数组
        if len(token_types) == 1:
            payload["type"] = token_types[0]
        else:
            payload["types"] = token_types
        
        # 构建 Token 生成 API URL
        url = f"{self.TOOLBOX_SERVER_HOST}/v2/token/generate"
        
        # 创建独立的 HTTP 会话（Token 生成不需要 Basic Auth）
        token_session = requests.Session()
        token_session.headers.update({
            "Content-Type": "application/json"
        })
        
        # 发送 POST 请求
        response = token_session.post(url, json=payload)
        
        # 检查 HTTP 状态码
        if not response.ok:
            raise RuntimeError(
                f"Fetch token error: httpCode={response.status_code}, "
                f"httpMsg={response.reason}, body={response.text}"
            )
        
        # 解析 JSON 响应
        response_body = response.json()
        
        # 检查响应码（参考 Android 代码中的错误检查）
        # 响应格式：{"code": 0, "message": "...", "data": {"token": "..."}}
        if response_body.get("code", -1) != 0:
            raise RuntimeError(
                f"Fetch token error: httpCode={response.status_code}, "
                f"httpMsg={response.reason}, "
                f"reqCode={response_body.get('code')}, "
                f"reqMsg={response_body.get('message')}"
            )
        
        # 从响应中提取 Token（参考 Android 代码：bodyJson.getJSONObject("data").getString("token")）
        data = response_body.get("data", {})
        token = data.get("token", "")
        
        # 验证 Token 是否存在
        if not token:
            raise RuntimeError(
                f"Failed to parse token from response: {response.text}"
            )
        
        return token


# Flask 应用设置
app = Flask(__name__)
CORS(app)  # 启用 CORS 以支持跨域请求

# 存储活跃的 Agent（生产环境应使用数据库）
active_agents: Dict[str, str] = {}  # channel_name -> agent_id

# 服务器端配置（从本地环境变量加载）
# 这些配置不应暴露给客户端
SERVER_BASIC_KEY = os.getenv("AGORA_BASIC_KEY", "")
SERVER_BASIC_SECRET = os.getenv("AGORA_BASIC_SECRET", "")
SERVER_PIPELINE_ID = os.getenv("AGORA_PIPELINE_ID", "")


def validate_server_config():
    """
    验证服务器端配置是否可用
    如果缺少必需的配置，抛出 ValueError
    """
    if not SERVER_BASIC_KEY or not SERVER_BASIC_SECRET:
        raise ValueError(
            "服务器端配置缺失：AGORA_BASIC_KEY 和 AGORA_BASIC_SECRET "
            "必须在 .env.local 文件或环境变量中设置"
        )
    if not SERVER_PIPELINE_ID:
        raise ValueError(
            "服务器端配置缺失：AGORA_PIPELINE_ID "
            "必须在 .env.local 文件或环境变量中设置"
        )


@app.route('/agent/start', methods=['POST'])
def start_agent():
    """
    启动一个 Agora 对话式 AI Agent
    服务器端配置（basic_key, basic_secret, pipeline_id）从本地环境变量加载
    客户端配置（appid, appcert, channelName, agent_rtc_uid）在请求体中提供
    
    请求体 (JSON):
    {
        "appid": "YOUR_APP_ID",           // 必需：来自客户端
        "appcert": "YOUR_APP_CERT",       // 可选：来自客户端
        "channelName": "channel_name",    // 必需：来自客户端
        "agent_rtc_uid": "1009527",       // 必需：来自客户端
        "expire": 86400,                  // 可选：token 过期时间（秒）（默认：24 小时）
        "remote_rtc_uids": ["*"]          // 可选：远程 RTC UIDs 列表（默认：["*"]）
    }
    
    响应 (JSON):
    {
        "agent_id": "agent_id",
        "channel_name": "channel_name"
    }
    """
    try:
        # 验证服务器端配置
        validate_server_config()
        
        # 解析请求体
        data = request.get_json()
        if not data:
            return jsonify({
                "code": 1,
                "msg": "Request body is required",
                "data": None
            }), 200
        
        # 提取客户端配置
        app_id = data.get("appid", "").strip()
        app_cert = data.get("appcert", "").strip()
        channel_name = data.get("channelName", "").strip()
        agent_rtc_uid = data.get("agent_rtc_uid", "").strip()
        expire_seconds = data.get("expire")
        remote_rtc_uids = data.get("remote_rtc_uids", ["*"])
        
        # 验证必需的客户端参数
        if not app_id:
            return jsonify({
                "code": 1,
                "msg": "appid is required in request body",
                "data": None
            }), 200
        if not channel_name:
            return jsonify({
                "code": 1,
                "msg": "channelName is required in request body",
                "data": None
            }), 200
        if not agent_rtc_uid:
            return jsonify({
                "code": 1,
                "msg": "agent_rtc_uid is required in request body",
                "data": None
            }), 200
        
        # 默认 token 类型：RTC 和 RTM（参考 Android 代码的默认行为）
        token_types = [1, 2]  # 1=RTC, 2=RTM
        
        # 创建 AgoraStarterServer 实例（用于生成 Token）
        # 注意：生成 Token 不需要 basic_key/basic_secret 和 pipeline_id
        token_server = AgoraStarterServer(
            app_id=app_id,
            basic_key="dummy",  # 占位符，生成 Token 不需要 Basic Auth
            basic_secret="dummy",  # 占位符，生成 Token 不需要 Basic Auth
            pipeline_id="",  # 占位符，生成 Token 不需要 Pipeline ID
            channel_name=channel_name,
            app_cert=app_cert if app_cert else None
        )
        
        # 自动生成 Token
        print(f"[INFO] Generating token for app_id={app_id}, channel={channel_name}...")
        token = token_server.generate_token(
            channel_name=channel_name,
            uid=agent_rtc_uid,
            token_types=token_types,
            expire_seconds=expire_seconds
        )
        print(f"[INFO] Token generated successfully")
        
        # 创建用于启动 Agent 的 AgoraStarterServer 实例
        # 使用服务器端配置（basic_key, basic_secret, pipeline_id）从环境变量
        server = AgoraStarterServer(
            app_id=app_id,
            basic_key=SERVER_BASIC_KEY,
            basic_secret=SERVER_BASIC_SECRET,
            pipeline_id=SERVER_PIPELINE_ID,
            channel_name=channel_name,
            app_cert=app_cert if app_cert else None
        )
        
        # 使用生成的 Token 启动 Agent（使用 channelName 作为 Agent name）
        print(f"[INFO] Starting agent for app_id={app_id}, channel={channel_name}...")
        agent_data = server.start_agent(
            name=channel_name,  # 使用 channelName 作为 Agent name
            agent_rtc_uid=agent_rtc_uid,
            token=token,
            channel=channel_name,
            remote_rtc_uids=remote_rtc_uids
        )
        
        # 存储 agent ID 用于跟踪
        agent_id = agent_data.get("agent_id", "")
        active_agents[channel_name] = agent_id
        
        print(f"[INFO] Agent started successfully. Agent ID: {agent_id}")
        
        # 返回统一格式：成功
        return jsonify({
            "code": 0,
            "msg": "",
            "data": agent_data
        })
        
    except Exception as e:
        # 统一错误处理
        error_msg = str(e)
        print(f"[ERROR] Error: {error_msg}")
        import traceback
        error_trace = traceback.format_exc()
        print(f"[ERROR] Traceback:\n{error_trace}")
        return jsonify({
            "code": 1,
            "msg": error_msg,
            "data": None
        }), 200


@app.route('/agent/stop', methods=['POST'])
def stop_agent():
    """
    停止一个 Agora 对话式 AI Agent
    服务器端配置（basic_key, basic_secret）从本地环境变量加载
    客户端配置（appid）在请求体中提供
    
    请求体 (JSON):
    {
        "appid": "YOUR_APP_ID",    // 必需：来自客户端
        "agent_id": "agent_id"     // 必需：要停止的 Agent ID
    }
    
    响应 (JSON):
    {
        "message": "Agent stopped successfully",
        "agent_id": "agent_id"
    }
    """
    try:
        # 验证服务器端配置
        validate_server_config()
        
        # 解析请求体
        data = request.get_json()
        if not data:
            return jsonify({
                "code": 1,
                "msg": "Request body is required",
                "data": None
            }), 200
        
        # 提取客户端配置
        app_id = data.get("appid", "").strip()
        agent_id = data.get("agent_id", "").strip()
        
        # 验证必需参数
        if not app_id:
            return jsonify({
                "code": 1,
                "msg": "appid is required in request body",
                "data": None
            }), 200
        if not agent_id:
            return jsonify({
                "code": 1,
                "msg": "agent_id is required in request body",
                "data": None
            }), 200
        
        # 创建 AgoraStarterServer 实例
        # 注意：停止命令不需要 pipeline_id 和 channel_name，传入空字符串作为占位符
        server = AgoraStarterServer(
            app_id=app_id,
            basic_key=SERVER_BASIC_KEY,
            basic_secret=SERVER_BASIC_SECRET,
            pipeline_id="",  # 占位符，停止 Agent 不需要 Pipeline ID
            channel_name="",  # 占位符，停止 Agent 不需要 channel_name
            app_cert=None
        )
        
        # 停止 Agent
        print(f"[INFO] Stopping agent: app_id={app_id}, agent_id={agent_id}...")
        server.stop_agent(agent_id)
        
        # 从活跃 Agent 中移除（通过 agent_id 查找 channel_name）
        channel_to_remove = None
        for channel_name, stored_agent_id in active_agents.items():
            if stored_agent_id == agent_id:
                channel_to_remove = channel_name
                break
        
        if channel_to_remove:
            del active_agents[channel_to_remove]
        
        print(f"[INFO] Agent stopped successfully. Agent ID: {agent_id}")
        
        # 返回统一格式：成功
        return jsonify({
            "code": 0,
            "msg": "",
            "data": None
        })
        
    except Exception as e:
        # 统一错误处理
        error_msg = str(e)
        print(f"[ERROR] Error: {error_msg}")
        import traceback
        error_trace = traceback.format_exc()
        print(f"[ERROR] Traceback:\n{error_trace}")
        return jsonify({
            "code": 1,
            "msg": error_msg,
            "data": None
        }), 200


def get_local_ip_address():
    """
    获取可以从其他设备访问的主要本地 IP 地址
    返回单个 IP 地址（排除回环、VPN 和虚拟接口）
    
    此方法通过连接到远程地址来确定用于互联网访问的网络接口，
    这通常是客户端应该使用的接口。
    """
    try:
        # 连接到远程地址以确定主要网络接口
        # 这是最可靠的方法，因为它返回实际用于互联网连接的接口的 IP
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            # 连接到远程地址（实际上不发送数据）
            s.connect(("8.8.8.8", 80))
            local_ip = s.getsockname()[0]
            if local_ip and local_ip != "127.0.0.1":
                return local_ip
        except Exception:
            pass
        finally:
            s.close()
    except Exception:
        pass
    
    # 回退：如果上述方法失败，返回 None
    # 用户需要手动查找 IP
    return None


def print_connection_info(port: int):
    """
    打印客户端连接信息
    """
    local_ip = get_local_ip_address()
    print(f"\nServer URL: http://localhost:{port}")
    if local_ip:
        print(f"Network URL: http://{local_ip}:{port}")


if __name__ == '__main__':
    # 启动前验证服务器端配置
    try:
        validate_server_config()
    except ValueError as e:
        print(f"[ERROR] Server configuration error: {e}", file=sys.stderr)
        print(f"\n💡 请在 .env.local 文件中设置以下环境变量：", file=sys.stderr)
        print(f"   AGORA_BASIC_KEY=<your_basic_key>", file=sys.stderr)
        print(f"   AGORA_BASIC_SECRET=<your_basic_secret>", file=sys.stderr)
        print(f"   AGORA_PIPELINE_ID=<your_pipeline_id>", file=sys.stderr)
        sys.exit(1)
    
    # 服务器配置
    host = "0.0.0.0"  # 监听所有网络接口
    port = 8080  # 默认端口
    
    print(f"Starting server on port {port}...")
    print_connection_info(port)
    
    try:
        app.run(host=host, port=port, debug=True)
    except OSError as e:
        if "Address already in use" in str(e) or e.errno == 48:
            print(f"\n❌ Error: Port {port} is already in use.", file=sys.stderr)
            print(f"\n💡 Solutions:", file=sys.stderr)
            print(f"  1. Use a different port:", file=sys.stderr)
            print(f"     python server_startup_lite.py --port <port>", file=sys.stderr)
            print(f"  2. Find and stop the process using port {port}:", file=sys.stderr)
            print(f"     lsof -ti:{port} | xargs kill -9", file=sys.stderr)
            sys.exit(1)
        else:
            raise
