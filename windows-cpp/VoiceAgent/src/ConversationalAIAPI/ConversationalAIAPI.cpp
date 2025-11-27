//
// ConversationalAIAPI.cpp: Transcript parser and message handler implementation
//

#include "../General/pch.h"
#include "ConversationalAIAPI.h"
#include "../rtm/RtmManager.h"
#include "../tools/Logger.h"
#include "../tools/StringUtils.h"

#include <nlohmann/json.hpp>
#include <sstream>
#include <algorithm>

using json = nlohmann::json;

// Constructor / Destructor

ConversationalAIAPI::ConversationalAIAPI(RtmManager* rtmManager)
    : m_rtmManager(rtmManager) {
    LOG_INFO("[ConversationalAIAPI] Initialized");
}

ConversationalAIAPI::~ConversationalAIAPI() {
    // Clean up handlers and cache
    m_handlers.clear();
    m_transcriptCache.clear();
    LOG_INFO("[ConversationalAIAPI] Destroyed");
}

// Public Methods

void ConversationalAIAPI::AddHandler(IConversationalAIAPIEventHandler* handler) {
    if (handler && std::find(m_handlers.begin(), m_handlers.end(), handler) == m_handlers.end()) {
        m_handlers.push_back(handler);
        LOG_INFO("[ConversationalAIAPI] Handler added, total: " + std::to_string(m_handlers.size()));
    }
}

void ConversationalAIAPI::RemoveHandler(IConversationalAIAPIEventHandler* handler) {
    auto it = std::find(m_handlers.begin(), m_handlers.end(), handler);
    if (it != m_handlers.end()) {
        m_handlers.erase(it);
        LOG_INFO("[ConversationalAIAPI] Handler removed, remaining: " + std::to_string(m_handlers.size()));
    }
}

void ConversationalAIAPI::SubscribeMessage(const std::string& channelName, std::function<void(int, const std::string&)> completion) {
    if (!m_rtmManager) {
        LOG_ERROR("[ConversationalAIAPI] RTM manager is null");
        if (completion) {
            completion(-1, "RTM manager is null");
        }
        return;
    }
    
    m_channelName = channelName;
    LOG_INFO("[ConversationalAIAPI] Subscribing to channel: " + channelName);
    
    // Subscribe through RTM manager
    m_rtmManager->SubscribeChannel(channelName, [this, completion](int errorCode, const std::string& errorMsg) {
        if (errorCode == 0) {
            LOG_INFO("[ConversationalAIAPI] ✅ Subscribed to channel: " + m_channelName);
        } else {
            LOG_ERROR("[ConversationalAIAPI] ❌ Failed to subscribe to channel: " + errorMsg);
        }
        
        if (completion) {
            completion(errorCode, errorMsg);
        }
    });
}

void ConversationalAIAPI::HandleMessage(const std::string& message, const std::string& fromUserId) {
    LOG_INFO("[ConversationalAIAPI] Received message from: " + fromUserId);
    ParseAndDispatchMessage(message, fromUserId);
}

// Private Methods

void ConversationalAIAPI::ParseAndDispatchMessage(const std::string& jsonString, const std::string& userId) {
    try {
        // Parse JSON using nlohmann/json
        json jsonValue = json::parse(jsonString);
        
        if (!jsonValue.is_object()) {
            LOG_ERROR("[ConversationalAIAPI] Invalid JSON format");
            return;
        }

        // Get message type from "object" field
        if (!jsonValue.contains("object")) {
            LOG_ERROR("[ConversationalAIAPI] Missing 'object' field");
            return;
        }

        std::string messageType = jsonValue["object"].get<std::string>();
        LOG_INFO("[ConversationalAIAPI] Message type: " + messageType);

        // Convert JSON to map for easier handling
        std::map<std::string, std::string> messageData;
        for (auto& [key, value] : jsonValue.items()) {
            if (value.is_string()) {
                messageData[key] = value.get<std::string>();
            } else if (value.is_number_integer()) {
                messageData[key] = std::to_string(value.get<int64_t>());
            } else if (value.is_number_float()) {
                messageData[key] = std::to_string(value.get<double>());
            }
        }

        // Dispatch based on message type
        if (messageType == "assistant.transcription" || messageType == "user.transcription") {
            HandleTranscriptMessage(userId, messageData);
        } else if (messageType == "message.state") {
            HandleStateMessage(userId, messageData);
        }
        // Add more message types as needed (metrics, error, etc.)

    } catch (const std::exception& e) {
        LOG_ERROR("[ConversationalAIAPI] Parse error: " + std::string(e.what()));
    }
}

void ConversationalAIAPI::HandleTranscriptMessage(const std::string& userId, const std::map<std::string, std::string>& messageData) {
    try {
        // Extract required fields
        auto turnIdIt = messageData.find("turn_id");
        auto textIt = messageData.find("text");
        auto statusIt = messageData.find("status");
        auto objectIt = messageData.find("object");

        if (turnIdIt == messageData.end() || textIt == messageData.end()) {
            LOG_ERROR("[ConversationalAIAPI] Missing required transcript fields");
            return;
        }

        int turnId = std::stoi(turnIdIt->second);
        std::string text = textIt->second;
        
        // Determine transcript status
        TranscriptStatus status = TranscriptStatus::InProgress;
        if (statusIt != messageData.end()) {
            std::string statusStr = statusIt->second;
            if (statusStr == "end") {
                status = TranscriptStatus::End;
            } else if (statusStr == "interrupted") {
                status = TranscriptStatus::Interrupted;
            }
        }

        // Determine transcript type (agent or user)
        TranscriptType type = TranscriptType::Agent;
        if (objectIt != messageData.end()) {
            std::string objectStr = objectIt->second;
            if (objectStr == "user.transcription") {
                type = TranscriptType::User;
            }
        }

        // Create or update transcript
        std::string cacheKey = userId + "_" + std::to_string(turnId);
        
        auto it = m_transcriptCache.find(cacheKey);
        if (it != m_transcriptCache.end()) {
            // Update existing transcript
            it->second.text = text;
            it->second.status = status;
            // Convert UTF-8 to GBK for log display
            std::string displayText = StringUtils::Utf8ToGBK(text);
            LOG_INFO("[ConversationalAIAPI] Updated transcript: turnId=" + std::to_string(turnId) + ", text=" + displayText);
        } else {
            // Create new transcript
            Transcript transcript(turnId, userId, text, status, type);
            m_transcriptCache[cacheKey] = transcript;
            // Convert UTF-8 to GBK for log display
            std::string displayText = StringUtils::Utf8ToGBK(text);
            LOG_INFO("[ConversationalAIAPI] New transcript: turnId=" + std::to_string(turnId) + ", text=" + displayText);
        }

        // Notify handlers
        NotifyTranscriptUpdated(userId, m_transcriptCache[cacheKey]);

    } catch (const std::exception& e) {
        LOG_ERROR("[ConversationalAIAPI] HandleTranscriptMessage error: " + std::string(e.what()));
    }
}

void ConversationalAIAPI::HandleStateMessage(const std::string& userId, const std::map<std::string, std::string>& messageData) {
    try {
        // Extract required fields
        auto stateIt = messageData.find("state");
        auto turnIdIt = messageData.find("turn_id");
        auto timestampIt = messageData.find("timestamp");
        auto reasonIt = messageData.find("reason");

        if (stateIt == messageData.end() || turnIdIt == messageData.end()) {
            LOG_ERROR("[ConversationalAIAPI] Missing required state fields");
            return;
        }

        // Parse state
        std::string stateStr = stateIt->second;
        AgentState state = AgentState::Unknown;
        if (stateStr == "idle") state = AgentState::Idle;
        else if (stateStr == "silent") state = AgentState::Silent;
        else if (stateStr == "listening") state = AgentState::Listening;
        else if (stateStr == "thinking") state = AgentState::Thinking;
        else if (stateStr == "speaking") state = AgentState::Speaking;

        int turnId = std::stoi(turnIdIt->second);
        int64_t timestamp = (timestampIt != messageData.end()) ? std::stoll(timestampIt->second) : 0;
        std::string reason = (reasonIt != messageData.end()) ? reasonIt->second : "";

        StateChangeEvent event(state, turnId, timestamp, reason);
        LOG_INFO("[ConversationalAIAPI] State changed: " + stateStr + ", turnId=" + std::to_string(turnId));

        // Notify handlers
        NotifyStateChanged(userId, event);

    } catch (const std::exception& e) {
        LOG_ERROR("[ConversationalAIAPI] HandleStateMessage error: " + std::string(e.what()));
    }
}

void ConversationalAIAPI::NotifyTranscriptUpdated(const std::string& agentUserId, const Transcript& transcript) {
    for (auto handler : m_handlers) {
        if (handler) {
            handler->OnTranscriptUpdated(agentUserId, transcript);
        }
    }
}

void ConversationalAIAPI::NotifyStateChanged(const std::string& agentUserId, const StateChangeEvent& event) {
    for (auto handler : m_handlers) {
        if (handler) {
            handler->OnAgentStateChanged(agentUserId, event);
        }
    }
}

