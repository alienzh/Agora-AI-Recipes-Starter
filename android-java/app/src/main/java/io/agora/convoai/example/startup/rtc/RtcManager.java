package io.agora.convoai.example.startup.rtc;

import android.util.Log;
import androidx.annotation.Nullable;
import io.agora.convoai.example.startup.AgentApp;
import io.agora.convoai.example.startup.KeyCenter;
import io.agora.mediaplayer.IMediaPlayer;
import io.agora.rtc2.ChannelMediaOptions;
import io.agora.rtc2.Constants;
import io.agora.rtc2.IRtcEngineEventHandler;
import io.agora.rtc2.RtcEngine;
import io.agora.rtc2.RtcEngineConfig;
import io.agora.rtc2.RtcEngineEx;
import io.agora.rtc2.video.CameraCapturerConfiguration;
import io.agora.rtc2.video.VideoCanvas;

/**
 * RTC Manager - Manages RTC engine lifecycle and operations
 */
public class RtcManager {

    private static final String TAG = "RtcManager";

    private static RtcEngineEx rtcEngine;
    private static IMediaPlayer mediaPlayer;
    private static final ChannelMediaOptions channelOptions = new ChannelMediaOptions();

    /**
     * Create RTC engine
     * @param rtcCallback RTC engine event handler
     * @return RtcEngineEx instance or null if creation fails
     */
    @Nullable
    public static RtcEngineEx createRtcEngine(IRtcEngineEventHandler rtcCallback) {
        RtcEngineConfig config = new RtcEngineConfig();
        config.mContext = AgentApp.instance();
        config.mAppId = KeyCenter.AGORA_APP_ID;
        config.mChannelProfile = Constants.CHANNEL_PROFILE_LIVE_BROADCASTING;
        config.mAudioScenario = Constants.AUDIO_SCENARIO_DEFAULT;
        config.mEventHandler = rtcCallback;
        try {
            rtcEngine = (RtcEngineEx) RtcEngine.create(config);
            rtcEngine.enableVideo();
            // Load extension provider for AI-QoS
            rtcEngine.loadExtensionProvider("ai_echo_cancellation_extension");
            rtcEngine.loadExtensionProvider("ai_noise_suppression_extension");
            Log.d(TAG, "createRtcEngine success");
        } catch (Exception e) {
            Log.e(TAG, "createRtcEngine error: " + e.getMessage(), e);
            rtcEngine = null;
            return null;
        }
        Log.d(TAG, "current sdk version: " + RtcEngine.getSdkVersion());
        return rtcEngine;
    }

    /**
     * Create media player
     * @return IMediaPlayer instance
     */
    public static IMediaPlayer createMediaPlayer() {
        try {
            mediaPlayer = rtcEngine != null ? rtcEngine.createMediaPlayer() : null;
        } catch (Exception e) {
            Log.e(TAG, "createMediaPlayer error: " + e.getMessage(), e);
        }
        return mediaPlayer;
    }

    /**
     * Join RTC channel
     * @param rtcToken RTC token
     * @param channelName Channel name
     * @param uid User ID
     */
    public static void joinChannel(String rtcToken, String channelName, int uid) {
        Log.d(TAG, "joinChannel channelName: " + channelName + ", localUid: " + uid);
        if (rtcEngine != null) {
            // Join RTC channel
            channelOptions.clientRoleType = Constants.CLIENT_ROLE_BROADCASTER;
            channelOptions.publishMicrophoneTrack = true;
            channelOptions.publishCameraTrack = false;
            channelOptions.autoSubscribeAudio = true;
            channelOptions.autoSubscribeVideo = true;
            
            int ret = rtcEngine.joinChannel(rtcToken, channelName, uid, channelOptions);
            Log.d(TAG, "Joining RTC channel: " + channelName + ", uid: " + uid);
            if (ret == Constants.ERR_OK) {
                Log.d(TAG, "Join RTC room success");
            } else {
                Log.e(TAG, "Join RTC room failed, ret: " + ret);
            }
        }
    }

    /**
     * Set parameter
     * @param parameter Parameter string
     */
    public static void setParameter(String parameter) {
        Log.d(TAG, "setParameter " + parameter);
        if (rtcEngine != null) {
            rtcEngine.setParameters(parameter);
        }
    }

    /**
     * Leave RTC channel
     */
    public static void leaveChannel() {
        Log.d(TAG, "leaveChannel");
        if (rtcEngine != null) {
            rtcEngine.leaveChannel();
        }
    }

    /**
     * Renew RTC token
     * @param token New token value
     */
    public static void renewToken(String token) {
        Log.d(TAG, "renewToken");
        if (rtcEngine != null) {
            rtcEngine.renewToken(token);
        }
    }

    /**
     * Mute or unmute local audio
     * @param mute true to mute, false to unmute
     */
    public static void muteLocalAudio(boolean mute) {
        Log.d(TAG, "muteLocalAudio " + mute);
        if (rtcEngine != null) {
            rtcEngine.adjustRecordingSignalVolume(mute ? 0 : 100);
        }
    }

    /**
     * Destroy RTC engine
     */
    public static void destroy() {
        if (rtcEngine != null) {
            rtcEngine.leaveChannel();
        }
        rtcEngine = null;
        mediaPlayer = null;
        RtcEngine.destroy();
    }
}
