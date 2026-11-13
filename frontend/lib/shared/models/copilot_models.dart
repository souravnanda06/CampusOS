import 'dart:convert';
import 'dart:typed_data';

/// Data models for the CampusOS AI Copilot (Student, Teacher, Admin).

class CopilotAttachment {
  final String filename;
  final String mimeType;
  final Uint8List bytes;

  const CopilotAttachment({
    required this.filename,
    required this.mimeType,
    required this.bytes,
  });

  int get sizeBytes => bytes.length;

  String get formattedSize {
    if (sizeBytes < 1024) return '${sizeBytes}B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toUploadJson() => {
        'filename': filename,
        'mimeType': mimeType,
        'dataBase64': base64Encode(bytes),
      };
}

enum CopilotSender { user, assistant }

enum CopilotActionStatus { pendingConfirmation, executing, executed, dismissed, failed }

class CopilotSuggestion {
  final String label;
  final String prompt;

  const CopilotSuggestion({
    required this.label,
    required this.prompt,
  });

  factory CopilotSuggestion.fromJson(Map<String, dynamic> json) {
    return CopilotSuggestion(
      label: (json['label'] ?? '').toString(),
      prompt: (json['prompt'] ?? '').toString(),
    );
  }
}

class CopilotMetricItem {
  final String label;
  final String value;

  const CopilotMetricItem({required this.label, required this.value});

  factory CopilotMetricItem.fromJson(Map<String, dynamic> json) {
    return CopilotMetricItem(
      label: (json['label'] ?? '').toString(),
      value: (json['value'] ?? '').toString(),
    );
  }
}

class CopilotListRow {
  final String title;
  final String subtitle;
  final String? badge;

  const CopilotListRow({
    required this.title,
    required this.subtitle,
    this.badge,
  });

  factory CopilotListRow.fromJson(Map<String, dynamic> json) {
    return CopilotListRow(
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      badge: json['badge']?.toString(),
    );
  }
}

class CopilotCardData {
  final String type; // 'metrics' | 'list' | 'document'
  final String title;
  final String? subtitle;
  final List<String> badges;
  final String? content;
  final String? answerKey;
  final List<CopilotMetricItem> items;
  final List<CopilotListRow> rows;

  const CopilotCardData({
    required this.type,
    required this.title,
    this.subtitle,
    this.badges = const [],
    this.content,
    this.answerKey,
    this.items = const [],
    this.rows = const [],
  });

  factory CopilotCardData.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List?) ?? const [];
    final rawRows = (json['rows'] as List?) ?? const [];
    final rawBadges = (json['badges'] as List?) ?? const [];
    return CopilotCardData(
      type: (json['type'] ?? 'metrics').toString(),
      title: (json['title'] ?? '').toString(),
      subtitle: json['subtitle']?.toString(),
      badges: rawBadges.map((e) => e.toString()).where((e) => e.isNotEmpty).toList(),
      content: json['content']?.toString(),
      answerKey: json['answerKey']?.toString(),
      items: rawItems
          .whereType<Map>()
          .map((e) => CopilotMetricItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      rows: rawRows
          .whereType<Map>()
          .map((e) => CopilotListRow.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class CopilotPendingAction {
  final String actionId;
  final String actionType;
  final String title;
  final String summary;
  final Map<String, dynamic> payload;
  CopilotActionStatus status;
  String? executionMessage;

  CopilotPendingAction({
    required this.actionId,
    required this.actionType,
    required this.title,
    required this.summary,
    required this.payload,
    this.status = CopilotActionStatus.pendingConfirmation,
    this.executionMessage,
  });

  factory CopilotPendingAction.fromJson(Map<String, dynamic> json) {
    final rawStatus = (json['status'] ?? 'PENDING_CONFIRMATION').toString().toUpperCase();
    final mappedStatus = rawStatus == 'EXECUTED'
        ? CopilotActionStatus.executed
        : CopilotActionStatus.pendingConfirmation;
    return CopilotPendingAction(
      actionId: (json['actionId'] ?? '').toString(),
      actionType: (json['actionType'] ?? '').toString(),
      title: (json['title'] ?? 'Confirm Action').toString(),
      summary: (json['summary'] ?? '').toString(),
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : const {},
      status: mappedStatus,
    );
  }
}

class CopilotMessage {
  final String id;
  final CopilotSender sender;
  final String text;
  final DateTime timestamp;
  final String? mode; // 'gemini' | 'local_assist' | 'offline_local'
  final List<CopilotCardData> cards;
  final List<CopilotPendingAction> pendingActions;
  final List<String> attachmentNames;
  final bool isError;

  CopilotMessage({
    required this.id,
    required this.sender,
    required this.text,
    DateTime? timestamp,
    this.mode,
    this.cards = const [],
    this.pendingActions = const [],
    this.attachmentNames = const [],
    this.isError = false,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toHistoryMap() => {
        'sender': sender == CopilotSender.user ? 'user' : 'assistant',
        'text': text,
      };
}
