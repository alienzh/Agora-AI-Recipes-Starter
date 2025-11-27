package io.agora.convoai.example.startup;

/**
 * KeyCenter
 * Load values from BuildConfig, which are populated from env.properties at build time
 */
public class KeyCenter {
    public static final String AGORA_APP_ID = BuildConfig.AGORA_APP_ID;
    public static final String AGORA_APP_CERTIFICATE = BuildConfig.AGORA_APP_CERTIFICATE;
    public static final String REST_KEY = BuildConfig.REST_KEY;
    public static final String REST_SECRET = BuildConfig.REST_SECRET;
    public static final String PIPELINE_ID = BuildConfig.PIPELINE_ID;
}

