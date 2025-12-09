import 'package:flutter/services.dart' show rootBundle;

class AppConfig {
  static String appId = const String.fromEnvironment('AGORA_APP_ID', defaultValue: '');
  static String appCertificate = const String.fromEnvironment('AGORA_APP_CERTIFICATE', defaultValue: '');
  static String restKey = const String.fromEnvironment('REST_KEY', defaultValue: '');
  static String restSecret = const String.fromEnvironment('REST_SECRET', defaultValue: '');
  static String pipelineId = const String.fromEnvironment('PIPELINE_ID', defaultValue: '');

  static Future<void> load() async {
    try {
      final content = await rootBundle.loadString('assets/env.properties');
      final lines = content.split(RegExp(r'\r?\n'));
      for (final raw in lines) {
        final line = raw.trim();
        if (line.isEmpty || line.startsWith('#')) continue;
        final idx = line.indexOf('=');
        if (idx <= 0) continue;
        final key = line.substring(0, idx).trim();
        final value = line.substring(idx + 1).trim();
        switch (key) {
          case 'agora.appId':
            appId = value;
            break;
          case 'agora.appCertificate':
            appCertificate = value;
            break;
          case 'agora.restKey':
            restKey = value;
            break;
          case 'agora.restSecret':
            restSecret = value;
            break;
          case 'agora.pipelineId':
            pipelineId = value;
            break;
        }
      }
    } catch (_) {
      // keep dart-define values as fallback
    }
  }
}