package io.agora.convoai.example.voiceassistant.tools

import java.util.Base64

object Base64Encoding {

    /**
     * Generate Basic authorization header from customer key and secret
     *
     * @param customerKey Customer key
     * @param customerSecret Customer secret
     * @return Authorization header string in format "Basic <base64_encoded_credentials>"
     */
    fun gen(customerKey: String, customerSecret: String): String {
        // Concatenate customer ID and customer secret, then encode with base64
        val plainCredentials = "$customerKey:$customerSecret"
        val base64Credentials = String(Base64.getEncoder().encode(plainCredentials.toByteArray()))

        // Create authorization header
        return "Basic $base64Credentials"
    }
}