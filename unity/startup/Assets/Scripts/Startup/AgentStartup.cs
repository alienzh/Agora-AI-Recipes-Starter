using System;
using System.Collections;
using System.Text;
using UnityEngine;
using UnityEngine.UI;
using Agora.Rtc;
using Agora.Rtm;

namespace Startup
{
    public class AgentStartup : MonoBehaviour
    {
        public Text LogText;
        public Text TranscriptText;
        public Button StartButton;
        public Button MuteButton;
        public Button StopButton;

        private IRtcEngine _rtc;
        private IRtmClient _rtm;
        private readonly TranscriptManager _transcriptMgr = new TranscriptManager();
        private string _channelName = string.Empty;
        private string _agentId = string.Empty;
        private bool _muted = false;

        private const int UserUid = 1001086;
        private const string AgentUid = "1009527";

        private void Awake()
        {
            EnvConfig.Load();
            if (StartButton != null) 
            { 
                StartButton.onClick.AddListener(OnStart);
                SetButtonText(StartButton, "启动 Agent");
            }
            if (MuteButton != null) 
            { 
                MuteButton.onClick.AddListener(OnToggleMute); 
                MuteButton.gameObject.SetActive(false);
                SetButtonText(MuteButton, "关麦");
            }
            if (StopButton != null) 
            { 
                StopButton.onClick.AddListener(OnStop); 
                StopButton.gameObject.SetActive(false);
                SetButtonText(StopButton, "停止 Agent");
            }
        }

        private void SetButtonText(Button btn, string text)
        {
            var txt = btn.GetComponentInChildren<Text>();
            if (txt != null) txt.text = text;
        }

        private string RandomChannel()
        {
            var r = UnityEngine.Random.Range(1000, 9999);
            return $"channel_unity_{r}";
        }

        private void AppendLog(string msg)
        {
            if (LogText == null) return;
            LogText.text += (string.IsNullOrEmpty(LogText.text) ? "" : "\n") + msg;
        }

        private void RefreshTranscripts()
        {
            if (TranscriptText == null) return;
            var sb = new StringBuilder();
            foreach (var t in _transcriptMgr.Items)
            {
                var badge = t.Type == TranscriptType.User ? "USER" : "AGENT";
                sb.AppendLine($"[{badge}] {t.Text}");
            }
            TranscriptText.text = sb.ToString();
        }

        private void OnStart()
        {
            if (StartButton != null) StartButton.interactable = false;
            AppendLog("Starting...");
            Debug.Log("Starting...");
            _channelName = RandomChannel();
            StartCoroutine(StartFlow());
        }

        private IEnumerator StartFlow()
        {
            string userToken = null;
            yield return TokenGenerator.GenerateUnifiedToken(_channelName, UserUid.ToString(),
                (tok) => { userToken = tok; AppendLog("获取 Token 成功"); Debug.Log("获取 Token 成功"); },
                (err) => { AppendLog("获取 Token 失败: " + err); Debug.LogError("获取 Token 失败: " + err); });
            if (string.IsNullOrEmpty(userToken)) { StartButton.interactable = true; yield break; }

            _rtc = Agora.Rtc.RtcEngine.CreateAgoraRtcEngine();
            var ctx = new RtcEngineContext();
            ctx.appId = EnvConfig.AppId;
            ctx.channelProfile = CHANNEL_PROFILE_TYPE.CHANNEL_PROFILE_LIVE_BROADCASTING;
            ctx.audioScenario = AUDIO_SCENARIO_TYPE.AUDIO_SCENARIO_DEFAULT;
            _rtc.Initialize(ctx);
            AppendLog("RtcEngine 初始化成功");
            Debug.Log("RtcEngine 初始化成功");
            _rtc.InitEventHandler(new RtcHandler(this));
            _rtc.EnableAudio();
            _rtc.SetChannelProfile(CHANNEL_PROFILE_TYPE.CHANNEL_PROFILE_LIVE_BROADCASTING);
            _rtc.SetClientRole(CLIENT_ROLE_TYPE.CLIENT_ROLE_BROADCASTER);
            _rtc.JoinChannel(userToken, _channelName, "", (uint)UserUid);
            var pubOpts = new ChannelMediaOptions();
            pubOpts.publishMicrophoneTrack.SetValue(true);
            pubOpts.autoSubscribeAudio.SetValue(true);
            _rtc.UpdateChannelMediaOptions(pubOpts);
            AppendLog("joinChannel 调用完成");
            Debug.Log("joinChannel 调用完成");
            _rtc.AdjustRecordingSignalVolume(100);
            _muted = false;
            AppendLog("已自动开麦");
            Debug.Log("已自动开麦");

            var rtmInitOk = false;
            try
            {
                var cfg = new RtmConfig { appId = EnvConfig.AppId, userId = UserUid.ToString(), presenceTimeout = 30, useStringUserId = true };
                _rtm = RtmClient.CreateAgoraRtmClient(cfg);
                _rtm.OnMessageEvent += OnRtmMessageEvent;
                _rtm.OnConnectionStateChanged += (channel, state, reason) => AppendLog($"RTM {state} -> {reason}");
                rtmInitOk = true;
                AppendLog("RtmClient 初始化成功");
                Debug.Log("RtmClient 初始化成功");
            }
            catch (Exception e)
            {
                AppendLog("RtmClient 初始化失败: " + e.Message);
                Debug.LogError("RtmClient 初始化失败: " + e.Message);
            }
            if (!rtmInitOk) { StartButton.interactable = true; yield break; }

            AppendLog("rtmLogin 调用");
            Debug.Log("rtmLogin 调用");
            var loginTask = _rtm.LoginAsync(userToken);
            while (!loginTask.IsCompleted) yield return null;
            if (loginTask.Result.Status.Error)
            {
                AppendLog("rtmLogin 失败: " + loginTask.Result.Status.ErrorCode);
                Debug.LogError("rtmLogin 失败: " + loginTask.Result.Status.ErrorCode);
                StartButton.interactable = true; yield break;
            }
            else
            {
                AppendLog("rtmLogin 成功");
                Debug.Log("rtmLogin 成功");
            }
            var subTask = _rtm.SubscribeAsync(_channelName, new SubscribeOptions { withMessage = true });
            while (!subTask.IsCompleted) yield return null;
            if (subTask.Result.Status.Error)
            {
                AppendLog("Subscribe 失败: " + subTask.Result.Status.ErrorCode);
                Debug.LogError("Subscribe 失败: " + subTask.Result.Status.ErrorCode);
                StartButton.interactable = true; yield break;
            }

            string agentToken = null;
            yield return TokenGenerator.GenerateUnifiedToken(_channelName, AgentUid,
                (tok) => { agentToken = tok; AppendLog("获取 Agent Token 成功"); Debug.Log("获取 Agent Token 成功"); },
                (err) => { AppendLog("获取 Agent Token 失败: " + err); Debug.LogError("获取 Agent Token 失败: " + err); });
            if (string.IsNullOrEmpty(agentToken)) { StartButton.interactable = true; yield break; }

            var agentStartOk = false;
            yield return AgentStarter.StartAgent(_channelName, AgentUid, UserUid, agentToken,
                (agentId) => { _agentId = agentId; agentStartOk = true; AppendLog("Agent Start 成功"); Debug.Log("Agent Start 成功"); },
                (err) => { AppendLog("Agent Start 失败: " + err); Debug.LogError("Agent Start 失败: " + err); StartButton.interactable = true; });

            if (!agentStartOk)
            {
                yield break;
            }

            AppendLog("Agent start successfully");
            Debug.Log("Agent start successfully");
            
            // 更新按钮状态
            if (StartButton != null) StartButton.gameObject.SetActive(false);
            if (MuteButton != null) MuteButton.gameObject.SetActive(true);
            if (StopButton != null) StopButton.gameObject.SetActive(true);
        }

        private void OnToggleMute()
        {
            _muted = !_muted;
            _rtc?.AdjustRecordingSignalVolume(_muted ? 0 : 100);
            SetButtonText(MuteButton, _muted ? "开麦" : "关麦");
            Debug.Log(_muted ? "Mic muted" : "Mic unmuted");
        }

        private void OnStop()
        {
            StartCoroutine(StopFlow());
        }

        private IEnumerator StopFlow()
        {
            if (_rtm != null)
            {
                var unsubTask = _rtm.UnsubscribeAsync(_channelName);
                while (!unsubTask.IsCompleted) yield return null;
                var logoutTask = _rtm.LogoutAsync();
                while (!logoutTask.IsCompleted) yield return null;
                Debug.Log("RTM unsubscribed and logged out");
            }
            if (!string.IsNullOrEmpty(_agentId))
            {
                yield return AgentStarter.StopAgent(_agentId, () => { AppendLog("Agent stopped successfully"); Debug.Log("Agent stopped successfully"); }, (err) => { AppendLog("Stop agent error: " + err); Debug.LogError("Stop agent error: " + err); });
                _agentId = string.Empty;
            }
            _rtc?.LeaveChannel();
            _rtc?.Dispose();
            Debug.Log("RTC left and disposed");
            _rtc = null;
            _rtm = null;
            _transcriptMgr.Items.Clear();
            RefreshTranscripts();
            
            // 恢复按钮状态
            if (StartButton != null) { StartButton.gameObject.SetActive(true); StartButton.interactable = true; }
            if (MuteButton != null) MuteButton.gameObject.SetActive(false);
            if (StopButton != null) StopButton.gameObject.SetActive(false);
        }

        private void OnDestroy()
        {
            // Editor 停止运行时清理资源
            if (_rtc != null || _rtm != null || !string.IsNullOrEmpty(_agentId))
            {
                StartCoroutine(StopFlow());
            }
        }

        private void OnApplicationQuit()
        {
            // 应用退出时同步清理（协程可能不会执行完）
            if (!string.IsNullOrEmpty(_agentId))
            {
                Debug.Log("OnApplicationQuit: stopping agent...");
                // 同步停止 agent（协程在退出时不可靠）
                StartCoroutine(AgentStarter.StopAgent(_agentId, () => {}, (err) => {}));
            }
            _rtc?.LeaveChannel();
            _rtc?.Dispose();
            _rtc = null;
            _rtm = null;
        }

        private void OnRtmMessageEvent(MessageEvent @event)
        {
            var text = @event.message.GetData<string>();
            Debug.Log("RTM 收到消息: " + text);
            if (_transcriptMgr.UpsertFromJson(text))
            {
                RefreshTranscripts();
            }
        }

        private class RtcHandler : IRtcEngineEventHandler
        {
            private readonly AgentStartup _owner;
            public RtcHandler(AgentStartup owner) { _owner = owner; }
            public override void OnJoinChannelSuccess(RtcConnection connection, int elapsed)
            {
                _owner.AppendLog($"RTC 加入成功 {connection.localUid}");
                Debug.Log($"RTC 加入成功 {connection.localUid}");
            }
            public override void OnUserJoined(RtcConnection connection, uint remoteUid, int elapsed)
            {
                _owner.AppendLog($"RTC onUserJoined uid:{remoteUid}");
                Debug.Log($"RTC onUserJoined uid:{remoteUid}");
            }
            public override void OnError(int err, string msg)
            {
                _owner.AppendLog($"RTC 错误 {err}");
                Debug.LogError($"RTC 错误 {err} {msg}");
            }
        }
    }
}