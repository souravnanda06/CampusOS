import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/mesh_theme.dart';
import '../mesh_chat_channel.dart';

/// Frosted Glass Header Bar for Screen 2 (Chat screen).
///
/// Features:
/// - Frosted glass with BackdropFilter sigma 24 and hairline bottom border
/// - Back chevron with 44x44 minimum touch target & haptic feedback
/// - 42px circular channel avatar with initial and gradient
/// - Channel name (17px, weight 600)
/// - Green-dot status line "Hybrid mesh · {n} peer nearby"
/// - White "Hybrid" pill with Bluetooth icon
class ChatHeader extends StatelessWidget {
  final MeshChatChannel channel;
  final int peerCount;
  final VoidCallback onBack;

  const ChatHeader({
    super.key,
    required this.channel,
    required this.peerCount,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final (initial, gradient) = _resolveVisuals(channel.name);
    final peerText = peerCount == 1 ? '1 peer nearby' : '$peerCount peers nearby';

    return RepaintBoundary(
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.frostedHeaderWhite,
              border: Border(
                bottom: BorderSide(
                  color: AppColors.hairlineBorder,
                  width: 0.8,
                ),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    // Back button with >= 44x44 touch target and Semantics
                    Semantics(
                      label: 'Back to channels',
                      button: true,
                      child: Tooltip(
                        message: 'Back to channels',
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(22),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              onBack();
                            },
                            child: const SizedBox(
                              width: 44,
                              height: 44,
                              child: Icon(
                                Icons.chevron_left_rounded,
                                color: AppColors.accentIndigo,
                                size: 32,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // 42px Channel Avatar
                    Container(
                      width: AppRadii.avatarMedium,
                      height: AppRadii.avatarMedium,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: gradient,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: gradient.first.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Channel Name & Mesh Status line
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            channel.name,
                            style: AppTextStyles.chatHeaderTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.successGreen,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  'Hybrid mesh · $peerText',
                                  style: AppTextStyles.chatHeaderStatus,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // White "Hybrid" pill with Bluetooth icon
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        border: Border.all(
                          color: AppColors.hairlineBorder,
                          width: 0.8,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0A14142B),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.bluetooth_rounded,
                            size: 14,
                            color: AppColors.accentIndigo,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Hybrid',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  (String, List<Color>) _resolveVisuals(String channelName) {
    final clean = channelName.replaceAll('#', '').trim();
    final initial = clean.isNotEmpty ? clean[0].toUpperCase() : '#';

    switch (clean.toLowerCase()) {
      case 'general':
        return ('G', const [Color(0xFF6B58F6), Color(0xFF8B76FF)]);
      case 'hostel-b':
        return ('H', const [Color(0xFFFF7063), Color(0xFFFF957B)]);
      case 'study-group':
        return ('S', const [Color(0xFF1EAEBA), Color(0xFF47D1DF)]);
      case 'alerts':
      case 'emergency':
        return ('A', const [Color(0xFFE58B24), Color(0xFFF9B854)]);
      default:
        return (initial, const [Color(0xFF5B5BD6), Color(0xFF7A56F0)]);
    }
  }
}
