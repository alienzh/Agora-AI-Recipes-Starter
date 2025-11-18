package io.agora.convoai.example.voiceassistant.rtc

import android.util.Log
import io.agora.convoai.example.voiceassistant.AgentApp
import io.agora.convoai.example.voiceassistant.KeyCenter
import io.agora.mediaplayer.IMediaPlayer
import io.agora.rtc2.ChannelMediaOptions
import io.agora.rtc2.Constants
import io.agora.rtc2.Constants.CLIENT_ROLE_BROADCASTER
import io.agora.rtc2.Constants.ERR_OK
import io.agora.rtc2.IRtcEngineEventHandler
import io.agora.rtc2.RtcEngine
import io.agora.rtc2.RtcEngineConfig
import io.agora.rtc2.RtcEngineEx
import io.agora.rtc2.video.CameraCapturerConfiguration
import io.agora.rtc2.video.VideoCanvas
import kotlin.apply

object RtcManager {

    private const val TAG = "RtcManager"

    private var rtcEngine: RtcEngineEx? = null

    private var mediaPlayer: IMediaPlayer? = null

    // create rtc engine
    fun createRtcEngine(rtcCallback: IRtcEngineEventHandler): RtcEngineEx {
        val config = RtcEngineConfig()
        config.mContext = AgentApp.instance()
        config.mAppId = KeyCenter.AGORA_APP_ID
        config.mChannelProfile = Constants.CHANNEL_PROFILE_LIVE_BROADCASTING
        config.mAudioScenario = Constants.AUDIO_SCENARIO_DEFAULT
        config.mEventHandler = rtcCallback
        try {
            rtcEngine = (RtcEngine.create(config) as RtcEngineEx).apply {
                enableVideo()
                // load extension provider for AI-QoS
                loadExtensionProvider("ai_echo_cancellation_extension")
                loadExtensionProvider("ai_noise_suppression_extension")
            }
            Log.d(TAG, "createRtcEngine success")
        } catch (e: Exception) {
            Log.e(TAG, "createRtcEngine error: $e")
        }
        Log.d(TAG, "current sdk version: ${RtcEngine.getSdkVersion()}")
        return rtcEngine!!
    }

    // create media player
    fun createMediaPlayer(): IMediaPlayer {
        try {
            mediaPlayer = rtcEngine?.createMediaPlayer()
        } catch (e: Exception) {
            Log.e(TAG, "createMediaPlayer error: $e")
        }
        return mediaPlayer!!
    }

    private val channelOptions = ChannelMediaOptions()

    // join rtc channel
    fun joinChannel(rtcToken: String, channelName: String, uid: Int) {
        Log.d(TAG, "joinChannel channelName: $channelName, localUid: $uid")
        // Calling this API enables the onAudioVolumeIndication callback to report volume values,
        // which can be used to drive microphone volume animation rendering
        // If you don't need this feature, you can skip this setting
        rtcEngine?.enableAudioVolumeIndication(100, 3, true)
        rtcEngine?.setCameraCapturerConfiguration(CameraCapturerConfiguration(CameraCapturerConfiguration.CAMERA_DIRECTION.CAMERA_REAR))

        // Audio pre-dump is enabled by default in demo, you don't need to set this in your app
        rtcEngine?.setParameters("{\"che.audio.enable.predump\":{\"enable\":\"true\",\"duration\":\"60\"}}")

        // join rtc channel
        channelOptions.apply {
            clientRoleType = CLIENT_ROLE_BROADCASTER
            publishMicrophoneTrack = true
            publishCameraTrack = false
            autoSubscribeAudio = true
            autoSubscribeVideo = true
        }
        val ret = rtcEngine?.joinChannel(rtcToken, channelName, uid, channelOptions)
        Log.d(TAG, "Joining RTC channel: $channelName, uid: $uid")
        if (ret == ERR_OK) {
            Log.d(TAG, "Join RTC room success")
        } else {
            Log.e(TAG, "Join RTC room failed, ret: $ret")
        }
    }

    fun setParameter(parameter: String) {
        Log.d(TAG, "setParameter $parameter")
        rtcEngine?.setParameters(parameter)
    }

    // leave rtc channel
    fun leaveChannel() {
        Log.d(TAG, "leaveChannel")
        rtcEngine?.leaveChannel()
    }

    // renew rtc token
    fun renewRtcToken(value: String) {
        Log.d(TAG, "renewRtcToken")
        rtcEngine?.renewToken(value)
    }

    // open or close microphone
    fun muteLocalAudio(mute: Boolean) {
        Log.d(TAG, "muteLocalAudio $mute")
        rtcEngine?.adjustRecordingSignalVolume(if (mute) 0 else 100)
    }

    // mute remote audio
    fun muteRemoteAudio(uid: Int, mute: Boolean) {
        Log.d(TAG, "muteRemoteAudio $uid $mute")
        rtcEngine?.muteRemoteAudioStream(uid, mute)
    }


    // setup local video
    fun setupLocalVideo(videoCanvas: VideoCanvas) {
        rtcEngine?.setupLocalVideo(videoCanvas)
    }

    // setup remote video
    fun setupRemoteVideo(videoCanvas: VideoCanvas) {
        rtcEngine?.setupRemoteVideo(videoCanvas)
    }

    // publish camera track
    fun publishCameraTrack(publish: Boolean) {
        Log.d(TAG, "publishCameraTrack $publish")
        channelOptions.publishCameraTrack = publish
        rtcEngine?.updateChannelMediaOptions(channelOptions)
        if (publish) {
            rtcEngine?.startPreview()
        } else {
            rtcEngine?.stopPreview()
        }
    }

    // switch camera
    fun switchCamera() {
        Log.d(TAG, "switchCamera")
        rtcEngine?.switchCamera()
    }

    fun onAudioDump(enable: Boolean) {
        if (enable) {
            rtcEngine?.setParameters("{\"che.audio.apm_dump\": true}")
        } else {
            rtcEngine?.setParameters("{\"che.audio.apm_dump\": false}")
        }
    }

    fun generatePreDumpFile() {
        rtcEngine?.setParameters("{\"che.audio.start.predump\": true}")
    }

    fun destroy() {
        rtcEngine?.leaveChannel()
        rtcEngine = null
        mediaPlayer = null
        RtcEngine.destroy()
    }
}