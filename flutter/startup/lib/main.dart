import 'package:flutter/material.dart';
import 'services/app_config.dart';
import 'agent_chat_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  runApp(const StartupApp());
}

class StartupApp extends StatelessWidget {
  const StartupApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Agora Startup',
      theme: ThemeData(primarySwatch: Colors.indigo),
      home: const AgentChatPage(),
    );
  }
}