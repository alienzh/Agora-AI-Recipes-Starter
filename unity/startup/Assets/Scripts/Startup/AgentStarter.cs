using System;
using System.Text;
using System.Collections;
using System.Collections.Generic;
using Agora.Rtc.LitJson;
using UnityEngine;
using UnityEngine.Networking;

namespace Startup
{
    public static class AgentStarter
    {
        private const string JsonType = "application/json";
        private const string BaseUrl = "https://api.sd-rtn.com/cn/api/conversational-ai-agent/v2/projects";

        public static IEnumerator StartAgent(string channelName, string agentRtcUid, int remoteRtcUid, string token, Action<string> onSuccess, Action<string> onError)
        {
            var projectId = EnvConfig.AppId;
            var url = $"{BaseUrl}/{projectId}/join";
            Debug.Log("POST " + url);
            
            var uid = string.IsNullOrEmpty(agentRtcUid) ? "1009527" : agentRtcUid;
            
            // Use defined classes for proper JSON serialization
            var props = new JoinProps
            {
                channel = channelName,
                agent_rtc_uid = uid,
                remote_rtc_uids = new string[] { "*" },
                token = token
            };

            var req = new JoinReq
            {
                name = channelName,
                pipeline_id = EnvConfig.PipelineId,
                properties = props
            };
            
            var body = JsonMapper.ToJson(req);
            Debug.Log("Agent start body: " + body);
            
            yield return PostSimple(url, body, (resp) =>
            {
                try
                {
                    var json = JsonUtility.FromJson<AgentResp>(resp);
                    if (!string.IsNullOrEmpty(json.agent_id))
                    {
                        Debug.Log("Agent start success");
                        onSuccess?.Invoke(json.agent_id);
                    }
                    else
                    {
                        Debug.LogError("agent_id empty");
                        onError?.Invoke("agent_id empty");
                    }
                }
                catch (Exception e)
                {
                    Debug.LogError("Agent start parse error: " + e.Message);
                    onError?.Invoke(e.Message);
                }
            }, onError);
        }

        public static IEnumerator StopAgent(string agentId, Action onSuccess, Action<string> onError)
        {
            var projectId = EnvConfig.AppId;
            var url = $"{BaseUrl}/{projectId}/agents/{agentId}/leave";
            Debug.Log("POST " + url);
            yield return PostSimple(url, "", (resp) => { onSuccess?.Invoke(); }, onError);
        }

        private static IEnumerator PostSimple(string url, string body, Action<string> onSuccess, Action<string> onError)
        {
            using var req = new UnityWebRequest(url, UnityWebRequest.kHttpVerbPOST);
            req.uploadHandler = new UploadHandlerRaw(Encoding.Default.GetBytes(body));
            req.downloadHandler = new DownloadHandlerBuffer();
            req.chunkedTransfer = false;
            req.SetRequestHeader("Content-Type", JsonType);
            req.uploadHandler.contentType = JsonType;
            var creds = Convert.ToBase64String(Encoding.UTF8.GetBytes($"{EnvConfig.RestKey}:{EnvConfig.RestSecret}"));
            req.SetRequestHeader("Authorization", $"Basic {creds}");
            yield return req.SendWebRequest();
            if (req.result != UnityWebRequest.Result.Success)
            {
                Debug.LogError($"HTTP {req.responseCode} {req.error} body: {req.downloadHandler.text}");
                onError?.Invoke($"http {req.responseCode} {req.error}");
                yield break;
            }
            Debug.Log($"HTTP {req.responseCode} success");
            onSuccess?.Invoke(req.downloadHandler.text);
        }

        [Serializable]
        private class AgentResp
        {
            public string agent_id;
        }

        [Serializable]
        private class JoinReq
        {
            public string name;
            public string pipeline_id;
            public JoinProps properties;
        }

        [Serializable]
        private class JoinProps
        {
            public string channel;
            public string agent_rtc_uid;
            public string[] remote_rtc_uids;
            public string token;
        }
    }
}