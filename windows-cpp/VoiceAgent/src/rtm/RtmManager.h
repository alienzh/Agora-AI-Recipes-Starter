// RtmManager.h: RTM SDK Manager (v2.x API with Internal Forwarding)
//
#pragma once

#include <string>
#include <functional>
#include <map>
#include <memory>
#include <IAgoraRtmClient.h>  // Must include for IRtmEventHandler definition
#include <AgoraRtmBase.h>     // Must include for RTM types

// RTM Manager Event Handler Protocol
class IRtmManagerEventHandler {
public:
    virtual ~IRtmManagerEventHandler() = default;
    virtual void onLoginSuccess(const char* userId) = 0;
    virtual void onLoginFailed(int errorCode, const char* errorMessage) = 0;
    virtual void onLogout() = 0;
    virtual void onMessageReceived(const char* message, const char* fromUserId) = 0;
    virtual void onConnectionStateChanged(agora::rtm::RTM_LINK_STATE state, agora::rtm::RTM_LINK_STATE_CHANGE_REASON reason) = 0;
};

// RTM Manager Configuration
struct RtmManagerConfig {
    std::string appId;
    std::string userId;
};

// RTM Manager
/// Manages Agora RTM SDK v2.x lifecycle and operations
/// Singleton pattern for easy access throughout the application
/// Has internal event forwarding layer
class RtmManager {
public:
    // Singleton pattern
    static RtmManager& GetInstance();

    // Prevent copy and assignment
    RtmManager(const RtmManager&) = delete;
    RtmManager& operator=(const RtmManager&) = delete;

    // Public methods
    /// Initialize the RTM client with configuration
    bool Initialize(const RtmManagerConfig& config);

    /// Set the event handler for RTM callbacks
    void SetEventHandler(IRtmManagerEventHandler* handler);

    /// Login to RTM
    /// @param token RTM token for authentication (can be empty string)
    /// @param completion Completion callback with error code and message
    void Login(const std::string& token, std::function<void(int, const std::string&)> completion);

    /// Logout from RTM
    void Logout();

    /// Subscribe to a message channel
    /// @param channelName Name of the channel to subscribe
    /// @param completion Completion callback with error code and message
    void SubscribeChannel(const std::string& channelName, std::function<void(int, const std::string&)> completion);

    /// Unsubscribe from a channel
    /// @param channelName Name of the channel to unsubscribe
    void UnsubscribeChannel(const std::string& channelName);

    /// Send message to a channel
    /// @param channelName Name of the channel
    /// @param message Message to send
    /// @param completion Completion callback with error code and message
    void SendChannelMessage(const std::string& channelName, const std::string& message,
                           std::function<void(int, const std::string&)> completion);

    /// Destroy the RTM client and release resources
    void Destroy();

    /// Get the underlying RTM client instance (v2.x)
    agora::rtm::IRtmClient* GetRtmClient();

    // Getters
    bool IsInitialized() const { return m_isInitialized; }
    bool IsLoggedIn() const { return m_isLoggedIn; }
    std::string GetCurrentUserId() const { return m_currentUserId; }

private:
    RtmManager(); // Private constructor for singleton
    ~RtmManager(); // Private destructor for singleton

    // Internal event handler wrapper
    class RtmEventHandler : public agora::rtm::IRtmEventHandler {
    public:
        explicit RtmEventHandler(RtmManager* manager);

        // IRtmEventHandler callbacks (v2.x API) - use full type paths for override
        void onLinkStateEvent(const agora::rtm::IRtmEventHandler::LinkStateEvent& event) override;
        void onMessageEvent(const agora::rtm::IRtmEventHandler::MessageEvent& event) override;
        void onPresenceEvent(const agora::rtm::IRtmEventHandler::PresenceEvent& event) override;
        void onTopicEvent(const agora::rtm::IRtmEventHandler::TopicEvent& event) override;
        void onLockEvent(const agora::rtm::IRtmEventHandler::LockEvent& event) override;
        void onStorageEvent(const agora::rtm::IRtmEventHandler::StorageEvent& event) override;
        void onJoinResult(const uint64_t requestId, const char* channelName, const char* userId, 
                         agora::rtm::RTM_ERROR_CODE errorCode) override;
        void onLeaveResult(const uint64_t requestId, const char* channelName, const char* userId, 
                          agora::rtm::RTM_ERROR_CODE errorCode) override;
        void onLoginResult(const uint64_t requestId, agora::rtm::RTM_ERROR_CODE errorCode) override;
        void onSubscribeResult(const uint64_t requestId, const char* channelName, 
                              agora::rtm::RTM_ERROR_CODE errorCode) override;
        void onPublishResult(const uint64_t requestId, agora::rtm::RTM_ERROR_CODE errorCode) override;
        void onUnsubscribeResult(const uint64_t requestId, const char* channelName, 
                                agora::rtm::RTM_ERROR_CODE errorCode) override;

    private:
        RtmManager* m_manager;
    };

    // Internal properties
    agora::rtm::IRtmClient* m_rtmClient;
    std::unique_ptr<RtmEventHandler> m_internalHandler;
    IRtmManagerEventHandler* m_eventHandler;  // External event handler

    std::string m_appId;
    std::string m_currentUserId;
    bool m_isLoggedIn;
    bool m_isInitialized;

    // Request tracking for callbacks
    std::map<uint64_t, std::function<void(int, const std::string&)>> m_requestCallbacks;
    uint64_t m_lastLoginRequestId;
    uint64_t m_lastLogoutRequestId;

    // Subscribed channels
    std::map<std::string, bool> m_subscribedChannels;

    friend class RtmEventHandler;
};
