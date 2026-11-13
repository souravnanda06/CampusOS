import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/mesh_theme.dart';
import '../providers/mesh_chat_providers.dart';

/// Single Channel Row within the frosted inset-grouped card on Screen 1.
///
/// Features:
/// - 52px circular gradient avatar with channel initial & glossy inner highlight
/// - Channel name (17px, weight 600)
/// - Last-message preview (single line, ellipsis, "You: " prefix for own messages)
/// - Time on the right and unread badge pill
/// - Hairline divider inset 80px from the left
/// - Pressed & hover states tinting indigo at 12% and 6% with tactile haptic feedback
class ChannelRow extends StatelessWidget {
  final ChannelSummary summary;
  final VoidCallback onTap;
  final bool showDivider;

  const ChannelRow({
    super.key,
    required this.summary,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            splashColor: AppColors.inkWellIndigo12,
            highlightColor: AppColors.inkWellIndigo6,
            hoverColor: AppColors.inkWellIndigo6,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  // 52px circular gradient avatar with glossy inner highlight
                  _buildGlossyAvatar(),
                  const SizedBox(width: 14),

                  // Channel Name & Last Message Preview
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                summary.name,
                                style: AppTextStyles.channelName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (summary.lastMessageTime.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                summary.lastMessageTime,
                                style: AppTextStyles.channelTime,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                summary.lastMessagePreview,
                                style: AppTextStyles.channelPreview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (summary.hasUnread && summary.unreadCount > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  gradient: AppColors.accentGradient,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.accentIndigo
                                          .withValues(alpha: 0.35),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '${summary.unreadCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Hairline divider inset 80px from left
        if (showDivider)
          Container(
            height: 0.8,
            margin: const EdgeInsets.only(left: 80, right: 16),
            color: AppColors.hairlineBorder,
          ),
      ],
    );
  }

  Widget _buildGlossyAvatar() {
    return Container(
      width: AppRadii.avatarLarge,
      height: AppRadii.avatarLarge,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: summary.avatarGradient,
        ),
        boxShadow: [
          BoxShadow(
            color: summary.avatarGradient.first.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glossy top-half inner highlight
          Positioned(
            top: 2,
            left: 6,
            right: 6,
            height: 22,
            child: Container(
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.40),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Channel Initial Text
          Text(
            summary.initial,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}
