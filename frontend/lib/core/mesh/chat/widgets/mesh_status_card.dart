import 'package:flutter/material.dart';
import '../../theme/mesh_theme.dart';
import '../providers/mesh_chat_providers.dart';

/// Mesh Status Card displayed on Screen 1 (Channels list).
///
/// Features:
/// - Indigo-violet gradient with radius 26
/// - Inset top highlight border and radial corner glow
/// - 40px translucent circle with Bluetooth icon
/// - Title "Hybrid mesh active" and dynamic subtitle "{n} peer nearby · syncing"
/// - Transport chips: Bluetooth, Wi-Fi, Internet
/// - Repeating pulsing green dot indicator
class MeshStatusCard extends StatefulWidget {
  final MeshLiveStatus status;
  final VoidCallback? onTap;

  const MeshStatusCard({
    super.key,
    required this.status,
    this.onTap,
  });

  @override
  State<MeshStatusCard> createState() => _MeshStatusCardState();
}

class _MeshStatusCardState extends State<MeshStatusCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final peerText = widget.status.peerCount == 1
        ? '1 peer nearby'
        : '${widget.status.peerCount} peers nearby';
    final syncText = widget.status.isSyncing ? ' · syncing' : '';

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadii.card),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF5346E8), Color(0xFF7E56F5)],
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.28),
            width: 1.0,
          ),
          boxShadow: AppShadows.meshStatusCard,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.card),
            onTap: widget.onTap,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.card),
              child: Stack(
                children: [
              // Radial corner ambient glow
              Positioned(
                top: -30,
                right: -20,
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.22),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),

              // Inset top highlight line
              Positioned(
                top: 0,
                left: 20,
                right: 20,
                height: 1,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.45),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),

              // Card Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 40px translucent circle with Bluetooth icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 1,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.bluetooth_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Title, Subtitle, and Transport Chips
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Hybrid mesh active',
                            style: AppTextStyles.statusTitle,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '$peerText$syncText',
                            style: AppTextStyles.statusSubtitle,
                          ),
                          const SizedBox(height: 10),
                          const Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _TransportChip(label: 'Bluetooth'),
                              _TransportChip(label: 'Wi-Fi'),
                              _TransportChip(label: 'Internet'),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Pulsing green dot indicator on the right
                    Padding(
                      padding: const EdgeInsets.only(left: 8, right: 6),
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          final scale = 1.0 + (_pulseAnimation.value * 0.35);
                          final opacity = 0.5 - (_pulseAnimation.value * 0.35);
                          return SizedBox(
                            width: 22,
                            height: 22,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Pulsing ambient wave
                                Transform.scale(
                                  scale: scale,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF34D399)
                                          .withValues(alpha: opacity.clamp(0.0, 1.0)),
                                    ),
                                  ),
                                ),
                                // Core bright green dot
                                Container(
                                  width: 11,
                                  height: 11,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF34D399),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF34D399)
                                            .withValues(alpha: 0.8),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
      ),
    );
  }
}

class _TransportChip extends StatelessWidget {
  final String label;

  const _TransportChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.28),
          width: 0.8,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
