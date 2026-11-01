import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_colors.dart';

/// Performance-optimized high-contrast QR credential display with isolated countdown.
///
/// Uses [ValueListenableBuilder] for the remaining seconds counter, avoiding
/// unnecessary widget tree rebuilds during the 30-second rotation cycle.
class PassportQrView extends StatelessWidget {
  final String qrData;
  final ValueNotifier<int> remainingSecondsNotifier;
  final double qrSize;
  final VoidCallback? onManualRefresh;

  const PassportQrView({
    Key? key,
    required this.qrData,
    required this.remainingSecondsNotifier,
    this.qrSize = 180.0,
    this.onManualRefresh,
  }) : super(key: key);

  String _formatSeconds(int seconds) {
    final s = seconds.clamp(0, 99);
    return '00:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Crisp High-Contrast QR Code Surface
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.08),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: RepaintBoundary(
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: qrSize,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF0F172A),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF0F172A),
              ),
              padding: const EdgeInsets.all(4),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Isolated 30-Second Countdown Badge
        ValueListenableBuilder<int>(
          valueListenable: remainingSecondsNotifier,
          builder: (context, seconds, _) {
            final isExpiringSoon = seconds <= 5;
            final badgeColor = isExpiringSoon
                ? AppColors.warning
                : const Color(0xFF6366F1);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: badgeColor.withValues(alpha: 0.28),
                  width: 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 13,
                    color: badgeColor,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Refreshes in ${_formatSeconds(seconds)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: badgeColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (onManualRefresh != null) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: onManualRefresh,
                      behavior: HitTestBehavior.opaque,
                      child: Icon(
                        Icons.refresh_rounded,
                        size: 14,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
