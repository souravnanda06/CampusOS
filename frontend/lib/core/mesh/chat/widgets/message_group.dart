import 'package:flutter/material.dart';
import '../../theme/mesh_theme.dart';
import '../mesh_chat_message.dart';
import 'message_bubble.dart';

/// Telegram-style Grouped Messages Widget.
///
/// Features:
/// - Clusters consecutive messages from the same sender
/// - Shows sender name & green mono role tag (STUDENT) only on the first bubble
/// - Shows 30px circular avatar only on the last bubble; uses SizedBox spacer on others
/// - 6px joined corners between consecutive messages in the group
/// - Supports outgoing and incoming message groups
class MessageGroup extends StatelessWidget {
  final List<MeshChatMessage> messages;
  final bool isOutgoing;
  final Set<String> revealedFlaggedIds;
  final void Function(String messageId, bool isRevealed)? onFlaggedRevealChanged;
  final String? newestMessageId;

  const MessageGroup({
    super.key,
    required this.messages,
    required this.isOutgoing,
    this.revealedFlaggedIds = const {},
    this.onFlaggedRevealChanged,
    this.newestMessageId,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) return const SizedBox.shrink();

    final firstMsg = messages.first;
    final senderName = firstMsg.senderDisplayName.isNotEmpty
        ? firstMsg.senderDisplayName
        : (isOutgoing ? 'You' : 'Peer');
    final role = firstMsg.senderRole.toUpperCase();

    if (isOutgoing) {
      // Outgoing messages group (Right aligned)
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (int i = 0; i < messages.length; i++) ...[
              if (i > 0) const SizedBox(height: 3),
              MessageBubble(
                message: messages[i],
                isFirstInGroup: i == 0,
                isLastInGroup: i == messages.length - 1,
                animateEntrance: messages[i].messageId == newestMessageId,
                isFlaggedRevealed: revealedFlaggedIds.contains(messages[i].messageId),
                onFlaggedRevealChanged: (revealed) {
                  onFlaggedRevealChanged?.call(messages[i].messageId, revealed);
                },
              ),
            ],
          ],
        ),
      );
    }

    // Incoming messages group (Left aligned with avatar and header)
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header on the first bubble: Sender Name & Green Mono Role Tag
          Padding(
            padding: const EdgeInsets.only(left: 38, bottom: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  senderName,
                  style: AppTextStyles.senderName,
                ),
                const SizedBox(width: 8),
                _buildRoleTag(role),
              ],
            ),
          ),

          // Consecutive message bubbles with 30px avatar or spacer
          for (int i = 0; i < messages.length; i++) ...[
            if (i > 0) const SizedBox(height: 3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 30px avatar only on last bubble; SizedBox spacer on others
                if (i == messages.length - 1)
                  _buildSenderAvatar(senderName)
                else
                  const SizedBox(width: AppRadii.avatarSmall),

                const SizedBox(width: 8),

                // Bubble
                Flexible(
                  child: MessageBubble(
                    message: messages[i],
                    isFirstInGroup: i == 0,
                    isLastInGroup: i == messages.length - 1,
                    animateEntrance: messages[i].messageId == newestMessageId,
                    isFlaggedRevealed: revealedFlaggedIds.contains(messages[i].messageId),
                    onFlaggedRevealChanged: (revealed) {
                      onFlaggedRevealChanged?.call(messages[i].messageId, revealed);
                    },
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRoleTag(String role) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.successGreenLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.successGreen.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Text(
        role.isNotEmpty ? role : 'STUDENT',
        style: AppTextStyles.roleTag,
      ),
    );
  }

  Widget _buildSenderAvatar(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';
    // Generate deterministic gradient from name hash
    final gradients = [
      const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
      const [Color(0xFF0EA5E9), Color(0xFF06B6D4)],
      const [Color(0xFF10B981), Color(0xFF059669)],
      const [Color(0xFFF59E0B), Color(0xFFD97706)],
      const [Color(0xFFEC4899), Color(0xFFD946EF)],
    ];
    final colorPair = gradients[name.hashCode.abs() % gradients.length];

    return Container(
      width: AppRadii.avatarSmall,
      height: AppRadii.avatarSmall,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colorPair,
        ),
        boxShadow: [
          BoxShadow(
            color: colorPair.first.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
