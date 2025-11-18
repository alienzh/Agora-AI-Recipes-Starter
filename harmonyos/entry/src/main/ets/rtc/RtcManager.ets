import {
  RtcEngine,
  Constants,
  RtcEngineEx,
  RtcEngineConfig,
  IRtcEngineEventHandler,
  ChannelMediaOptions
} from '@shengwang/rtc-full';
import { KeyCenter } from '../common/KeyCenter';
import { Context } from '@kit.AbilityKit';

/**
 * RTC Manager for Agora RTC SDK
 *
 * Reference: https://doc.shengwang.cn/doc/rtc/harmonyos/landing-page
 */
export class RtcManager {
  private static readonly TAG = 'RtcManager';
  private static rtcEngine: RtcEngineEx | null = null;
  private static context: Context | null = null;

  /**
   * Create RTC engine instance
   * @param rtcEventHandler Event handler object with callback methods
   * @returns RTC Engine instance
   */
  static createRtcEngine(context: Context,rtcEventHandler: IRtcEngineEventHandler): RtcEngineEx | null {
    if (RtcManager.rtcEngine) {
      console.info(RtcManager.TAG, 'RTC engine already exists, returning existing instance');
      return RtcManager.rtcEngine;
    }
    RtcManager.context = context;
    try {
      // Create RTC engine config
      const config: RtcEngineConfig = new RtcEngineConfig();
      config.mContext = RtcManager.context!;
      config.mAppId = KeyCenter.AGORA_APP_ID;
      config.mEventHandler = rtcEventHandler;

      // Create RTC engine
      RtcManager.rtcEngine = RtcEngine.create(config) as RtcEngineEx;

      if (!RtcManager.rtcEngine) {
        throw new Error('Failed to create RTC engine');
      }

      // Log SDK version
      const sdkVersion = RtcEngine.getSdkVersion();
      console.info(RtcManager.TAG, `Current SDK version: ${sdkVersion}`);
      console.info(RtcManager.TAG, 'createRtcEngine success');
      return RtcManager.rtcEngine;
    } catch (error) {
      console.error(RtcManager.TAG, `createRtcEngine error: ${JSON.stringify(error)}`);
      return null;
    }
  }

  /**
   * Join RTC channel
   * @param rtcToken RTC token
   * @param channelName Channel name
   * @param uid User ID
   */
  static joinChannel(rtcToken: string, channelName: string, uid: number): void {
    console.info(RtcManager.TAG, `joinChannel channelName: ${channelName}, localUid: ${uid}`);

    if (!RtcManager.rtcEngine) {
      console.error(RtcManager.TAG, 'RTC engine not initialized');
      throw new Error('RTC engine not initialized. Call createRtcEngine() first.');
    }

    try {
      // Enable audio volume indication for volume animation (optional)
      RtcManager.rtcEngine.enableAudioVolumeIndication(100, 3, true);

      // Configure channel media options
      const options: ChannelMediaOptions = new ChannelMediaOptions();
      options.clientRoleType = Constants.ClientRole.BROADCASTER;
      options.publishMicrophoneTrack = true;
      options.publishCameraTrack = false;
      options.autoSubscribeAudio = true;
      options.autoSubscribeVideo = false;

      // Join channel
      const ret = RtcManager.rtcEngine.joinChannelWithOptions(rtcToken, channelName, uid, options);
      if (ret === Constants.ErrorCode.ERR_OK) {
        console.info(RtcManager.TAG, 'Join RTC channel success');
      } else {
        const errorDesc = RtcEngine.getErrorDescription(ret);
        console.error(RtcManager.TAG, `Join RTC channel failed, ret: ${ret}, desc: ${errorDesc}`);
        throw new Error(`Join channel failed with error code: ${ret}, description: ${errorDesc}`);
      }
    } catch (error) {
      console.error(RtcManager.TAG, `joinChannel error: ${JSON.stringify(error)}`);
    }
  }

  /**
   * Leave RTC channel
   */
  static leaveChannel(): void {
    console.info(RtcManager.TAG, 'leaveChannel');

    if (!RtcManager.rtcEngine) {
      console.warn(RtcManager.TAG, 'RTC engine not initialized, cannot leave channel');
      return;
    }

    try {
      RtcManager.rtcEngine.leaveChannel();
      console.info(RtcManager.TAG, 'Leave RTC channel success');
    } catch (error) {
      console.error(RtcManager.TAG, `leaveChannel error: ${JSON.stringify(error)}`);
    }
  }

  /**
   * Mute or unmute local audio
   * @param mute Mute state
   */
  static muteLocalAudio(mute: boolean): void {
    console.info(RtcManager.TAG, `muteLocalAudio ${mute}`);

    if (!RtcManager.rtcEngine) {
      console.warn(RtcManager.TAG, 'RTC engine not initialized, cannot mute audio');
      return;
    }

    try {
      // Adjust recording signal volume: 0 for mute, 100 for unmute
      const ret = RtcManager.rtcEngine.adjustRecordingSignalVolume(mute ? 0 : 100);
      if (ret === Constants.ErrorCode.ERR_OK) {
        console.info(RtcManager.TAG, `Audio ${mute ? 'muted' : 'unmuted'}`);
      } else {
        console.error(RtcManager.TAG, `Failed to ${mute ? 'mute' : 'unmute'} audio, error code: ${ret}`);
      }
    } catch (error) {
      console.error(RtcManager.TAG, `muteLocalAudio error: ${JSON.stringify(error)}`);
    }
  }

  /**
   * Renew RTC token
   * @param token New token
   */
  static renewRtcToken(token: string): void {
    console.info(RtcManager.TAG, 'renewRtcToken');

    if (!RtcManager.rtcEngine) {
      console.warn(RtcManager.TAG, 'RTC engine not initialized, cannot renew token');
      return;
    }

    try {
      const ret = RtcManager.rtcEngine.renewToken(token);
      if (ret === Constants.ErrorCode.ERR_OK) {
        console.info(RtcManager.TAG, 'Renew RTC token success');
      } else {
        console.error(RtcManager.TAG, `Failed to renew token, error code: ${ret}`);
        throw new Error(`Renew token failed with error code: ${ret}`);
      }
    } catch (error) {
      console.error(RtcManager.TAG, `renewRtcToken error: ${JSON.stringify(error)}`);
    }
  }

  /**
   * Get RTC engine instance
   * @returns RTC Engine instance or null
   */
  static getRtcEngine(): RtcEngineEx | null {
    return RtcManager.rtcEngine;
  }

  /**
   * Destroy RTC engine
   */
  static destroy(): void {
    console.info(RtcManager.TAG, 'destroy');

    if (RtcManager.rtcEngine) {
      try {
        RtcManager.leaveChannel();
        RtcEngine.destroy();
        RtcManager.rtcEngine = null;
        console.info(RtcManager.TAG, 'RTC engine destroyed');
      } catch (error) {
        console.error(RtcManager.TAG, `destroy error: ${JSON.stringify(error)}`);
      }
    }
    RtcManager.context = null;
  }
}

