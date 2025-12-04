import http from '@ohos.net.http';
import { KeyCenter } from '../config/KeyCenter';

/**
 * Token type enum
 */
export enum AgoraTokenType {
  RTC = 1,
  RTM = 2,
  CHAT = 3
}

/**
 * Token generator for Agora services
 * Generates unified tokens for RTC and RTM
 */
export class TokenGenerator {
  private static readonly TOOLBOX_SERVER_HOST = 'https://service.apprtc.cn/toolbox';
  private static readonly DEFAULT_EXPIRE_SECOND = 60 * 60 * 24; // 24 hours
  private static expireSecond: number = -1; // Custom expire time, -1 means use default

  /**
   * Set custom expire time in seconds
   * @param seconds Expire time in seconds, -1 to use default (24 hours)
   */
  static setExpireSecond(seconds: number): void {
    TokenGenerator.expireSecond = seconds;
  }

  /**
   * Generate unified token for RTC and RTM
   * @param channelName Channel name
   * @param uid User ID
   * @param tokenTypes Token types (default: RTC and RTM)
   * @returns Promise with token string
   */
  static async generateTokensAsync(
    channelName: string,
    uid: string,
    tokenTypes: AgoraTokenType[] = [AgoraTokenType.RTC, AgoraTokenType.RTM]
  ): Promise<string> {
    try {
      const token = await TokenGenerator.fetchToken(channelName, uid, tokenTypes);
      return token;
    } catch (error) {
      console.error('TokenGenerator', `Failed to generate token: ${JSON.stringify(error)}`);
      throw new Error(`Failed to generate token: ${JSON.stringify(error)}`);
    }
  }

  /**
   * Build JSON request body
   * Similar to Kotlin: buildJsonRequest
   */
  private static buildJsonRequest(
    channelName: string,
    uid: string,
    tokenTypes: AgoraTokenType[]
  ): Record<string, Object> {
    const request: Record<string, Object> = {};
    request['appId'] = KeyCenter.AGORA_APP_ID;
    request['appCertificate'] = KeyCenter.AGORA_APP_CERTIFICATE;
    request['channelName'] = channelName;
    request['expire'] = TokenGenerator.expireSecond > 0 
      ? TokenGenerator.expireSecond 
      : TokenGenerator.DEFAULT_EXPIRE_SECOND;
    request['src'] = 'HarmonyOS';
    request['ts'] = Date.now().toString();
    request['uid'] = uid;

    // When tokenTypes.size == 1, use "type", else use "types" array
    if (tokenTypes.length === 1) {
      request['type'] = tokenTypes[0];
    } else {
      // Convert enum array to number array
      const typesArray: number[] = [];
      for (let i = 0; i < tokenTypes.length; i++) {
        typesArray.push(tokenTypes[i]);
      }
      request['types'] = typesArray;
    }

    return request;
  }

  /**
   * Fetch token from server
   * Similar to Kotlin: fetchToken -> executeRequest
   */
  private static async fetchToken(
    channelName: string,
    uid: string,
    tokenTypes: AgoraTokenType[]
  ): Promise<string> {
    const postBody = TokenGenerator.buildJsonRequest(channelName, uid, tokenTypes);
    const url = `${TokenGenerator.TOOLBOX_SERVER_HOST}/v2/token/generate`;
    
    const httpRequest = http.createHttp();
    const response = await httpRequest.request(url, {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': 'application/json'
      },
      extraData: JSON.stringify(postBody)
    });

    httpRequest.destroy();

    // Check if response is successful (similar to response.isSuccessful in Kotlin)
    if (response.responseCode !== 200) {
      throw new Error(
        `Fetch token error: httpCode=${response.responseCode}, httpMsg=${response.result}`
      );
    }

    // Parse response body
    const bodyString = response.result?.toString();
    if (!bodyString) {
      throw new Error('Response body is null');
    }

    const bodyJson = JSON.parse(bodyString) as Record<string, Object>;
    
    // Check code (similar to bodyJson.optInt("code", -1) != 0 in Kotlin)
    const code = bodyJson['code'] as number | undefined;
    if (code === undefined || code !== 0) {
      const message = bodyJson['message'] as string | undefined;
      throw new Error(
        `Fetch token error: httpCode=${response.responseCode}, ` +
        `httpMsg=${response.result}, ` +
        `reqCode=${code}, ` +
        `reqMsg=${message}`
      );
    }

    // Extract token from data.token (similar to bodyJson.getJSONObject("data").getString("token"))
    const data = bodyJson['data'] as Record<string, Object> | undefined;
    if (!data) {
      throw new Error('Response data is null');
    }

    const token = data['token'] as string | undefined;
    if (!token) {
      throw new Error('Token is null in response data');
    }

    return token;
  }
}

