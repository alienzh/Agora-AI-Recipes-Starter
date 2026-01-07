# Agora Agent Starter Script (Avatar)

[中文](README-CN.md) | English

Command-line script for starting and stopping Agora Conversational AI Agent (Avatar version). All configuration is loaded from local environment variables.

## Use Cases

- Quick testing and experiencing Agora Conversational AI Agent's Avatar functionality
- Use with mobile applications: start Agent via script, then join channel in app to experience Avatar conversation
- Scenarios requiring protection of server-side authentication information

## Prerequisites

- Python 3.6 or higher
- Network connection (for calling Agora REST API)
- Agora developer account [Console](https://console.shengwang.cn/)
- Created Agora project and obtained App ID
- Obtained REST API Basic Auth credentials (Key and Secret)
- Obtained Pipeline ID

## Install Dependencies

```bash
cd server-avatar

# Create virtual environment
python3 -m venv venv

# Activate virtual environment
# Linux/macOS:
source venv/bin/activate
# Windows:
# venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

## Configuration

1. Copy example configuration file:

```bash
cd server-avatar
cp .env.example .env.local
```

2. Edit `.env.local` file and fill in your actual configuration values:

```bash
# App ID (used to generate Token and start Agent)
AGORA_APP_ID=your_app_id_here

# App Certificate (used to generate Token, optional)
AGORA_APP_CERT=your_app_certificate_here

# Basic Auth credentials (used to call Agora REST API)
AGORA_BASIC_KEY=your_basic_key_here
AGORA_BASIC_SECRET=your_basic_secret_here

# Pipeline ID (used to start Agent)
AGORA_PIPELINE_ID=your_pipeline_id_here

# Channel name (channel Agent will join)
AGORA_CHANNEL_NAME=your_channel_name_here
```

## Pipeline Configuration

When creating Pipeline in [AI Studio](https://console-conversationai.shengwang.cn/product/ConversationAI/studio), you need to additionally configure Avatar module:

1. Go to Pipeline editing page
2. Enable `Avatar Settings` option
3. Enable `Enable Avatar`
4. Configure Avatar-related parameters
5. Save and publish Pipeline

**Note**: Only Pipelines with Avatar enabled can use this script to start Avatar Agent.

## Usage

### Start Agent (Avatar Mode)

Run command directly to start Agent, using fixed configuration:
- Current RTC UID: `1001` (client uses this UID to join channel)
- Agent RTC UID: `2001`
- Avatar RTC UID: `3001`

```bash
python agent_start_avatar.py start
```

### Script Startup Flow

Complete flow when script executes `startAgent`:

1. **Generate Agent RTC UID and Token**
   - Agent RTC UID fixed value: `2001`
   - Call token generation service to generate Agent's RTC/RTM Token
   - API: `POST https://service.apprtc.cn/toolbox/v2/token/generate`

2. **Generate Avatar RTC UID and Token**
   - Avatar RTC UID fixed value: `3001`
   - Call token generation service to generate Avatar's RTC/RTM Token
   - API: `POST https://service.apprtc.cn/toolbox/v2/token/generate`

3. **RESTful Request to Start Agent**
   - Build request body containing Avatar configuration
   - Send POST request to Agora REST API
   - API: `POST https://api.sd-rtn.com/cn/api/conversational-ai-agent/v2/projects/{app_id}/join/`
   - Request headers contain Basic Auth credentials
   - **Important**: When Avatar is enabled, `remote_rtc_uids` cannot use `["*"]`, must specify specific UID (fixed as `1001`)
   - Request body example:
     ```json
     {
       "name": "<channel_name>",
       "pipeline_id": "<pipeline_id>",
       "properties": {
         "channel": "<channel_name>",
         "agent_rtc_uid": "2001",
         "remote_rtc_uids": ["1001"],
         "token": "<agent_token>",
         "avatar": {
           "params": {
             "agora_uid": "3001",
             "agora_token": "<avatar_rtc_token>"
           }
         }
       }
     }
     ```

4. **Save Agent ID**
   - Get `agent_id` from response
   - Save to `.agent_id` file for subsequent Agent stop operations

After successful startup, script will output:

- Agent ID
- Channel name
- Agent RTC UID: `2001`
- Avatar RTC UID: `3001`
- Current RTC UID: `1001` (client needs to use this UID to join channel)

### Stop Agent

```bash
python agent_start_avatar.py stop
```

Optional parameters:

- `--agent-id`: Agent ID (optional, uses previous Agent ID if not provided)

Examples:
```bash
# Use previous Agent ID
python agent_start_avatar.py stop

# Or specify Agent ID
python agent_start_avatar.py stop --agent-id 1NT29X10YHxxxxxWJOXLYHNYB
```

## Avatar Feature Description

This script enables Avatar functionality by default. The script includes the following Avatar configuration in the Agent start request:

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

- `current_rtc_uid` fixed value: `1001` (client uses this UID to join channel)
- `agent_rtc_uid` fixed value: `2001`
- `avatar_rtc_uid` fixed value: `3001`
- `avatar_rtc_token` automatically generated by server, no manual configuration needed

Agent will run in Avatar mode, supporting Avatar-related functionality.

## View Results

After starting Agent, you can use mobile applications to view results. Please refer to related mobile application README documentation.

**Important Notes**:

- Channel name used in mobile application must match `AGORA_CHANNEL_NAME` in `.env.local`
- Mobile application must use fixed value `1001` as client RTC UID to join channel
- When Avatar is enabled, Agent can only subscribe to specified `current_rtc_uid` (fixed as `1001`), cannot use `["*"]` to subscribe to all users

## License

Please refer to the LICENSE file in the project root directory.
