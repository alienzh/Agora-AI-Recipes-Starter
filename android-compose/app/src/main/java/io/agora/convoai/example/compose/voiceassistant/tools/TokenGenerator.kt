package io.agora.convoai.example.compose.voiceassistant.tools

import io.agora.convoai.example.compose.voiceassistant.KeyCenter
import io.agora.convoai.example.compose.voiceassistant.net.SecureOkHttpClient
import kotlinx.coroutines.*
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject

sealed class AgoraTokenType(val value: Int) {
    data object Rtc : AgoraTokenType(1)
    data object Rtm : AgoraTokenType(2)
    data object Chat : AgoraTokenType(3)
}

object TokenGenerator {
    private const val TOOLBOX_SERVER_HOST = "https://service.apprtc.cn/toolbox"

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private val okHttpClient: OkHttpClient by lazy {
        SecureOkHttpClient.create()
            .build()
    }

    var expireSecond: Long = -1
        private set

    fun generateTokens(
        channelName: String,
        uid: String,
        tokenTypes: Array<AgoraTokenType> = arrayOf(AgoraTokenType.Rtc, AgoraTokenType.Rtm),
        success: (String) -> Unit,
        failure: ((Exception?) -> Unit)? = null
    ) {
        scope.launch(Dispatchers.Main) {
            try {
                val token = fetchToken(channelName, uid, tokenTypes)
                success(token)
            } catch (e: Exception) {
                failure?.invoke(e)
            }
        }
    }

    suspend fun generateTokensAsync(
        channelName: String,
        uid: String,
        tokenTypes: Array<AgoraTokenType> = arrayOf(AgoraTokenType.Rtc, AgoraTokenType.Rtm)
    ): Result<String> = withContext(Dispatchers.Main) {
        try {
            Result.success(fetchToken(channelName, uid, tokenTypes))
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    private suspend fun fetchToken(
        channelName: String,
        uid: String,
        tokenTypes: Array<AgoraTokenType>
    ): String = withContext(Dispatchers.IO) {
        val postBody = buildJsonRequest(channelName, uid, tokenTypes)
        val request = buildHttpRequest(postBody)

        executeRequest(request)
    }

    private fun buildJsonRequest(
        channelName: String,
        uid: String,
        tokenTypes: Array<AgoraTokenType>
    ): JSONObject = JSONObject().apply {
        put("appId", KeyCenter.AGORA_APP_ID)
        put("appCertificate", KeyCenter.AGORA_APP_CERTIFICATE)
        put("channelName", channelName)
        put("expire", if (expireSecond > 0) expireSecond else 60 * 60 * 24)
        put("src", "Android")
        put("ts", System.currentTimeMillis().toString())

        when (tokenTypes.size) {
            1 -> put("type", tokenTypes[0].value)
            else -> put("types", JSONArray(tokenTypes.map { it.value }))
        }

        put("uid", uid)
    }

    private fun buildHttpRequest(postBody: JSONObject): Request {
        // Use Token007 endpoint
        val url = "$TOOLBOX_SERVER_HOST/v2/token/generate"

        return Request.Builder()
            .url(url)
            .addHeader("Content-Type", "application/json")
            .post(postBody.toString().toRequestBody())
            .build()
    }

    private fun executeRequest(request: Request): String {
        val response = okHttpClient.newCall(request).execute()

        if (!response.isSuccessful) {
            throw RuntimeException("Fetch token error: httpCode=${response.code}, httpMsg=${response.message}")
        }

        val body = response.body?.string() ?: throw RuntimeException("Response body is null")
        val bodyJson = JSONObject(body)
        if (bodyJson.optInt("code", -1) != 0) {
            throw RuntimeException(
                "Fetch token error: httpCode=${response.code}, " +
                        "httpMsg=${response.message}, " +
                        "reqCode=${bodyJson.opt("code")}, " +
                        "reqMsg=${bodyJson.opt("message")}"
            )
        }
        return (bodyJson.getJSONObject("data")).getString("token")
    }
}