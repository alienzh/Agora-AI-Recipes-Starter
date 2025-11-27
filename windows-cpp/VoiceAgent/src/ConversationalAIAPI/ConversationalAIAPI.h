//
// ConversationalAIAPI.h: Transcript parser and message handler
//
#pragma once

#include <string>
#include <vector>
#include <functional>
#include <map>

// Forward Declarations
class RtmManager;

// Enums

/// Transcript status
enum class TranscriptStatus {
    InProgress = 0,
    End = 1,
    Interrupted = 2
};

/// Transcript type (agent or user)
enum class TranscriptType {
    Agent = 0,
    User = 1
};

/// Agent state
enum class AgentState {
    Idle = 0,
    Silent = 1,
    Listening = 2,
    Thinking = 3,
    Speaking = 4,
    Unknown = 5
};

// Data Models

/// Transcript data model
struct Transcript {
    int turnId;
    std::string userId;
    std::string text;
    TranscriptStatus status;
    TranscriptType type;
    
    Transcript() : turnId(0), status(TranscriptStatus::InProgress), type(TranscriptType::Agent) {}
    Transcript(int tid, const std::string& uid, const std::string& txt, TranscriptStatus st, TranscriptType tp)
        : turnId(tid), userId(uid), text(txt), status(st), type(tp) {}
};

/// Agent state change event
struct StateChangeEvent {
    AgentState state;
    int turnId;
    int64_t timestamp;
    std::string reason;
    
    StateChangeEvent() : state(AgentState::Unknown), turnId(0), timestamp(0) {}
    StateChangeEvent(AgentState s, int tid, int64_t ts, const std::string& r)
        : state(s), turnId(tid), timestamp(ts), reason(r) {}
};

// Event Handler Protocol

/// ConversationalAI API event handler
/// Receives callbacks for transcript updates and state changes
class IConversationalAIAPIEventHandler {
public:
    virtual ~IConversationalAIAPIEventHandler() = default;
    
    /// Called when agent state changes
    /// - Parameters:
    ///   - agentUserId: Agent RTM user ID
    ///   - event: State change event
    virtual void OnAgentStateChanged(const std::string& agentUserId, const StateChangeEvent& event) = 0;
    
    /// Called when transcript is updated
    /// - Parameters:
    ///   - agentUserId: Agent RTM user ID
    ///   - transcript: Updated transcript data
    virtual void OnTranscriptUpdated(const std::string& agentUserId, const Transcript& transcript) = 0;
};

// ConversationalAI API

/// ConversationalAI API for handling RTM messages and parsing transcripts
class ConversationalAIAPI {
public:
    /// Initialize the API
    /// - Parameter rtmManager: RTM manager instance for receiving messages
    explicit ConversationalAIAPI(RtmManager* rtmManager);
    
    ~ConversationalAIAPI();
    
    /// Add event handler
    /// - Parameter handler: Event handler to add
    void AddHandler(IConversationalAIAPIEventHandler* handler);
    
    /// Remove event handler
    /// - Parameter handler: Event handler to remove
    void RemoveHandler(IConversationalAIAPIEventHandler* handler);
    
    /// Subscribe to channel messages
    /// - Parameters:
    ///   - channelName: Channel name to subscribe
    ///   - completion: Completion callback with error code and message
    void SubscribeMessage(const std::string& channelName, std::function<void(int, const std::string&)> completion);
    
    /// Handle incoming RTM message
    /// - Parameters:
    ///   - message: Message content (JSON string)
    ///   - fromUserId: Sender user ID
    void HandleMessage(const std::string& message, const std::string& fromUserId);
    
private:
    // Internal methods
    void ParseAndDispatchMessage(const std::string& jsonString, const std::string& userId);
    void HandleTranscriptMessage(const std::string& userId, const std::map<std::string, std::string>& messageData);
    void HandleStateMessage(const std::string& userId, const std::map<std::string, std::string>& messageData);
    void NotifyTranscriptUpdated(const std::string& agentUserId, const Transcript& transcript);
    void NotifyStateChanged(const std::string& agentUserId, const StateChangeEvent& event);
    
    // Members
    RtmManager* m_rtmManager;
    std::vector<IConversationalAIAPIEventHandler*> m_handlers;
    std::string m_channelName;  // Subscribed channel name
    
    // Transcript cache (key: userId_turnId)
    std::map<std::string, Transcript> m_transcriptCache;
};

