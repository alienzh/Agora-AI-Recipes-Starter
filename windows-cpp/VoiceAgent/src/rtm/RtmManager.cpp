// RtmManager.cpp: RTM SDK Manager Implementation (v2.x API based on actual SDK)
//
#include "General/pch.h"
#include "RtmManager.h"
#include "KeyCenter.h"
#include "Logger.h"
#include <IAgoraRtmClient.h>
#include <AgoraRtmBase.h>
#include <string>

using namespace agora::rtm;

// Singleton Implementation

RtmManager& RtmManager::GetInstance() {
    static RtmManager instance;
    return instance;
}

// Constructor / Destructor

RtmManager::RtmManager()
    : m_rtmClient(nullptr)
    , m_eventHandler(nullptr)
    , m_isLoggedIn(false)
    , m_isInitialized(false)
    , m_lastLoginRequestId(0)
    , m_lastLogoutRequestId(0)
{
    LOG_INFO("[RtmManager] Instance created (v2.x API - Real SDK)");
}

RtmManager::~RtmManager() {
    Destroy();
}

// Public Methods

bool RtmManager::Initialize(const RtmManagerConfig& config) {
    if (m_isInitialized) {
        LOG_WARN("[RtmManager] Already initialized");
        return true;
    }

    LOG_INFO("[RtmManager] Initializing RTM Client v2.x...");

    // Create internal event handler wrapper
    m_internalHandler = std::make_unique<RtmEventHandler>(this);

    // Configure RTM client
    RtmConfig rtmConfig;
    rtmConfig.appId = config.appId.c_str();
    rtmConfig.userId = config.userId.c_str();
    rtmConfig.eventHandler = m_internalHandler.get();
    rtmConfig.presenceTimeout = 300;
    rtmConfig.useStringUserId = true;
    rtmConfig.areaCode = RTM_AREA_CODE_GLOB;

    // Create RTM client
    int errorCode = 0;
    m_rtmClient = createAgoraRtmClient(rtmConfig, errorCode);
    if (!m_rtmClient || errorCode != 0) {
        LOG_ERROR("[RtmManager] Failed to create RTM client, error: " + std::to_string(errorCode));
        return false;
    }

    m_appId = config.appId;
    m_currentUserId = config.userId;
    m_isInitialized = true;

    LOG_INFO("[RtmManager] RTM Client initialized successfully for user: " + m_currentUserId);

    return true;
}

void RtmManager::SetEventHandler(IRtmManagerEventHandler* handler) {
    m_eventHandler = handler;
    LOG_INFO("[RtmManager] Event handler set");
}

void RtmManager::Login(const std::string& token, std::function<void(int, const std::string&)> completion) {
    if (!m_isInitialized || !m_rtmClient) {
        LOG_ERROR("[RtmManager] RTM client not initialized");
        if (completion) {
            completion(-1, "RTM client not initialized");
        }
        return;
    }

    if (m_isLoggedIn) {
        LOG_WARN("[RtmManager] Already logged in");
        if (completion) {
            completion(0, "Already logged in");
        }
        return;
    }

    LOG_INFO("[RtmManager] Logging in...");

    // Login using v2.x API
    uint64_t requestId = 0;
    m_rtmClient->login(token.empty() ? nullptr : token.c_str(), requestId);

    // Store request ID and callback
    m_lastLoginRequestId = requestId;
    if (completion) {
        m_requestCallbacks[requestId] = completion;
    }

    LOG_INFO("[RtmManager] Login request sent, requestId: " + std::to_string(requestId));
}

void RtmManager::Logout() {
    if (!m_isInitialized || !m_rtmClient) {
        LOG_WARN("[RtmManager] RTM client not initialized");
        return;
    }

    if (!m_isLoggedIn) {
        LOG_WARN("[RtmManager] Not logged in, no need to logout");
        return;
    }

    LOG_INFO("[RtmManager] Logging out (clearing " + std::to_string(m_subscribedChannels.size()) + " subscriptions)");

    uint64_t requestId = 0;
    m_rtmClient->logout(requestId);
    m_lastLogoutRequestId = requestId;

    // Immediately set logged out state to prevent race condition
    m_isLoggedIn = false;
    m_subscribedChannels.clear();
    m_requestCallbacks.clear();
}

void RtmManager::SubscribeChannel(const std::string& channelName, std::function<void(int, const std::string&)> completion) {
    if (!m_isInitialized || !m_rtmClient) {
        LOG_ERROR("[RtmManager] RTM client not initialized");
        if (completion) {
            completion(-1, "RTM client not initialized");
        }
        return;
    }

    if (!m_isLoggedIn) {
        LOG_ERROR("[RtmManager] Not logged in");
        if (completion) {
            completion(-1, "Not logged in");
        }
        return;
    }

    LOG_INFO("[RtmManager] Subscribing to channel: " + channelName);
    
    // Check if already subscribed
    if (m_subscribedChannels.find(channelName) != m_subscribedChannels.end()) {
        LOG_WARN("[RtmManager] Channel already subscribed");
    }

    // Subscribe to channel using v2.x API
    uint64_t requestId = 0;
    SubscribeOptions options;
    options.withMessage = true;
    options.withPresence = true;
    options.withMetadata = false;
    options.withLock = false;

    m_rtmClient->subscribe(channelName.c_str(), options, requestId);

    // Store callback
    if (completion) {
        m_requestCallbacks[requestId] = completion;
    }
}

void RtmManager::UnsubscribeChannel(const std::string& channelName) {
    if (!m_isInitialized || !m_rtmClient) {
        LOG_WARN("[RtmManager] RTM client not initialized");
        return;
    }

    auto it = m_subscribedChannels.find(channelName);
    if (it == m_subscribedChannels.end()) {
        LOG_WARN("[RtmManager] Channel not subscribed: " + channelName);
        return;
    }

    LOG_INFO("[RtmManager] Unsubscribing from channel: " + channelName);

    uint64_t requestId = 0;
    m_rtmClient->unsubscribe(channelName.c_str(), requestId);

    m_subscribedChannels.erase(it);
    LOG_INFO("[RtmManager] Unsubscribe request sent, requestId: " + std::to_string(requestId));
}

void RtmManager::SendChannelMessage(const std::string& channelName, const std::string& message,
                                   std::function<void(int, const std::string&)> completion) {
    if (!m_isInitialized || !m_rtmClient) {
        LOG_ERROR("[RtmManager] RTM client not initialized");
        if (completion) {
            completion(-1, "RTM client not initialized");
        }
        return;
    }

    if (!m_isLoggedIn) {
        LOG_ERROR("[RtmManager] Not logged in");
        if (completion) {
            completion(-1, "Not logged in");
        }
        return;
    }

    LOG_INFO("[RtmManager] Sending message to channel: " + channelName);

    // Publish message using v2.x API
    uint64_t requestId = 0;
    PublishOptions options;
    options.channelType = agora::rtm::RTM_CHANNEL_TYPE_MESSAGE;
    options.messageType = agora::rtm::RTM_MESSAGE_TYPE_STRING;
    options.customType = nullptr;
    options.storeInHistory = false;
    
    m_rtmClient->publish(channelName.c_str(), message.c_str(), message.length(), options, requestId);

    if (completion) {
        m_requestCallbacks[requestId] = completion;
    }

    LOG_INFO("[RtmManager] Publish request sent, requestId: " + std::to_string(requestId));
}

void RtmManager::Destroy() {
    if (m_rtmClient) {
        LOG_INFO("[RtmManager] Destroying RTM client...");

        // Unsubscribe from all channels
        for (auto& pair : m_subscribedChannels) {
            uint64_t requestId = 0;
            m_rtmClient->unsubscribe(pair.first.c_str(), requestId);
        }
        m_subscribedChannels.clear();

        // Logout if logged in
        if (m_isLoggedIn) {
            uint64_t requestId = 0;
            m_rtmClient->logout(requestId);
            m_isLoggedIn = false;
        }

        // Release RTM client
        m_rtmClient->release();
        m_rtmClient = nullptr;
        m_isInitialized = false;

        LOG_INFO("[RtmManager] RTM client destroyed");
    }
}

IRtmClient* RtmManager::GetRtmClient() {
    return m_rtmClient;
}

// Internal Event Handler (v2.x API)

RtmManager::RtmEventHandler::RtmEventHandler(RtmManager* manager)
    : m_manager(manager) {}

void RtmManager::RtmEventHandler::onLoginResult(const uint64_t requestId, agora::rtm::RTM_ERROR_CODE errorCode) {
    if (errorCode == agora::rtm::RTM_ERROR_OK) {
        LOG_INFO("[RtmManager] Login successful, requestId: " + std::to_string(requestId));
        m_manager->m_isLoggedIn = true;

        if (m_manager->m_eventHandler) {
            m_manager->m_eventHandler->onLoginSuccess(m_manager->m_currentUserId.c_str());
        }

        // Call completion callback
        auto it = m_manager->m_requestCallbacks.find(requestId);
        if (it != m_manager->m_requestCallbacks.end()) {
            it->second(0, "Login successful");
            m_manager->m_requestCallbacks.erase(it);
        }
    } else {
        std::string errorMsg = "Login failed, error code: " + std::to_string(errorCode);
        LOG_ERROR("[RtmManager] " + errorMsg);

        if (m_manager->m_eventHandler) {
            m_manager->m_eventHandler->onLoginFailed(errorCode, errorMsg.c_str());
        }

        // Call completion callback
        auto it = m_manager->m_requestCallbacks.find(requestId);
        if (it != m_manager->m_requestCallbacks.end()) {
            it->second(errorCode, errorMsg);
            m_manager->m_requestCallbacks.erase(it);
        }
    }
}

void RtmManager::RtmEventHandler::onLinkStateEvent(const agora::rtm::IRtmEventHandler::LinkStateEvent& event) {
    std::string stateStr;
    switch (event.currentState) {
        case agora::rtm::RTM_LINK_STATE_IDLE: stateStr = "IDLE"; break;
        case agora::rtm::RTM_LINK_STATE_CONNECTING: stateStr = "CONNECTING"; break;
        case agora::rtm::RTM_LINK_STATE_CONNECTED: stateStr = "CONNECTED"; break;
        case agora::rtm::RTM_LINK_STATE_DISCONNECTED: stateStr = "DISCONNECTED"; break;
        case agora::rtm::RTM_LINK_STATE_SUSPENDED: stateStr = "SUSPENDED"; break;
        case agora::rtm::RTM_LINK_STATE_FAILED: stateStr = "FAILED"; break;
        default: stateStr = "UNKNOWN"; break;
    }

    LOG_INFO("[RtmManager] Link state changed: " + stateStr + ", reason: " + std::to_string(event.reasonCode));

    // Check if this is a logout event
    if (event.operation == agora::rtm::RTM_LINK_OPERATION_LOGOUT && event.currentState == agora::rtm::RTM_LINK_STATE_DISCONNECTED) {
        LOG_INFO("[RtmManager] Logout completed");
        
        if (m_manager->m_eventHandler) {
            m_manager->m_eventHandler->onLogout();
        }
    }

    if (m_manager->m_eventHandler) {
        m_manager->m_eventHandler->onConnectionStateChanged(event.currentState, event.reasonCode);
    }
}

void RtmManager::RtmEventHandler::onMessageEvent(const agora::rtm::IRtmEventHandler::MessageEvent& event) {
    std::string publisher = event.publisher ? event.publisher : "unknown";
    std::string channelName = event.channelName ? event.channelName : "unknown";
    
    LOG_INFO("[RtmManager] Message received from: " + publisher + " in channel: " + channelName);

    if (m_manager->m_eventHandler && event.message && event.messageLength > 0) {
        // v2.x: event.message is const char* (not uint8_t* like before)
        std::string messageData(event.message, event.messageLength);
        
        LOG_INFO("[RtmManager] Message content: " + messageData);
        
        m_manager->m_eventHandler->onMessageReceived(messageData.c_str(), publisher.c_str());
    }
}

void RtmManager::RtmEventHandler::onPresenceEvent(const agora::rtm::IRtmEventHandler::PresenceEvent& event) {
    // Parse agent state from Presence Event stateItems
    if (event.stateItemCount > 0 && event.stateItems) {
        std::string agentState;
        std::string turnIdStr;
        
        // Extract "state" and "turn_id" from event.stateItems
        for (size_t i = 0; i < event.stateItemCount; ++i) {
            std::string key = event.stateItems[i].key ? event.stateItems[i].key : "";
            std::string value = event.stateItems[i].value ? event.stateItems[i].value : "";
            
            if (key == "state") {
                agentState = value;
            } else if (key == "turn_id") {
                turnIdStr = value;
            }
        }
        
        // If agent state found, construct a synthetic message for ConversationalAIAPI
        if (!agentState.empty()) {
            LOG_INFO("[RtmManager] Agent state: " + agentState + ", turnId: " + turnIdStr);
            
            // Construct JSON message
            std::string stateMessage = "{"
                "\"object\": \"message.state\","
                "\"state\": \"" + agentState + "\","
                "\"turn_id\": " + (turnIdStr.empty() ? "0" : turnIdStr) + ","
                "\"timestamp\": " + std::to_string(event.timestamp) + ","
                "\"reason\": \"\""
                "}";
            
            // Get agent user ID from event.publisher
            std::string agentUserId = event.publisher ? event.publisher : "-1";
            
            // Forward to message handler
            if (m_manager && m_manager->m_eventHandler) {
                m_manager->m_eventHandler->onMessageReceived(stateMessage.c_str(), agentUserId.c_str());
            } else {
                LOG_ERROR("[RtmManager] Cannot forward state message: handler is null");
            }
        }
    }
}

void RtmManager::RtmEventHandler::onTopicEvent(const agora::rtm::IRtmEventHandler::TopicEvent& event) {
    // Handle topic events if needed
    LOG_INFO("[RtmManager] Topic event received, type: " + std::to_string(static_cast<int>(event.type)));
}

void RtmManager::RtmEventHandler::onLockEvent(const agora::rtm::IRtmEventHandler::LockEvent& event) {
    // Handle lock events if needed
    (void)event;
}

void RtmManager::RtmEventHandler::onStorageEvent(const agora::rtm::IRtmEventHandler::StorageEvent& event) {
    // Handle storage events if needed
    (void)event;
}

void RtmManager::RtmEventHandler::onJoinResult(const uint64_t requestId, const char* channelName, 
                                              const char* userId, agora::rtm::RTM_ERROR_CODE errorCode) {
    if (errorCode == agora::rtm::RTM_ERROR_OK) {
        LOG_INFO("[RtmManager] Join channel successful: " + std::string(channelName) + 
                 ", requestId: " + std::to_string(requestId));
    } else {
        LOG_ERROR("[RtmManager] Join channel failed: " + std::to_string(errorCode));
    }

    // Call completion callback
    auto it = m_manager->m_requestCallbacks.find(requestId);
    if (it != m_manager->m_requestCallbacks.end()) {
        it->second(errorCode, errorCode == agora::rtm::RTM_ERROR_OK ? "Success" : "Failed");
        m_manager->m_requestCallbacks.erase(it);
    }
}

void RtmManager::RtmEventHandler::onLeaveResult(const uint64_t requestId, const char* channelName, 
                                               const char* userId, agora::rtm::RTM_ERROR_CODE errorCode) {
    LOG_INFO("[RtmManager] Leave channel: " + std::string(channelName ? channelName : "unknown") + 
             ", error: " + std::to_string(errorCode));
}

void RtmManager::RtmEventHandler::onSubscribeResult(const uint64_t requestId, const char* channelName, 
                                                   agora::rtm::RTM_ERROR_CODE errorCode) {
    if (errorCode == agora::rtm::RTM_ERROR_OK) {
        LOG_INFO("[RtmManager] Subscribe successful: " + std::string(channelName ? channelName : "unknown") + 
                 ", requestId: " + std::to_string(requestId));
        
        // Add to subscribed channels
        if (channelName) {
            m_manager->m_subscribedChannels[channelName] = true;
        }
    } else {
        LOG_ERROR("[RtmManager] Subscribe failed: " + std::to_string(errorCode));
    }

    // Call completion callback
    auto it = m_manager->m_requestCallbacks.find(requestId);
    if (it != m_manager->m_requestCallbacks.end()) {
        it->second(errorCode, errorCode == agora::rtm::RTM_ERROR_OK ? "Success" : "Failed");
        m_manager->m_requestCallbacks.erase(it);
    }
}

void RtmManager::RtmEventHandler::onPublishResult(const uint64_t requestId, agora::rtm::RTM_ERROR_CODE errorCode) {
    if (errorCode == agora::rtm::RTM_ERROR_OK) {
        LOG_INFO("[RtmManager] Publish successful, requestId: " + std::to_string(requestId));
    } else {
        LOG_ERROR("[RtmManager] Publish failed: " + std::to_string(errorCode));
    }

    // Call completion callback
    auto it = m_manager->m_requestCallbacks.find(requestId);
    if (it != m_manager->m_requestCallbacks.end()) {
        it->second(errorCode, errorCode == agora::rtm::RTM_ERROR_OK ? "Success" : "Failed");
        m_manager->m_requestCallbacks.erase(it);
    }
}

void RtmManager::RtmEventHandler::onUnsubscribeResult(const uint64_t requestId, const char* channelName, 
                                                     agora::rtm::RTM_ERROR_CODE errorCode) {
    if (errorCode == agora::rtm::RTM_ERROR_OK) {
        LOG_INFO("[RtmManager] Unsubscribe successful: " + std::string(channelName ? channelName : "unknown") + 
                 ", requestId: " + std::to_string(requestId));
    } else {
        LOG_ERROR("[RtmManager] Unsubscribe failed: " + std::to_string(errorCode));
    }
}
