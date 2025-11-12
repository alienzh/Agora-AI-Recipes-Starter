#!/usr/bin/env python3
"""
Agora API Client
Transparent proxy for Agora RESTful API
All headers and data are passed through from client request
"""
import json
from typing import Dict, Any
import requests


class AgoraAPIClient:
    """
    Agora API Client
    Transparent proxy for Agora RESTful API
    All headers and data are passed through from client request
    """
    
    # API 端点配置
    API_BASE_URL = "https://api.sd-rtn.com/cn/api/conversational-ai-agent/v2/projects"  # Agent 管理 API 基础 URL
    DEFAULT_TIMEOUT = 30  # 默认 HTTP 请求超时时间（秒）
    
    def __init__(self, app_id: str):
        """
        初始化 Agora API Client
        
        参数:
            app_id: Agora App ID（项目 ID）
        """
        self.app_id = app_id
    
    def _execute_join_request(
        self,
        request_body: Dict[str, Any],
        headers: Dict[str, str]
    ) -> str:
        """
        执行启动 Agent 的 HTTP 请求（透传模式）
        
        参数:
            request_body: 请求体（从客户端透传）
            headers: 请求头（从客户端透传，包含 Authorization 等）
            
        返回:
            响应文本（JSON 格式）
            
        抛出:
            RuntimeError: 如果请求失败
        """
        # 构建 API URL：POST /api/conversational-ai-agent/v2/projects/{project_id}/join/
        url = f"{self.API_BASE_URL}/{self.app_id}/join/"
        
        print(f"[DEBUG] Calling Agora API: {url}")
        print(f"[DEBUG] Request payload: {json.dumps(request_body, indent=2)}")
        print(f"[DEBUG] Request headers: {headers}")
        
        try:
            # 使用透传的 headers 和 request_body
            response = requests.post(
                url,
                json=request_body,
                headers=headers,
                timeout=self.DEFAULT_TIMEOUT
            )
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
        
        print(f"[DEBUG] Response status: {response.status_code}")
        print(f"[DEBUG] Response body: {response.text}")
        
        # 检查响应状态码
        if not response.ok:
            raise RuntimeError(
                f"Join agent error: httpCode={response.status_code}, "
                f"httpMsg={response.reason}, body={response.text}"
            )
        
        # 返回响应文本（应该是 JSON 格式，包含 agent_id, create_ts, status 等）
        return response.text
    
    def _execute_leave_request(
        self,
        agent_id: str,
        headers: Dict[str, str]
    ) -> None:
        """
        执行停止 Agent 的 HTTP 请求（透传模式）
        
        参数:
            agent_id: 要停止的 Agent ID
            headers: 请求头（从客户端透传，包含 Authorization 等）
            
        抛出:
            RuntimeError: 如果请求失败
        """
        # 构建 API URL：POST /api/conversational-ai-agent/v2/projects/{project_id}/agents/{agent_id}/leave
        url = f"{self.API_BASE_URL}/{self.app_id}/agents/{agent_id}/leave"
        
        print(f"[DEBUG] Calling Agora API: {url}")
        print(f"[DEBUG] Request payload: {{}}")
        print(f"[DEBUG] Request headers: {headers}")
        
        # 发送 POST 请求，请求体为空，使用透传的 headers
        try:
            response = requests.post(
                url,
                json={},
                headers=headers,
                timeout=self.DEFAULT_TIMEOUT
            )
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
        
        print(f"[DEBUG] Response status: {response.status_code}")
        print(f"[DEBUG] Response body: {response.text}")
        
        # 检查响应状态码
        if not response.ok:
            raise RuntimeError(
                f"Leave agent error: httpCode={response.status_code}, "
                f"httpMsg={response.reason}, body={response.text}"
            )
        
        # 关闭响应（释放资源）
        response.close()

