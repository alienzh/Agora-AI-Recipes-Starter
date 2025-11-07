#!/usr/bin/env python3
"""
Agora Agent Starter Server
A Python script to start and stop Agora conversational AI agents via REST API
"""
# 导入必要的模块
import argparse  # 用于解析命令行参数
import base64  # 用于 Base64 编码（Basic Auth 认证）
import json  # 用于处理 JSON 数据
import os  # 用于环境变量和文件操作
import sys  # 用于系统操作和退出
import time  # 用于获取时间戳（生成 token 时需要）
from typing import Optional, Dict, Any, List  # 类型提示，用于代码可读性
import requests  # HTTP 请求库，用于调用 REST API

# Load .env.local file for configuration
# Note: python-dotenv package is required, install with: pip install python-dotenv
try:
    from dotenv import load_dotenv
    load_dotenv(".env.local")
except ImportError:
    # dotenv not installed, skip loading .env.local file
    # You can still use environment variables or command line arguments
    pass


class AgoraStarterServer:
    """
    Agora Agent Starter Server 实现类
    用于管理 Agora 对话式 AI Agent 的启动、停止和 Token 生成
    """
    
    # API 端点配置
    API_BASE_URL = "https://api.sd-rtn.com/cn/api/conversational-ai-agent/v2/projects"  # Agent 管理 API 基础 URL
    TOOLBOX_SERVER_HOST = "https://service.apprtc.cn/toolbox"  # Token 生成服务的基础 URL
    JSON_MEDIA_TYPE = "application/json; charset=utf-8"  # JSON 请求的 Content-Type
    DEFAULT_CHANNEL_NAME = "default_android_channel"  # 默认频道名称
    DEFAULT_AGENT_RTC_UID = "1009527"  # 默认 Agent RTC UID
    DEFAULT_EXPIRE_SECONDS = 60 * 60 * 24  # 默认 Token 过期时间：24 小时（秒）
    DEFAULT_TIMEOUT = 30  # 默认 HTTP 请求超时时间（秒）
    
    # 默认配置（从环境变量或 .env 文件读取，如果没有则使用空字符串）
    # 优先级：命令行参数 > 环境变量/.env > 代码中的默认值
    DEFAULT_APP_ID = os.getenv("AGORA_APP_ID", "")  # 默认 App ID
    DEFAULT_APP_CERT = os.getenv("AGORA_APP_CERT", "")  # 默认 App Certificate
    DEFAULT_PIPELINE_ID = os.getenv("AGORA_PIPELINE_ID", "")  # 默认 Pipeline ID
    
    # Basic Auth 配置（从两个独立的环境变量读取）
    _BASIC_KEY = os.getenv("AGORA_BASIC_KEY", "")  # Basic Auth Key
    _BASIC_SECRET = os.getenv("AGORA_BASIC_SECRET", "")  # Basic Auth Secret
    
    def __init__(
        self,
        app_id: str,
        basic_key: str,
        basic_secret: str,
        pipeline_id: str,
        channel_name: Optional[str] = None,
        app_cert: Optional[str] = None
    ):
        """
        初始化 Agora Starter Server
        
        参数:
            app_id: Agora App ID（项目 ID）
            basic_key: Basic Auth Key
            basic_secret: Basic Auth Secret
            pipeline_id: Pipeline ID（用于启动 Agent）
            channel_name: 频道名称（可选，默认使用 DEFAULT_CHANNEL_NAME）
            app_cert: App Certificate（可选，用于生成 Token）
        """
        # 保存配置信息
        self.app_id = app_id
        self.pipeline_id = pipeline_id
        self.channel_name = channel_name or self.DEFAULT_CHANNEL_NAME  # 如果没有指定频道名，使用默认值
        self.app_cert = app_cert
        
        # 保存 Basic Auth 认证信息
        self.rest_key = basic_key
        self.rest_secret = basic_secret
        
        # 创建 HTTP 会话并配置 Basic Auth 认证
        # 参考 Android 代码中的 Base64Encoding.gen() 方法
        self.session = requests.Session()
        credentials = f"{self.rest_key}:{self.rest_secret}"  # 拼接 key:secret
        # 将 credentials 进行 Base64 编码
        encoded_credentials = base64.b64encode(credentials.encode()).decode()
        # 设置 HTTP 请求头：Authorization 使用 Basic Auth 格式，Content-Type 为 JSON
        self.session.headers.update({
            "Authorization": f"Basic {encoded_credentials}",  # Basic Auth 格式：Basic <base64_encoded_credentials>
            "Content-Type": self.JSON_MEDIA_TYPE
        })
    
    def _generate_authorization_header(self) -> str:
        """
        生成 Basic Authorization 请求头
        参考 Android 代码中的 Base64Encoding.gen() 方法
        
        返回:
            Authorization 请求头字符串，格式为 "Basic <base64_encoded_credentials>"
        """
        # 拼接 key:secret
        credentials = f"{self.rest_key}:{self.rest_secret}"
        # Base64 编码
        encoded_credentials = base64.b64encode(credentials.encode()).decode()
        # 返回 Basic Auth 格式的请求头
        return f"Basic {encoded_credentials}"
    
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
        # 构建请求体，结构参考 Android 代码
        payload = {
            "name": name,
            "pipeline_id": self.pipeline_id,
            "properties": {
                "channel": channel,
                "agent_rtc_uid": agent_rtc_uid,
                "remote_rtc_uids": remote_rtc_uids,  # 远程用户 UID 列表，["*"] 表示所有用户
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
        # 构建请求体
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
            raise RuntimeError(
                f"Join agent error: httpCode={response.status_code}, "
                f"httpMsg={response.reason}, body={response.text}"
            )
        
        # 返回响应文本（应该是 JSON 格式，包含 agent_id）
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
            raise RuntimeError(
                f"Leave agent error: httpCode={response.status_code}, "
                f"httpMsg={response.reason}, body={response.text}"
            )
        
        # 关闭响应（释放资源）
        response.close()
    
    def start_agent(
        self,
        name: str,
        agent_rtc_uid: str,
        token: str,
        channel: Optional[str] = None,
        remote_rtc_uids: Optional[List[str]] = None
    ) -> str:
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
            从响应中解析出的 Agent ID
        """
        # 使用传入的频道名或实例默认频道名
        channel = channel or self.channel_name
        # 使用传入的远程 UIDs 或默认值 ["*"]
        remote_rtc_uids = remote_rtc_uids or ["*"]
        
        # 执行启动请求
        response_text = self._execute_join_request(
            name, channel, agent_rtc_uid, token, remote_rtc_uids
        )
        
        # 解析 JSON 响应
        response_json = json.loads(response_text)
        # 提取 agent_id（参考 Android 代码中的解析逻辑）
        agent_id = response_json.get("agent_id", "")
        
        # 验证 agent_id 是否存在
        if not agent_id:
            raise RuntimeError(
                f"Failed to parse agent_id from response: {response_text}"
            )
        
        return agent_id
    
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


def main():
    """
    脚本的主入口函数
    处理命令行参数解析和命令分发
    """
    # 创建命令行参数解析器
    parser = argparse.ArgumentParser(
        description="Agora Agent Starter Server - Start and stop Agora conversational AI agents",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Start an agent (token will be generated automatically)
  # If configs are set in script, you can simply run:
  python agora_starter_server.py start
  
  # Or override with command line arguments:
  python agora_starter_server.py start \\
    --appid YOUR_APP_ID \\
    --appcert "YOUR_APP_CERTIFICATE" \\
    --basic-key YOUR_REST_KEY \\
    --basic-secret YOUR_REST_SECRET \\
    --pipeline YOUR_PIPELINE_ID \\
    --channelName "my_channel"
  
  # Stop an agent
  python agora_starter_server.py stop \\
    --appid YOUR_APP_ID \\
    --basic-key YOUR_REST_KEY \\
    --basic-secret YOUR_REST_SECRET \\
    --agent-id "agent_id_here"
        """
    )
    
    # 所有命令共用的参数（通过 parents 继承）
    common_parser = argparse.ArgumentParser(add_help=False)
    common_parser.add_argument(
        "--appid",
        default=AgoraStarterServer.DEFAULT_APP_ID,
        help=f"Agora App ID (Project ID) (optional, default: from script config)"
    )
    common_parser.add_argument(
        "--channelName",
        default=AgoraStarterServer.DEFAULT_CHANNEL_NAME,
        help=f"Channel name (optional, default: {AgoraStarterServer.DEFAULT_CHANNEL_NAME})"
    )
    common_parser.add_argument(
        "--appcert",
        default=AgoraStarterServer.DEFAULT_APP_CERT,
        help="App certificate (optional, default: from script config)"
    )
    
    # 需要 Basic Auth 的命令的参数（start 和 stop 命令需要）
    auth_parser = argparse.ArgumentParser(add_help=False)
    auth_parser.add_argument(
        "--basic-key",
        default=AgoraStarterServer._BASIC_KEY,
        help="Basic Auth Key (optional, default: from AGORA_BASIC_KEY environment variable)"
    )
    auth_parser.add_argument(
        "--basic-secret",
        default=AgoraStarterServer._BASIC_SECRET,
        help="Basic Auth Secret (optional, default: from AGORA_BASIC_SECRET environment variable)"
    )
    
    # 创建子命令解析器（支持 start、stop 两个命令）
    subparsers = parser.add_subparsers(dest="command", help="Command to execute", required=True)
    
    # 启动 Agent 命令的参数
    start_parser = subparsers.add_parser(
        "start",
        parents=[common_parser, auth_parser],  # 继承共用参数和认证参数
        help="Start an agent (token will be generated automatically)"
    )
    start_parser.add_argument(
        "--pipeline",
        default=AgoraStarterServer.DEFAULT_PIPELINE_ID,
        help="Pipeline ID (optional, default: from script config)"
    )
    start_parser.add_argument(
        "--expire",
        type=int,
        help=f"Token expiration time in seconds (optional, default: {AgoraStarterServer.DEFAULT_EXPIRE_SECONDS})"
    )
    start_parser.add_argument(
        "--remote-rtc-uids",
        nargs="+",  # 支持多个值
        default=["*"],  # 默认值：["*"] 表示所有用户
        help="Remote RTC UIDs list (default: *)"
    )
    
    # 停止 Agent 命令的参数
    stop_parser = subparsers.add_parser(
        "stop",
        parents=[common_parser, auth_parser],  # 继承共用参数和认证参数
        help="Stop an agent"
    )
    stop_parser.add_argument(
        "--agent-id",
        required=True,
        help="Agent ID to stop"
    )
    
    # 解析命令行参数
    args = parser.parse_args()
    
    try:
        # 处理启动 Agent 命令
        if args.command == "start":
            # 验证必需的配置参数
            if not args.appid:
                raise ValueError("App ID is required. Please set DEFAULT_APP_ID in script or use --appid argument")
            if not args.basic_key or not args.basic_secret:
                raise ValueError("Basic Auth Key and Secret are required. Please set AGORA_BASIC_KEY and AGORA_BASIC_SECRET in .env.local file or use --basic-key and --basic-secret arguments")
            if not args.pipeline:
                raise ValueError("Pipeline ID is required. Please set DEFAULT_PIPELINE_ID in script or use --pipeline argument")
            
            # 默认使用 RTC 和 RTM Token（参考 Android 代码中的默认行为）
            token_types = [1, 2]  # 1=RTC, 2=RTM
            
            # 使用默认的 Agent RTC UID
            agent_rtc_uid = AgoraStarterServer.DEFAULT_AGENT_RTC_UID
            
            # 创建 AgoraStarterServer 实例（用于生成 Token，不需要 basic_key/basic_secret 和 pipeline_id）
            token_server = AgoraStarterServer(
                app_id=args.appid,
                basic_key="dummy",  # 占位符，生成 Token 不需要 Basic Auth
                basic_secret="dummy",  # 占位符，生成 Token 不需要 Basic Auth
                pipeline_id="",  # 占位符，生成 Token 不需要 Pipeline ID
                channel_name=args.channelName,
                app_cert=args.appcert
            )
            
            # 先自动生成 Token
            print("Generating token...")
            token = token_server.generate_token(
                channel_name=args.channelName,
                uid=agent_rtc_uid,
                token_types=token_types,
                expire_seconds=args.expire
            )
            print(f"Token generated successfully")
            
            # 创建用于启动 Agent 的 AgoraStarterServer 实例
            server = AgoraStarterServer(
                app_id=args.appid,
                basic_key=args.basic_key,
                basic_secret=args.basic_secret,
                pipeline_id=args.pipeline,
                channel_name=args.channelName,
                app_cert=args.appcert
            )
            
            # 使用生成的 Token 启动 Agent（使用 channelName 作为 Agent name）
            print("Starting agent...")
            agent_id = server.start_agent(
                name=args.channelName,  # 使用 channelName 作为 Agent name
                agent_rtc_uid=agent_rtc_uid,
                token=token,
                channel=args.channelName,
                remote_rtc_uids=args.remote_rtc_uids
            )
            
            # 输出结果
            print(f"Agent started successfully. Agent ID: {agent_id}")
            sys.exit(0)
            
        # 处理停止 Agent 命令
        elif args.command == "stop":
            # 验证必需的配置参数
            if not args.appid:
                raise ValueError("App ID is required. Please set DEFAULT_APP_ID in script or use --appid argument")
            if not args.basic_key or not args.basic_secret:
                raise ValueError("Basic Auth Key and Secret are required. Please set AGORA_BASIC_KEY and AGORA_BASIC_SECRET in .env.local file or use --basic-key and --basic-secret arguments")
            
            # 创建 AgoraStarterServer 实例
            # 注意：停止命令不需要 pipeline_id
            server = AgoraStarterServer(
                app_id=args.appid,
                basic_key=args.basic_key,
                basic_secret=args.basic_secret,
                pipeline_id="",  # 占位符，停止 Agent 不需要 Pipeline ID
                channel_name=args.channelName,
                app_cert=args.appcert
            )
            
            # 停止 Agent
            server.stop_agent(args.agent_id)
            print(f"Agent stopped successfully. Agent ID: {args.agent_id}")
            sys.exit(0)
            
    # 异常处理
    except ValueError as e:
        # 参数值错误（如 basic_auth 格式错误）
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except RuntimeError as e:
        # 运行时错误（如 API 请求失败）
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    except Exception as e:
        # 其他未预期的错误
        print(f"Unexpected error: {e}", file=sys.stderr)
        sys.exit(1)


# 脚本入口：当直接运行此脚本时执行 main() 函数
if __name__ == "__main__":
    main()

