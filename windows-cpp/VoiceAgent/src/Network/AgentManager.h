#pragma once

#include <string>
#include <functional>

// Agent operation callback
using AgentCallback = std::function<void(bool success, const std::string& agentIdOrError)>;

// Agent Manager
// Unified interface for starting/stopping AI agents
// Supports both local server and Agora API
class AgentManager {
public:
    /// Start an agent
    /// @param channelName Channel name for the agent
    /// @param agentRtcUid Agent RTC UID
    /// @param token Agent token (required)
    /// @param callback Completion handler with success flag and agentId or error message
    static void StartAgent(
        const std::string& channelName,
        const std::string& agentRtcUid,
        const std::string& token,
        AgentCallback callback = nullptr
    );
    
    /// Stop an agent
    /// @param agentId Agent ID returned from StartAgent
    /// @param callback Completion handler with success flag and error message if failed
    static void StopAgent(
        const std::string& agentId,
        AgentCallback callback = nullptr
    );
    
    /// Check server health (for debugging)
    /// @param callback Completion handler with success flag and response
    static void CheckServerHealth(AgentCallback callback = nullptr);
    
private:
    // Generate Basic Authorization header (Base64 encoded REST_KEY:REST_SECRET)
    static std::string GenerateAuthorization();
    
    // HTTP POST request helper
    static void PostRequest(
        const std::string& url,
        const std::string& authorization,
        const std::string& jsonBody,
        std::function<void(bool success, const std::string& response, const std::string& error)> callback
    );
    
    // HTTP DELETE request helper
    static void DeleteRequest(
        const std::string& url,
        const std::string& authorization,
        std::function<void(bool success, const std::string& response, const std::string& error)> callback
    );
};

