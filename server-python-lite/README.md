# Agora Agent Starter Script (Lite)

Command-line script for starting and stopping Agora Conversational AI Agent. All configuration is loaded from local environment variables.

## Use Cases

- Quick testing and experiencing Agora Conversational AI Agent
- Use with Web applications: start Agent via script, then join channel in Web app to experience
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
cd server-python-lite

# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate
# Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

## Configuration

1. Copy example configuration file:
```bash
cd server-python-lite
cp .env.example .env.local
```

2. Edit `.env.local` file and fill in your actual configuration values:

```bash

# App ID (for generating Token and starting Agent)
AGORA_APP_ID=your_app_id_here

# App Certificate (for generating Token, optional)
AGORA_APP_CERT=your_app_certificate_here

# Basic Auth credentials (for calling Agora REST API)
AGORA_BASIC_KEY=your_basic_key_here
AGORA_BASIC_SECRET=your_basic_secret_here

# Pipeline ID (for starting Agent)
AGORA_PIPELINE_ID=your_pipeline_id_here

# Channel name (channel that Agent will join)
AGORA_CHANNEL_NAME=your_channel_name_here
```

## Usage

### Start Agent

```bash
python agora_agent_startup.py start
```

After successful startup, the script will:
1. Automatically generate Agent RTC UID Token
2. Start Agent
3. Automatically save Agent ID to `.agent_id` file (for stopping Agent later)

### Stop Agent

```bash
python agora_agent_startup.py stop
```

Optional parameters:
- `--agent-id`: Agent ID (optional, uses previous Agent ID if not provided)

Examples:
```bash
# Use previous Agent ID
python agora_agent_startup.py stop

# Or specify Agent ID
python agora_agent_startup.py stop --agent-id 1NT29X10YHxxxxxWJOXLYHNYB
```

## View Results

After starting Agent, you can use the Web application to view results. Please refer to [web-react-lite/README.md](../web-react-lite/README.md).

**Note**: The channel name used in the Web application must match `AGORA_CHANNEL_NAME` in `.env.local`.

## License

Please refer to the LICENSE file in the project root directory.
