import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> ensureMicrophoneGranted(BuildContext context) async {
    var status = await Permission.microphone.status;
    if (status.isGranted) return true;

    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('需要麦克风权限'),
        content: const Text('为进行语音通话，请授予麦克风权限。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('允许')),
        ],
      ),
    );
    if (proceed != true) return false;

    status = await Permission.microphone.request();
    if (status.isGranted) return true;

    if (status.isPermanentlyDenied || status.isRestricted) {
      final go = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('前往设置开启权限'),
          content: const Text('麦克风权限被关闭，请在系统设置中开启后继续。'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('稍后')),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('去设置')),
          ],
        ),
      );
      if (go == true) {
        await openAppSettings();
        final again = await Permission.microphone.status;
        return again.isGranted;
      }
    }
    return false;
  }
}