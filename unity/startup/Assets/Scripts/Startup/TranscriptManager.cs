using System;
using System.Collections.Generic;
using UnityEngine;

namespace Startup
{
    public enum TranscriptType { User, Agent }
    public enum TranscriptStatus { InProgress, End, Interrupted, Unknown }

    [Serializable]
    public class TranscriptItem
    {
        public string Id;
        public TranscriptType Type;
        public string Text;
        public TranscriptStatus Status;
    }

    public class TranscriptManager
    {
        public readonly List<TranscriptItem> Items = new List<TranscriptItem>();

        public bool UpsertFromJson(string json)
        {
            try
            {
                var obj = new DictWrapper { json = json };
                var objectType = obj.GetString("object");
                TranscriptType type;
                if (objectType == "assistant.transcription") type = TranscriptType.Agent;
                else if (objectType == "user.transcription") type = TranscriptType.User;
                else return false;

                var id = (obj.GetInt("turn_id")?.ToString()) ?? obj.GetString("message_id") ?? DateTimeOffset.UtcNow.ToUnixTimeMilliseconds().ToString();
                var text = obj.GetString("text") ?? "(empty)";
                var statusCode = obj.GetInt("turn_status");
                var status = TranscriptStatus.Unknown;
                if (statusCode == null || statusCode == 0) status = TranscriptStatus.InProgress;
                else if (statusCode == 1) status = TranscriptStatus.End;
                else if (statusCode == 2) status = TranscriptStatus.Interrupted;

                var item = new TranscriptItem { Id = id, Type = type, Text = text, Status = status };
                var idx = Items.FindIndex(e => e.Id == id && e.Type == type);
                if (idx >= 0) Items[idx] = item; else Items.Add(item);
                return true;
            }
            catch
            {
                return false;
            }
        }

        [Serializable]
        private class DictWrapper
        {
            public string objectType;

            public string GetString(string key)
            {
                return ExtractString(key);
            }

            public int? GetInt(string key)
            {
                var s = ExtractString(key);
                if (int.TryParse(s, out var v)) return v;
                return null;
            }

            private string ExtractString(string key)
            {
                // JsonUtility not friendly with dynamic keys; fallback to naive parsing
                var idx = json.IndexOf("\"" + key + "\"");
                if (idx < 0) return null;
                var colon = json.IndexOf(':', idx);
                if (colon < 0) return null;
                var startQuote = json.IndexOf('"', colon + 1);
                var endQuote = json.IndexOf('"', startQuote + 1);
                if (startQuote < 0 || endQuote < 0) return null;
                return json.Substring(startQuote + 1, endQuote - startQuote - 1);
            }

            public string json;
        }
    }
}