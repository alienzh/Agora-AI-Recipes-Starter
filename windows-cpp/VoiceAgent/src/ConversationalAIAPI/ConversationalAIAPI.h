//
// ConversationalAIAPI.h: Transcript parser and message handler
//
#pragma once

#include <string>
#include <vector>
#include <functional>
#include <map>

// Enums

enum class TranscriptStatus {
    InProgress = 0,
    End = 1,
    Interrupted = 2
};

enum class TranscriptType {
    Agent = 0,
    User = 1
};

enum class AgentState {
    Idle = 0,
    Silent = 1,
    Listening = 2,
    Thinking = 3,
    Speaking = 4,
    Unknown = 5
};

// Data Models

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

class IConversationalAIAPIEventHandler {
public:
    virtual ~IConversationalAIAPIEventHandler() = default;
    virtual void OnAgentStateChanged(const std::string& agentUserId, const StateChangeEvent& event) = 0;
    virtual void OnTranscriptUpdated(const std::string& agentUserId, const Transcript& transcript) = 0;
};

// ConversationalAI API - Message parser only (no RTM dependency)

class ConversationalAIAPI {
public:
    ConversationalAIAPI();
    ~ConversationalAIAPI();
    
    void AddHandler(IConversationalAIAPIEventHandler* handler);
    void RemoveHandler(IConversationalAIAPIEventHandler* handler);
    
    /// Handle incoming RTM message
    void HandleMessage(const std::string& message, const std::string& fromUserId);
    
private:
    void ParseAndDispatchMessage(const std::string& jsonString, const std::string& userId);
    void HandleTranscriptMessage(const std::string& userId, const std::map<std::string, std::string>& messageData);
    void HandleStateMessage(const std::string& userId, const std::map<std::string, std::string>& messageData);
    void NotifyTranscriptUpdated(const std::string& agentUserId, const Transcript& transcript);
    void NotifyStateChanged(const std::string& agentUserId, const StateChangeEvent& event);
    
    std::vector<IConversationalAIAPIEventHandler*> m_handlers;
    std::map<std::string, Transcript> m_transcriptCache;
};
