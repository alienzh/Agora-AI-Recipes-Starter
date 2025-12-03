import { KeyCenter } from '../utils/KeyCenter';

/**
 * ⚠️ WARNING: DO NOT USE IN PRODUCTION ⚠️
 *
 * This TokenGenerator is for DEMO/DEVELOPMENT purposes ONLY.
 * Production MUST use backend server to generate tokens.
 */
export class TokenGenerator {
  private static readonly TOOLBOX_SERVER_HOST =
    'https://service.apprtc.cn/toolbox';

  static async generateTokenAsync(
    channelName: string,
    uid: string | number,
    tokenTypes: ('rtc' | 'rtm')[] = ['rtc'] // Default to RTC only for RTC+DataStream mode
  ): Promise<string> {
    // Convert token types to numbers (RTC=1, RTM=2)
    const typeNumbers = tokenTypes.map((type) => (type === 'rtc' ? 1 : 2));
    
    // Build request body - use "type" for single type, "types" for multiple types
    // Reference: Android Kotlin TokenGenerator.kt and HarmonyOS TokenGenerator.ets
    const requestBody: Record<string, any> = {
      appId: KeyCenter.AGORA_APP_ID,
      appCertificate: KeyCenter.AGORA_APP_CERTIFICATE,
      channelName,
      uid: uid.toString(),
      expire: 60 * 60 * 24, // 24 hours
      src: 'ReactNative',
      ts: Date.now().toString(),
    };
    
    // When tokenTypes.length == 1, use "type", else use "types" array
    if (typeNumbers.length === 1) {
      requestBody['type'] = typeNumbers[0];
    } else {
      requestBody['types'] = typeNumbers;
    }

    const url = `${this.TOOLBOX_SERVER_HOST}/v2/token/generate`;
    
    // Log request details for debugging
    console.log('[TokenGenerator] Request URL:', url);
    console.log('[TokenGenerator] Request body:', JSON.stringify({
      ...requestBody,
      appCertificate: requestBody.appCertificate ? '***' : '', // Hide sensitive data
    }));

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(requestBody),
      });

      console.log('[TokenGenerator] Response status:', response.status, response.statusText);

      if (!response.ok) {
        const errorBody = await response.text();
        const errorMessage = `Token generation failed: httpCode=${response.status}, httpMsg=${errorBody}`;
        console.error('[TokenGenerator]', errorMessage);
        throw new Error(errorMessage);
      }

      const data = await response.json();
      console.log('[TokenGenerator] Response data:', JSON.stringify({
        code: data.code,
        message: data.message,
        hasToken: !!data.data?.token,
      }));

      if (data.code !== 0) {
        const errorMessage = `Token generation failed: code=${data.code}, message=${data.message || 'Unknown error'}`;
        console.error('[TokenGenerator]', errorMessage);
        throw new Error(errorMessage);
      }

      if (!data.data?.token) {
        const errorMessage = `Token generation failed: token is empty in response`;
        console.error('[TokenGenerator]', errorMessage);
        throw new Error(errorMessage);
      }

      return data.data.token;
    } catch (error: any) {
      // Handle network errors
      if (error instanceof TypeError && error.message.includes('fetch')) {
        const errorMessage = `Token generation network error: ${error.message}`;
        console.error('[TokenGenerator]', errorMessage);
        throw new Error(errorMessage);
      }
      // Re-throw other errors
      throw error;
    }
  }
}

