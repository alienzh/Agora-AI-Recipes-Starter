package io.agora.convoai.example.voiceassistant.rtc;

import android.util.Log;
import io.agora.convoai.example.voiceassistant.AgentApp;
import io.agora.convoai.example.voiceassistant.KeyCenter;
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
     * @return RtcEngineEx instance
     */
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
        // Calling this API enables the onAudioVolumeIndication callback to report volume values,
        // which can be used to drive microphone volume animation rendering
        // If you don't need this feature, you can skip this setting
        if (rtcEngine != null) {
            rtcEngine.enableAudioVolumeIndication(100, 3, true);
            rtcEngine.setCameraCapturerConfiguration(
                new CameraCapturerConfiguration(CameraCapturerConfiguration.CAMERA_DIRECTION.CAMERA_REAR)
            );

            // Audio pre-dump is enabled by default in demo, you don't need to set this in your app
            rtcEngine.setParameters("{\"che.audio.enable.predump\":{\"enable\":\"true\",\"duration\":\"60\"}}");

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
     * @param value New token value
     */
    public static void renewRtcToken(String value) {
        Log.d(TAG, "renewRtcToken");
        if (rtcEngine != null) {
            rtcEngine.renewToken(value);
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
     * Mute or unmute remote audio
     * @param uid Remote user ID
     * @param mute true to mute, false to unmute
     */
    public static void muteRemoteAudio(int uid, boolean mute) {
        Log.d(TAG, "muteRemoteAudio " + uid + " " + mute);
        if (rtcEngine != null) {
            rtcEngine.muteRemoteAudioStream(uid, mute);
        }
    }

    /**
     * Setup local video
     * @param videoCanvas Video canvas configuration
     */
    public static void setupLocalVideo(VideoCanvas videoCanvas) {
        if (rtcEngine != null) {
            rtcEngine.setupLocalVideo(videoCanvas);
        }
    }

    /**
     * Setup remote video
     * @param videoCanvas Video canvas configuration
     */
    public static void setupRemoteVideo(VideoCanvas videoCanvas) {
        if (rtcEngine != null) {
            rtcEngine.setupRemoteVideo(videoCanvas);
        }
    }

    /**
     * Publish or unpublish camera track
     * @param publish true to publish, false to unpublish
     */
    public static void publishCameraTrack(boolean publish) {
        Log.d(TAG, "publishCameraTrack " + publish);
        if (rtcEngine != null) {
            channelOptions.publishCameraTrack = publish;
            rtcEngine.updateChannelMediaOptions(channelOptions);
            if (publish) {
                rtcEngine.startPreview();
            } else {
                rtcEngine.stopPreview();
            }
        }
    }

    /**
     * Switch camera
     */
    public static void switchCamera() {
        Log.d(TAG, "switchCamera");
        if (rtcEngine != null) {
            rtcEngine.switchCamera();
        }
    }

    /**
     * Enable or disable audio dump
     * @param enable true to enable, false to disable
     */
    public static void onAudioDump(boolean enable) {
        if (rtcEngine != null) {
            if (enable) {
                rtcEngine.setParameters("{\"che.audio.apm_dump\": true}");
            } else {
                rtcEngine.setParameters("{\"che.audio.apm_dump\": false}");
            }
        }
    }

    /**
     * Generate pre-dump file
     */
    public static void generatePreDumpFile() {
        if (rtcEngine != null) {
            rtcEngine.setParameters("{\"che.audio.start.predump\": true}");
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

