package io.agora.convoai.example.voiceassistant.tools;

import java.util.Base64;

/**
 * Base64Encoding utility class
 * Generate Basic authorization header from customer key and secret
 */
public class Base64Encoding {

    /**
     * Generate Basic authorization header from customer key and secret
     *
     * @param customerKey Customer key
     * @param customerSecret Customer secret
     * @return Authorization header string in format "Basic <base64_encoded_credentials>"
     */
    public static String gen(String customerKey, String customerSecret) {
        // Concatenate customer ID and customer secret, then encode with base64
        String plainCredentials = customerKey + ":" + customerSecret;
        String base64Credentials = new String(Base64.getEncoder().encode(plainCredentials.getBytes()));

        // Create authorization header
        return "Basic " + base64Credentials;
    }
}
