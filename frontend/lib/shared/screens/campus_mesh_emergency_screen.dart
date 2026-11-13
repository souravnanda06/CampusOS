import 'package:flutter/material.dart';

import '../../core/mesh/campus_mesh_manager.dart';
import '../../core/mesh/emergency/campus_mesh_emergency_service.dart';
import '../../core/mesh/emergency/emergency_alert.dart';
import '../../core/mesh/emergency/emergency_authorization.dart';
import '../../core/theme/app_colors.dart';

/// Screen displaying official CampusOS Emergency Disaster Flare alerts.
///
/// Provides a high-contrast, zero-internet offline emergency command view
/// showing active hazards, certified sender roles, hop telemetry, student SOS beacons,
/// and local acknowledgement.
class CampusMeshEmergencyScreen extends StatefulWidget {
  final CampusMeshEmergencyService emergencyService;

  const CampusMeshEmergencyScreen({
    super.key,
    required this.emergencyService,
  });

  @override
  State<CampusMeshEmergencyScreen> createState() => _CampusMeshEmergencyScreenState();
}

class _CampusMeshEmergencyScreenState extends State<CampusMeshEmergencyScreen> {
  bool _showHistory = false;

  @override
  void initState() {
    super.initState();
    // Ensure repository tables and packet listeners are active
    widget.emergencyService.initialize();
  }

  void _onRoleChanged(String role) {
    widget.emergencyService.meshService.setLocalRole(role);
    try {
      CampusMeshManager.instance.setLocalRole(role);
    } catch (_) {}
    setState(() {});
  }

  Future<void> _testSiren() async {
    final notifier = widget.emergencyService.notifier;
    if (notifier.activeSirenAlert.value != null) {
      await notifier.stopSiren();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔇 Emergency siren silenced.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    await notifier.triggerSirenTest(pattern: EmergencySirenPattern.wail);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔊 Emergency siren & heavy haptic pulse triggered (6s test)!'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _triggerTestDrillFlare() async {
    final currentRole = widget.emergencyService.meshService.localRole;
    final isStudent = currentRole == 'student';

    // If student, issue under warden drill authority so it broadcasts across all hops
    if (isStudent) {
      widget.emergencyService.meshService.setLocalRole('warden');
    }

    try {
      await widget.emergencyService.issueEmergencyAlert(
        title: 'Campus Emergency Mesh Drill',
        message: 'Authorized offline BLE mesh disaster test signal. Sound alarm and local acknowledgement verified.',
        severity: EmergencySeverity.warning,
        category: EmergencyCategory.weather,
        scope: EmergencyScope.hostel,
        duration: const Duration(hours: 2),
        sendSiren: true,
        sirenPattern: EmergencySirenPattern.alertChime,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚨 Test Drill Flare broadcasted across offline BLE mesh!'),
            backgroundColor: Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Drill broadcast error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (isStudent) {
        widget.emergencyService.meshService.setLocalRole('student');
      }
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final userRole = widget.emergencyService.meshService.localRole;
    final isStudent = userRole == 'student';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0A0A) : const Color(0xFFFFF7F7),
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: AppColors.danger, size: 22),
            SizedBox(width: 8),
            Text(
              'Emergency Disaster Flare',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up_rounded, color: Color(0xFFEF4444)),
            tooltip: 'Test Siren Alarm & Haptics',
            onPressed: _testSiren,
          ),
          IconButton(
            icon: Icon(_showHistory ? Icons.alarm_on : Icons.history),
            tooltip: _showHistory ? 'View Active Alerts' : 'View Alert History',
            onPressed: () {
              setState(() => _showHistory = !_showHistory);
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_alert_rounded, color: AppColors.danger),
            tooltip: isStudent ? 'Trigger SOS Beacon' : 'Broadcast Emergency Flare',
            onPressed: () {
              if (isStudent) {
                _openStudentSosSheet(context);
              } else {
                _openEmergencyComposer(context);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Live Active Siren Banner
          _buildLiveSirenBanner(),

          // Cyber Control Banner: Role Switcher & Drill Actions
          _buildRoleAndDrillBanner(isDark, userRole),

          // Main Alerts List Stream
          Expanded(
            child: StreamBuilder<List<EmergencyAlert>>(
              stream: widget.emergencyService.watchActiveEmergencies(),
              builder: (context, snapshot) {
                final alerts = snapshot.data ?? [];

                if (_showHistory) {
                  return FutureBuilder<List<EmergencyAlert>>(
                    future: widget.emergencyService.getEmergencyHistory(),
                    builder: (context, histSnapshot) {
                      final historyAlerts = histSnapshot.data ?? [];
                      if (historyAlerts.isEmpty) {
                        return _buildEmptyState(
                          title: 'No Emergency History',
                          subtitle: 'No disaster alerts have been recorded on this mesh node.',
                          icon: Icons.history_toggle_off,
                        );
                      }
                      return _buildAlertsList(historyAlerts, isHistory: true, isDark: isDark);
                    },
                  );
                }

                if (alerts.isEmpty) {
                  return _buildEmptyActiveState(isDark, isStudent);
                }

                return _buildAlertsList(alerts, isHistory: false, isDark: isDark);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.danger,
        foregroundColor: Colors.white,
        icon: Icon(isStudent ? Icons.sos_rounded : Icons.broadcast_on_personal, size: isStudent ? 28 : 22),
        label: Text(
          isStudent ? 'TRIGGER SOS' : 'ISSUE FLARE',
          style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
        onPressed: () {
          if (isStudent) {
            _openStudentSosSheet(context);
          } else {
            _openEmergencyComposer(context);
          }
        },
      ),
    );
  }

  Widget _buildLiveSirenBanner() {
    return ValueListenableBuilder<EmergencyAlert?>(
      valueListenable: widget.emergencyService.notifier.activeSirenAlert,
      builder: (context, activeSiren, _) {
        if (activeSiren == null) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDC2626).withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.campaign_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SIREN ACTIVE · ${activeSiren.sirenPattern.label.toUpperCase()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                      ),
                    ),
                    Text(
                      activeSiren.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFB91C1C),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () async {
                  await widget.emergencyService.stopActiveSiren();
                },
                child: const Text(
                  'SILENCE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRoleAndDrillBanner(bool isDark, String currentRole) {
    final bannerBg = isDark ? const Color(0xFF1A0E0E) : const Color(0xFFFFECEC);
    final borderColor = AppColors.danger.withValues(alpha: 0.35);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'DUTY ROLE: ${currentRole.toUpperCase()}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: Color(0xFFEF4444),
                ),
              ),
              const Spacer(),
              // Test Drill Button
              InkWell(
                onTap: _triggerTestDrillFlare,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt_rounded, size: 14, color: AppColors.danger),
                      SizedBox(width: 4),
                      Text(
                        'TEST DRILL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildRoleChip('student', '🎓 Student SOS', currentRole),
                const SizedBox(width: 6),
                _buildRoleChip('warden', '🛡️ Warden', currentRole),
                const SizedBox(width: 6),
                _buildRoleChip('dean', '🏛️ Dean', currentRole),
                const SizedBox(width: 6),
                _buildRoleChip('admin', '⚡ Admin', currentRole),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChip(String role, String label, String currentRole) {
    final isSelected = currentRole == role;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500)),
      selected: isSelected,
      selectedColor: const Color(0xFFEF4444),
      backgroundColor: Colors.black12,
      labelStyle: TextStyle(color: isSelected ? Colors.white : null),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      onSelected: (val) {
        if (val) _onRoleChanged(role);
      },
    );
  }

  Widget _buildEmptyActiveState(bool isDark, bool isStudent) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1414) : const Color(0xFFFFEEEE),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.3), width: 2),
              ),
              child: const Icon(Icons.shield_outlined, size: 56, color: AppColors.success),
            ),
            const SizedBox(height: 18),
            const Text(
              'All Clear · No Active Alerts',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'CampusOS mesh monitoring active. No emergency flares in effect.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            // Student SOS Distress Panel
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF220D0D) : const Color(0xFFFFE5E5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
              ),
              child: Column(
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'PERSONAL SOS BEACON',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.danger, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Zero-internet offline emergency distress. In an immediate crisis (Medical, Fire, Threat), trigger SOS to alert nearby nodes across the mesh.',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.sos_rounded, size: 24),
                      label: const Text('OPEN SOS DISTRESS PANEL', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => _openStudentSosSheet(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppColors.success),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsList(List<EmergencyAlert> alerts, {required bool isHistory, required bool isDark}) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: alerts.length,
      itemBuilder: (context, index) {
        final alert = alerts[index];
        return _buildAlertCard(alert, isHistory: isHistory, isDark: isDark);
      },
    );
  }

  Widget _buildAlertCard(EmergencyAlert alert, {required bool isHistory, required bool isDark}) {
    final isCritical = alert.isCritical;
    final borderColor = isCritical
        ? AppColors.danger
        : (alert.severity == EmergencySeverity.warning ? AppColors.warning : AppColors.info);

    final cardBg = isDark
        ? (isCritical ? const Color(0xFF260A0A) : const Color(0xFF1F1206))
        : (isCritical ? const Color(0xFFFFEEEE) : const Color(0xFFFFF9E6));

    final isExpired = !alert.isActive();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isCritical ? 2.0 : 1.2),
        boxShadow: isCritical && !isExpired
            ? [
                BoxShadow(
                  color: AppColors.danger.withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Severity badge + Category + Role Badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    alert.severity.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  alert.category.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: borderColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '[${alert.issuerRole.toUpperCase()}]',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Title
            Text(
              alert.title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),

            const SizedBox(height: 6),

            // Message
            Text(
              alert.message,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 10),

            // Telemetry & Verification Footer
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Hop Telemetry
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    alert.hopDescription,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),

                // Scope
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Scope: ${alert.scope}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ),

                if (alert.hasSiren)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.volume_up_rounded, size: 12, color: AppColors.danger),
                        const SizedBox(width: 3),
                        Text(
                          'Siren: ${alert.sirenPattern.label}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Trust Badge
                if (alert.isTrusted)
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified, size: 14, color: AppColors.success),
                      SizedBox(width: 3),
                      Text(
                        'Verified Authority',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  )
                else
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wifi_tethering, size: 14, color: AppColors.warning),
                      SizedBox(width: 3),
                      Text(
                        'Offline Mesh Peer',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Action: Acknowledge Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isExpired
                      ? 'Status: Expired'
                      : (alert.isAcknowledged ? 'Status: Acknowledged ✓' : 'Status: Active'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: alert.isAcknowledged ? AppColors.success : Colors.grey,
                  ),
                ),
                if (!alert.isAcknowledged && !isExpired)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: borderColor,
                      side: BorderSide(color: borderColor),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('ACKNOWLEDGE'),
                    onPressed: () async {
                      await widget.emergencyService.acknowledgeEmergency(alert.alertId);
                      setState(() {});
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openStudentSosSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _StudentSosSheet(
        emergencyService: widget.emergencyService,
        onDispatched: () => setState(() {}),
      ),
    );
  }

  void _openEmergencyComposer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _EmergencyComposerSheet(
        emergencyService: widget.emergencyService,
        onDispatched: () => setState(() {}),
      ),
    );
  }
}

/// Student SOS Distress Beacon bottom sheet
class _StudentSosSheet extends StatefulWidget {
  final CampusMeshEmergencyService emergencyService;
  final VoidCallback onDispatched;

  const _StudentSosSheet({
    required this.emergencyService,
    required this.onDispatched,
  });

  @override
  State<_StudentSosSheet> createState() => _StudentSosSheetState();
}

class _StudentSosSheetState extends State<_StudentSosSheet> {
  EmergencyCategory _selectedCategory = EmergencyCategory.fire;
  EmergencySirenPattern _selectedSiren = EmergencySirenPattern.yelp;
  bool _sendSiren = true;
  final _detailsController = TextEditingController();
  bool _isBroadcasting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _handleBroadcastSos() async {
    setState(() {
      _isBroadcasting = true;
      _errorMessage = null;
    });

    try {
      await widget.emergencyService.sendStudentSosBeacon(
        category: _selectedCategory,
        details: _detailsController.text.trim(),
        scope: EmergencyScope.hostel,
        sendSiren: _sendSiren,
        sirenPattern: _sendSiren ? _selectedSiren : EmergencySirenPattern.none,
        duration: const Duration(hours: 4),
      );

      if (mounted) {
        Navigator.of(context).pop();
        widget.onDispatched();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _sendSiren
                  ? '🚨 SOS Distress Flare + ${_selectedSiren.label} siren sent to nearby mesh nodes!'
                  : '🚨 SOS Distress Flare broadcasted to all nearby mesh nodes!',
            ),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBroadcasting = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1010) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.sos_rounded, color: Color(0xFFEF4444), size: 30),
                ),
                const SizedBox(width: 12),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dispatch SOS Distress Beacon',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                    Text(
                      'Broadcasts critical alarm to all nearby hostel & campus phones',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger),
                ),
                child: Text(_errorMessage!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              ),

            const Text('Emergency Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildCategoryChip(EmergencyCategory.fire, '🔥 Fire / Smoke'),
                _buildCategoryChip(EmergencyCategory.security, '🚨 Physical Threat'),
                _buildCategoryChip(EmergencyCategory.hostel, '🏥 Medical Crisis'),
                _buildCategoryChip(EmergencyCategory.evacuation, '⚠️ Evacuate'),
                _buildCategoryChip(EmergencyCategory.other, '⚡ Hazard'),
              ],
            ),
            const SizedBox(height: 14),

            const Text('Location / Details (Optional, Max 180 chars)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            TextField(
              controller: _detailsController,
              maxLength: 180,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'e.g. Hostel Block B, 3rd floor. Trapped in room.',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Send Audible Siren to Nearby Phones',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Triggers loud alarm + vibration on nearby CampusOS nodes',
                style: TextStyle(fontSize: 11),
              ),
              activeThumbColor: const Color(0xFFEF4444),
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
                    label: Text(pat.label, style: const TextStyle(fontSize: 11)),
                    selected: selected,
                    selectedColor: const Color(0xFFEF4444),
                    labelStyle: TextStyle(color: selected ? Colors.white : null),
                    onSelected: (val) {
                      if (val) setState(() => _selectedSiren = pat);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 6),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isBroadcasting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.emergency_share_rounded),
                label: Text(
                  _isBroadcasting ? 'TRANSMITTING OVER BLE MESH...' : 'BROADCAST SOS BEACON NOW',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
                onPressed: _isBroadcasting ? null : _handleBroadcastSos,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(EmergencyCategory cat, String label) {
    final isSelected = _selectedCategory == cat;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500)),
      selected: isSelected,
      selectedColor: const Color(0xFFEF4444),
      labelStyle: TextStyle(color: isSelected ? Colors.white : null),
      onSelected: (val) {
        if (val) setState(() => _selectedCategory = cat);
      },
    );
  }
}

class _EmergencyComposerSheet extends StatefulWidget {
  final CampusMeshEmergencyService emergencyService;
  final VoidCallback onDispatched;

  const _EmergencyComposerSheet({
    required this.emergencyService,
    required this.onDispatched,
  });

  @override
  State<_EmergencyComposerSheet> createState() => _EmergencyComposerSheetState();
}

class _EmergencyComposerSheetState extends State<_EmergencyComposerSheet> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();

  EmergencySeverity _selectedSeverity = EmergencySeverity.critical;
  EmergencyCategory _selectedCategory = EmergencyCategory.cyclone;
  EmergencySirenPattern _selectedSirenPattern = EmergencySirenPattern.wail;
  bool _sendSiren = true;
  late String _selectedScope;
  bool _isBroadcasting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final role = widget.emergencyService.meshService.localRole;
    final availableScopes = EmergencyAuthorization.getAvailableScopesForRole(role: role);
    _selectedScope = availableScopes.isNotEmpty ? availableScopes.first : EmergencyScope.hostel;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _applyTemplate(String title, String message, EmergencyCategory cat, EmergencySeverity sev) {
    setState(() {
      _titleController.text = title;
      _messageController.text = message;
      _selectedCategory = cat;
      _selectedSeverity = sev;
      _sendSiren = sev != EmergencySeverity.advisory;
      _selectedSirenPattern = EmergencySirenPattern.defaultFor(
        severity: sev,
        category: cat,
      );
    });
  }

  Future<void> _handleBroadcast() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();

    if (title.isEmpty) {
      setState(() => _errorMessage = 'Please enter an alert title.');
      return;
    }
    if (message.isEmpty) {
      setState(() => _errorMessage = 'Please enter the advisory message.');
      return;
    }

    setState(() {
      _isBroadcasting = true;
      _errorMessage = null;
    });

    try {
      await widget.emergencyService.issueEmergencyAlert(
        title: title,
        message: message,
        severity: _selectedSeverity,
        category: _selectedCategory,
        scope: _selectedScope,
        duration: const Duration(hours: 4),
        sendSiren: _sendSiren,
        sirenPattern: _sendSiren ? _selectedSirenPattern : EmergencySirenPattern.none,
      );
      if (mounted) {
        Navigator.of(context).pop();
        widget.onDispatched();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _sendSiren
                  ? '🚨 Emergency Flare + ${_selectedSirenPattern.label} siren broadcasted to BLE mesh!'
                  : '🚨 Emergency Disaster Flare broadcasted to BLE mesh!',
            ),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isBroadcasting = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final role = widget.emergencyService.meshService.localRole;
    var availableScopes = EmergencyAuthorization.getAvailableScopesForRole(role: role);
    if (availableScopes.isEmpty) {
      availableScopes = const [EmergencyScope.hostel, EmergencyScope.campus, EmergencyScope.academic, EmergencyScope.administrative];
    }

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1414) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 24),
                SizedBox(width: 8),
                Text(
                  'Issue Emergency Disaster Flare',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Broadcasts verified alerts offline across local and relayed BLE nodes.',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(height: 12),

            // Quick templates
            const Text('Preset Templates', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ActionChip(
                    label: const Text('🌪️ Cyclone Warning', style: TextStyle(fontSize: 11)),
                    onPressed: () => _applyTemplate(
                      'Cyclone Dana Warning',
                      'Severe storm landfall expected within 2 hours. Move indoors to designated shelter.',
                      EmergencyCategory.cyclone,
                      EmergencySeverity.critical,
                    ),
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    label: const Text('🔥 Fire Evacuation', style: TextStyle(fontSize: 11)),
                    onPressed: () => _applyTemplate(
                      'Hostel Fire Evacuation',
                      'Smoke detected. Evacuate immediately via fire escape stairs to safe muster point.',
                      EmergencyCategory.fire,
                      EmergencySeverity.critical,
                    ),
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    label: const Text('⚡ Power Grid Failure', style: TextStyle(fontSize: 11)),
                    onPressed: () => _applyTemplate(
                      'Campus Power Outage',
                      'Main transformer grid failure. Backup generators active in critical blocks only.',
                      EmergencyCategory.power,
                      EmergencySeverity.warning,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.danger),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 12),
                ),
              ),

            // Severity selector
            const Text('Severity', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(
              children: EmergencySeverity.values.map((s) {
                final isSelected = s == _selectedSeverity;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      label: Text(s.label, style: const TextStyle(fontSize: 11)),
                      selected: isSelected,
                      selectedColor: s == EmergencySeverity.critical
                          ? AppColors.danger
                          : (s == EmergencySeverity.warning ? AppColors.warning : AppColors.info),
                      onSelected: (val) {
                        if (val) setState(() => _selectedSeverity = s);
                      },
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 12),

            // Category & Scope Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<EmergencyCategory>(
                        initialValue: _selectedCategory,
                        isDense: true,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        items: EmergencyCategory.values.map((c) {
                          return DropdownMenuItem(value: c, child: Text(c.label, style: const TextStyle(fontSize: 13)));
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedCategory = v);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Scope', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: availableScopes.contains(_selectedScope) ? _selectedScope : availableScopes.firstOrNull,
                        isDense: true,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        items: availableScopes.map((s) {
                          return DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)));
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _selectedScope = v);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Headline Title
            const Text('Headline Title (Max 48 chars)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              maxLength: 48,
              decoration: const InputDecoration(
                hintText: 'e.g. Cyclone Alert Level 3',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),

            const SizedBox(height: 8),

            // Message Body
            const Text('Advisory Message (Max 180 chars)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _messageController,
              maxLength: 180,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. Severe wind gusts. Evacuate to concrete shelter immediately.',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 8),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Send Audible Siren Alarm',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Sounds emergency siren on all receiving devices',
                style: TextStyle(fontSize: 11),
              ),
              activeThumbColor: AppColors.danger,
              value: _sendSiren,
              onChanged: (val) => setState(() {
                _sendSiren = val;
                if (val && _selectedSirenPattern == EmergencySirenPattern.none) {
                  _selectedSirenPattern = EmergencySirenPattern.wail;
                }
              }),
            ),

            if (_sendSiren) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: EmergencySirenPattern.values
                    .where((p) => p != EmergencySirenPattern.none)
                    .map((pat) {
                  final selected = _selectedSirenPattern == pat;
                  return ChoiceChip(
                    label: Text(pat.label, style: const TextStyle(fontSize: 11)),
                    selected: selected,
                    selectedColor: AppColors.danger,
                    labelStyle: TextStyle(color: selected ? Colors.white : null),
                    onSelected: (val) {
                      if (val) setState(() => _selectedSirenPattern = pat);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],

            const SizedBox(height: 12),

            // Send Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: _isBroadcasting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _isBroadcasting ? 'BROADCASTING OVER MESH...' : 'BROADCAST EMERGENCY FLARE',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: _isBroadcasting ? null : _handleBroadcast,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
