// RtcManager.h: RTC SDK Manager
//
#pragma once

#include <string>
#include <IAgoraRtcEngine.h>  // Must include for IRtcEngineEventHandler definition

// RTC Manager
/// Manages Agora RTC SDK lifecycle and operations
/// Singleton pattern for easy access throughout the application
/// Uses direct delegate pattern with no internal event forwarding
class RtcManager {
public:
    // Singleton pattern
    static RtcManager& GetInstance();

    // Prevent copy and assignment
    RtcManager(const RtcManager&) = delete;
    RtcManager& operator=(const RtcManager&) = delete;

    // Public methods
    
    /// Creates and initializes an RTC engine instance
    /// @param delegate External event handler (e.g., MainFrm implements IRtcEngineEventHandler)
    /// @return Pointer to the initialized RTC engine, or nullptr if failed
    agora::rtc::IRtcEngine* CreateRtcEngine(agora::rtc::IRtcEngineEventHandler* delegate);

    /// Join an RTC channel
    /// @param rtcToken RTC token for authentication
    /// @param channelName Name of the channel to join
    /// @param uid User ID (0 for auto-assignment)
    /// @return true if join request was successful
    bool JoinChannel(const std::string& rtcToken, const std::string& channelName, unsigned int uid);

    /// Leave the current RTC channel
    void LeaveChannel();

    /// Renew the RTC token
    void RenewToken(const std::string& token);

    /// Mute or unmute local audio
    /// @param mute true to mute, false to unmute
    void MuteLocalAudio(bool mute);

    /// Destroy the RTC engine and release resources
    void Destroy();

    /// Get the underlying RTC engine instance
    agora::rtc::IRtcEngine* GetRtcEngine();

    // Getters
    bool IsInitialized() const { return m_isInitialized; }
    std::string GetCurrentChannel() const { return m_currentChannel; }
    unsigned int GetCurrentUid() const { return m_currentUid; }

private:
    RtcManager(); // Private constructor for singleton
    ~RtcManager(); // Private destructor for singleton

    // Internal properties
    agora::rtc::IRtcEngine* m_rtcEngine;

    std::string m_currentChannel;
    unsigned int m_currentUid;
    bool m_isInitialized;
};
