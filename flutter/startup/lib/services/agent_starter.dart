import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'app_config.dart';

class AgentStarter {
  static const _jsonType = 'application/json; charset=utf-8';

  static const String _base = 'https://api.sd-rtn.com/cn/api/conversational-ai-agent/v2/projects';

  static String _authHeader() {
    final creds = '${AppConfig.restKey}:${AppConfig.restSecret}';
    return 'Basic ${base64Encode(utf8.encode(creds))}';
  }

  static final Set<String> _sensitive = {
    'auth','token','password','cert','secret','appId','app_id','appCertificate','restKey','restSecret'
  };

  static dynamic _mask(dynamic v) {
    if (v is Map) {
      return v.map((k, value) {
        final key = k.toString();
        if (_sensitive.contains(key)) {
          return MapEntry(key, '***');
        }
        return MapEntry(key, _mask(value));
      });
    } else if (v is List) {
      return v.map(_mask).toList();
    }
    return v;
  }

  static String _maskJson(String input) {
    try {
      final obj = jsonDecode(input);
      return jsonEncode(_mask(obj));
    } catch (_) {
      return input;
    }
  }

  static Future<String> startAgent({required String channelName, required String agentRtcUid, required String token}) async {
    final projectId = AppConfig.appId;
    final url = Uri.parse('$_base/$projectId/join/');
    final body = jsonEncode({
      'name': channelName,
      'pipeline_id': AppConfig.pipelineId,
      'properties': {
        'channel': channelName,
        'agent_rtc_uid': agentRtcUid,
        'remote_rtc_uids': ['*'],
        'token': token,
        'parameters': {
          'transcript': {
            'enable_words': false,
          },
        }
      }
    });
    debugPrint('POST $url');
    debugPrint('Headers: ${jsonEncode({'Authorization': '***', 'Content-Type': _jsonType})}');
    debugPrint('Body: ${_maskJson(body)}');
    final resp = await _postWithRedirects(url, headers: {
      'Authorization': _authHeader(),
      'Content-Type': _jsonType,
    }, body: body);
    debugPrint('Resp ${resp.statusCode} ${resp.reasonPhrase}');
    debugPrint(_maskJson(resp.body));
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final json = jsonDecode(resp.body);
      final agentId = (json['agent_id'] ?? '').toString();
      if (agentId.isEmpty) {
        throw Exception('agent_id empty');
      }
      return agentId;
    }
    throw Exception('Start agent error: ${resp.statusCode} ${resp.body}');
  }

  static Future<void> stopAgent(String agentId) async {
    final projectId = AppConfig.appId;
    final url = Uri.parse('$_base/$projectId/agents/$agentId/leave');
    debugPrint('POST $url');
    debugPrint('Headers: ${jsonEncode({'Authorization': '***', 'Content-Type': _jsonType})}');
    final resp = await _postWithRedirects(url, headers: {
      'Authorization': _authHeader(),
      'Content-Type': _jsonType,
    }, body: "");
    debugPrint('Resp ${resp.statusCode} ${resp.reasonPhrase}');
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Stop agent error: ${resp.statusCode} ${resp.body}');
    }
  }
  static Future<http.Response> _postWithRedirects(Uri url, {required Map<String, String> headers, required String body, int maxRedirects = 3}) async {
    var current = url;
    for (var i = 0; i <= maxRedirects; i++) {
      final resp = await http.post(current, headers: headers, body: body);
      final code = resp.statusCode;
      if (code == 308 || code == 307 || code == 302 || code == 301) {
        final loc = resp.headers['location'] ?? resp.headers['Location'];
        debugPrint('Redirect ($code) to: ${loc ?? "<none>"}');
        if (loc == null || loc.isEmpty) {
          return resp;
        }
        current = Uri.parse(loc);
        continue;
      }
      return resp;
    }
    return await http.post(current, headers: headers, body: body);
  }
}