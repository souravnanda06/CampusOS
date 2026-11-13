import 'package:flutter/material.dart';

import '../../core/mesh/emergency/dispatcher/emergency_audit_event.dart';
import '../../core/mesh/emergency/dispatcher/emergency_dispatcher_service.dart';
import '../../core/mesh/emergency/dispatcher/emergency_incident.dart';
import '../../core/mesh/emergency/emergency_alert.dart';
import '../../core/theme/app_colors.dart';

/// Screen providing the institutional "Dean Emergency Mesh Dispatcher + Audit"
/// console for CampusOS.
///
/// Designed for high-stress crisis scenarios:
/// - Instant authority verification badge (Dean, Director, Admin, Warden, Faculty).
/// - Fast offline emergency creation and signed BLE mesh broadcast.
/// - Truthful propagation telemetry (real hops, observed relays, real ACKs).
/// - Signed incident cancellation and automatic expiration countdowns.
/// - Immutable append-only audit trail viewer.
class CampusMeshEmergencyDispatcherScreen extends StatefulWidget {
  final MeshEmergencyDispatcherService dispatcherService;

  const CampusMeshEmergencyDispatcherScreen({
    super.key,
    required this.dispatcherService,
  });

  @override
  State<CampusMeshEmergencyDispatcherScreen> createState() =>
      _CampusMeshEmergencyDispatcherScreenState();
}

class _CampusMeshEmergencyDispatcherScreenState
    extends State<CampusMeshEmergencyDispatcherScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Form state for creating a new incident
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  EmergencyCategory _selectedCategory = EmergencyCategory.cyclone;
  EmergencySeverity _selectedSeverity = EmergencySeverity.critical;
  EmergencySirenPattern _selectedSirenPattern = EmergencySirenPattern.wail;
  bool _sendSiren = true;
  late String _selectedScope;
  Duration _selectedDuration = const Duration(minutes: 30);
  bool _isDispatching = false;
  String? _selectedIncidentAuditId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    final availableScopes = widget.dispatcherService.getAvailableScopes();
    _selectedScope = availableScopes.isNotEmpty
        ? availableScopes.first
        : EmergencyScope.campus;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final userRole = widget.dispatcherService.localRole.toUpperCase();
    final isAuthorized = widget.dispatcherService.isAuthorizedToDispatch(_selectedScope) ||
        widget.dispatcherService.getAvailableScopes().isNotEmpty;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0A0A) : const Color(0xFFFFF7F7),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Emergency Dispatcher',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'Institutional Mesh Command & Audit',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.danger,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColors.danger,
          tabs: const [
            Tab(icon: Icon(Icons.emergency_share), text: 'Active'),
            Tab(icon: Icon(Icons.add_alert_rounded), text: 'Dispatch'),
            Tab(icon: Icon(Icons.history_edu), text: 'Audit & History'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildAuthorityBanner(userRole, isAuthorized),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildActiveIncidentsTab(isDark),
                _buildDispatchFormTab(isAuthorized, isDark),
                _buildAuditHistoryTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthorityBanner(String role, bool isAuthorized) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isAuthorized
          ? AppColors.success.withValues(alpha: 0.15)
          : AppColors.danger.withValues(alpha: 0.15),
      child: Row(
        children: [
          Icon(
            isAuthorized ? Icons.verified_user_rounded : Icons.gpp_bad_rounded,
            color: isAuthorized ? AppColors.success : AppColors.danger,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            isAuthorized ? 'AUTHORIZED · $role' : 'NOT AUTHORIZED · $role',
            style: TextStyle(
              color: isAuthorized ? AppColors.success : AppColors.danger,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Text(
            isAuthorized ? 'Offline BLE Mesh Ready' : 'Student Prohibited',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 1: Active Incidents
  // =========================================================================
  Widget _buildActiveIncidentsTab(bool isDark) {
    return StreamBuilder<List<EmergencyIncident>>(
      stream: widget.dispatcherService.watchActiveIncidents(),
      builder: (context, snapshot) {
        final incidents = snapshot.data ?? [];

        if (incidents.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shield_outlined, size: 64, color: AppColors.success),
                  const SizedBox(height: 16),
                  const Text(
                    'No Active Emergency Incidents',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'CampusOS mesh monitoring active. Tap "Dispatch" to issue an emergency instruction.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.add_alert_rounded),
                    label: const Text('New Emergency Dispatch'),
                    onPressed: () => _tabController.animateTo(1),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: incidents.length,
          itemBuilder: (context, index) {
            final incident = incidents[index];
            return _buildIncidentCard(incident, isDark);
          },
        );
      },
    );
  }

  Widget _buildIncidentCard(EmergencyIncident incident, bool isDark) {
    Color sevColor;
    switch (incident.severity) {
      case EmergencySeverity.critical:
        sevColor = AppColors.danger;
        break;
      case EmergencySeverity.warning:
        sevColor = Colors.orange;
        break;
      case EmergencySeverity.advisory:
        sevColor = Colors.blue;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: sevColor.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Severity Pill, Category, Scope
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: sevColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    incident.severity.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  incident.category.label.toUpperCase(),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                if (incident.hasSiren) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.volume_up_rounded, size: 11, color: AppColors.danger),
                        const SizedBox(width: 3),
                        Text(
                          incident.sirenPattern.label.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    incident.scope.toUpperCase(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Title & Message
            Text(
              incident.title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              incident.message,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const Divider(height: 24),

            // Telemetry & Authority Attribution
            Row(
              children: [
                const Icon(Icons.account_circle_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Issued by: ${incident.issuerRole.toUpperCase()} • VERIFIED',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                const Icon(Icons.timer_outlined, size: 16, color: AppColors.danger),
                const SizedBox(width: 4),
                Text(
                  incident.remainingTimeFormatted,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Truthful Propagation Telemetry Row
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1414) : const Color(0xFFF9F2F2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTelemetryItem(
                      icon: Icons.alt_route_rounded,
                      label: 'Propagation',
                      value: incident.hopTelemetryDescription,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTelemetryItem(
                      icon: Icons.done_all_rounded,
                      label: 'Telemetry',
                      value: incident.acknowledgementSummary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTelemetryItem(
                      icon: Icons.repeat_rounded,
                      label: 'Relays',
                      value: '${incident.relayCount} observed',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Action Buttons: Cancel & View Audit
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.receipt_long, size: 16),
                  label: const Text('Audit Trail', style: TextStyle(fontSize: 12)),
                  onPressed: () => _viewAuditTrail(incident.incidentId),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.cancel_rounded, size: 16),
                  label: const Text('Cancel Incident', style: TextStyle(fontSize: 12)),
                  onPressed: () => _confirmCancelIncident(incident),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTelemetryItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // =========================================================================
  // TAB 2: Dispatch Form
  // =========================================================================
  Widget _buildDispatchFormTab(bool isAuthorized, bool isDark) {
    if (!isAuthorized) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded, size: 64, color: AppColors.danger),
              const SizedBox(height: 16),
              const Text(
                'Authorization Required',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Current role "${widget.dispatcherService.localRole}" does not have privileges to dispatch emergency flares. Only Dean, Director, Admin, Warden, and authorized Faculty may issue incidents.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final availableScopes = widget.dispatcherService.getAvailableScopes();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ISSUE EMERGENCY INCIDENT',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.8),
            ),
            const SizedBox(height: 4),
            const Text(
              'Dispatches an authoritative, signed disaster flare across the offline BLE Mesh.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Category Picker
            const Text('Emergency Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: EmergencyCategory.values.map((cat) {
                final isSelected = _selectedCategory == cat;
                return ChoiceChip(
                  label: Text(cat.label),
                  selected: isSelected,
                  selectedColor: AppColors.danger.withValues(alpha: 0.2),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedCategory = cat);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Severity Selector
            const Text('Severity Level', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: EmergencySeverity.values.map((sev) {
                final isSelected = _selectedSeverity == sev;
                Color chipColor = sev == EmergencySeverity.critical
                    ? AppColors.danger
                    : (sev == EmergencySeverity.warning ? Colors.orange : Colors.blue);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Center(
                        child: Text(
                          sev.label,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isSelected ? Colors.white : chipColor,
                          ),
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: chipColor,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedSeverity = sev;
                            _sendSiren = sev != EmergencySeverity.advisory;
                            _selectedSirenPattern =
                                EmergencySirenPattern.defaultFor(
                              severity: sev,
                              category: _selectedCategory,
                            );
                          });
                        }
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Scope Selector
            const Text('Target Scope', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: availableScopes.contains(_selectedScope)
                  ? _selectedScope
                  : (availableScopes.isNotEmpty ? availableScopes.first : EmergencyScope.campus),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: availableScopes.map((scope) {
                return DropdownMenuItem<String>(
                  value: scope,
                  child: Text(scope.toUpperCase()),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedScope = val);
              },
            ),
            const SizedBox(height: 16),

            // Title Input (max 48)
            const Text('Headline Title (max 48 chars)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              maxLength: 48,
              decoration: const InputDecoration(
                hintText: 'e.g. Cyclone Warning · Severe Weather Alert',
                border: OutlineInputBorder(),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Title is required';
                if (val.length > 48) return 'Title exceeds 48 characters';
                return null;
              },
            ),
            const SizedBox(height: 8),

            // Message Input (max 180)
            const Text('Advisory Message (max 180 chars)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _messageController,
              maxLength: 180,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. Severe cyclonic storm approaching campus. Move indoors to designated shelters immediately.',
                border: OutlineInputBorder(),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Message is required';
                if (val.length > 180) return 'Message exceeds 180 characters';
                return null;
              },
            ),
            const SizedBox(height: 8),

            // Duration Picker
            const Text('Incident Expiration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _buildDurationChip(const Duration(minutes: 15), '15m'),
                _buildDurationChip(const Duration(minutes: 30), '30m'),
                _buildDurationChip(const Duration(hours: 1), '1 Hour'),
                _buildDurationChip(const Duration(hours: 2), '2 Hours'),
                _buildDurationChip(const Duration(hours: 4), '4 Hours'),
              ],
            ),
            const SizedBox(height: 16),

            // Audible Siren Dispatch Configuration
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1F1212) : const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Send Audible Emergency Siren',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    subtitle: const Text(
                      'Broadcasts alarm tone & continuous vibration to all receiving nodes',
                      style: TextStyle(fontSize: 11),
                    ),
                    activeThumbColor: AppColors.danger,
                    value: _sendSiren,
                    onChanged: (val) => setState(() {
                      _sendSiren = val;
                      if (val &&
                          _selectedSirenPattern == EmergencySirenPattern.none) {
                        _selectedSirenPattern = EmergencySirenPattern.wail;
                      }
                    }),
                  ),
                  if (_sendSiren) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: EmergencySirenPattern.values
                          .where((p) => p != EmergencySirenPattern.none)
                          .map((pat) {
                        final isSelected = _selectedSirenPattern == pat;
                        return ChoiceChip(
                          label: Text(pat.label, style: const TextStyle(fontSize: 11)),
                          selected: isSelected,
                          selectedColor: AppColors.danger,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : null,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedSirenPattern = pat);
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        icon: const Icon(Icons.volume_up_rounded, size: 16, color: AppColors.danger),
                        label: const Text(
                          'Preview Siren (4s)',
                          style: TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          widget.dispatcherService.emergencyService.notifier
                              .triggerSirenTest(
                            pattern: _selectedSirenPattern,
                            duration: const Duration(seconds: 4),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Dispatch Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: _isDispatching
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.broadcast_on_personal_rounded, size: 22),
                label: Text(
                  _isDispatching ? 'DISPATCHING TO MESH...' : 'DISPATCH CRITICAL EMERGENCY',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: _isDispatching ? null : _confirmAndDispatch,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationChip(Duration duration, String label) {
    final isSelected = _selectedDuration == duration;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _selectedDuration = duration);
      },
    );
  }

  // =========================================================================
  // TAB 3: Audit Trail & History
  // =========================================================================
  Widget _buildAuditHistoryTab(bool isDark) {
    return FutureBuilder<List<EmergencyIncident>>(
      future: widget.dispatcherService.getAllIncidents(),
      builder: (context, snapshot) {
        final allIncidents = snapshot.data ?? [];

        if (allIncidents.isEmpty) {
          return const Center(
            child: Text('No emergency incidents recorded in audit history.'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: allIncidents.length,
          itemBuilder: (context, index) {
            final inc = allIncidents[index];
            final isExpanded = _selectedIncidentAuditId == inc.incidentId;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                initiallyExpanded: isExpanded,
                onExpansionChanged: (expanded) {
                  setState(() {
                    _selectedIncidentAuditId = expanded ? inc.incidentId : null;
                  });
                },
                leading: Icon(
                  inc.isCancelled
                      ? Icons.cancel_outlined
                      : (inc.isExpired() ? Icons.alarm_off_outlined : Icons.emergency_rounded),
                  color: inc.isCancelled
                      ? Colors.grey
                      : (inc.isExpired() ? Colors.orange : AppColors.danger),
                ),
                title: Text(
                  inc.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                subtitle: Text(
                  '${inc.status.label.toUpperCase()} · ${inc.category.label} · ${inc.scope.toUpperCase()}',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: Text(
                  '${inc.createdAt.hour.toString().padLeft(2, '0')}:${inc.createdAt.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                children: [
                  _buildAuditEventsList(inc.incidentId, isDark),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAuditEventsList(String incidentId, bool isDark) {
    return FutureBuilder<List<EmergencyAuditEvent>>(
      future: widget.dispatcherService.getAuditEvents(incidentId),
      builder: (context, snapshot) {
        final events = snapshot.data ?? [];
        if (events.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Loading audit timeline...', style: TextStyle(fontSize: 12, color: Colors.grey)),
          );
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isDark ? Colors.black12 : Colors.grey.withValues(alpha: 0.05),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'IMMUTABLE AUDIT LOG',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              const SizedBox(height: 8),
              ...events.map((e) => _buildAuditEventRow(e)),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAuditEventRow(EmergencyAuditEvent event) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${event.timestamp.hour.toString().padLeft(2, '0')}:${event.timestamp.minute.toString().padLeft(2, '0')}:${event.timestamp.second.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Colors.grey),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              event.eventType.code,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${event.actorRole != null ? '[${event.actorRole}] ' : ''}${event.details.isNotEmpty ? event.details.toString() : ''}',
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // ACTIONS & CONFIRMATIONS
  // =========================================================================
  Future<void> _confirmAndDispatch() async {
    if (!_formKey.currentState!.validate()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            SizedBox(width: 8),
            Text('Confirm Dispatch'),
          ],
        ),
        content: Text(
          'Are you sure you want to broadcast this ${_selectedSeverity.label} emergency flare across the entire offline mesh for scope "${_selectedScope.toUpperCase()}"?\n\nTitle: ${_titleController.text.trim()}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DISPATCH NOW'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDispatching = true);

    try {
      await widget.dispatcherService.createAndDispatchIncident(
        title: _titleController.text.trim(),
        message: _messageController.text.trim(),
        category: _selectedCategory,
        severity: _selectedSeverity,
        scope: _selectedScope,
        duration: _selectedDuration,
        sendSiren: _sendSiren,
        sirenPattern: _sendSiren ? _selectedSirenPattern : EmergencySirenPattern.none,
      );

      _titleController.clear();
      _messageController.clear();
      _tabController.animateTo(0);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('✓ Emergency incident dispatched and broadcast over mesh.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Dispatch failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDispatching = false);
    }
  }

  Future<void> _confirmCancelIncident(EmergencyIncident incident) async {
    final reasonController = TextEditingController(text: 'Hazard resolved by authority');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Emergency Incident'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cancel "${incident.title}"? A signed cancellation packet will be broadcast across the mesh.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Cancellation Reason',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('CONFIRM CANCELLATION'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await widget.dispatcherService.cancelIncident(
        incident.incidentId,
        reason: reasonController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.blueGrey,
            content: Text('✓ Emergency incident cancelled and cancellation notice broadcast.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Cancellation failed: $e'),
          ),
        );
      }
    }
  }

  void _viewAuditTrail(String incidentId) {
    setState(() {
      _selectedIncidentAuditId = incidentId;
      _tabController.animateTo(2);
    });
  }
}
