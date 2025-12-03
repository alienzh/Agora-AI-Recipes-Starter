import { Platform, PermissionsAndroid, Alert } from 'react-native';
import { request, PERMISSIONS, RESULTS } from 'react-native-permissions';

export async function requestAudioPermission(): Promise<boolean> {
  if (Platform.OS === 'android') {
    try {
      const granted = await PermissionsAndroid.request(
        PermissionsAndroid.PERMISSIONS.RECORD_AUDIO,
        {
          title: '音频权限',
          message: '应用需要访问麦克风以进行语音对话',
          buttonNeutral: '稍后询问',
          buttonNegative: '拒绝',
          buttonPositive: '允许',
        }
      );
      return granted === PermissionsAndroid.RESULTS.GRANTED;
    } catch (err) {
      console.warn('Permission request error:', err);
      return false;
    }
  } else if (Platform.OS === 'ios') {
    try {
      const result = await request(PERMISSIONS.IOS.MICROPHONE);
      return result === RESULTS.GRANTED;
    } catch (err) {
      console.warn('Permission request error:', err);
      return false;
    }
  }
  return false;
}

