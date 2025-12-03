import { KeyCenterConfig } from './KeyCenterConfig';

export class KeyCenter {
  static get AGORA_APP_ID(): string {
    return KeyCenterConfig.AGORA_APP_ID;
  }

  static get AGORA_APP_CERTIFICATE(): string {
    return KeyCenterConfig.AGORA_APP_CERTIFICATE;
  }

  static get REST_KEY(): string {
    return KeyCenterConfig.REST_KEY;
  }

  static get REST_SECRET(): string {
    return KeyCenterConfig.REST_SECRET;
  }

  static get PIPELINE_ID(): string {
    return KeyCenterConfig.PIPELINE_ID;
  }

  static readonly USER_ID = 1001086;
  static readonly AGENT_RTC_UID = 1009527;
}
