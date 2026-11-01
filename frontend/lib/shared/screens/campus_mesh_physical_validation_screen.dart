import 'package:flutter/material.dart';

import '../../core/mesh/simulator/mesh_validation_exporter.dart';
import '../../core/mesh/simulator/physical_validation_harness.dart';
import '../../core/theme/app_colors.dart';

/// Screen providing the Physical Multi-Device Validation Console for CampusOS Mesh.
///
/// Prominently displays:
/// "PHYSICAL MESH TEST · NOT SIMULATION"
///
/// Features:
/// - Role configuration for real test devices (Source A, Relay B, Receiver C).
/// - Pre-flight checklist ensuring Bluetooth, Mesh, and cryptographic keys are ready.
/// - Safe controlled test execution tagged with "[M7 TEST EMERGENCY]".
/// - Real-time physical telemetry display (hops, latency, RSSI, signature verification).
/// - RFC 4180 CSV and JSON telemetry export.
class CampusMeshPhysicalValidationScreen extends StatefulWidget {
  final PhysicalValidationHarnessService harnessService;

  const CampusMeshPhysicalValidationScreen({
    super.key,
    required this.harnessService,
  });

  @override
  State<CampusMeshPhysicalValidationScreen> createState() =>
      _CampusMeshPhysicalValidationScreenState();
}

class _CampusMeshPhysicalValidationScreenState
    extends State<CampusMeshPhysicalValidationScreen> {
  final TextEditingController _messageController =
      TextEditingController(text: 'CampusOS physical mesh multi-hop test');
  PhysicalPreflightChecklist? _preflight;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    widget.harnessService.initializeListener();
    _refreshPreflight();
  }

  Future<void> _refreshPreflight() async {
    final result = await widget.harnessService.checkPreflight();
    if (mounted) setState(() => _preflight = result);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Physical Mesh Validation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('3+ Device Hardware Testing Console', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export Telemetry',
            onPressed: _showExportDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHardwareNoticeBanner(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRoleSelectorCard(),
                  const SizedBox(height: 16),
                  _buildPreflightChecklistCard(),
                  const SizedBox(height: 16),
                  _buildTestExecutionCard(),
                  const SizedBox(height: 16),
                  _buildTelemetryResultsSection(isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHardwareNoticeBanner() {
    return Container(
      width: double.infinity,
      color: Colors.green.shade800,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        children: [
          Icon(Icons.bluetooth_connected_rounded, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text(
            'PHYSICAL MESH TEST · NOT SIMULATION',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.8,
            ),
          ),
          Spacer(),
          Text(
            'HARDWARE VALIDATION',
            style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelectorCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ASSIGN DEVICE TEST ROLE',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8),
            ),
            const SizedBox(height: 4),
            const Text(
              'Configure whether this hardware unit originates, relays, or receives test packets.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              children: PhysicalTestRole.values.map((role) {
                final isSelected = widget.harnessService.currentRole == role;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Center(
                        child: Text(
                          role.name.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => widget.harnessService.currentRole = role);
                        }
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreflightChecklistCard() {
    final pf = _preflight;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.checklist_rounded, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text('HARDWARE PRE-FLIGHT CHECKLIST', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: _refreshPreflight,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildCheckItem('Bluetooth Hardware Available', pf?.isBluetoothAvailable ?? false),
            _buildCheckItem('CampusOS Mesh Service Active', pf?.isMeshActive ?? false),
            _buildCheckItem('Cryptographic Identity Certified', pf?.isCryptoAvailable ?? false),
            _buildCheckItem('Nearby BLE Peers Observed', pf?.hasPeersObserved ?? false, optional: true),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckItem(String label, bool isOk, {bool optional = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(
            isOk ? Icons.check_circle : (optional ? Icons.info_outline : Icons.cancel_outlined),
            size: 16,
            color: isOk ? AppColors.success : (optional ? Colors.amber : AppColors.danger),
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildTestExecutionCard() {
    final isSource = widget.harnessService.currentRole == PhysicalTestRole.source;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('CONTROLLED TEST BROADCAST', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            const Text(
              'SAFETY: Test broadcasts are marked [FIELD TEST] and will not trigger device sirens.',
              style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              enabled: isSource && !_isLoading,
              decoration: const InputDecoration(
                labelText: 'Test Payload Message',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSource ? AppColors.primary : Colors.grey,
                  foregroundColor: Colors.white,
                ),
                icon: _isLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.cell_tower_rounded),
                label: Text(
                  isSource ? 'EXECUTE PHYSICAL TEST BROADCAST' : 'LISTENING IN ${widget.harnessService.currentRole.name.toUpperCase()} MODE',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: isSource && !_isLoading ? _executeTest : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _executeTest() async {
    setState(() => _isLoading = true);
    try {
      await widget.harnessService.runSourceBroadcastTest(
        testType: PhysicalTestType.emergency,
        testMessage: _messageController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.success,
            content: Text('✓ Physical test packet broadcast across BLE mesh.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Physical broadcast error: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTelemetryResultsSection(bool isDark) {
    return StreamBuilder<PhysicalTestTelemetry>(
      stream: widget.harnessService.onTelemetry,
      builder: (context, _) {
        final last = widget.harnessService.lastTelemetry;

        if (last == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No physical telemetry recorded yet.', style: TextStyle(color: Colors.grey)),
            ),
          );
        }

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.analytics_outlined, color: AppColors.success),
                    const SizedBox(width: 8),
                    const Text('PHYSICAL TEST RESULT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: last.status == PhysicalTestStatus.pass ? AppColors.success : AppColors.danger,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        last.status.label,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _buildTelemetryRow('Test ID', last.testId),
                _buildTelemetryRow('Observed Hops', '${last.hopCount} hops'),
                _buildTelemetryRow('Signature Status', last.isSignatureValid ? 'VERIFIED (Ed25519)' : 'FAILED'),
                _buildTelemetryRow('End-to-End Latency', last.latencyMs != null ? '${last.latencyMs} ms' : 'N/A (Origin)'),
                _buildTelemetryRow('Transport', last.transportType),
                _buildTelemetryRow('Notes', last.notes),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTelemetryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Physical Telemetry'),
        content: const Text('Export physical multi-device test results to CSV or JSON format. No private keys are included.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final json = MeshValidationExporter.exportPhysicalTelemetryToJson(widget.harnessService.testHistory);
              _showDataPreviewDialog('Telemetry JSON', json);
            },
            child: const Text('EXPORT JSON'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final csv = MeshValidationExporter.exportPhysicalTelemetryToCsv(widget.harnessService.testHistory);
              _showDataPreviewDialog('Telemetry CSV', csv);
            },
            child: const Text('EXPORT CSV'),
          ),
        ],
      ),
    );
  }

  void _showDataPreviewDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: SingleChildScrollView(
            child: SelectableText(
              content,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CLOSE')),
        ],
      ),
    );
  }
}
