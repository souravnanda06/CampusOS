import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../auth/models/user_model.dart';
import '../../core/haptics/app_haptics.dart';
import '../../core/mesh/campus_mesh_manager.dart';
import '../../core/mesh/emergency/campus_mesh_emergency_service.dart';
import '../../core/mesh/emergency/emergency_alert.dart';
import '../../core/theme/app_colors.dart';
import '../../router/app_routes.dart';
import '../../shared/widgets/motion/apple_bounceable.dart';
import '../../shared/widgets/motion/apple_spring_scroll_physics.dart';

/// Student-focused Emergency, SOS Distress & Siren Alert Center.
///
/// Gives students:
/// - Instant live emergency alert feed & audible siren control (Silence / Test)
/// - One-tap offline BLE Mesh SOS Distress Beacon + Audible Siren sender
/// - Quick-dial campus emergency helplines & offline evacuation instructions
class StudentEmergencyScreen extends StatefulWidget {
  final UserModel? user;
  final CampusMeshEmergencyService? emergencyService;

  const StudentEmergencyScreen({
    super.key,
    this.user,
    this.emergencyService,
  });

  @override
  State<StudentEmergencyScreen> createState() => _StudentEmergencyScreenState();
}

class _StudentEmergencyScreenState extends State<StudentEmergencyScreen> {
  late final CampusMeshEmergencyService _emergencyService;
  final TextEditingController _detailsController = TextEditingController();

  EmergencyCategory _selectedCategory = EmergencyCategory.hostel;
  EmergencySirenPattern _selectedSiren = EmergencySirenPattern.yelp;
  bool _sendSiren = true;
  bool _isSendingSos = false;
  bool _showHistory = false;

  @override
  void initState() {
    super.initState();
    _emergencyService =
        widget.emergencyService ?? CampusMeshManager.instance.emergencyService;
    _emergencyService.initialize();
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _sendSosWithSiren() async {
    if (_isSendingSos) return;
    AppHaptics.heavyImpact();
    setState(() => _isSendingSos = true);

    try {
      await _emergencyService.sendStudentSosBeacon(
        category: _selectedCategory,
        details: _detailsController.text.trim(),
        scope: EmergencyScope.hostel,
        sendSiren: _sendSiren,
        sirenPattern: _sendSiren ? _selectedSiren : EmergencySirenPattern.none,
      );

      _detailsController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _sendSiren
                  ? 'SOS Beacon + ${_selectedSiren.label} siren sent to nearby CampusOS devices!'
                  : 'SOS Distress Beacon broadcasted over CampusOS Mesh!',
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to broadcast SOS: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSendingSos = false);
    }
  }

  Future<void> _toggleSirenTest() async {
    AppHaptics.mediumImpact();
    final notifier = _emergencyService.notifier;
    if (notifier.activeSirenAlert.value != null) {
      await _emergencyService.stopActiveSiren();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Emergency siren silenced.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    await notifier.triggerSirenTest(pattern: _selectedSiren);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Testing ${_selectedSiren.label} siren & vibration (6s)...'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _callEmergencyNumber(String label, String number) async {
    AppHaptics.selectionClick();
    final uri = Uri(scheme: 'tel', path: number);
    try {
      final launched = await launchUrl(uri);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dial $label at $number'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dial $label at $number'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0B0C10) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF13151C) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.emergency_share_rounded,
                color: AppColors.danger,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emergency & Safety',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Offline Mesh SOS · Audible Sirens',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _showHistory ? 'Show Active Alerts' : 'Show Alert History',
            icon: Icon(_showHistory ? Icons.notifications_active_rounded : Icons.history_rounded),
            onPressed: () {
              setState(() => _showHistory = !_showHistory);
            },
          ),
          IconButton(
            tooltip: 'Open Full Mesh Flare Console',
            icon: const Icon(Icons.hub_outlined),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.meshEmergency);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: AppleSpringScrollPhysics.always,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Live Siren Active Banner (appears whenever a siren is sounding)
            _buildLiveSirenBanner(isDark),

            // 2. Active / Historical Campus Emergency Alerts
            _buildAlertsSection(isDark),
            const SizedBox(height: 18),

            // 3. Student SOS & Siren Beacon Card
            _buildStudentSosCard(isDark),
            const SizedBox(height: 18),

            // 4. Campus Emergency Helplines
            _buildHelplinesCard(isDark),
            const SizedBox(height: 18),

            // 5. Offline Mesh Safety Guidance
            _buildSafetyGuideCard(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveSirenBanner(bool isDark) {
    return ValueListenableBuilder<EmergencyAlert?>(
      valueListenable: _emergencyService.notifier.activeSirenAlert,
      builder: (context, activeSiren, _) {
        if (activeSiren == null) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDC2626).withValues(alpha: 0.4),
                blurRadius: 18,
                offset: const Offset(0, 6),
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
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.volume_up_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SIREN SOUNDING · ${activeSiren.sirenPattern.label.toUpperCase()}',
                          style: GoogleFonts.jetBrainsMono(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          activeSiren.title,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                activeSiren.message,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFB91C1C),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.volume_off_rounded, size: 18),
                  label: Text(
                    'SILENCE SIREN & ACKNOWLEDGE',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  onPressed: () async {
                    await _emergencyService.acknowledgeEmergency(
                      activeSiren.alertId,
                    );
                    if (mounted) setState(() {});
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlertsSection(bool isDark) {
    final surface = isDark ? const Color(0xFF161822) : Colors.white;
    final border = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _showHistory ? 'Recent Emergency History' : 'Active Campus Alerts',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            TextButton.icon(
              icon: Icon(
                _showHistory ? Icons.radar_rounded : Icons.history_rounded,
                size: 16,
              ),
              label: Text(_showHistory ? 'Active' : 'History'),
              onPressed: () => setState(() => _showHistory = !_showHistory),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_showHistory)
          FutureBuilder<List<EmergencyAlert>>(
            future: _emergencyService.getEmergencyHistory(limit: 25),
            builder: (context, snapshot) {
              final list = snapshot.data ?? [];
              if (list.isEmpty) {
                return _buildAllClearCard(
                  isDark: isDark,
                  surface: surface,
                  border: border,
                  title: 'No Alert History',
                  subtitle: 'No emergency flares or SOS alerts recorded on this device.',
                );
              }
              return Column(
                children: list.map((a) => _buildAlertCard(a, isDark)).toList(),
              );
            },
          )
        else
          StreamBuilder<List<EmergencyAlert>>(
            stream: _emergencyService.watchActiveEmergencies(),
            builder: (context, snapshot) {
              final alerts = snapshot.data ?? [];
              if (alerts.isEmpty) {
                return _buildAllClearCard(
                  isDark: isDark,
                  surface: surface,
                  border: border,
                  title: 'All Clear · Campus Safe',
                  subtitle: 'Offline BLE & Wi-Fi mesh monitoring is active for emergency sirens and flares.',
                );
              }
              return Column(
                children: alerts.map((a) => _buildAlertCard(a, isDark)).toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _buildAllClearCard({
    required bool isDark,
    required Color surface,
    required Color border,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: AppColors.success,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(EmergencyAlert alert, bool isDark) {
    final color = alert.isCritical
        ? AppColors.danger
        : (alert.severity == EmergencySeverity.warning
            ? AppColors.warning
            : AppColors.info);
    final isExpired = !alert.isActive();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? (alert.isCritical ? const Color(0xFF251012) : const Color(0xFF181A24))
            : (alert.isCritical ? const Color(0xFFFFF1F2) : Colors.white),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  alert.severity.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                alert.category.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              if (alert.hasSiren) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.volume_up_rounded, size: 11, color: AppColors.danger),
                      const SizedBox(width: 3),
                      Text(
                        alert.sirenPattern.label,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              Text(
                alert.hopDescription,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            alert.title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            alert.message,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              height: 1.4,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                alert.isTrusted ? Icons.verified_rounded : Icons.wifi_tethering_rounded,
                size: 14,
                color: alert.isTrusted ? AppColors.success : AppColors.warning,
              ),
              const SizedBox(width: 4),
              Text(
                alert.isTrusted
                    ? 'Verified ${alert.issuerRole.toUpperCase()}'
                    : 'Offline Mesh Peer',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: alert.isTrusted ? AppColors.success : AppColors.warning,
                ),
              ),
              const Spacer(),
              if (!alert.isAcknowledged && !isExpired)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 15),
                  label: const Text('Acknowledge', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  onPressed: () async {
                    await _emergencyService.acknowledgeEmergency(alert.alertId);
                    if (mounted) setState(() {});
                  },
                )
              else
                Text(
                  isExpired ? 'Expired' : 'Acknowledged ✓',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: isExpired ? Colors.grey : AppColors.success,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentSosCard(bool isDark) {
    final surface = isDark ? const Color(0xFF191215) : Colors.white;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.35),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.danger.withValues(alpha: isDark ? 0.18 : 0.08),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.sos_rounded, color: AppColors.danger, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Personal SOS & Siren Beacon',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Alerts nearby students, wardens & security with zero internet',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Emergency Type',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white70 : const Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSosTypeChip(EmergencyCategory.hostel, '🏥 Medical'),
              _buildSosTypeChip(EmergencyCategory.fire, '🔥 Fire / Smoke'),
              _buildSosTypeChip(EmergencyCategory.security, '🚨 Threat'),
              _buildSosTypeChip(EmergencyCategory.evacuation, '⚠️ Evacuate'),
              _buildSosTypeChip(EmergencyCategory.other, '⚡ Hazard'),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _detailsController,
            maxLength: 180,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Your hostel block, room or landmark (optional)',
              filled: true,
              fillColor: isDark ? const Color(0xFF10121A) : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Send Audible Siren to Nearby Phones',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              'Triggers alarm sound & vibration on all nearby CampusOS devices',
              style: GoogleFonts.plusJakartaSans(fontSize: 11.5),
            ),
            activeThumbColor: AppColors.danger,
            value: _sendSiren,
            onChanged: (val) => setState(() => _sendSiren = val),
          ),
          if (_sendSiren) ...[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                EmergencySirenPattern.yelp,
                EmergencySirenPattern.wail,
                EmergencySirenPattern.lockdown,
              ].map((pat) {
                final selected = _selectedSiren == pat;
                return ChoiceChip(
                  label: Text(pat.label, style: const TextStyle(fontSize: 11.5)),
                  selected: selected,
                  selectedColor: AppColors.danger,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : null,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedSiren = pat);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                flex: 2,
                child: AppleBounceable(
                  onTap: _isSendingSos ? null : _sendSosWithSiren,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.danger.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isSendingSos
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.campaign_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  _sendSiren ? 'SEND SOS + SIREN' : 'BROADCAST SOS',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(color: AppColors.danger.withValues(alpha: 0.6)),
                    minimumSize: const Size(0, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.volume_up_rounded, size: 18),
                  label: const Text('Test', style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: _toggleSirenTest,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSosTypeChip(EmergencyCategory category, String label) {
    final isSelected = _selectedCategory == category;
    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      selected: isSelected,
      selectedColor: AppColors.danger,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : null,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      ),
      onSelected: (val) {
        if (val) setState(() => _selectedCategory = category);
      },
    );
  }

  Widget _buildHelplinesCard(bool isDark) {
    final surface = isDark ? const Color(0xFF161822) : Colors.white;
    final border = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);

    const contacts = [
      ('Campus Security Control', '24x7 Gate & Patrol Desk', '100', Icons.shield_rounded, Color(0xFF2563EB)),
      ('Medical & Ambulance', 'Campus Health Center', '108', Icons.local_hospital_rounded, Color(0xFFDC2626)),
      ('Fire & Rescue', 'Emergency Fire Response', '101', Icons.local_fire_department_rounded, Color(0xFFEA580C)),
      ('National Helpline', 'Unified Emergency Response', '112', Icons.call_rounded, Color(0xFF059669)),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Campus Emergency Helplines',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          ...contacts.map((c) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _callEmergencyNumber(c.$1, c.$3),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1D202D) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: c.$5.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(c.$4, color: c.$5, size: 19),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.$1,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              c.$2,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: c.$5.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          c.$3,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: c.$5,
                          ),
                        ),
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

  Widget _buildSafetyGuideCard(bool isDark) {
    final surface = isDark ? const Color(0xFF161822) : Colors.white;
    final border = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF6366F1)),
              const SizedBox(width: 8),
              Text(
                'How Offline Mesh Sirens Work',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '• Works without mobile data or Wi-Fi router via Bluetooth Low Energy & Peer Hotspot.\n'
            '• Verified flares from Dean, Admin, or Warden automatically relay across student phones.\n'
            '• Tap Acknowledge once safe to silence your device siren and confirm reception.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              height: 1.5,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}
