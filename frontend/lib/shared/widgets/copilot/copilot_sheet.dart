import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../auth/models/user_model.dart';
import '../../../auth/services/auth_service.dart';
import '../../../core/haptics/app_haptics.dart';
import '../../../core/localization/language_provider.dart';
import '../../../core/network/connectivity_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../router/app_routes.dart';
import '../../models/copilot_models.dart';
import '../../providers/copilot_provider.dart';
import 'copilot_action_card.dart';

class CopilotSheet extends StatefulWidget {
  final UserModel? user;
  final String roleOverride;
  final String? screenContext;
  final String? initialPrompt;

  const CopilotSheet({
    super.key,
    required this.user,
    required this.roleOverride,
    this.screenContext,
    this.initialPrompt,
  });

  static Future<void> show(
    BuildContext context, {
    required UserModel? user,
    required String role,
    String? screenContext,
    String? initialPrompt,
  }) {
    AppHaptics.mediumImpact();
    CopilotProvider? existingProvider;
    try {
      existingProvider = Provider.of<CopilotProvider>(context, listen: false);
    } catch (_) {
      existingProvider = null;
    }

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final content = CopilotSheet(
          user: user,
          roleOverride: role,
          screenContext: screenContext,
          initialPrompt: initialPrompt,
        );
        if (existingProvider != null) {
          return ChangeNotifierProvider.value(
            value: existingProvider,
            child: content,
          );
        }
        return ChangeNotifierProvider(
          create: (_) => CopilotProvider(),
          child: content,
        );
      },
    );
  }

  @override
  State<CopilotSheet> createState() => _CopilotSheetState();
}

class _CopilotSheetState extends State<CopilotSheet> {
  static const int _maxAttachmentBytes = 5 * 1024 * 1024; // 5 MB

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<CopilotAttachment> _pendingAttachments = [];

  String get _effectiveRole =>
      (widget.user?.role.isNotEmpty == true ? widget.user!.role : widget.roleOverride);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<CopilotProvider>();
      final lang = LanguageProvider.instance.currentLanguage;
      await provider.loadSuggestions(role: _effectiveRole, language: lang);
      if (widget.initialPrompt != null && widget.initialPrompt!.trim().isNotEmpty) {
        _send(widget.initialPrompt!.trim());
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final clean = text.trim();
    if (clean.isEmpty && _pendingAttachments.isEmpty) return;

    final attachmentsToSend = List<CopilotAttachment>.from(_pendingAttachments);
    _inputController.clear();
    if (_pendingAttachments.isNotEmpty) {
      setState(() => _pendingAttachments.clear());
    }
    AppHaptics.selectionClick();
    final provider = context.read<CopilotProvider>();
    final lang = LanguageProvider.instance.currentLanguage;
    await provider.sendMessage(
      role: _effectiveRole,
      text: clean,
      language: lang,
      attachments: attachmentsToSend,
      screenContext: widget.screenContext,
      userId: widget.user?.id,
    );
    _scrollToBottom();
  }

  String _mimeFromExt(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.csv')) return 'text/csv';
    if (lower.endsWith('.md')) return 'text/markdown';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  void _addAttachment(String name, String mime, Uint8List bytes) {
    if (bytes.length > _maxAttachmentBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File too large. Max 5 MB per attachment.'),
        ),
      );
      return;
    }
    if (_pendingAttachments.length >= 3) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 3 attachments per message.')),
      );
      return;
    }
    setState(() {
      _pendingAttachments.add(CopilotAttachment(
        filename: name,
        mimeType: mime,
        bytes: bytes,
      ));
    });
  }

  Future<void> _pickNotesFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt', 'md', 'csv', 'png', 'jpg', 'jpeg', 'webp'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.first;
      Uint8List? bytes = file.bytes;
      if ((bytes == null || bytes.isEmpty) && file.path != null && file.path!.isNotEmpty) {
        final f = File(file.path!);
        if (await f.exists()) {
          bytes = await f.readAsBytes();
        }
      }
      if (bytes == null || bytes.isEmpty) return;
      _addAttachment(file.name, _mimeFromExt(file.name), bytes);
    } catch (_) {}
  }

  Future<void> _pickNotesImage(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1800,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      _addAttachment(picked.name, _mimeFromExt(picked.name), bytes);
    } catch (_) {}
  }

  void _showAttachmentMenu() {
    AppHaptics.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary),
                title: const Text('Upload Notes / Syllabus (PDF, TXT, MD)'),
                subtitle: const Text('Generate exam papers, quizzes, or study prep'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickNotesFile();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
                title: const Text('Photo of Notes / Whiteboard (Gallery)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickNotesImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                title: const Text('Snap Notes / Textbook Page (Camera)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickNotesImage(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  String _roleTitle(String role) {
    final r = role.toLowerCase();
    if (r == 'teacher' || r == 'faculty') return 'Campus AI · Teacher';
    if (r == 'admin' || r == 'dean' || r == 'administrator' || r == 'superadmin') {
      return 'Campus AI · Admin';
    }
    return 'Campus AI · Student';
  }

  String _roleHint(String role) {
    final r = role.toLowerCase();
    if (r == 'teacher' || r == 'faculty') {
      return 'Ask about low attendance, sessions, or draft updates...';
    }
    if (r == 'admin' || r == 'dean' || r == 'administrator' || r == 'superadmin') {
      return 'Ask for campus pulse, SLA ageing, or draft notices...';
    }
    return 'Ask about 75% attendance, mess menu, fees, or leave...';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isOnline = ConnectivityService.instance.isOnline;

    return Consumer<CopilotProvider>(
      builder: (context, provider, _) {
        final messages = provider.messagesFor(_effectiveRole);
        final suggestions = provider.suggestionsFor(_effectiveRole);
        final sending = provider.isSending(_effectiveRole);

        return Container(
          height: screenHeight * 0.84,
          padding: EdgeInsets.only(bottom: bottomInset),
          decoration: BoxDecoration(
            color: isDark ? AppColors.bgDark : const Color(0xFFF6F7FB),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: AppColors.borderOf(context), width: 0.8),
            ),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiaryOf(context).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _roleTitle(_effectiveRole),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimaryOf(context),
                              letterSpacing: -0.3,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isOnline ? AppColors.emerald : AppColors.warning,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isOnline ? 'Campus AI · Role-Scoped' : 'Campus AI · Offline Mode',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondaryOf(context),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (messages.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear conversation',
                        onPressed: () {
                          AppHaptics.selectionClick();
                          provider.clearChat(_effectiveRole);
                        },
                        icon: Icon(
                          Icons.delete_sweep_outlined,
                          color: AppColors.textSecondaryOf(context),
                          size: 20,
                        ),
                      ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.borderOf(context)),

              // Chat body
              Expanded(
                child: messages.isEmpty
                    ? _buildEmptyState(context, suggestions)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                        itemCount: messages.length + (sending ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == messages.length) {
                            return _buildTypingBubble(context);
                          }
                          final msg = messages[index];
                          return _buildMessageBubble(context, provider, msg);
                        },
                      ),
              ),

              // Quick suggestion chips when conversation is active
              if (messages.isNotEmpty && suggestions.isNotEmpty && !sending)
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: suggestions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final s = suggestions[idx];
                      return ActionChip(
                        label: Text(
                          s.label,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                        backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        onPressed: () => _send(s.prompt),
                      );
                    },
                  ),
                ),

              // Input bar + pending attachments preview
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 14, 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceOf(context),
                    border: Border(
                      top: BorderSide(color: AppColors.borderOf(context), width: 0.8),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_pendingAttachments.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: List.generate(_pendingAttachments.length, (i) {
                              final att = _pendingAttachments[i];
                              return Chip(
                                avatar: Icon(
                                  att.mimeType.startsWith('image/')
                                      ? Icons.image_outlined
                                      : Icons.description_outlined,
                                  size: 15,
                                  color: AppColors.primary,
                                ),
                                label: Text(
                                  '${att.filename} (${att.formattedSize})',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                deleteIcon: const Icon(Icons.close_rounded, size: 15),
                                onDeleted: () => setState(() {
                                  _pendingAttachments.removeAt(i);
                                }),
                                backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                                side: BorderSide(
                                  color: AppColors.primary.withValues(alpha: 0.2),
                                ),
                              );
                            }),
                          ),
                        ),
                      Row(
                        children: [
                          IconButton(
                            key: const Key('copilot_attach_button'),
                            tooltip: 'Attach notes, PDF, or photo',
                            onPressed: sending ? null : _showAttachmentMenu,
                            icon: const Icon(
                              Icons.attach_file_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _inputController,
                              textInputAction: TextInputAction.send,
                              onSubmitted: _send,
                              minLines: 1,
                              maxLines: 3,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                color: AppColors.textPrimaryOf(context),
                              ),
                              decoration: InputDecoration(
                                hintText: _pendingAttachments.isNotEmpty
                                    ? 'Add instructions or tap send...'
                                    : _roleHint(_effectiveRole),
                                hintStyle: GoogleFonts.plusJakartaSans(
                                  fontSize: 13.5,
                                  color: AppColors.textSecondaryOf(context),
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? AppColors.surfaceAltDark
                                    : const Color(0xFFF3F4F8),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 11,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: sending ? null : () => _send(_inputController.text),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: sending ? null : AppColors.primaryGradient,
                                color: sending
                                    ? AppColors.textTertiaryOf(context)
                                    : null,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.arrow_upward_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    List<CopilotSuggestion> suggestions,
  ) {
    final firstName = (widget.user?.name.trim().isNotEmpty == true)
        ? widget.user!.name.trim().split(' ').first
        : 'there';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceOf(context),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.borderOf(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi $firstName,',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'I can look up live CampusOS records for your role and draft actions with your confirmation before saving anything.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    height: 1.45,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'TRY ASKING',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
              color: AppColors.textSecondaryOf(context),
            ),
          ),
          const SizedBox(height: 10),
          ...suggestions.map((s) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => _send(s.prompt),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceOf(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderOf(context)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.label,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimaryOf(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.prompt,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                color: AppColors.textSecondaryOf(context),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textSecondaryOf(context),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    CopilotProvider provider,
    CopilotMessage msg,
  ) {
    final isUser = msg.sender == CopilotSender.user;
    final isDark = AppColors.isDark(context);

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.84,
        ),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (isUser && msg.attachmentNames.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: msg.attachmentNames
                      .map((name) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.attach_file_rounded,
                                    size: 12, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  name,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.primary
                    : (isDark ? AppColors.surfaceDark : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 6),
                  bottomRight: Radius.circular(isUser ? 6 : 18),
                ),
                border: isUser
                    ? null
                    : Border.all(color: AppColors.borderOf(context)),
              ),
              child: _buildFormattedText(
                msg.text,
                GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  height: 1.45,
                  color: isUser
                      ? Colors.white
                      : AppColors.textPrimaryOf(context),
                ),
              ),
            ),
            if (!isUser &&
                (msg.text.contains('session is out of sync') ||
                 msg.text.contains('Authenticated user record not found') ||
                 msg.text.contains('sign in again')))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    ),
                    icon: const Icon(Icons.login_rounded, size: 16),
                    label: Text(
                      'Sign In Again',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    onPressed: () async {
                      Navigator.of(context).pop();
                      AppHaptics.mediumImpact();
                      await AuthService.signOut();
                      if (!context.mounted) return;
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRoutes.login,
                        (route) => false,
                      );
                    },
                  ),
                ),
              ),
            if (!isUser && msg.cards.isNotEmpty)
              ...msg.cards.map((card) => card.type == 'document'
                  ? CopilotDocumentCard(card: card)
                  : CopilotMetricsCard(card: card)),
            if (!isUser && msg.pendingActions.isNotEmpty)
              ...msg.pendingActions.map(
                (action) => CopilotActionCard(
                  action: action,
                  onConfirm: () => provider.confirmPendingAction(
                    role: _effectiveRole,
                    action: action,
                  ),
                  onDismiss: () => provider.dismissPendingAction(action),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormattedText(String text, TextStyle baseStyle) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    int lastEnd = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1) ?? '',
        style: baseStyle.copyWith(fontWeight: FontWeight.w800),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }
    return SelectableText.rich(
      TextSpan(style: baseStyle, children: spans),
    );
  }

  Widget _buildTypingBubble(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderOf(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Thinking...',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
