//
// ConversationalAIAPI.cpp: Transcript parser and message handler implementation
//

#include "../general/pch.h"
#include "ConversationalAIAPI.h"
#include "../tools/Logger.h"
#include "../tools/StringUtils.h"

#include <nlohmann/json.hpp>
#include <sstream>
#include <algorithm>

using json = nlohmann::json;

ConversationalAIAPI::ConversationalAIAPI() {
    LOG_INFO("[ConversationalAIAPI] Initialized");
}

ConversationalAIAPI::~ConversationalAIAPI() {
    m_handlers.clear();
    m_transcriptCache.clear();
    LOG_INFO("[ConversationalAIAPI] Destroyed");
}

void ConversationalAIAPI::AddHandler(IConversationalAIAPIEventHandler* handler) {
    if (handler && std::find(m_handlers.begin(), m_handlers.end(), handler) == m_handlers.end()) {
        m_handlers.push_back(handler);
    }
}

void ConversationalAIAPI::RemoveHandler(IConversationalAIAPIEventHandler* handler) {
    auto it = std::find(m_handlers.begin(), m_handlers.end(), handler);
    if (it != m_handlers.end()) {
        m_handlers.erase(it);
    }
}

void ConversationalAIAPI::HandleMessage(const std::string& message, const std::string& fromUserId) {
    ParseAndDispatchMessage(message, fromUserId);
}

void ConversationalAIAPI::ParseAndDispatchMessage(const std::string& jsonString, const std::string& userId) {
    try {
        json jsonValue = json::parse(jsonString);
        
        if (!jsonValue.is_object() || !jsonValue.contains("object")) {
            return;
        }

        std::string messageType = jsonValue["object"].get<std::string>();

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

        if (messageType == "assistant.transcription" || messageType == "user.transcription") {
            HandleTranscriptMessage(userId, messageData);
        } else if (messageType == "message.state") {
            HandleStateMessage(userId, messageData);
        }

    } catch (const std::exception& e) {
        LOG_ERROR("[ConversationalAIAPI] Parse error: " + std::string(e.what()));
    }
}

void ConversationalAIAPI::HandleTranscriptMessage(const std::string& userId, const std::map<std::string, std::string>& messageData) {
    try {
        auto turnIdIt = messageData.find("turn_id");
        auto textIt = messageData.find("text");
        auto statusIt = messageData.find("status");
        auto objectIt = messageData.find("object");

        if (turnIdIt == messageData.end() || textIt == messageData.end()) {
            return;
        }

        int turnId = std::stoi(turnIdIt->second);
        std::string text = textIt->second;
        
        TranscriptStatus status = TranscriptStatus::InProgress;
        if (statusIt != messageData.end()) {
            std::string statusStr = statusIt->second;
            if (statusStr == "end") {
                status = TranscriptStatus::End;
            } else if (statusStr == "interrupted") {
                status = TranscriptStatus::Interrupted;
            }
        }

        TranscriptType type = TranscriptType::Agent;
        if (objectIt != messageData.end()) {
            if (objectIt->second == "user.transcription") {
                type = TranscriptType::User;
            }
        }

        std::string cacheKey = userId + "_" + std::to_string(turnId);
        
        auto it = m_transcriptCache.find(cacheKey);
        if (it != m_transcriptCache.end()) {
            it->second.text = text;
            it->second.status = status;
        } else {
            Transcript transcript(turnId, userId, text, status, type);
            m_transcriptCache[cacheKey] = transcript;
        }

        NotifyTranscriptUpdated(userId, m_transcriptCache[cacheKey]);

    } catch (const std::exception& e) {
        LOG_ERROR("[ConversationalAIAPI] HandleTranscriptMessage error: " + std::string(e.what()));
    }
}

void ConversationalAIAPI::HandleStateMessage(const std::string& userId, const std::map<std::string, std::string>& messageData) {
    try {
        auto stateIt = messageData.find("state");
        auto turnIdIt = messageData.find("turn_id");
        auto timestampIt = messageData.find("timestamp");
        auto reasonIt = messageData.find("reason");

        if (stateIt == messageData.end() || turnIdIt == messageData.end()) {
            return;
        }

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
