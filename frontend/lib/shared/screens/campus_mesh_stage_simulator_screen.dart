import 'package:flutter/material.dart';

import '../../core/mesh/simulator/stage_simulation_controller.dart';
import '../../core/mesh/simulator/virtual_mesh_node.dart';
import '../../core/theme/app_colors.dart';

/// Interactive demonstration screen for the CampusOS Mesh Stage Simulator.
///
/// Prominently displays:
/// "STAGE SIMULATOR · SIMULATED NETWORK"
///
/// Features:
/// - Visual campus topology graph with real-time state changes.
/// - 8 interactive scenario runners (Emergency, Chat, AirDrop, Cancellation, Failure, Deduplication, Tamper, TTL).
/// - 60–90 second scripted M7 Demo player.
/// - Live event timeline log with cryptographic & hop telemetry.
class CampusMeshStageSimulatorScreen extends StatefulWidget {
  final StageSimulationController controller;

  const CampusMeshStageSimulatorScreen({
    super.key,
    required this.controller,
  });

  @override
  State<CampusMeshStageSimulatorScreen> createState() =>
      _CampusMeshStageSimulatorScreenState();
}

class _CampusMeshStageSimulatorScreenState
    extends State<CampusMeshStageSimulatorScreen> {
  @override
  void initState() {
    super.initState();
    if (!widget.controller.isInitialized) {
      widget.controller.initializeTopology();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F1216) : const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Campus Mesh Stage Simulator',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              'BPUT PS07 Protocol Demonstration Engine',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset Stats',
            onPressed: () {
              widget.controller.resetStats();
              setState(() {});
            },
          ),
        ],
      ),
      body: StreamBuilder<List<VirtualMeshNode>>(
        stream: widget.controller.onNodesUpdate,
        initialData: widget.controller.virtualNodes,
        builder: (context, snapshot) {
          final nodes = snapshot.data ?? [];

          return Column(
            children: [
              _buildSimulationNoticeBanner(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Topology Canvas
                      _buildTopologyCard(nodes, isDark),
                      const SizedBox(height: 16),

                      // Scripted Demo Runner Card
                      _buildDemoRunnerCard(),
                      const SizedBox(height: 16),

                      // Interactive Scenario Triggers
                      _buildScenarioControlGrid(),
                      const SizedBox(height: 16),

                      // Live Event Timeline
                      _buildTimelineSection(isDark),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSimulationNoticeBanner() {
    return Container(
      width: double.infinity,
      color: Colors.amber.shade900,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: const Row(
        children: [
          Icon(Icons.developer_mode_rounded, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text(
            'STAGE SIMULATOR · SIMULATED NETWORK',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.8,
            ),
          ),
          Spacer(),
          Text(
            'REAL PROTOCOL ENGINE',
            style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTopologyCard(List<VirtualMeshNode> nodes, bool isDark) {
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
                const Icon(Icons.hub_outlined, size: 20, color: AppColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'CAMPUS MESH TOPOLOGY',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${nodes.length} Virtual Nodes',
                    style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              height: 240,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF15191E) : const Color(0xFFE9EDF2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: [
                  CustomPaint(
                    size: const Size(double.infinity, 240),
                    painter: _TopologyLinkPainter(controller: widget.controller),
                  ),
                  ...nodes.map((node) => _buildNodeWidget(node)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNodeWidget(VirtualMeshNode node) {
    Color roleColor;
    switch (node.role.toLowerCase()) {
      case 'dean':
        roleColor = AppColors.danger;
        break;
      case 'warden':
        roleColor = Colors.orange;
        break;
      case 'admin':
        roleColor = Colors.purple;
        break;
      default:
        roleColor = Colors.teal;
    }

    if (!node.isOnline) {
      roleColor = Colors.grey;
    }

    return Positioned(
      left: node.position.x - 45,
      top: node.position.y - 30,
      child: GestureDetector(
        onTap: () {
          setState(() {
            node.isOnline = !node.isOnline;
            node.statusMessage = node.isOnline ? 'Online · Ready' : 'Manually Toggled Offline';
          });
        },
        child: Container(
          width: 90,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: roleColor.withValues(alpha: 0.15),
            border: Border.all(color: roleColor, width: 2),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              if (node.isOnline)
                BoxShadow(
                  color: roleColor.withValues(alpha: 0.2),
                  blurRadius: 6,
                ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                node.isOnline ? Icons.router_rounded : Icons.signal_wifi_off_rounded,
                size: 18,
                color: roleColor,
              ),
              const SizedBox(height: 2),
              Text(
                node.displayName.split(' ').first,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: roleColor,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                node.isOnline ? node.role.toUpperCase() : 'OFFLINE',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: node.isOnline ? Colors.grey : Colors.red,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDemoRunnerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade900, Colors.indigo.shade800],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.play_circle_filled_rounded, color: Colors.white, size: 40),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '60s M7 HACKATHON DEMO RUNNER',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  'Automated sequence: Blackout → Emergency → Hops → Cancel → Chat → AirDrop → Audit.',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.indigo.shade900,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: widget.controller.isRunningScenario
                ? null
                : () async {
                    await widget.controller.runScriptedDemo();
                    setState(() {});
                  },
            child: const Text('LAUNCH DEMO', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioControlGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PROTOCOL SCENARIOS',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildScenarioButton(
              icon: Icons.warning_amber_rounded,
              label: '1. Emergency Flare',
              color: AppColors.danger,
              onPressed: () => widget.controller.runEmergencyPropagationScenario(),
            ),
            _buildScenarioButton(
              icon: Icons.chat_bubble_outline_rounded,
              label: '2. Mesh Chat',
              color: Colors.teal,
              onPressed: () => widget.controller.runMeshChatScenario(),
            ),
            _buildScenarioButton(
              icon: Icons.airplanemode_active_rounded,
              label: '3. AirDrop Transfer',
              color: Colors.blue,
              onPressed: () => widget.controller.runAirDropScenario(),
            ),
            _buildScenarioButton(
              icon: Icons.cancel_outlined,
              label: '4. Signed Cancel',
              color: Colors.orange,
              onPressed: () => widget.controller.runEmergencyCancellationScenario(),
            ),
            _buildScenarioButton(
              icon: Icons.link_off_rounded,
              label: '5. Node Failure',
              color: Colors.blueGrey,
              onPressed: () => widget.controller.runNodeFailureScenario(),
            ),
            _buildScenarioButton(
              icon: Icons.content_copy_rounded,
              label: '6. Deduplication',
              color: Colors.purple,
              onPressed: () => widget.controller.runDuplicatePacketScenario(),
            ),
            _buildScenarioButton(
              icon: Icons.gpp_bad_rounded,
              label: '7. Tamper Detection',
              color: Colors.red.shade900,
              onPressed: () => widget.controller.runTamperedSignatureScenario(),
            ),
            _buildScenarioButton(
              icon: Icons.hourglass_bottom_rounded,
              label: '8. TTL Bounding',
              color: Colors.deepOrange,
              onPressed: () => widget.controller.runTtlExpirationScenario(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildScenarioButton({
    required IconData icon,
    required String label,
    required Color color,
    required Future<void> Function() onPressed,
  }) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withValues(alpha: 0.1),
        foregroundColor: color,
        elevation: 0,
        side: BorderSide(color: color.withValues(alpha: 0.4)),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      onPressed: widget.controller.isRunningScenario
          ? null
          : () async {
              await onPressed();
              setState(() {});
            },
    );
  }

  Widget _buildTimelineSection(bool isDark) {
    return StreamBuilder<SimulationEvent>(
      stream: widget.controller.onEvent,
      builder: (context, _) {
        final events = widget.controller.timeline;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history_edu_rounded, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'EVENT TIMELINE LOG',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.8),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    widget.controller.clearTimeline();
                    setState(() {});
                  },
                  child: const Text('Clear', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (events.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No simulation events yet. Launch a scenario above.', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: events.length,
                itemBuilder: (context, index) {
                  final event = events[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      dense: true,
                      leading: Icon(
                        event.isSuccess ? Icons.check_circle_outline : Icons.highlight_off,
                        color: event.isSuccess ? AppColors.success : AppColors.danger,
                        size: 20,
                      ),
                      title: Text(
                        event.summary,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      subtitle: Text(
                        '${event.timeFormatted} · ${event.details}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          event.scenario,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _TopologyLinkPainter extends CustomPainter {
  final StageSimulationController controller;

  _TopologyLinkPainter({required this.controller});

  @override
  void paint(Canvas canvas, Size size) {
    final activePaint = Paint()
      ..color = Colors.teal.withValues(alpha: 0.6)
      ..strokeWidth = 2.0;

    final disabledPaint = Paint()
      ..color = Colors.red.withValues(alpha: 0.5)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    for (final link in controller.medium.links) {
      final nodeA = controller.medium.nodes[link.nodeA];
      final nodeB = controller.medium.nodes[link.nodeB];

      if (nodeA != null && nodeB != null) {
        final isAvailable = link.isEnabled && nodeA.isOnline && nodeB.isOnline;
        final p1 = Offset(nodeA.position.x, nodeA.position.y);
        final p2 = Offset(nodeB.position.x, nodeB.position.y);

        canvas.drawLine(p1, p2, isAvailable ? activePaint : disabledPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
