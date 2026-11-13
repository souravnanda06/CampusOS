import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/mesh_theme.dart';
import '../mesh_chat_delivery_state.dart';
import '../mesh_chat_message.dart';
import '../providers/mesh_chat_providers.dart';
import 'flagged_message.dart';

/// Single Message Bubble (Incoming or Outgoing) styled to Apple/Telegram standards.
///
/// Features:
/// - WhatsApp-style double blue ticks for read direct messages
/// - Bidirectional Gemini AI translation: English <-> Odia (ଓଡ଼ିଆ) with 1-tap quick action
/// - Incoming: white, hairline border, subtle shadow, responsive max width, right-aligned meta
/// - Outgoing: indigo gradient, white text, tail bottom-right, colored shadow
/// - Flagged message embedding with animated cross-fade reveal
/// - Long-press action sheet: Translate to English / Odia via Gemini, Copy Text
class MessageBubble extends ConsumerWidget {
  final MeshChatMessage message;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final bool animateEntrance;
  final bool isFlaggedRevealed;
  final ValueChanged<bool>? onFlaggedRevealChanged;

  const MessageBubble({
    super.key,
    required this.message,
    this.isFirstInGroup = true,
    this.isLastInGroup = true,
    this.animateEntrance = false,
    this.isFlaggedRevealed = false,
    this.onFlaggedRevealChanged,
  });

  static bool _isOdiaText(String text) => RegExp(r'[\u0B00-\u0B7F]').hasMatch(text);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOut = message.isOutgoing;
    final borderRadius = _resolveBorderRadius(isOut);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxBubbleWidth = screenWidth > 0 ? math.min(350.0, screenWidth * 0.76) : 250.0;

    final translations = ref.watch(messageTranslationsProvider);
    final translation = translations[message.messageId];

    Widget bubble = Align(
      alignment: isOut ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxBubbleWidth,
          minWidth: 90,
        ),
        child: GestureDetector(
          onLongPress: () => _showMessageActions(context, ref, translation != null),
          child: Container(
            decoration: BoxDecoration(
              color: isOut ? null : AppColors.incomingBubbleBg,
              gradient: isOut ? AppColors.accentGradient : null,
              borderRadius: borderRadius,
              border: isOut
                  ? null
                  : Border.all(
                      color: AppColors.hairlineBorder,
                      width: 0.9,
                    ),
              boxShadow: isOut ? AppShadows.outgoingBubble : AppShadows.incomingBubble,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Embedded photo thumbnail if present
                if (message.imageBase64 != null && message.imageBase64!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      base64Decode(message.imageBase64!),
                      fit: BoxFit.cover,
                      width: double.infinity,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Flagged safety warning or message body
                if (message.isFlagged)
                  FlaggedMessage(
                    text: message.text,
                    customReason: message.flagReason,
                    initialRevealed: isFlaggedRevealed,
                    onRevealChanged: onFlaggedRevealChanged,
                  )
                else
                  Text(
                    message.text,
                    style: isOut
                        ? AppTextStyles.outgoingMessageText
                        : AppTextStyles.incomingMessageText,
                  ),

                // Gemini Odia / English Translation box
                if (translation != null && translation.text.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isOut
                          ? Colors.white.withValues(alpha: 0.18)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isOut
                            ? Colors.white.withValues(alpha: 0.3)
                            : const Color(0xFFCBD5E1),
                        width: 0.8,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 13,
                              color: isOut ? Colors.amberAccent : const Color(0xFF6366F1),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${translation.targetLanguageName} · Gemini AI',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: isOut ? Colors.white70 : const Color(0xFF475569),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          translation.text,
                          style: TextStyle(
                            fontSize: 14.0,
                            fontWeight: FontWeight.w500,
                            color: isOut ? Colors.white : const Color(0xFF0F172A),
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 5),

                // Right-aligned Meta line
                Align(
                  alignment: Alignment.bottomRight,
                  child: _buildMetaRow(context, ref, isOut, translation != null),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (animateEntrance) {
      return TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          final scale = 0.92 + (0.08 * value);
          final slideY = 8.0 * (1.0 - value);
          return Transform.translate(
            offset: Offset(0, slideY),
            child: Transform.scale(
              scale: scale,
              alignment: isOut ? Alignment.bottomRight : Alignment.bottomLeft,
              child: Opacity(
                opacity: value.clamp(0.0, 1.0),
                child: child,
              ),
            ),
          );
        },
        child: bubble,
      );
    }

    return bubble;
  }

  void _showMessageActions(BuildContext context, WidgetRef ref, bool hasTranslation) {
    HapticFeedback.lightImpact();
    final isOdia = _isOdiaText(message.text);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: AppShadows.softCard,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4D6E2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              if (hasTranslation)
                ListTile(
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 20),
                  ),
                  title: const Text('Hide Translation', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  subtitle: const Text('Remove current translation from view', style: TextStyle(fontSize: 12, color: Colors.black54)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    ref.read(messageTranslationsProvider.notifier).removeTranslation(message.messageId);
                  },
                ),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6366F1), size: 20),
                ),
                title: Text(
                  isOdia ? 'Translate to English ✨' : 'Translate to Odia (ଓଡ଼ିଆ) ✨',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: Text(
                  isOdia
                      ? 'Translate Odia text into English via Google Gemini AI'
                      : 'Translate English text into Odia via Google Gemini AI',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _handleTranslate(context, ref, targetLanguage: isOdia ? 'en' : 'or');
                },
              ),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.translate_rounded, color: Color(0xFF0EA5E9), size: 20),
                ),
                title: Text(
                  isOdia ? 'Translate to Odia (ଓଡ଼ିଆ) ✨' : 'Translate to English ✨',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: Text(
                  isOdia
                      ? 'Refresh / re-translate into Odia via Google Gemini AI'
                      : 'Translate into English via Google Gemini AI',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _handleTranslate(context, ref, targetLanguage: isOdia ? 'or' : 'en');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.copy_rounded, color: Colors.black87, size: 20),
                ),
                title: const Text('Copy Text', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  Clipboard.setData(ClipboardData(text: message.text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Message copied to clipboard'),
                      duration: const Duration(milliseconds: 1400),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleTranslate(BuildContext context, WidgetRef ref, {String? targetLanguage}) async {
    final translations = ref.read(messageTranslationsProvider);
    if (targetLanguage == null && translations.containsKey(message.messageId)) {
      ref.read(messageTranslationsProvider.notifier).removeTranslation(message.messageId);
      return;
    }

    final isOdia = _isOdiaText(message.text);
    final target = targetLanguage ?? (isOdia ? 'en' : 'or');
    final targetLabel = target == 'en' ? 'English' : 'Odia (ଓଡ଼ିଆ)';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Text('Translating to $targetLabel with Gemini AI...'),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    final chatService = ref.read(meshChatServiceProvider);
    final res = await chatService?.translateMessage(message.text, targetLanguage: target);
    if (res != null && res.text.isNotEmpty) {
      ref.read(messageTranslationsProvider.notifier).setTranslation(message.messageId, res);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not translate message. Check internet connection.')),
        );
      }
    }
  }

  Widget _buildMetaRow(BuildContext context, WidgetRef ref, bool isOut, bool hasTranslation) {
    final timeStr = DateFormat('HH:mm').format(message.createdAt);

    if (isOut) {
      Widget statusIcon;

      if (message.isDirectMessage) {
        // WhatsApp-like ticks for 1-by-1 Direct Messages
        switch (message.deliveryState) {
          case MeshChatDeliveryState.seen:
            // Double Blue Tick
            statusIcon = const Icon(
              Icons.done_all_rounded,
              size: 15,
              color: Color(0xFF34B7F1), // WhatsApp blue
            );
            break;
          case MeshChatDeliveryState.received:
            // Double Grey Tick (Delivered to peer)
            statusIcon = const Icon(
              Icons.done_all_rounded,
              size: 15,
              color: AppColors.outgoingCheckmarks,
            );
            break;
          case MeshChatDeliveryState.relayed:
            // Single Grey Tick (Sent/Relayed over mesh/cloud)
            statusIcon = const Icon(
              Icons.done_rounded,
              size: 15,
              color: AppColors.outgoingCheckmarks,
            );
            break;
          case MeshChatDeliveryState.queued:
          case MeshChatDeliveryState.broadcasting:
            statusIcon = const Icon(
              Icons.access_time_rounded,
              size: 13,
              color: AppColors.outgoingCheckmarks,
            );
            break;
          case MeshChatDeliveryState.failed:
          case MeshChatDeliveryState.expired:
            statusIcon = const Icon(
              Icons.error_outline_rounded,
              size: 14,
              color: Colors.redAccent,
            );
            break;
        }
      } else {
        // Broadcast / public group channels
        switch (message.deliveryState) {
          case MeshChatDeliveryState.queued:
          case MeshChatDeliveryState.broadcasting:
            statusIcon = const Icon(
              Icons.access_time_rounded,
              size: 13,
              color: AppColors.outgoingCheckmarks,
            );
            break;
          case MeshChatDeliveryState.failed:
          case MeshChatDeliveryState.expired:
            statusIcon = const Icon(
              Icons.error_outline_rounded,
              size: 14,
              color: Colors.redAccent,
            );
            break;
          default:
            statusIcon = const Icon(
              Icons.done_all_rounded,
              size: 15,
              color: AppColors.outgoingCheckmarks,
            );
            break;
        }
      }

      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            timeStr,
            style: AppTextStyles.metaOutgoing,
          ),
          const SizedBox(width: 4),
          statusIcon,
        ],
      );
    }

    // Incoming: "P2P · 1 hop · 17:05" or "Internet · 17:05" + subtle Odia/English translate action
    String transportLabel;
    if (message.syncStatus == 'SYNCED') {
      transportLabel = 'Internet';
    } else if (message.hopCount <= 1) {
      transportLabel = 'P2P · 1 hop';
    } else {
      transportLabel = 'P2P · ${message.hopCount} hops';
    }

    final isOdia = _isOdiaText(message.text);
    final quickButtonLabel = hasTranslation ? 'Hide' : (isOdia ? 'English' : 'ଓଡ଼ିଆ');

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '$transportLabel · $timeStr',
          style: AppTextStyles.metaIncoming,
        ),
        const SizedBox(width: 6),
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => _handleTranslate(context, ref),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 11,
                  color: Color(0xFF6366F1),
                ),
                const SizedBox(width: 2),
                Text(
                  quickButtonLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6366F1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  BorderRadius _resolveBorderRadius(bool isOut) {
    const double radiusNormal = AppRadii.bubble; // 20
    const double radiusSmall = AppRadii.bubbleTail; // 6

    if (isOut) {
      return BorderRadius.only(
        topLeft: const Radius.circular(radiusNormal),
        topRight: Radius.circular(isFirstInGroup ? radiusNormal : radiusSmall),
        bottomLeft: const Radius.circular(radiusNormal),
        bottomRight: const Radius.circular(radiusSmall),
      );
    } else {
      return BorderRadius.only(
        topLeft: Radius.circular(isFirstInGroup ? radiusNormal : radiusSmall),
        topRight: const Radius.circular(radiusNormal),
        bottomLeft: Radius.circular(isLastInGroup ? radiusSmall : radiusSmall),
        bottomRight: const Radius.circular(radiusNormal),
      );
    }
  }
}
