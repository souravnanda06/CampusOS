import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';
import '../../core/database/database_service.dart';
import '../models/copilot_models.dart';

class CopilotChatResponse {
  final String reply;
  final String role;
  final String mode;
  final List<CopilotCardData> cards;
  final List<CopilotPendingAction> pendingActions;
  final List<CopilotSuggestion> suggestedPrompts;

  const CopilotChatResponse({
    required this.reply,
    required this.role,
    required this.mode,
    this.cards = const [],
    this.pendingActions = const [],
    this.suggestedPrompts = const [],
  });
}

class CopilotConfirmResponse {
  final bool success;
  final String message;
  final Map<String, dynamic> result;

  const CopilotConfirmResponse({
    required this.success,
    required this.message,
    this.result = const {},
  });
}

class CopilotService {
  CopilotService._();
  static final CopilotService instance = CopilotService._();

  final ApiClient _api = ApiClient.instance;

  List<CopilotSuggestion> defaultSuggestionsForRole(String role) {
    final r = role.toLowerCase();
    if (r == 'teacher' || r == 'faculty') {
      return const [
        CopilotSuggestion(
          label: 'Create Exam Paper',
          prompt: 'Create a 30-mark mid-sem exam paper for DBMS (Units 1-3) with 5 MCQs, 3 short questions, 2 long questions, and answer key',
        ),
        CopilotSuggestion(
          label: '50-Min Lesson Plan',
          prompt: 'Create a 50-minute lesson plan on Operating Systems Deadlocks with examples and exit quiz',
        ),
        CopilotSuggestion(
          label: 'Low Attendance (<75%)',
          prompt: 'Which students are below 75% attendance right now?',
        ),
        CopilotSuggestion(
          label: 'Class Cohort Health',
          prompt: 'Show overall class cohort attendance health breakdown',
        ),
        CopilotSuggestion(
          label: 'Start Lecture Session',
          prompt: 'Draft an attendance session for Data Structures in Room 204',
        ),
      ];
    }
    if (r == 'admin' || r == 'dean' || r == 'administrator' || r == 'superadmin') {
      return const [
        CopilotSuggestion(
          label: 'Executive Report',
          prompt: 'Generate today’s executive campus briefing report',
        ),
        CopilotSuggestion(
          label: 'Campus Pulse Briefing',
          prompt: 'Give me today’s campus pulse briefing',
        ),
        CopilotSuggestion(
          label: 'Ageing & Recurring Issues',
          prompt: 'Show complaints ageing over 48 hours and recurring clusters',
        ),
        CopilotSuggestion(
          label: 'Pending Student Approvals',
          prompt: 'List pending student registration approvals',
        ),
        CopilotSuggestion(
          label: 'Draft Campus Notice',
          prompt: 'Draft an urgent notice for all students about mid-semester registration verification',
        ),
      ];
    }
    return const [
      CopilotSuggestion(
        label: '75% Attendance Check',
        prompt: 'Check my attendance and tell me how many classes I can skip or need for 75%',
      ),
      CopilotSuggestion(
        label: 'Practice Quiz Prep',
        prompt: 'Create 5 practice exam questions on DBMS Normalization with short answers',
      ),
      CopilotSuggestion(
        label: 'Request Bonafide',
        prompt: 'Draft a Bonafide Certificate request for internship verification',
      ),
      CopilotSuggestion(
        label: "Today's Mess Menu",
        prompt: "What is on today's mess menu?",
      ),
      CopilotSuggestion(
        label: 'Apply Weekend Leave',
        prompt: 'Draft a home visit leave request for tomorrow to day after tomorrow for family function',
      ),
    ];
  }

  Future<List<CopilotSuggestion>> fetchSuggestions({
    required String role,
    required String language,
  }) async {
    try {
      final resp = await _api.get(
        '/copilot/suggestions',
        queryParameters: {'language': language},
        timeout: const Duration(seconds: 8),
      );
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
        final list = (decoded['suggestions'] as List?) ?? const [];
        final parsed = list
            .whereType<Map>()
            .map((e) => CopilotSuggestion.fromJson(Map<String, dynamic>.from(e)))
            .where((s) => s.label.isNotEmpty && s.prompt.isNotEmpty)
            .toList();
        if (parsed.isNotEmpty) return parsed;
      }
    } catch (e) {
      debugPrint('[CopilotService] fetchSuggestions fallback: $e');
    }
    return defaultSuggestionsForRole(role);
  }

  Future<CopilotChatResponse> sendMessage({
    required String message,
    required String role,
    required String language,
    required List<CopilotMessage> history,
    List<CopilotAttachment> attachments = const [],
    String? screenContext,
    String? userId,
  }) async {
    try {
      final recentHistory = history.length > 10
          ? history.sublist(history.length - 10)
          : history;
      final resp = await _api.post(
        '/copilot/chat',
        body: {
          'message': message,
          'language': language,
          'screenContext': screenContext,
          'history': recentHistory.map((m) => m.toHistoryMap()).toList(),
          if (attachments.isNotEmpty)
            'attachments': attachments.map((a) => a.toUploadJson()).toList(),
        },
        timeout: Duration(seconds: attachments.isNotEmpty ? 60 : 30),
      );

      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
        final cardsRaw = (decoded['cards'] as List?) ?? const [];
        final actionsRaw = (decoded['pendingActions'] as List?) ?? const [];
        final suggRaw = (decoded['suggestedPrompts'] as List?) ?? const [];

        return CopilotChatResponse(
          reply: (decoded['reply'] ?? '').toString(),
          role: (decoded['role'] ?? role).toString(),
          mode: (decoded['mode'] ?? 'gemini').toString(),
          cards: cardsRaw
              .whereType<Map>()
              .map((e) => CopilotCardData.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
          pendingActions: actionsRaw
              .whereType<Map>()
              .map((e) => CopilotPendingAction.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
          suggestedPrompts: suggRaw
              .whereType<Map>()
              .map((e) => CopilotSuggestion.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
        );
      }

      String errMsg = 'Unable to reach Campus AI (${resp.statusCode}).';
      try {
        final errJson = jsonDecode(resp.body) as Map<String, dynamic>;
        errMsg = (errJson['message'] ?? errMsg).toString();
      } catch (_) {}

      final isAuthError = resp.statusCode == 401 ||
          errMsg.toLowerCase().contains('authenticated user record not found') ||
          errMsg.toLowerCase().contains('authentication required') ||
          errMsg.toLowerCase().contains('unauthorized');

      if (isAuthError) {
        errMsg =
            'Your login session is out of sync with the server database. Please sign in again to continue using Campus AI.';
        return CopilotChatResponse(
          reply: errMsg,
          role: role,
          mode: 'session_expired',
          suggestedPrompts: defaultSuggestionsForRole(role),
        );
      }

      return CopilotChatResponse(
        reply: errMsg,
        role: role,
        mode: 'error',
        suggestedPrompts: defaultSuggestionsForRole(role),
      );
    } catch (e) {
      debugPrint('[CopilotService] sendMessage network fallback: $e');
      return _offlineLocalResponse(
        message: message,
        role: role,
        userId: userId,
      );
    }
  }

  Future<CopilotConfirmResponse> confirmAction(String actionId) async {
    try {
      final resp = await _api.post(
        '/copilot/confirm',
        body: {'actionId': actionId},
        timeout: const Duration(seconds: 20),
      );
      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode == 200) {
        return CopilotConfirmResponse(
          success: true,
          message: (decoded['message'] ?? 'Action completed.').toString(),
          result: decoded['result'] is Map
              ? Map<String, dynamic>.from(decoded['result'] as Map)
              : const {},
        );
      }
      return CopilotConfirmResponse(
        success: false,
        message: (decoded['message'] ?? 'Action failed (${resp.statusCode}).').toString(),
      );
    } catch (e) {
      return const CopilotConfirmResponse(
        success: false,
        message: 'Could not confirm action while offline or unreachable.',
      );
    }
  }

  Future<CopilotChatResponse> _offlineLocalResponse({
    required String message,
    required String role,
    String? userId,
  }) async {
    final lower = message.toLowerCase();
    final r = role.toLowerCase();
    final cards = <CopilotCardData>[];
    String reply =
        'You are currently offline. Connect to campus Wi-Fi or mobile data for full AI Copilot actions.';

    try {
      final db = DatabaseService.instance;
      if (r == 'student') {
        final records = await db.attendanceRepository.getPendingRecords();
        final complaints = userId != null && userId.isNotEmpty
            ? await db.complaintRepository.getStudentComplaints(userId)
            : const [];
        if (lower.contains('attendance') || lower.contains('check')) {
          reply =
              'Offline Local Mode: You have ${records.length} locally queued check-in(s) waiting to sync. Connect online for your full 75% subject calculator.';
        } else if (lower.contains('complaint') || lower.contains('ticket')) {
          reply =
              'Offline Local Mode: ${complaints.length} cached complaint(s) found on device. You can still file offline complaints from the Requests tab.';
        } else {
          reply =
              'Offline Local Mode: Cached local records (${records.length} pending attendance syncs, ${complaints.length} cached complaints). Reconnect for live mess menu, notices, and AI drafting.';
        }
        cards.add(CopilotCardData(
          type: 'metrics',
          title: 'Offline Device Cache',
          items: [
            CopilotMetricItem(label: 'Pending Check-ins', value: '${records.length}'),
            CopilotMetricItem(label: 'Cached Complaints', value: '${complaints.length}'),
          ],
        ));
      } else if (r == 'teacher' || r == 'faculty') {
        if (lower.contains('lesson') || lower.contains('lecture') || lower.contains('plan')) {
          // Extract topic cleanly
          String topic = message;
          final match = RegExp(r'(?:on|about|for)\s+([A-Za-z0-9\s\-_]{3,40})', caseSensitive: false).firstMatch(message);
          if (match != null) {
            topic = match.group(1)!.trim();
          } else if (topic.length > 50) {
            topic = topic.substring(0, 50);
          }

          reply = "I've structured a 50-minute lesson plan for **$topic** (device offline mode). You can review or copy it below:";
          cards.add(CopilotCardData(
            type: 'document',
            title: '$topic — 50-Minute Lesson Plan',
            subtitle: 'Offline Lesson Outline',
            badges: const ['LESSON PLAN', '50 Mins', 'Offline Ready'],
            content: "• 00-05 min: Context Hook & Recap of prior foundations\n"
                "• 05-20 min: Core Concept Walkthrough & Structural Flow\n"
                "• 20-35 min: Worked Interactive Example & Case Study\n"
                "• 35-45 min: Guided Student Problem Solving & Pair Discussion\n"
                "• 45-50 min: 2-Question Exit Ticket & Wrap-Up",
            answerKey: "Exit Quiz Checks:\n1. Verify core definition and prerequisite constraints.\n2. State one standard mitigation strategy.",
          ));
        } else if (lower.contains('exam') || lower.contains('quiz') || lower.contains('paper') || lower.contains('assessment')) {
          String topic = 'Assessment';
          final match = RegExp(r'(?:for|on|in)\s+([A-Za-z0-9\s\-_]{3,40})', caseSensitive: false).firstMatch(message);
          if (match != null) {
            topic = match.group(1)!.trim();
          }

          reply = "I've generated a structured assessment paper for **$topic** (device offline mode):";
          cards.add(CopilotCardData(
            type: 'document',
            title: '$topic Question Paper',
            subtitle: 'Offline Generated Exam',
            badges: const ['QUIZ', '20 Marks', '30 Mins'],
            content: "Section A — Objective / Short Answer (10 Marks)\n"
                "1. State the primary objective and definitions of $topic. [2]\n"
                "2. List two key criteria or conditions governing $topic. [2]\n"
                "3. Differentiate between conventional and modern approaches in $topic. [2]\n"
                "4. Identify common failure modes or edge cases in $topic. [2]\n"
                "5. Write a short 2-line practical takeaway. [2]\n\n"
                "Section B — Analytical Problem (10 Marks)\n"
                "6. Provide a step-by-step worked solution or proof for a core problem in $topic. [10]",
            answerKey: "Section A: 2 marks per question for accurate terminology and justification.\nSection B: 5 marks logic, 3 marks calculation, 2 marks conclusion.",
          ));
        } else {
          final sessions = await db.sessionRepository.getAllSessions();
          reply =
              'Offline Local Mode: ${sessions.length} cached class session(s) stored on device. Live roster analytics and notice publishing require connectivity.';
          cards.add(CopilotCardData(
            type: 'metrics',
            title: 'Offline Session Cache',
            items: [
              CopilotMetricItem(label: 'Cached Sessions', value: '${sessions.length}'),
            ],
          ));
        }
      } else {
        reply =
            'Offline Local Mode: Admin campus pulse, SLA ageing, and circular publishing require an active connection to the CampusOS server.';
      }
    } catch (e) {
      debugPrint('[CopilotService] offline DB check skipped: $e');
    }

    return CopilotChatResponse(
      reply: reply,
      role: r,
      mode: 'offline_local',
      cards: cards,
      suggestedPrompts: defaultSuggestionsForRole(role),
    );
  }
}
