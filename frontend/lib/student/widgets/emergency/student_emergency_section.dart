import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../auth/models/user_model.dart';
import '../../../core/haptics/app_haptics.dart';
import '../../../core/mesh/campus_mesh_manager.dart';
import '../../../core/mesh/emergency/campus_mesh_emergency_service.dart';
import '../../../core/mesh/emergency/emergency_alert.dart';
import '../../../core/theme/app_colors.dart';
import '../../screens/student_emergency_screen.dart';
import '../../../shared/widgets/motion/apple_bounceable.dart';

/// Emergency & SOS section displayed inside the Student Home dashboard.
///
/// Highlights active campus emergency flares & sounding sirens immediately at the top
/// with one-tap silence/acknowledge controls, and provides direct access to
/// [StudentEmergencyScreen] even when all clear.
class StudentEmergencySection extends StatelessWidget {
  final UserModel? user;
  final CampusMeshEmergencyService? emergencyService;

  const StudentEmergencySection({
    super.key,
    this.user,
    this.emergencyService,
  });

  CampusMeshEmergencyService? _resolveService() {
    if (emergencyService != null) return emergencyService;
    if (CampusMeshManager.instance.isInitialized) {
      return CampusMeshManager.instance.emergencyService;
    }
    return null;
  }

  void _openStudentEmergency(BuildContext context) {
    AppHaptics.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentEmergencyScreen(
          user: user,
          emergencyService: emergencyService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = _resolveService();
    if (service == null) {
      return _buildStandbyCard(context);
    }

    return ValueListenableBuilder<EmergencyAlert?>(
      valueListenable: service.notifier.activeSirenAlert,
      builder: (context, activeSiren, _) {
        return StreamBuilder<List<EmergencyAlert>>(
          stream: service.watchActiveEmergencies(),
          builder: (context, snapshot) {
            final alerts = snapshot.data ?? const <EmergencyAlert>[];
            final priorityAlert = activeSiren ??
                (alerts.isNotEmpty ? alerts.first : null);

            if (priorityAlert != null) {
              return _buildActiveEmergencyCard(
                context,
                service: service,
                alert: priorityAlert,
                isSirenSounding: activeSiren != null,
                totalActiveCount: alerts.length,
              );
            }

            return _buildStandbyCard(context);
          },
        );
      },
    );
  }

  Widget _buildActiveEmergencyCard(
    BuildContext context, {
    required CampusMeshEmergencyService service,
    required EmergencyAlert alert,
    required bool isSirenSounding,
    required int totalActiveCount,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isSirenSounding
                      ? Icons.volume_up_rounded
                      : Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSirenSounding
                          ? 'EMERGENCY SIREN ACTIVE · ${alert.sirenPattern.label.toUpperCase()}'
                          : 'ACTIVE EMERGENCY ALERT (${alert.severity.label})',
                      style: GoogleFonts.jetBrainsMono(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      alert.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (totalActiveCount > 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '+${totalActiveCount - 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            alert.message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (isSirenSounding || !alert.isAcknowledged) ...[
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFB91C1C),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(
                      isSirenSounding
                          ? Icons.volume_off_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 16,
                    ),
                    label: Text(
                      isSirenSounding ? 'Silence Siren' : 'Acknowledge',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onPressed: () async {
                      AppHaptics.mediumImpact();
                      await service.acknowledgeEmergency(alert.alertId);
                    },
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: Text(
                    'Safety Hub',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () => _openStudentEmergency(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStandbyCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppleBounceable(
        scaleFactor: 0.98,
        onTap: () => _openStudentEmergency(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1215) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.danger.withValues(alpha: isDark ? 0.35 : 0.22),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.25)
                    : AppColors.danger.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.danger.withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.sos_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Emergency & SOS',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'READY',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Send SOS + Siren offline · View campus alerts',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? Colors.white60
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Open',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.danger,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.danger,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
