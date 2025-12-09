import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:agora_rtm/agora_rtm.dart';
import 'services/app_config.dart';
import 'services/token_generator.dart';
import 'services/agent_starter.dart';
import 'services/permission_service.dart';
import 'services/transcript_manager.dart';

enum ConnectionStateX { idle, connecting, connected, error }


class AgentChatPage extends StatefulWidget {
  const AgentChatPage({super.key});
  @override
  State<AgentChatPage> createState() => _AgentChatPageState();
}

class _AgentChatPageState extends State<AgentChatPage> {
  static const int userUid = 1001086;
  static const int agentUid = 1009527;
  ConnectionStateX connectionState = ConnectionStateX.idle;
  bool isMuted = false;
  String agentStateText = 'Unknown';
  String channelName = '';
  String? agentId;
  RtcEngine? _rtc;
  RtmClient? _rtm;
  final TranscriptManager transcriptMgr = TranscriptManager();
  final List<String> debugLogs = [];
  final ScrollController _logCtrl = ScrollController();
  final ScrollController _transcriptCtrl = ScrollController();

  String _randomChannel() {
    final r = 1000 + (DateTime.now().millisecondsSinceEpoch % 9000);
    return 'channel_flutter_$r';
  }

  Future<void> _startFlow() async {
    if (connectionState == ConnectionStateX.connecting) return;
    final appId = AppConfig.appId;
    final isMobile = !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
    channelName = _randomChannel();
    setState(() {
      connectionState = ConnectionStateX.connecting;
      debugLogs.add('Starting...');
    });
    try {
      if (!isMobile) {
        setState(() {
          connectionState = ConnectionStateX.error;
          debugLogs.add('当前平台不支持 RTC/RTM 插件');
        });
        return;
      }
      final granted = await PermissionService.ensureMicrophoneGranted(context);
      if (!granted) {
        setState(() {
          connectionState = ConnectionStateX.error;
          debugLogs.add('麦克风权限未授予');
        });
        return;
      }

      // RTC: create engine
      _rtc = await createAgoraRtcEngine();
      // RTC: initialize with App ID and live broadcasting profile
      await _rtc!.initialize(RtcEngineContext(appId: appId, channelProfile: ChannelProfileType.channelProfileLiveBroadcasting));
      debugLogs.add('RtcEngine 初始化成功');
      // RTC: register event handlers
      _rtc!.registerEventHandler(RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        debugLogs.add('RTC 加入成功 ${connection.localUid}');
        setState(() {});
      },
        onError: (ErrorCodeType code, String message) {
        debugLogs.add('RTC 错误 ${code.index}');
        setState(() {
          connectionState = ConnectionStateX.error;
        });
      },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        debugLogs.add('RTC onUserJoined uid:$remoteUid');
        setState(() {});
      }));

      // Token: unified token for RTC/RTM (user)
      String userToken;
      try {
        userToken = await TokenGenerator.generateUnifiedToken(channelName: channelName, uid: userUid.toString());
        debugLogs.add('获取 Token 成功');
      } catch (e) {
        debugLogs.add('获取 Token 失败: $e');
        rethrow;
      }
      // RTC: join channel with unified token and audio publish options
      await _rtc!.joinChannel(
        token: userToken,
        channelId: channelName,
        uid: userUid,
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          publishMicrophoneTrack: true,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
      debugLogs.add('joinChannel 调用完成');
      // RTC: auto unmute after joining
      await _rtc?.adjustRecordingSignalVolume(100);
      setState(() { isMuted = false; });
      debugLogs.add('已自动开麦');

      try {
        // RTM: create client
        final result = await RTM(appId, userUid.toString());
        _rtm = result.$2;
        debugLogs.add('RtmClient 初始化成功');
      } catch (e) {
        debugLogs.add('RtmClient 初始化失败: $e');
        rethrow;
      }
      // RTM: add message and link state listeners
      _rtm!.addListener(
        message: (event) {
          final text = utf8.decode(event.message ?? []);
          print('RTM 收到消息: $text');
          if (transcriptMgr.upsertFromJson(text)) {
            setState(() {});
          }
        },
        linkState: (event) {
          debugLogs.add('RTM ${event.previousState} -> ${event.currentState}');
          setState(() {});
        },
      );
      try {
        // RTM: login with unified token
        debugLogs.add('rtmLogin 调用');
        await _rtm!.login(userToken);
        debugLogs.add('rtmLogin 成功');
      } catch (e) {
        debugLogs.add('rtmLogin 失败: $e');
        rethrow;
      }
      // RTM: subscribe to channel
      await _rtm!.subscribe(channelName);

      // Token: agent RTC token
      String agentToken;
      try {
        agentToken = await TokenGenerator.generateUnifiedToken(channelName: channelName, uid: agentUid.toString());
        debugLogs.add('获取 Agent Token 成功');
      } catch (e) {
        debugLogs.add('获取 Agent Token 失败: $e');
        rethrow;
      }
      try {
        // REST: start agent
        debugLogs.add('Agent Start 调用');
        agentId = await AgentStarter.startAgent(channelName: channelName, agentRtcUid: agentUid.toString(), token: agentToken);
        debugLogs.add('Agent Start 成功');
      } catch (e) {
        debugLogs.add('Agent Start 失败: $e');
        rethrow;
      }

      setState(() {
        connectionState = ConnectionStateX.connected;
        agentStateText = 'Connected';
        debugLogs.add('Agent start successfully');
      });
    } catch (e) {
      setState(() {
        connectionState = ConnectionStateX.error;
        debugLogs.add('连接失败 $e');
      });
    }
  }

  Future<void> _toggleMute() async {
    isMuted = !isMuted;
    await _rtc?.adjustRecordingSignalVolume(isMuted ? 0 : 100);
    setState(() {});
  }

  Future<void> _hangup() async {
    try {
      if (_rtm != null) {
        await _rtm!.unsubscribe(channelName);
        await _rtm!.logout();
      }
    } catch (_) {}
    try {
      if (agentId != null && agentId!.isNotEmpty) {
        await AgentStarter.stopAgent(agentId!);
        debugLogs.add('Agent stopped successfully');
      }
      await _rtc?.leaveChannel();
      await _rtc?.release();
    } catch (_) {}
    setState(() {
      connectionState = ConnectionStateX.idle;
      agentStateText = 'IDLE';
      transcriptMgr.items.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = connectionState == ConnectionStateX.connected;
    final isConnecting = connectionState == ConnectionStateX.connecting;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_logCtrl.hasClients) {
        _logCtrl.jumpTo(_logCtrl.position.maxScrollExtent);
      }
      if (_transcriptCtrl.hasClients) {
        _transcriptCtrl.jumpTo(_transcriptCtrl.position.maxScrollExtent);
      }
    });
    return Scaffold(
      backgroundColor: const Color(0xFFEEF2FF),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                child: SizedBox(
                  height: 140,
                  child: ListView.builder(
                    controller: _logCtrl,
                    itemCount: debugLogs.length,
                    itemBuilder: (_, i) => Text(debugLogs[i]),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: _transcriptCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: transcriptMgr.items.length,
                      itemBuilder: (_, i) {
                        final t = transcriptMgr.items[i];
                        final isUser = t.type == TranscriptTypeX.user;
                        final bg = isUser ? const Color(0xFFE8FFF3) : const Color(0xFFE9E9FF);
                        final badge = isUser ? 'USER' : 'AGENT';
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: isUser ? const Color(0xFF10B981) : const Color(0xFF6366F1), borderRadius: BorderRadius.circular(12)), child: Text(badge, style: const TextStyle(color: Colors.white))),
                            ]),
                            const SizedBox(height: 8),
                            Text(t.text.isEmpty ? '(empty)' : t.text),
                          ]),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: Text('Agent 状态: $agentStateText', style: const TextStyle(color: Colors.black54)),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!isConnected)
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isConnecting ? null : _startFlow,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(isConnecting ? 'Starting...' : 'Start Agent'),
                        ),
                      ),
                    )
                  else ...[
                    ElevatedButton(onPressed: _toggleMute, child: Icon(isMuted ? Icons.mic_off : Icons.mic)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _hangup,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Text('Stop'),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}