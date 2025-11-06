package io.agora.convoai.example.voiceassistant.tools

import io.agora.convoai.example.voiceassistant.KeyCenter
import io.agora.convoai.example.voiceassistant.net.SecureOkHttpClient
import kotlinx.coroutines.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject

/**
 * Agent starter utility for joining conversational AI agents
 */
object AgentAIStudioStarter {
    private const val API_BASE_URL = "https://api.agora.io/cn/api/conversational-ai-agent/v2/projects"
    private const val JSON_MEDIA_TYPE = "application/json; charset=utf-8"

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private val okHttpClient: OkHttpClient by lazy {
        SecureOkHttpClient.create()
            .build()
    }

    /**
     * Start an agent with suspend function
     * Project ID is automatically retrieved from KeyCenter.AGORA_APP_ID
     *
     * @param name Agent name
     * @param pipelineId Pipeline ID
     * @param channel Channel name
     * @param agentRtcUid Agent RTC UID
     * @param token Token string
     * @param remoteRtcUids Remote RTC UIDs list, defaults to ["*"]
     * @return Result containing response text or exception
     */
    suspend fun startAgentAsync(
        name: String,
        pipelineId: String,
        channel: String,
        agentRtcUid: String,
        token: String,
        remoteRtcUids: List<String> = listOf("*")
    ): Result<String> = withContext(Dispatchers.IO) {
        try {
            val responseText = executeJoinRequest(name, pipelineId, channel, agentRtcUid, token, remoteRtcUids)
            val json = JSONObject(responseText)
            val agentId = json.optString("agent_id", "")
            if (agentId.isBlank()) {
                throw RuntimeException("Failed to parse agent_id from response: $responseText")
            }
            Result.success(agentId)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    /**
     * Stop an agent with suspend function
     * Project ID is automatically retrieved from KeyCenter.AGORA_APP_ID
     *
     * @param agentId Agent ID to stop
     * @return Result containing success or exception
     */
    suspend fun stopAgentAsync(agentId: String): Result<Unit> = withContext(Dispatchers.IO) {
        try {
            executeLeaveRequest(agentId)
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    private suspend fun executeJoinRequest(
        name: String,
        pipelineId: String,
        channel: String,
        agentRtcUid: String,
        token: String,
        remoteRtcUids: List<String>
    ): String = withContext(Dispatchers.IO) {
        val projectId = KeyCenter.AGORA_APP_ID
        val url = "$API_BASE_URL/$projectId/join/"
        val payload = buildJsonPayload(name, pipelineId, channel, agentRtcUid, token, remoteRtcUids)
        val httpRequest = buildHttpRequest(url, payload)

        val response = okHttpClient.newCall(httpRequest).execute()

        if (!response.isSuccessful) {
            throw RuntimeException(
                "Join agent error: httpCode=${response.code}, httpMsg=${response.message}"
            )
        }

        return@withContext response.body.string()
    }

    private fun buildJsonPayload(
        name: String,
        pipelineId: String,
        channel: String,
        agentRtcUid: String,
        token: String,
        remoteRtcUids: List<String>
    ): JSONObject {
        val payloadMap = mapOf(
            "name" to name,
            "pipeline_id" to pipelineId,
            "properties" to mapOf(
                "channel" to channel,
                "agent_rtc_uid" to agentRtcUid,
                "remote_rtc_uids" to remoteRtcUids,
                "token" to token
            )
        )
        return mapToJsonObjectWithFilter(payloadMap)
    }

    private suspend fun executeLeaveRequest(agentId: String): Unit = withContext(Dispatchers.IO) {
        val projectId = KeyCenter.AGORA_APP_ID
        val url = "$API_BASE_URL/$projectId/agents/$agentId/leave"
        val httpRequest = buildLeaveHttpRequest(url)

        val response = okHttpClient.newCall(httpRequest).execute()

        if (!response.isSuccessful) {
            throw RuntimeException(
                "Leave agent error: httpCode=${response.code}, httpMsg=${response.message}"
            )
        }

        // Close the response body
        response.body.close()
    }

    private fun buildHttpRequest(url: String, payload: JSONObject): Request {
        // Generate Authorization header using KeyCenter REST_KEY and REST_SECRET
        val authorization = Base64Encoding.gen(KeyCenter.REST_KEY, KeyCenter.REST_SECRET)

        return Request.Builder()
            .url(url)
            .addHeader("Content-Type", JSON_MEDIA_TYPE)
            .addHeader("Authorization", authorization)
            .post(payload.toString().toRequestBody(JSON_MEDIA_TYPE.toMediaType()))
            .build()
    }

    private fun buildLeaveHttpRequest(url: String): Request {
        // Generate Authorization header using KeyCenter REST_KEY and REST_SECRET
        val authorization = Base64Encoding.gen(KeyCenter.REST_KEY, KeyCenter.REST_SECRET)

        // POST request without body
        return Request.Builder()
            .url(url)
            .addHeader("Authorization", authorization)
            .post("".toRequestBody("application/json; charset=utf-8".toMediaType()))
            .build()
    }

    private fun mapToJsonObjectWithFilter(map: Map<String, Any?>): JSONObject {
        val jsonObject = JSONObject()
        map.forEach { (key, value) ->
            when {
                value == null -> {
                    // Skip null values
                }

                value is Map<*, *> -> {
                    // Handle nested Map
                    @Suppress("UNCHECKED_CAST")
                    val nestedJsonObject = mapToJsonObjectWithFilter(value as Map<String, Any?>)
                    if (nestedJsonObject.length() > 0) {
                        jsonObject.put(key, nestedJsonObject)
                    }
                }

                value is List<*> -> {
                    // Handle List type
                    val jsonArray = org.json.JSONArray()
                    value.forEach { item ->
                        when {
                            item == null -> {
                                // Skip null values
                            }

                            item is Map<*, *> -> {
                                // Handle Map in List
                                @Suppress("UNCHECKED_CAST")
                                jsonArray.put(mapToJsonObjectWithFilter(item as Map<String, Any?>))
                            }

                            else -> {
                                jsonArray.put(item)
                            }
                        }
                    }
                    if (jsonArray.length() > 0) {
                        jsonObject.put(key, jsonArray)
                    }
                }

                else -> {
                    // Handle basic types
                    jsonObject.put(key, value)
                }
            }
        }
        return jsonObject
    }
}
