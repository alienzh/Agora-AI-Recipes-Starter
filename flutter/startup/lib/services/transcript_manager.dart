import 'dart:convert';

enum TranscriptTypeX { user, agent }

enum TranscriptStatusX { inProgress, end, interrupted, unknown }

class TranscriptItem {
  final String id;
  final TranscriptTypeX type;
  final String text;
  final TranscriptStatusX status;
  const TranscriptItem({required this.id, required this.type, required this.text, required this.status});
}

class TranscriptManager {
  final List<TranscriptItem> items = [];

  bool upsert(TranscriptItem item) {
    final idx = items.indexWhere((e) => e.id == item.id && e.type == item.type);
    if (idx >= 0) {
      items[idx] = item;
    } else {
      items.add(item);
    }
    return true;
  }

  bool upsertFromJson(String json) {
    final parsed = _parseJson(json);
    if (parsed == null) return false;
    return upsert(parsed);
  }

  TranscriptItem? _parseJson(String json) {
    try {
      final obj = jsonDecode(json);
      if (obj is! Map<String, dynamic>) return null;
      final objType = (obj['object'] ?? '').toString();
      TranscriptTypeX type;
      if (objType == 'assistant.transcription') {
        type = TranscriptTypeX.agent;
      } else if (objType == 'user.transcription') {
        type = TranscriptTypeX.user;
      } else {
        return null;
      }
      final idAny = obj['turn_id'] ?? obj['message_id'] ?? DateTime.now().microsecondsSinceEpoch;
      final id = idAny.toString();
      final text = (obj['text'] ?? '').toString();
      final statusCode = _asInt(obj['turn_status']);
      TranscriptStatusX status;
      switch (statusCode) {
        case null:
          status = TranscriptStatusX.inProgress;
          break;
        case 0:
          status = TranscriptStatusX.inProgress;
          break;
        case 1:
          status = TranscriptStatusX.end;
          break;
        case 2:
          status = TranscriptStatusX.interrupted;
          break;
        default:
          status = TranscriptStatusX.unknown;
      }
      return TranscriptItem(id: id, type: type, text: text.isEmpty ? '(empty)' : text, status: status);
    } catch (_) {
      return null;
    }
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }
}