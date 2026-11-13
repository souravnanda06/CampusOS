import 'package:flutter/material.dart';
import '../models/copilot_models.dart';
import '../services/copilot_service.dart';

class CopilotProvider extends ChangeNotifier {
  final CopilotService _service;

  CopilotProvider({CopilotService? service})
      : _service = service ?? CopilotService.instance;

  final Map<String, List<CopilotMessage>> _messagesByRole = {};
  final Map<String, List<CopilotSuggestion>> _suggestionsByRole = {};
  final Set<String> _loadingRoles = {};

  String _canonicalRole(String role) {
    final r = role.trim().toLowerCase();
    if (r == 'teacher' || r == 'faculty' || r == 'instructor') return 'teacher';
    if (r == 'admin' || r == 'dean' || r == 'administrator' || r == 'superadmin') {
      return 'admin';
    }
    return 'student';
  }

  List<CopilotMessage> messagesFor(String role) {
    final key = _canonicalRole(role);
    return List.unmodifiable(_messagesByRole[key] ?? const []);
  }

  List<CopilotSuggestion> suggestionsFor(String role) {
    final key = _canonicalRole(role);
    return _suggestionsByRole[key] ?? _service.defaultSuggestionsForRole(key);
  }

  bool isSending(String role) => _loadingRoles.contains(_canonicalRole(role));

  Future<void> loadSuggestions({
    required String role,
    required String language,
  }) async {
    final key = _canonicalRole(role);
    if (_suggestionsByRole.containsKey(key)) return;
    final list = await _service.fetchSuggestions(role: key, language: language);
    _suggestionsByRole[key] = list;
    notifyListeners();
  }

  void clearChat(String role) {
    final key = _canonicalRole(role);
    _messagesByRole[key] = [];
    notifyListeners();
  }

  Future<void> sendMessage({
    required String role,
    required String text,
    required String language,
    List<CopilotAttachment> attachments = const [],
    String? screenContext,
    String? userId,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && attachments.isEmpty) return;

    final effectiveText = trimmed.isNotEmpty
        ? trimmed
        : (_canonicalRole(role) == 'teacher'
            ? 'Generate a structured assessment paper with answer key from these uploaded notes.'
            : 'Summarize and create practice questions from these uploaded notes.');

    final key = _canonicalRole(role);
    if (_loadingRoles.contains(key)) return;

    final history = _messagesByRole.putIfAbsent(key, () => []);
    final priorSnapshot = List<CopilotMessage>.from(history);

    history.add(CopilotMessage(
      id: 'u_${DateTime.now().microsecondsSinceEpoch}',
      sender: CopilotSender.user,
      text: effectiveText,
      attachmentNames: attachments.map((a) => a.filename).toList(),
    ));
    _loadingRoles.add(key);
    notifyListeners();

    try {
      final resp = await _service.sendMessage(
        message: effectiveText,
        role: key,
        language: language,
        history: priorSnapshot,
        attachments: attachments,
        screenContext: screenContext,
        userId: userId,
      );

      if (resp.suggestedPrompts.isNotEmpty) {
        _suggestionsByRole[key] = resp.suggestedPrompts;
      }

      history.add(CopilotMessage(
        id: 'a_${DateTime.now().microsecondsSinceEpoch}',
        sender: CopilotSender.assistant,
        text: resp.reply,
        mode: resp.mode,
        cards: resp.cards,
        pendingActions: resp.pendingActions,
        isError: resp.mode == 'error',
      ));
    } finally {
      _loadingRoles.remove(key);
      notifyListeners();
    }
  }

  Future<void> confirmPendingAction({
    required String role,
    required CopilotPendingAction action,
  }) async {
    if (action.status == CopilotActionStatus.executing ||
        action.status == CopilotActionStatus.executed) {
      return;
    }

    action.status = CopilotActionStatus.executing;
    notifyListeners();

    final resp = await _service.confirmAction(action.actionId);
    if (resp.success) {
      action.status = CopilotActionStatus.executed;
      action.executionMessage = resp.message;
    } else {
      action.status = CopilotActionStatus.failed;
      action.executionMessage = resp.message;
    }
    notifyListeners();
  }

  void dismissPendingAction(CopilotPendingAction action) {
    if (action.status == CopilotActionStatus.executed) return;
    action.status = CopilotActionStatus.dismissed;
    action.executionMessage = 'Dismissed';
    notifyListeners();
  }
}
