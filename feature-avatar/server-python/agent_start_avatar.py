#!/usr/bin/env python3
"""
Agora Agent Starter Script (Avatar)
命令行脚本，用于启动和停止 Agora 对话式 AI Agent（数字人版本）
所有配置从本地环境变量加载（.env.local 文件）
"""
import argparse
import base64
import json
import os
import sys
import time
from typing import Optional, Dict, Any, List

# 检查必需的依赖包
try:
    import requests
except ImportError:
    print("[ERROR] 缺少必需的依赖包: requests", file=sys.stderr)
    print("[ERROR] 请安装依赖包:", file=sys.stderr)
    print("[ERROR]   pip install -r requirements.txt", file=sys.stderr)
    print("[ERROR]   或: pip install requests python-dotenv", file=sys.stderr)
    sys.exit(1)

class AgoraStarterServer:
    """
    Agora Agent Starter Server 实现类（数字人版本）
    用于管理 Agora 对话式 AI Agent 的启动、停止和 Token 生成
    支持数字人（Avatar）功能
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
        remote_rtc_uids: List[str],
        avatar_rtc_uid: Optional[str] = None,
        avatar_rtc_token: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        构建启动 Agent 的 JSON 请求体（数字人版本）
        参考 Android 代码中的 buildJsonPayload() 方法
        
        参数:
            name: Agent 名称
            channel: 频道名称
            agent_rtc_uid: Agent 的 RTC UID
            token: Token 字符串
            remote_rtc_uids: 远程 RTC UIDs 列表
            avatar_rtc_uid: Avatar 的 RTC UID（可选，用于数字人功能）
            avatar_rtc_token: Avatar 的 RTC Token（可选，用于数字人功能）
            
        返回:
            表示 JSON 请求体的字典
        """
        properties = {
            "channel": channel,
            "agent_rtc_uid": agent_rtc_uid,
            "remote_rtc_uids": remote_rtc_uids,  # ["*"] 表示所有用户
            "token": token,
            "parameters": {
                "transcript": {
                    "enable_words": False
                }
            }
        }
        
        # 添加 Avatar 配置（如果提供了 avatar_rtc_uid 和 avatar_rtc_token）
        if avatar_rtc_uid and avatar_rtc_token:
            properties["avatar"] = {
                "params": {
                    "agora_uid": avatar_rtc_uid,
                    "agora_token": avatar_rtc_token
                }
            }
        
        payload = {
            "name": name,
            "pipeline_id": self.pipeline_id,
            "properties": properties
        }
        return payload
    
    def _execute_join_request(
        self,
        name: str,
        channel: str,
        agent_rtc_uid: str,
        token: str,
        remote_rtc_uids: List[str],
        avatar_rtc_uid: Optional[str] = None,
        avatar_rtc_token: Optional[str] = None
    ) -> str:
        """
        执行启动 Agent 的 HTTP 请求（数字人版本）
        参考 Android 代码中的 executeJoinRequest() 方法
        
        参数:
            name: Agent 名称
            channel: 频道名称
            agent_rtc_uid: Agent 的 RTC UID
            token: Token 字符串
            remote_rtc_uids: 远程 RTC UIDs 列表
            avatar_rtc_uid: Avatar 的 RTC UID（可选）
            avatar_rtc_token: Avatar 的 RTC Token（可选）
            
        返回:
            响应文本（JSON 格式）
            
        抛出:
            RuntimeError: 如果请求失败
        """
        # 构建 API URL：POST /api/conversational-ai-agent/v2/projects/{project_id}/join/
        url = f"{self.API_BASE_URL}/{self.app_id}/join/"
        payload = self._build_json_payload(
            name, channel, agent_rtc_uid, token, remote_rtc_uids,
            avatar_rtc_uid, avatar_rtc_token
        )
        
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
                elif "message" in error_body:
                    error_detail = error_body["message"]
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
        remote_rtc_uids: Optional[List[str]] = None,
        avatar_rtc_uid: Optional[str] = None,
        avatar_rtc_token: Optional[str] = None
    ) -> Dict[str, Any]:
        """
        启动一个 Agent（数字人版本）
        参考 Android 代码中的 startAgentAsync() 方法
        
        参数:
            name: Agent 名称
            agent_rtc_uid: Agent 的 RTC UID
            token: Token 字符串
            channel: 频道名称（可选，如果不提供则使用实例默认值）
            remote_rtc_uids: 远程 RTC UIDs 列表（可选，默认为 ["*"] 表示所有用户）
            avatar_rtc_uid: Avatar 的 RTC UID（可选，用于数字人功能）
            avatar_rtc_token: Avatar 的 RTC Token（可选，用于数字人功能）
            
        返回:
            Agora API 返回的完整响应（包含 agent_id, create_ts, status）
        """
        # 使用传入的频道名或实例默认频道名
        channel = channel or self.channel_name
        # 使用传入的远程 UIDs 或默认值 ["*"]
        remote_rtc_uids = remote_rtc_uids or ["*"]
        
        # 执行启动请求
        response_text = self._execute_join_request(
            name, channel, agent_rtc_uid, token, remote_rtc_uids,
            avatar_rtc_uid, avatar_rtc_token
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


# 存储 agent_id 的文件路径
AGENT_ID_FILE = ".agent_id"


def save_agent_id(agent_id: str):
    """保存 agent_id 到文件"""
    try:
        # 获取脚本所在目录的绝对路径
        script_dir = os.path.dirname(os.path.abspath(__file__))
        agent_id_path = os.path.join(script_dir, AGENT_ID_FILE)
        with open(agent_id_path, 'w') as f:
            f.write(agent_id)
    except Exception as e:
        print(f"[WARN] 无法保存 agent_id 到文件: {e}", file=sys.stderr)


def load_agent_id() -> Optional[str]:
    """从文件加载 agent_id"""
    try:
        # 获取脚本所在目录的绝对路径
        script_dir = os.path.dirname(os.path.abspath(__file__))
        agent_id_path = os.path.join(script_dir, AGENT_ID_FILE)
        if os.path.exists(agent_id_path):
            with open(agent_id_path, 'r') as f:
                return f.read().strip()
    except Exception as e:
        print(f"[WARN] 无法从文件读取 agent_id: {e}", file=sys.stderr)
    return None


def delete_agent_id():
    """删除 agent_id 文件"""
    try:
        # 获取脚本所在目录的绝对路径
        script_dir = os.path.dirname(os.path.abspath(__file__))
        agent_id_path = os.path.join(script_dir, AGENT_ID_FILE)
        if os.path.exists(agent_id_path):
            os.remove(agent_id_path)
    except Exception as e:
        print(f"[WARN] 无法删除 agent_id 文件: {e}", file=sys.stderr)


def load_config():
    """
    从环境变量加载配置
    返回配置字典
    """
    return {
        "BASIC_KEY": os.getenv("AGORA_BASIC_KEY", ""),
        "BASIC_SECRET": os.getenv("AGORA_BASIC_SECRET", ""),
        "PIPELINE_ID": os.getenv("AGORA_PIPELINE_ID", ""),
        "APP_ID": os.getenv("AGORA_APP_ID", ""),
        "APP_CERT": os.getenv("AGORA_APP_CERT", ""),
        "CHANNEL_NAME": os.getenv("AGORA_CHANNEL_NAME", "")
    }


def validate_config(config: Dict[str, str]):
    """
    验证配置是否可用
    如果缺少必需的配置，抛出 ValueError
    
    参数:
        config: 配置字典
    """
    missing = []
    if not config.get("BASIC_KEY") or not config.get("BASIC_SECRET"):
        missing.append("AGORA_BASIC_KEY 和 AGORA_BASIC_SECRET")
    if not config.get("PIPELINE_ID"):
        missing.append("AGORA_PIPELINE_ID")
    if not config.get("APP_ID"):
        missing.append("AGORA_APP_ID")
    if not config.get("CHANNEL_NAME"):
        missing.append("AGORA_CHANNEL_NAME")
    
    if missing:
        error_msg = f"配置缺失：{', '.join(missing)} 必须在 .env.local 文件或环境变量中设置"
        raise ValueError(error_msg)


def cmd_start_agent(config: Dict[str, str]):
    """
    启动 Agent 的命令行函数（数字人版本）
    默认启用数字人功能
    
    参数:
        config: 配置字典
    """
    try:
        # Fixed RTC UIDs (hardcoded values used by client)
        # current_rtc_uid: Client uses this UID to join the channel
        # agent_rtc_uid: Agent RTC UID
        # avatar_rtc_uid: Avatar RTC UID
        current_rtc_uid = "1001"
        agent_rtc_uid = "2001"
        avatar_rtc_uid = "3001"
        
        # 验证基本配置
        validate_config(config)
        
        app_id = config["APP_ID"].strip()
        app_cert = config.get("APP_CERT", "").strip()
        channel_name = config["CHANNEL_NAME"].strip()
        basic_key = config["BASIC_KEY"].strip()
        basic_secret = config["BASIC_SECRET"].strip()
        pipeline_id = config["PIPELINE_ID"].strip()
        
        # 默认 token 类型：RTC 和 RTM
        token_types = [1, 2]  # 1=RTC, 2=RTM
        
        # 创建 AgoraStarterServer 实例（用于生成 Token）
        token_server = AgoraStarterServer(
            app_id=app_id,
            basic_key="dummy",  # 占位符，生成 Token 不需要 Basic Auth
            basic_secret="dummy",  # 占位符，生成 Token 不需要 Basic Auth
            pipeline_id="",  # 占位符，生成 Token 不需要 Pipeline ID
            channel_name=channel_name,
            app_cert=app_cert if app_cert else None
        )
        
        # 生成 Agent Token
        print(f"[INFO] 正在生成 Agent Token (app_id={app_id}, channel={channel_name})...")
        agent_token = token_server.generate_token(
            channel_name=channel_name,
            uid=agent_rtc_uid,
            token_types=token_types
        )
        print(f"[INFO] Agent Token 生成成功")
        
        # 生成 Avatar Token（数字人功能默认启用）
        print(f"[INFO] 正在生成 Avatar Token (app_id={app_id}, channel={channel_name}, uid={avatar_rtc_uid})...")
        avatar_token = token_server.generate_token(
            channel_name=channel_name,
            uid=avatar_rtc_uid,
            token_types=token_types
        )
        print(f"[INFO] Avatar Token 生成成功")
        
        # 创建用于启动 Agent 的 AgoraStarterServer 实例
        server = AgoraStarterServer(
            app_id=app_id,
            basic_key=basic_key,
            basic_secret=basic_secret,
            pipeline_id=pipeline_id,
            channel_name=channel_name,
            app_cert=app_cert if app_cert else None
        )
        
        # 启动 Agent（数字人模式）
        # 注意：启用 Avatar 时，不能使用 ["*"] 订阅所有用户，必须指定具体的 UID
        remote_rtc_uids = [current_rtc_uid]
        
        print(f"[INFO] 正在启动 Agent（数字人模式）(app_id={app_id}, channel={channel_name})...")
        print(f"[INFO] Agent RTC UID: {agent_rtc_uid}")
        print(f"[INFO] Avatar RTC UID: {avatar_rtc_uid}")
        print(f"[INFO] Current RTC UID (客户端使用): {current_rtc_uid}")
        
        agent_data = server.start_agent(
            name=channel_name,
            agent_rtc_uid=agent_rtc_uid,
            token=agent_token,
            channel=channel_name,
            remote_rtc_uids=remote_rtc_uids,
            avatar_rtc_uid=avatar_rtc_uid,
            avatar_rtc_token=avatar_token
        )
        
        agent_id = agent_data.get("agent_id", "")
        if not agent_id:
            raise RuntimeError("无法从响应中获取 agent_id")
        
        # 保存 agent_id 供下次使用
        save_agent_id(agent_id)
        
        print(f"[INFO] Agent 启动成功！")
        print(f"[INFO] Agent ID: {agent_id}")
        print(f"[INFO] Channel: {channel_name}")
        print(f"[INFO] Agent RTC UID: {agent_rtc_uid}")
        print(f"[INFO] Avatar RTC UID: {avatar_rtc_uid}")
        print(f"[INFO] Current RTC UID (客户端使用此 UID 加入频道): {current_rtc_uid}")
        print(f"\n💡 现在可以打开应用，使用 UID {current_rtc_uid} 加入频道 {channel_name} 来体验对话式 AI（数字人）")
        
        return 0
        
    except Exception as e:
        print(f"[ERROR] 启动 Agent 失败: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return 1


def cmd_stop_agent(config: Dict[str, str], agent_id: Optional[str] = None):
    """
    停止 Agent 的命令行函数
    """
    try:
        # 验证配置（停止只需要 basic_key 和 basic_secret）
        basic_key = config.get("BASIC_KEY", "")
        basic_secret = config.get("BASIC_SECRET", "")
        app_id = config.get("APP_ID", "")
        
        if not basic_key or not basic_secret:
            raise ValueError("配置缺失：AGORA_BASIC_KEY 和 AGORA_BASIC_SECRET 必须在 .env.local 文件或环境变量中设置")
        if not app_id:
            raise ValueError("配置缺失：AGORA_APP_ID 必须在 .env.local 文件或环境变量中设置")
        
        # 如果没有提供 agent_id，尝试从文件加载上一次的
        if not agent_id:
            agent_id = load_agent_id()
            if not agent_id:
                print("[ERROR] 未找到 agent_id。", file=sys.stderr)
                print("[ERROR] 请提供 --agent-id 参数，或确保之前已成功启动过 Agent。", file=sys.stderr)
                print("[ERROR] 使用方式: python agent_start_avatar.py stop --agent-id <agent_id>", file=sys.stderr)
                return 1
            print(f"[INFO] 使用上一次的 Agent ID: {agent_id}")
        
        # 创建 AgoraStarterServer 实例
        server = AgoraStarterServer(
            app_id=app_id,
            basic_key=basic_key,
            basic_secret=basic_secret,
            pipeline_id="",  # 占位符，停止 Agent 不需要 Pipeline ID
            channel_name="",  # 占位符，停止 Agent 不需要 channel_name
            app_cert=None
        )
        
        # 停止 Agent
        print(f"[INFO] 正在停止 Agent (agent_id={agent_id})...")
        server.stop_agent(agent_id)
        
        # 删除保存的 agent_id 文件
        delete_agent_id()
        
        print(f"[INFO] Agent 停止成功！")
        return 0
        
    except Exception as e:
        print(f"[ERROR] 停止 Agent 失败: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return 1


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='Agora Agent Starter Script (Avatar) - 启动和停止 Agora 对话式 AI Agent（数字人版本）'
    )
    subparsers = parser.add_subparsers(dest='command', help='可用命令')
    
    # start 命令
    start_parser = subparsers.add_parser('start', help='启动 Agent（数字人模式，默认启用）')
    
    # stop 命令
    stop_parser = subparsers.add_parser('stop', help='停止 Agent')
    stop_parser.add_argument(
        '--agent-id',
        type=str,
        default=None,
        metavar='AGENT_ID',
        help='Agent ID（可选，如果不提供则使用上一次启动的 Agent ID）'
    )
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        sys.exit(1)
    
    # 检查并加载 .env.local 文件
    dotenv_available = False
    try:
        from dotenv import load_dotenv
        dotenv_available = True
        # 获取脚本所在目录的绝对路径，然后加载 .env.local 文件
        script_dir = os.path.dirname(os.path.abspath(__file__))
        env_path = os.path.join(script_dir, ".env.local")
        load_dotenv(env_path)
    except ImportError:
        print("[WARN] python-dotenv 未安装，将不会加载 .env.local 文件。", file=sys.stderr)
        print("[WARN] 您仍可使用环境变量，或安装 python-dotenv:", file=sys.stderr)
        print("[WARN]   pip install python-dotenv", file=sys.stderr)
    
    # 加载配置
    config = load_config()
    
    # 执行命令
    if args.command == 'start':
        sys.exit(cmd_start_agent(config))
    elif args.command == 'stop':
        sys.exit(cmd_stop_agent(config, args.agent_id))

