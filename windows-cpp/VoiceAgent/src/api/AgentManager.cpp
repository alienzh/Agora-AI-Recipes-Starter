// AgentManager.cpp: Start/Stop AI Agent via Server API
// Using HttpClient (libcurl) - Automatically handles HTTP redirects (308, etc.)
//

#include "../general/pch.h"
#include "AgentManager.h"
#include "HttpClient.h"
#include "../KeyCenter.h"
#include "../tools/Logger.h"

#include <nlohmann/json.hpp>
#include <sstream>

using json = nlohmann::json;

// Helper Functions

#include <curl/curl.h>

static std::string Base64Encode(const std::string& input) {
    // Use libcurl's base64 encoding
    char* encoded = curl_easy_escape(nullptr, input.c_str(), (int)input.length());
    
    // Actually, let's use proper base64 encoding
    static const char base64_chars[] = 
        "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        "abcdefghijklmnopqrstuvwxyz"
        "0123456789+/";
    
    std::string ret;
    int i = 0;
    int j = 0;
    unsigned char char_array_3[3];
    unsigned char char_array_4[4];
    const unsigned char* bytes_to_encode = (const unsigned char*)input.c_str();
    size_t in_len = input.length();

    while (in_len--) {
        char_array_3[i++] = *(bytes_to_encode++);
        if (i == 3) {
            char_array_4[0] = (char_array_3[0] & 0xfc) >> 2;
            char_array_4[1] = ((char_array_3[0] & 0x03) << 4) + ((char_array_3[1] & 0xf0) >> 4);
            char_array_4[2] = ((char_array_3[1] & 0x0f) << 2) + ((char_array_3[2] & 0xc0) >> 6);
            char_array_4[3] = char_array_3[2] & 0x3f;

            for(i = 0; i < 4; i++)
                ret += base64_chars[char_array_4[i]];
            i = 0;
        }
    }

    if (i) {
        for(j = i; j < 3; j++)
            char_array_3[j] = '\0';

        char_array_4[0] = (char_array_3[0] & 0xfc) >> 2;
        char_array_4[1] = ((char_array_3[0] & 0x03) << 4) + ((char_array_3[1] & 0xf0) >> 4);
        char_array_4[2] = ((char_array_3[1] & 0x0f) << 2) + ((char_array_3[2] & 0xc0) >> 6);

        for (j = 0; j < i + 1; j++)
            ret += base64_chars[char_array_4[j]];

        while((i++ < 3))
            ret += '=';
    }

    return ret;
}

std::string AgentManager::GenerateAuthorization() {
    std::string credentials = std::string(KeyCenter::REST_KEY) + ":" + std::string(KeyCenter::REST_SECRET);
    return "Basic " + Base64Encode(credentials);
}

// AgentManager Implementation (using HttpClient with libcurl)

void AgentManager::StartAgent(
    const std::string& channelName,
    const std::string& agentRtcUid,
    const std::string& token,
    AgentCallback callback
) {
    LOG_INFO("[AgentManager] Starting agent for channel: " + channelName + ", UID: " + agentRtcUid);

    // Build URL
    std::string urlString = std::string(KeyCenter::AGENT_SERVER_BASE_URL) + "/" + 
                           std::string(KeyCenter::AGORA_APP_ID) + "/join/";
    
    LOG_INFO("[AgentManager] Request URL: " + urlString);

    // Build request payload (JSON) using nlohmann/json
    json payload = {
        {"name", channelName},
        {"pipeline_id", KeyCenter::PIPELINE_ID},
        {"properties", {
            {"channel", channelName},
            {"agent_rtc_uid", agentRtcUid},
            {"remote_rtc_uids", json::array({"*"})},
            {"token", token}
        }}
    };

    std::string requestBodyStr = payload.dump();
    LOG_INFO("[AgentManager] Request body: " + requestBodyStr);

    // Prepare headers
    std::map<std::string, std::string> headers;
    headers["Content-Type"] = "application/json; charset=utf-8";
    headers["Authorization"] = GenerateAuthorization();

    // ✅ Use HttpClient (libcurl) - automatically handles all redirects including 308!
    HttpClient client;
    client.SetTimeout(30);
    
    client.PostAsync(urlString, requestBodyStr, headers,
        [callback](bool success, const std::string& response, int statusCode) {
            if (!success) {
                LOG_ERROR("[AgentManager] Request failed: " + response);
                if (callback) {
                    callback(false, response);
                }
                return;
            }
            
            // Parse JSON response using nlohmann/json
            try {
                json responseJson = json::parse(response);
                
                if (responseJson.contains("agent_id") && responseJson["agent_id"].is_string()) {
                    std::string agentId = responseJson["agent_id"].get<std::string>();
                    LOG_INFO("[AgentManager] Agent started, ID: " + agentId);
                    
                    if (callback) {
                        callback(true, agentId);
                    }
                } else {
                    std::string errorMsg = "agent_id not found in response";
                    LOG_ERROR("[AgentManager] " + errorMsg);
                    if (callback) {
                        callback(false, errorMsg);
                    }
                }
            } catch (const std::exception& e) {
                std::string errorMsg = std::string("Failed to parse response: ") + e.what();
                LOG_ERROR("[AgentManager] " + errorMsg);
                if (callback) {
                    callback(false, errorMsg);
                }
            }
        }
    );
}

void AgentManager::StopAgent(
    const std::string& agentId,
    AgentCallback callback
) {
    LOG_INFO("[AgentManager] Stopping agent: " + agentId);

    // Build URL
    std::string urlString = std::string(KeyCenter::AGENT_SERVER_BASE_URL) + "/" + 
                           std::string(KeyCenter::AGORA_APP_ID) + "/agents/" + 
                           agentId + "/leave";
    
    LOG_INFO("[AgentManager] Stop URL: " + urlString);

    // Prepare headers
    std::map<std::string, std::string> headers;
    headers["Content-Type"] = "application/json; charset=utf-8";
    headers["Authorization"] = GenerateAuthorization();

    // ✅ Use HttpClient (libcurl) - automatically handles all redirects including 308!
    HttpClient client;
    client.SetTimeout(30);
    
    client.PostAsync(urlString, "", headers,
        [callback](bool success, const std::string& response, int statusCode) {
            if (!success) {
                LOG_ERROR("[AgentManager] Stop request failed: " + response);
                if (callback) {
                    callback(false, response);
                }
                return;
            }
            
            LOG_INFO("[AgentManager] Agent stopped");
            if (callback) {
                callback(true, "Agent stopped");
            }
        }
    );
}

void AgentManager::CheckServerHealth(AgentCallback callback) {
    std::string baseURL = KeyCenter::AGENT_SERVER_BASE_URL;
    
    // Health check only for local server
    if (baseURL.find("http://") != 0) {
        // For Agora API, assume healthy
        if (callback) {
            callback(true, "Agora API (assumed healthy)");
        }
        return;
    }
    
    std::string urlString = baseURL + "/health";
    
    std::map<std::string, std::string> headers;
    
    HttpClient client;
    client.SetTimeout(5);
    
    client.PostAsync(urlString, "", headers,
        [callback](bool success, const std::string& response, int statusCode) {
            if (callback) {
                callback(success && statusCode == 200, response);
            }
        }
    );
}

