using System;
using System.Collections.Generic;
using UnityEngine;

namespace Startup
{
    public static class EnvConfig
    {
        public static string AppId { get; private set; } = string.Empty;
        public static string AppCertificate { get; private set; } = string.Empty;
        public static string RestKey { get; private set; } = string.Empty;
        public static string RestSecret { get; private set; } = string.Empty;
        public static string PipelineId { get; private set; } = string.Empty;

        public static void Load()
        {
            try
            {
                var text = Resources.Load<TextAsset>("env");
                if (text == null)
                {
                    Debug.LogError("EnvConfig: Resources/env(.txt) not found. Using empty defaults");
                    return;
                }
                var lines = text.text.Split(new[] { '\n', '\r' }, StringSplitOptions.RemoveEmptyEntries);
                var dict = new Dictionary<string, string>();
                foreach (var raw in lines)
                {
                    var line = raw.Trim();
                    if (string.IsNullOrEmpty(line) || line.StartsWith("#")) continue;
                    var idx = line.IndexOf('=');
                    if (idx <= 0) continue;
                    var key = line.Substring(0, idx).Trim();
                    var value = line.Substring(idx + 1).Trim();
                    dict[key] = value;
                }
                AppId = dict.TryGetValue("agora.appId", out var v1) ? v1 : AppId;
                AppCertificate = dict.TryGetValue("agora.appCertificate", out var v2) ? v2 : AppCertificate;
                RestKey = dict.TryGetValue("agora.restKey", out var v3) ? v3 : RestKey;
                RestSecret = dict.TryGetValue("agora.restSecret", out var v4) ? v4 : RestSecret;
                PipelineId = dict.TryGetValue("agora.pipelineId", out var v5) ? v5 : PipelineId;
                Debug.Log($"EnvConfig: loaded AppId={(string.IsNullOrEmpty(AppId) ? "<empty>" : AppId)} PipelineId={(string.IsNullOrEmpty(PipelineId) ? "<empty>" : PipelineId)}");
            }
            catch (Exception)
            {
                Debug.LogError("EnvConfig: exception while loading env");
            }
        }
    }
}