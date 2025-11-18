#!/usr/bin/env python3
"""
Agora Agent Starter HTTP Server
A Flask-based HTTP server to start and stop Agora conversational AI agents
Provides REST API endpoints for Android apps to call via localhost
"""
import json
import os
import sys
import socket
from typing import Dict, Any
from flask import Flask, request, jsonify
from flask_cors import CORS
import requests

# Import the AgoraAPIClient class (without token generation logic)
# Import from the same directory
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from agora_api_client import AgoraAPIClient

app = Flask(__name__)
CORS(app)  # Enable CORS for cross-origin requests

# Store active agents (in production, use a database)
active_agents: Dict[str, str] = {}  # channel_name -> agent_id


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({"status": "ok", "message": "Agora Agent Starter Server is running"})


@app.route('/<project_id>/join/', methods=['POST'])
def start_agent(project_id: str):
    """
    Start an Agora conversational AI agent
    Unified interface: same format as Agora API
    Transparent proxy mode: all data is passed through as-is
    
    Request body (JSON):
    {
        "name": "agent_name",
        "pipeline_id": "pipeline_id",
        "properties": {
            "channel": "channel_name",
            "agent_rtc_uid": "1009527",
            "remote_rtc_uids": ["*"],
            "token": "token_string",
            // Optional: for dataStream mode, add these fields:
            "parameters": {
                "data_channel": "datastream"
            },
            "advanced_features": {
                "enable_rtm": false
            }
        }
    }
    
    Response (JSON):
    {
        "agent_id": "agent_id"
    }
    """
    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "Request body is required"}), 400
        
        # Extract channel name for tracking (from request body)
        properties = data.get("properties", {})
        channel_name = properties.get("channel", "")
        
        # Create API client instance (only needs project_id)
        client = AgoraAPIClient(app_id=project_id)
        
        # Extract headers from client request (transparent proxy)
        headers = {}
        if "Authorization" in request.headers:
            headers["Authorization"] = request.headers["Authorization"]
        if "Content-Type" in request.headers:
            headers["Content-Type"] = request.headers["Content-Type"]
        
        # Call Agora RESTful API and get the full response (proxy/transparent)
        # Pass through the request body and headers as-is
        response_text = client._execute_join_request(
            request_body=data,
            headers=headers
        )
        
        # Parse the response to get agent_id for tracking
        response_json = json.loads(response_text)
        agent_id = response_json.get("agent_id", "")
        
        if agent_id and channel_name:
            print(f"[INFO] Agent started successfully. Agent ID: {agent_id}")
            # Store agent ID for tracking
            active_agents[channel_name] = agent_id
        
        # Return the original Agora RESTful API response directly (transparent proxy)
        return jsonify(response_json)
        
    except Exception as e:
        import traceback
        error_trace = traceback.format_exc()
        print(f"[ERROR] Failed to start agent: {str(e)}")
        print(f"[ERROR] Traceback:\n{error_trace}")
        return jsonify({"error": str(e)}), 500


@app.route('/<project_id>/agents/<agent_id>/leave', methods=['POST'])
def stop_agent(project_id: str, agent_id: str):
    """
    Stop an Agora conversational AI agent
    Unified interface: same format as Agora API
    
    Request body: Empty (POST with empty body)
    
    Response: HTTP 200 OK (no body)
    """
    try:
        # Create API client instance (only needs project_id)
        client = AgoraAPIClient(app_id=project_id)
        
        # Extract headers from client request (transparent proxy)
        headers = {}
        if "Authorization" in request.headers:
            headers["Authorization"] = request.headers["Authorization"]
        if "Content-Type" in request.headers:
            headers["Content-Type"] = request.headers["Content-Type"]
        
        # Stop agent (pass through headers)
        client._execute_leave_request(agent_id, headers)
        
        # Remove from active agents by agent_id (find channel_name by agent_id)
        channel_to_remove = None
        for channel_name, stored_agent_id in active_agents.items():
            if stored_agent_id == agent_id:
                channel_to_remove = channel_name
                break
        
        if channel_to_remove:
            del active_agents[channel_to_remove]
        
        # Return empty response (HTTP 200 OK)
        return "", 200
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route('/agents', methods=['GET'])
def list_agents():
    """List all active agents (legacy endpoint, kept for compatibility)"""
    return jsonify({
        "success": True,
        "agents": [{"channelName": ch, "agentId": aid} for ch, aid in active_agents.items()]
    })


def get_local_ip_address():
    """
    Get the primary local IP address that can be accessed from Android devices
    Returns a single IP address (excluding loopback, VPN, and virtual interfaces)
    
    This method connects to a remote address to determine which network interface
    is used for internet access, which is typically the one Android devices should use.
    """
    try:
        # Connect to a remote address to determine the primary network interface
        # This is the most reliable method as it returns the IP of the interface
        # that's actually used for internet connectivity
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            # Connect to a remote address (doesn't actually send data)
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
    
    # Fallback: if the above method fails, return None
    # User will need to find IP manually
    return None


def print_connection_info(port: int):
    """
    Print connection information for clients
    """
    print("\n" + "="*60)
    print("🔗 Client Configuration")
    print("="*60)
    
    # Localhost configuration
    print("\n💻 For Localhost (same machine):")
    print(f"   http://localhost:{port}")
    print(f"   http://127.0.0.1:{port}")
    
    # Network configuration
    local_ip = get_local_ip_address()
    if local_ip:
        print(f"\n🌐 For Network Access (other devices):")
        print(f"   http://{local_ip}:{port}")
        print(f"\n   Use this URL in your client code, for example:")
        print(f'   const BASE_URL = "http://{local_ip}:{port}"')
    else:
        print(f"\n🌐 For Network Access (other devices):")
        print("   ⚠️  Could not detect local IP address automatically.")
        print("   Please find your computer's IP address manually:")
        print("   - macOS/Linux: ifconfig en0 | grep 'inet ' | grep -v 127.0.0.1 | awk '{print $2}'")
        print("   - Windows: ipconfig")
        print("   Then use: http://<your-ip>:{port}")
    
    # Special cases
    print(f"\n📝 Special Cases:")
    print(f"   - Android Emulator: Use http://10.0.2.2:{port}")
    print(f"   - iOS Simulator: Use http://localhost:{port} or http://127.0.0.1:{port}")
    
    print("\n" + "="*60 + "\n")


if __name__ == '__main__':
    # Server configuration (fixed defaults for transparent proxy mode)
    host = "0.0.0.0"  # Listen on all network interfaces
    port = 8080       # Default port
    
    print(f"Starting Agora Agent Starter HTTP Server on {host}:{port}")
    print(f"Mode: Transparent Proxy (headers and data passed through from client)")
    print(f"\nHealth check: http://localhost:{port}/health")
    print(f"API documentation (unified Agora API format):")
    print(f"  POST /{{project_id}}/join/ - Start an agent")
    print(f"  POST /{{project_id}}/agents/{{agent_id}}/leave - Stop an agent")
    print(f"  GET /agents - List all active agents (legacy)")
    
    # Print connection information for clients
    print_connection_info(port)
    
    try:
        app.run(host=host, port=port, debug=True)
    except OSError as e:
        if "Address already in use" in str(e) or e.errno == 48:
            print(f"\n❌ Error: Port {port} is already in use.", file=sys.stderr)
            print(f"\n💡 Solutions:", file=sys.stderr)
            print(f"  1. Use a different port:", file=sys.stderr)
            print(f"     python agora_http_server.py --port <port>", file=sys.stderr)
            print(f"  2. Find and stop the process using port {port}:", file=sys.stderr)
            print(f"     lsof -ti:{port} | xargs kill -9", file=sys.stderr)
            sys.exit(1)
        else:
            raise

