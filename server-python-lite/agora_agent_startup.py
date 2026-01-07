#!/usr/bin/env python3
"""
Agora Agent Starter Script (Lite)
Command-line script for starting and stopping Agora Conversational AI Agent
All configuration is loaded from local environment variables (.env.local file)
"""
import argparse
import base64
import json
import os
import sys
import time
from typing import Optional, Dict, Any, List
import requests

# Load .env.local file to get configuration
# Note: Requires python-dotenv package, install with: pip install python-dotenv
try:
    from dotenv import load_dotenv
    load_dotenv(".env.local")
except ImportError:
    # dotenv not installed, skip loading .env.local file
    # Can still use environment variables
    pass


class AgoraStarterServer:
    """
    Agora Agent Starter Server implementation class
    Used to manage Agora Conversational AI Agent startup, shutdown, and Token generation
    """
    
    # API endpoint configuration
    API_BASE_URL = "https://api.sd-rtn.com/cn/api/conversational-ai-agent/v2/projects"
    TOOLBOX_SERVER_HOST = "https://service.apprtc.cn/toolbox"
    JSON_MEDIA_TYPE = "application/json; charset=utf-8"
    DEFAULT_EXPIRE_SECONDS = 60 * 60 * 24  # Default token expiration time: 24 hours (in seconds)
    DEFAULT_TIMEOUT = 30  # Default HTTP request timeout (in seconds)
    
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
        Initialize Agora Starter Server
        
        Args:
            app_id: Agora App ID (Project ID)
            basic_key: Basic Auth Key
            basic_secret: Basic Auth Secret
            pipeline_id: Pipeline ID (used to start Agent)
            channel_name: Channel name
            app_cert: App Certificate (optional, used to generate Token)
        """
        # Save configuration information
        self.app_id = app_id
        self.pipeline_id = pipeline_id
        self.channel_name = channel_name
        self.app_cert = app_cert
        
        # Save Basic Auth credentials
        self.rest_key = basic_key
        self.rest_secret = basic_secret
        
        # Create HTTP session and configure Basic Auth
        # Reference: Base64Encoding.gen() method in Android code
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
        Build JSON request body for starting Agent
        Reference: buildJsonPayload() method in Android code
        
        Args:
            name: Agent name
            channel: Channel name
            agent_rtc_uid: Agent RTC UID
            token: Token string
            remote_rtc_uids: List of remote RTC UIDs
            
        Returns:
            Dictionary representing JSON request body
        """
        payload = {
            "name": name,
            "pipeline_id": self.pipeline_id,
            "properties": {
                "channel": channel,
                "agent_rtc_uid": agent_rtc_uid,
                "remote_rtc_uids": remote_rtc_uids,  # ["*"] means all users
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
        Execute HTTP request to start Agent
        Reference: executeJoinRequest() method in Android code
        
        Args:
            name: Agent name
            channel: Channel name
            agent_rtc_uid: Agent RTC UID
            token: Token string
            remote_rtc_uids: List of remote RTC UIDs
            
        Returns:
            Response text (JSON format)
            
        Raises:
            RuntimeError: If request fails
        """
        # Build API URL: POST /api/conversational-ai-agent/v2/projects/{project_id}/join/
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
        
        # Check response status code
        if not response.ok:
            # Try to parse detail from error response
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
        
        # Return response text (should be JSON format, containing agent_id, create_ts, status)
        return response.text
    
    def _execute_leave_request(self, agent_id: str) -> None:
        """
        Execute HTTP request to stop Agent
        Reference: executeLeaveRequest() method in Android code
        
        Args:
            agent_id: Agent ID to stop
            
        Raises:
            RuntimeError: If request fails
        """
        # Build API URL: POST /api/conversational-ai-agent/v2/projects/{project_id}/agents/{agent_id}/leave
        url = f"{self.API_BASE_URL}/{self.app_id}/agents/{agent_id}/leave"
        
        # Send POST request with empty JSON object as body (reference Android code)
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
        
        # Check response status code
        if not response.ok:
            # Try to parse detail from error response
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
        
        # Close response (release resources)
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
        Start an Agent
        Reference: startAgentAsync() method in Android code
        
        Args:
            name: Agent name
            agent_rtc_uid: Agent RTC UID
            token: Token string
            channel: Channel name (optional, uses instance default if not provided)
            remote_rtc_uids: List of remote RTC UIDs (optional, defaults to ["*"] for all users)
            
        Returns:
            Complete response from Agora API (containing agent_id, create_ts, status)
        """
        # Use provided channel name or instance default channel name
        channel = channel or self.channel_name
        # Use provided remote UIDs or default value ["*"]
        remote_rtc_uids = remote_rtc_uids or ["*"]
        
        # Execute start request
        response_text = self._execute_join_request(
            name, channel, agent_rtc_uid, token, remote_rtc_uids
        )
        
        # Parse JSON response and return complete data
        response_json = json.loads(response_text)
        
        # Verify agent_id exists
        agent_id = response_json.get("agent_id", "")
        if not agent_id:
            raise RuntimeError(
                f"Failed to parse agent_id from response: {response_text}"
            )
        
        return response_json
    
    def stop_agent(self, agent_id: str) -> None:
        """
        Stop an Agent
        Reference: stopAgentAsync() method in Android code
        
        Args:
            agent_id: Agent ID to stop
        """
        # Execute stop request
        self._execute_leave_request(agent_id)
    
    def generate_token(
        self,
        channel_name: str,
        uid: str,
        token_types: List[int],
        expire_seconds: Optional[int] = None
    ) -> str:
        """
        Generate RTC/RTM/Chat Token
        Reference: TokenGenerator.fetchToken() method in Android code
        
        Args:
            channel_name: Channel name
            uid: User ID (Agent RTC UID)
            token_types: List of token types (1=Rtc, 2=Rtm, 3=Chat)
            expire_seconds: Expiration time in seconds (optional, default 24 hours)
            
        Returns:
            Token string
            
        Raises:
            RuntimeError: If token generation fails
        """
        # Use provided expiration time or default value (24 hours)
        expire = expire_seconds if expire_seconds and expire_seconds > 0 else self.DEFAULT_EXPIRE_SECONDS
        
        # Build request body (reference buildJsonRequest() method in Android code)
        payload = {
            "appId": self.app_id,
            "appCertificate": self.app_cert or "",  # App Certificate (optional)
            "channelName": channel_name,
            "expire": expire,  # Expiration time (in seconds)
            "src": "Python",  # Source identifier ("Android" in Android code)
            "ts": str(int(time.time() * 1000)),  # Current timestamp (in milliseconds)
            "uid": uid
        }
        
        # Add token types (reference logic in Android code)
        # If only one type, use "type" field; if multiple types, use "types" array
        if len(token_types) == 1:
            payload["type"] = token_types[0]
        else:
            payload["types"] = token_types
        
        # Build token generation API URL
        url = f"{self.TOOLBOX_SERVER_HOST}/v2/token/generate"
        
        # Create independent HTTP session (token generation doesn't require Basic Auth)
        token_session = requests.Session()
        token_session.headers.update({
            "Content-Type": "application/json"
        })
        
        # Send POST request
        response = token_session.post(url, json=payload)
        
        # Check HTTP status code
        if not response.ok:
            raise RuntimeError(
                f"Fetch token error: httpCode={response.status_code}, "
                f"httpMsg={response.reason}, body={response.text}"
            )
        
        # Parse JSON response
        response_body = response.json()
        
        # Check response code (reference error checking in Android code)
        # Response format: {"code": 0, "message": "...", "data": {"token": "..."}}
        if response_body.get("code", -1) != 0:
            raise RuntimeError(
                f"Fetch token error: httpCode={response.status_code}, "
                f"httpMsg={response.reason}, "
                f"reqCode={response_body.get('code')}, "
                f"reqMsg={response_body.get('message')}"
            )
        
        # Extract token from response (reference Android code: bodyJson.getJSONObject("data").getString("token"))
        data = response_body.get("data", {})
        token = data.get("token", "")
        
        # Verify token exists
        if not token:
            raise RuntimeError(
                f"Failed to parse token from response: {response.text}"
            )
        
        return token


# File path for storing agent_id
AGENT_ID_FILE = ".agent_id"


def save_agent_id(agent_id: str):
    """Save agent_id to file"""
    try:
        # Get absolute path of script directory
        script_dir = os.path.dirname(os.path.abspath(__file__))
        agent_id_path = os.path.join(script_dir, AGENT_ID_FILE)
        with open(agent_id_path, 'w') as f:
            f.write(agent_id)
    except Exception as e:
        print(f"[WARN] Failed to save agent_id to file: {e}", file=sys.stderr)


def load_agent_id() -> Optional[str]:
    """Load agent_id from file"""
    try:
        # Get absolute path of script directory
        script_dir = os.path.dirname(os.path.abspath(__file__))
        agent_id_path = os.path.join(script_dir, AGENT_ID_FILE)
        if os.path.exists(agent_id_path):
            with open(agent_id_path, 'r') as f:
                return f.read().strip()
    except Exception as e:
        print(f"[WARN] Failed to read agent_id from file: {e}", file=sys.stderr)
    return None


def delete_agent_id():
    """Delete agent_id file"""
    try:
        # Get absolute path of script directory
        script_dir = os.path.dirname(os.path.abspath(__file__))
        agent_id_path = os.path.join(script_dir, AGENT_ID_FILE)
        if os.path.exists(agent_id_path):
            os.remove(agent_id_path)
    except Exception as e:
        print(f"[WARN] Failed to delete agent_id file: {e}", file=sys.stderr)


def load_config():
    """
    Load configuration from environment variables
    Returns configuration dictionary
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
    Validate configuration is available
    Raises ValueError if required configuration is missing
    """
    missing = []
    if not config.get("BASIC_KEY") or not config.get("BASIC_SECRET"):
        missing.append("AGORA_BASIC_KEY and AGORA_BASIC_SECRET")
    if not config.get("PIPELINE_ID"):
        missing.append("AGORA_PIPELINE_ID")
    if not config.get("APP_ID"):
        missing.append("AGORA_APP_ID")
    if not config.get("CHANNEL_NAME"):
        missing.append("AGORA_CHANNEL_NAME")
    
    if missing:
        raise ValueError(
            f"Missing configuration: {', '.join(missing)} "
            "must be set in .env.local file or environment variables"
        )


def cmd_start_agent(config: Dict[str, str], agent_rtc_uid: str = "1009527"):
    """
    Command-line function to start Agent
    """
    try:
        # Validate configuration
        validate_config(config)
        
        app_id = config["APP_ID"].strip()
        app_cert = config.get("APP_CERT", "").strip()
        channel_name = config["CHANNEL_NAME"].strip()
        basic_key = config["BASIC_KEY"].strip()
        basic_secret = config["BASIC_SECRET"].strip()
        pipeline_id = config["PIPELINE_ID"].strip()
        
        # Default token types: RTC and RTM
        token_types = [1, 2]  # 1=RTC, 2=RTM
        
        # Create AgoraStarterServer instance (for token generation)
        token_server = AgoraStarterServer(
            app_id=app_id,
            basic_key="dummy",  # Placeholder, token generation doesn't require Basic Auth
            basic_secret="dummy",  # Placeholder, token generation doesn't require Basic Auth
            pipeline_id="",  # Placeholder, token generation doesn't require Pipeline ID
            channel_name=channel_name,
            app_cert=app_cert if app_cert else None
        )
        
        # Generate token
        print(f"[INFO] Generating token (app_id={app_id}, channel={channel_name})...")
        token = token_server.generate_token(
            channel_name=channel_name,
            uid=agent_rtc_uid,
            token_types=token_types
        )
        print(f"[INFO] Token generated successfully")
        
        # Create AgoraStarterServer instance for starting Agent
        server = AgoraStarterServer(
            app_id=app_id,
            basic_key=basic_key,
            basic_secret=basic_secret,
            pipeline_id=pipeline_id,
            channel_name=channel_name,
            app_cert=app_cert if app_cert else None
        )
        
        # Start Agent
        print(f"[INFO] Starting Agent (app_id={app_id}, channel={channel_name})...")
        agent_data = server.start_agent(
            name=channel_name,
            agent_rtc_uid=agent_rtc_uid,
            token=token,
            channel=channel_name
        )
        
        agent_id = agent_data.get("agent_id", "")
        if not agent_id:
            raise RuntimeError("Failed to get agent_id from response")
        
        # Save agent_id for next use
        save_agent_id(agent_id)
        
        print(f"[INFO] Agent started successfully!")
        print(f"[INFO] Agent ID: {agent_id}")
        print(f"[INFO] Channel: {channel_name}")
        print(f"[INFO] Agent RTC UID: {agent_rtc_uid}")
        print(f"\n💡 You can now open the Web app and join channel {channel_name} to experience Conversational AI")
        
        return 0
        
    except Exception as e:
        print(f"[ERROR] Failed to start Agent: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return 1


def cmd_stop_agent(config: Dict[str, str], agent_id: Optional[str] = None):
    """
    Command-line function to stop Agent
    """
    try:
        # Validate configuration (stopping only requires basic_key and basic_secret)
        basic_key = config.get("BASIC_KEY", "")
        basic_secret = config.get("BASIC_SECRET", "")
        app_id = config.get("APP_ID", "")
        
        if not basic_key or not basic_secret:
            raise ValueError("Missing configuration: AGORA_BASIC_KEY and AGORA_BASIC_SECRET must be set in .env.local file or environment variables")
        if not app_id:
            raise ValueError("Missing configuration: AGORA_APP_ID must be set in .env.local file or environment variables")
        
        # If agent_id not provided, try to load from file
        if not agent_id:
            agent_id = load_agent_id()
            if not agent_id:
                print("[ERROR] agent_id not found.", file=sys.stderr)
                print("[ERROR] Please provide --agent-id parameter, or ensure Agent was started successfully before.", file=sys.stderr)
                print("[ERROR] Usage: python agora_agent_startup.py stop --agent-id <agent_id>", file=sys.stderr)
                return 1
            print(f"[INFO] Using previous Agent ID: {agent_id}")
        
        # Create AgoraStarterServer instance
        server = AgoraStarterServer(
            app_id=app_id,
            basic_key=basic_key,
            basic_secret=basic_secret,
            pipeline_id="",  # Placeholder, stopping Agent doesn't require Pipeline ID
            channel_name="",  # Placeholder, stopping Agent doesn't require channel_name
            app_cert=None
        )
        
        # Stop Agent
        print(f"[INFO] Stopping Agent (agent_id={agent_id})...")
        server.stop_agent(agent_id)
        
        # Delete saved agent_id file
        delete_agent_id()
        
        print(f"[INFO] Agent stopped successfully!")
        return 0
        
    except Exception as e:
        print(f"[ERROR] Failed to stop Agent: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return 1


if __name__ == '__main__':
    parser = argparse.ArgumentParser(
        description='Agora Agent Starter Script (Lite) - Start and stop Agora Conversational AI Agent'
    )
    subparsers = parser.add_subparsers(dest='command', help='Available commands')
    
    # start command
    start_parser = subparsers.add_parser('start', help='Start Agent')
    start_parser.add_argument(
        '--agent-rtc-uid',
        type=str,
        default='1009527',
        help='Agent RTC UID (default: 1009527)'
    )
    
    # stop command
    stop_parser = subparsers.add_parser('stop', help='Stop Agent')
    stop_parser.add_argument(
        '--agent-id',
        type=str,
        default=None,
        metavar='AGENT_ID',
        help='Agent ID (optional, uses previous Agent ID if not provided)'
    )
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        sys.exit(1)
    
    # Load .env.local file
    try:
        from dotenv import load_dotenv
        load_dotenv(".env.local")
    except ImportError:
        pass
    
    # Load configuration
    config = load_config()
    
    # Execute command
    if args.command == 'start':
        sys.exit(cmd_start_agent(config, args.agent_rtc_uid))
    elif args.command == 'stop':
        sys.exit(cmd_stop_agent(config, args.agent_id))
