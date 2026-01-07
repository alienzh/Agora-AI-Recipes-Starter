# Web React Lite

[中文文档](./README-CN.md) | [English Documentation](./README.md)

A React and Vite based frontend project focused on RTM, RTC, and ConvoAI connection functionality.

This is a **standalone frontend application** that does not require any backend server. All functionality runs entirely in the browser.

## Getting Started

### Install Dependencies

```bash
npm install --legacy-peer-deps
```

### Development Mode

```bash
npm run dev
```

This will start the frontend development server. No backend server is required.

### Build for Production

```bash
npm run build
```

### Preview Production Build

```bash
npm run preview
```

## Usage

1. After starting the project, fill in the following information on the entry page:
   - **App ID**: Agora App ID (required)
   - **App Certificate**: Agora App Certificate (optional)
   - **Channel Name**: Channel name (required)

2. Click the "Connect Conversational AI Engine" button to start connecting

### Configuration

- **App ID**: Agora App ID, used to initialize RTM and RTC engines (required)
- **App Certificate**: Agora App Certificate, used to generate user Token (optional)
- **Channel Name**: Channel name to join (required)

## Features

This version implements the following features:

1. **RTM Connection**: Initialize RTM engine and login
2. **RTC Connection**: Initialize RTC engine and join channel
3. **Audio Processing**: Create, publish and subscribe audio tracks
4. **ConvoAI Message Subscription**: Subscribe and display conversation transcriptions
5. **Debug Logs**: Real-time display of connection status and event logs (shown on the right side)

## How It Works

This application connects directly to Agora's services:

- **Token Generation**: Uses Agora's public token generation service (`https://service.apprtc.cn/toolbox/v2/token/generate`) when App Certificate is provided
- **RTM/RTC**: Connects directly to Agora RTM and RTC services
- **ConvoAI**: Subscribes to conversational AI messages through RTM channels

**Note**: The Agent (AI assistant) must be started separately through Agora's platform or other means. This frontend application only handles the client-side connection and message display.

## Project Structure

```text
web-react-lite/
├── src/
│   ├── components/
│   │   ├── MainView.jsx         # Main view component (combines configuration and chat functionality)
│   │   └── main-view.css        # Main view styles
│   ├── conversational-ai-api/  # ConvoAI API wrapper
│   ├── utils/
│   │   ├── api.js              # Token generation API
│   │   └── configStorage.js     # Configuration storage utility (localStorage)
│   ├── App.jsx                 # Main application component (includes log management and two-column layout)
│   ├── App.css                 # Application styles (includes two-column layout)
│   ├── main.jsx                # Entry file
│   └── index.css               # Global styles
├── index.html                   # HTML template
├── vite.config.js              # Vite configuration
└── package.json                # Project configuration
```

## Technical Details

- **Framework**: React 18
- **Build Tool**: Vite
- **SDKs**:
  - `agora-rtc-sdk-ng`: Agora RTC SDK
  - `agora-rtm`: Agora RTM SDK
- **Storage**: Uses `localStorage` to persist configuration
- **Token Service**: Uses Agora's public token generation service (no backend required)

## Notes

- This is a **pure frontend application** - no backend server is needed
- Configuration is entered directly in the UI and stored in browser localStorage
- Token generation (if App Certificate is provided) uses Agora's public service
- The Agent must be started separately through Agora's platform or other external means
