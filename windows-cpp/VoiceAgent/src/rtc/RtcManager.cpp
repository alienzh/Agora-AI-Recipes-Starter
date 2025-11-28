// RtcManager.cpp: RTC SDK Manager Implementation (No Internal Forwarding)
//

#include "General/pch.h"
// Include Agora SDK headers AFTER pch.h (Windows.h is already included in pch.h)
#include <IAgoraRtcEngine.h>
#include <AgoraBase.h>
#include "RtcManager.h"
#include "KeyCenter.h"
#include "Logger.h"
#include <string>

using namespace agora::rtc;

// Singleton Implementation

RtcManager& RtcManager::GetInstance() {
    static RtcManager instance;
    return instance;
}

// Constructor / Destructor

RtcManager::RtcManager()
    : m_rtcEngine(nullptr)
    , m_currentChannel("")
    , m_currentUid(0)
    , m_isInitialized(false)
{
    LOG_INFO("[RtcManager] Instance created");
}

RtcManager::~RtcManager() {
    Destroy();
}

// Public Methods

agora::rtc::IRtcEngine* RtcManager::CreateRtcEngine(agora::rtc::IRtcEngineEventHandler* delegate) {
    if (m_isInitialized) {
        LOG_WARN("[RtcManager] Already initialized, returning existing engine");
        return m_rtcEngine;
    }

    if (!delegate) {
        LOG_ERROR("[RtcManager] Delegate cannot be null");
        return nullptr;
    }

    LOG_INFO("[RtcManager] Creating RTC Engine...");

    // Create RTC engine instance
    m_rtcEngine = createAgoraRtcEngine();
    if (!m_rtcEngine) {
        LOG_ERROR("[RtcManager] Failed to create RTC engine");
        return nullptr;
    }

    // Initialize RTC engine context
    RtcEngineContext context;
    context.appId = KeyCenter::AGORA_APP_ID;
    context.eventHandler = delegate;
    context.audioScenario = AUDIO_SCENARIO_DEFAULT;

    int ret = m_rtcEngine->initialize(context);
    if (ret != 0) {
        LOG_ERROR("[RtcManager] Failed to initialize RTC engine, error: " + std::to_string(ret));
        m_rtcEngine->release();
        m_rtcEngine = nullptr;
        return nullptr;
    }

    // Set channel profile for live broadcasting
    m_rtcEngine->setChannelProfile(agora::CHANNEL_PROFILE_LIVE_BROADCASTING);
    
    // Enable audio (disable video for voice-only app)
    m_rtcEngine->enableAudio();
    m_rtcEngine->disableVideo();

    // Set client role to broadcaster
    m_rtcEngine->setClientRole(CLIENT_ROLE_BROADCASTER);
    m_rtcEngine->enableLocalAudio(true);
    m_isInitialized = true;
    LOG_INFO("[RtcManager] RTC Engine initialized successfully, SDK version: " + 
             std::string(m_rtcEngine->getVersion(nullptr)));
    return m_rtcEngine;
}

bool RtcManager::JoinChannel(const std::string& rtcToken, const std::string& channelName, unsigned int uid) {
    if (!m_isInitialized || !m_rtcEngine) {
        LOG_ERROR("[RtcManager] RTC engine not initialized");
        return false;
    }
    LOG_INFO("[RtcManager] Joining channel: " + channelName + ", uid: " + std::to_string(uid));
    // Set channel media options for voice-only application
    ChannelMediaOptions options;
    options.clientRoleType = CLIENT_ROLE_BROADCASTER;
    options.publishMicrophoneTrack = true;
    options.publishCameraTrack = false;
    options.autoSubscribeAudio = true;
    options.autoSubscribeVideo = false;

    int ret = m_rtcEngine->joinChannel(rtcToken.c_str(), channelName.c_str(), uid, options);
    
    if (ret == 0) {
        m_currentChannel = channelName;
        m_currentUid = uid;
        LOG_INFO("[RtcManager] Join channel request sent successfully");
        return true;
    } else {
        LOG_ERROR("[RtcManager] Failed to join channel, error: " + std::to_string(ret));
        return false;
    }
}

void RtcManager::LeaveChannel() {
    if (!m_isInitialized || !m_rtcEngine) {
        LOG_WARN("[RtcManager] RTC engine not initialized, cannot leave channel");
        return;
    }

    LOG_INFO("[RtcManager] Leaving channel: " + m_currentChannel);
    
    m_rtcEngine->leaveChannel();
    m_currentChannel.clear();
    m_currentUid = 0;
}

void RtcManager::RenewToken(const std::string& token) {
    if (!m_isInitialized || !m_rtcEngine) {
        LOG_WARN("[RtcManager] RTC engine not initialized, cannot renew token");
        return;
    }

    LOG_INFO("[RtcManager] Renewing token");
    m_rtcEngine->renewToken(token.c_str());
}

void RtcManager::MuteLocalAudio(bool mute) {
    if (!m_isInitialized || !m_rtcEngine) {
        LOG_WARN("[RtcManager] RTC engine not initialized, cannot mute/unmute");
        return;
    }

    // Adjust recording volume (0 = mute, 100 = normal)
    m_rtcEngine->adjustRecordingSignalVolume(mute ? 0 : 100);
    LOG_INFO(std::string("[RtcManager] Local audio ") + (mute ? "muted" : "unmuted"));
}

agora::rtc::IRtcEngine* RtcManager::GetRtcEngine() {
    return m_rtcEngine;
}

void RtcManager::Destroy() {
    if (m_rtcEngine) {
        LOG_INFO("[RtcManager] Destroying RTC engine");
        
        if (!m_currentChannel.empty()) {
            m_rtcEngine->leaveChannel();
        }
        
        m_rtcEngine->release();
        m_rtcEngine = nullptr;
        m_isInitialized = false;
        
        LOG_INFO("[RtcManager] RTC engine destroyed");
    }
}
