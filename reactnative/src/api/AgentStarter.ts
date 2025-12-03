import { KeyCenter } from '../utils/KeyCenter';

// Type declarations for global objects available in React Native
declare const btoa: ((data: string) => string) | undefined;
declare const Buffer: {
  from(data: string, encoding: 'utf-8'): {
    toString(encoding: 'base64'): string;
  };
} | undefined;

interface StartAgentRequest {
  channelName: string;
  agentRtcUid?: string; // 默认 "1009527"
  token: string;
}

interface StartAgentResponse {
  agent_id: string;
}

export class AgentStarter {
  private static readonly API_BASE_URL =
    'https://api.sd-rtn.com/cn/api/conversational-ai-agent/v2/projects';
  private static readonly DEFAULT_AGENT_RTC_UID = '1009527';

  static async startAgentAsync(
    request: StartAgentRequest
  ): Promise<string> {
    const projectId = KeyCenter.AGORA_APP_ID;
    const url = `${this.API_BASE_URL}/${projectId}/join/`;

    // Build request body for RTC+DataStream mode
    // Reference: harmonyos/entry/src/main/ets/api/AgentStarter.ets:113-133
    const properties: Record<string, any> = {
      channel: request.channelName,
      agent_rtc_uid: request.agentRtcUid || this.DEFAULT_AGENT_RTC_UID,
      remote_rtc_uids: ['*'],
      token: request.token,
    };

    // Add parameters for DataStream mode
    const parameters: Record<string, any> = {
      data_channel: 'datastream',
      transcript: {
        enable_words: false,
      },
    };
    properties.parameters = parameters;

    // Add advanced_features to disable RTM (using DataStream instead)
    const advancedFeatures: Record<string, any> = {
      enable_rtm: false,
    };
    properties.advanced_features = advancedFeatures;

    const requestBody = {
      name: request.channelName,
      pipeline_id: KeyCenter.PIPELINE_ID,
      properties: properties,
    };

    const authorization = this.generateAuthorizationHeader(
      KeyCenter.REST_KEY,
      KeyCenter.REST_SECRET
    );

    // Log request details for debugging
    console.log('[AgentStarter] Request URL:', url);
    console.log('[AgentStarter] Request body:', JSON.stringify({
      ...requestBody,
      properties: {
        ...requestBody.properties,
        token: requestBody.properties.token ? '***' : '', // Hide sensitive data
        // Keep parameters and advanced_features visible for debugging
      },
    }, null, 2));

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: authorization,
        },
        body: JSON.stringify(requestBody),
      });

      console.log('[AgentStarter] Response status:', response.status, response.statusText);

      if (!response.ok) {
        const errorBody = await response.text();
        const errorMessage = `Start agent error: httpCode=${response.status}, httpMsg=${errorBody}`;
        console.error('[AgentStarter]', errorMessage);
        throw new Error(errorMessage);
      }

      const data: StartAgentResponse = await response.json();
      console.log('[AgentStarter] Response data:', JSON.stringify({
        hasAgentId: !!data.agent_id,
        agentId: data.agent_id || 'missing',
      }));

      if (!data.agent_id) {
        const errorMessage = `Failed to parse agentId from response: ${JSON.stringify(data)}`;
        console.error('[AgentStarter]', errorMessage);
        throw new Error(errorMessage);
      }

      return data.agent_id;
    } catch (error: any) {
      // Handle network errors
      if (error instanceof TypeError && error.message.includes('fetch')) {
        const errorMessage = `Start agent network error: ${error.message}`;
        console.error('[AgentStarter]', errorMessage);
        throw new Error(errorMessage);
      }
      // Re-throw other errors
      throw error;
    }
  }

  static async stopAgentAsync(
    projectId: string,
    agentId: string
  ): Promise<void> {
    const url = `${this.API_BASE_URL}/${projectId}/agents/${agentId}/leave`;

    const authorization = this.generateAuthorizationHeader(
      KeyCenter.REST_KEY,
      KeyCenter.REST_SECRET
    );

    // Log request details for debugging
    console.log('[AgentStarter] Stop agent request URL:', url);
    console.log('[AgentStarter] Stop agent request: projectId=', projectId, 'agentId=', agentId);

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          Authorization: authorization,
        },
      });

      console.log('[AgentStarter] Stop agent response status:', response.status, response.statusText);

      if (!response.ok) {
        const errorBody = await response.text();
        const errorMessage = `Stop agent error: httpCode=${response.status}, httpMsg=${errorBody}`;
        console.error('[AgentStarter]', errorMessage);
        throw new Error(errorMessage);
      }

      console.log('[AgentStarter] Stop agent successfully');
    } catch (error: any) {
      // Handle network errors
      if (error instanceof TypeError && error.message.includes('fetch')) {
        const errorMessage = `Stop agent network error: ${error.message}`;
        console.error('[AgentStarter]', errorMessage);
        throw new Error(errorMessage);
      }
      // Re-throw other errors
      throw error;
    }
  }

  private static generateAuthorizationHeader(
    key: string,
    secret: string
  ): string {
    const credentials = `${key}:${secret}`;
    
    // Use btoa if available, otherwise use Buffer (React Native polyfill)
    let base64: string;
    if (typeof btoa !== 'undefined') {
      base64 = btoa(credentials);
    } else if (typeof Buffer !== 'undefined') {
      base64 = (Buffer as any).from(credentials, 'utf-8').toString('base64');
    } else {
      throw new Error('Neither btoa nor Buffer is available for Base64 encoding');
    }
    
    return `Basic ${base64}`;
  }
}

