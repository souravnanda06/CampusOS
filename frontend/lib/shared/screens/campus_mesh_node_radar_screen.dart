import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/mesh/simulator/mesh_node_radar.dart';
import '../../core/theme/app_colors.dart';

/// Screen providing the visual Campus Mesh Node Radar.
///
/// Features:
/// - Concentric circular radar visualizer plotting nearby peers by RSSI.
/// - Clear institutional trust badges (VERIFIED vs UNKNOWN UNVERIFIED).
/// - Truthful hop count and signal telemetry.
/// - Lightweight rendering optimized for resource-constrained Android devices.
class CampusMeshNodeRadarScreen extends StatefulWidget {
  final MeshNodeRadarService radarService;

  const CampusMeshNodeRadarScreen({
    super.key,
    required this.radarService,
  });

  @override
  State<CampusMeshNodeRadarScreen> createState() =>
      _CampusMeshNodeRadarScreenState();
}

class _CampusMeshNodeRadarScreenState extends State<CampusMeshNodeRadarScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _sweepAnimationController;

  @override
  void initState() {
    super.initState();
    _sweepAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    widget.radarService.startLiveRadar();
  }

  @override
  void dispose() {
    _sweepAnimationController.dispose();
    widget.radarService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C1014) : const Color(0xFFF2F5F8),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mesh Node Radar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Nearby BLE Mesh Peer Discovery', style: TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
      body: StreamBuilder<List<RadarNodeItem>>(
        stream: widget.radarService.onRadarNodes,
        initialData: widget.radarService.currentNodes,
        builder: (context, snapshot) {
          final nodes = snapshot.data ?? [];

          return Column(
            children: [
              // Radar Visualizer Canvas
              Container(
                margin: const EdgeInsets.all(16),
                height: 240,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF070B0E) : const Color(0xFFE4E9EF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
                ),
                child: AnimatedBuilder(
                  animation: _sweepAnimationController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _RadarSweepPainter(
                        sweepAngle: _sweepAnimationController.value * 2 * math.pi,
                        nodes: nodes,
                        isDark: isDark,
                      ),
                    );
                  },
                ),
              ),

              // Peer Count Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.radar_rounded, size: 18, color: Colors.teal),
                    const SizedBox(width: 8),
                    Text(
                      'OBSERVED NODES (${nodes.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.8),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.teal.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Scanning Active', style: TextStyle(fontSize: 10, color: Colors.teal, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),

              // Node List
              Expanded(
                child: nodes.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_rounded, size: 48, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('No BLE mesh peers observed nearby.', style: TextStyle(fontWeight: FontWeight.bold)),
                              SizedBox(height: 4),
                              Text('Ensure nearby devices have CampusOS Mesh enabled.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: nodes.length,
                        itemBuilder: (context, index) {
                          final node = nodes[index];
                          return _buildNodeCard(node, isDark);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNodeCard(RadarNodeItem node, bool isDark) {
    Color badgeColor = node.isTrusted ? Colors.teal : Colors.grey;
    if (node.role.toLowerCase() == 'dean' || node.role.toLowerCase() == 'admin') {
      badgeColor = AppColors.danger;
    } else if (node.role.toLowerCase() == 'warden') {
      badgeColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: badgeColor.withValues(alpha: 0.2),
              foregroundColor: badgeColor,
              child: Icon(node.isTrusted ? Icons.verified_user_rounded : Icons.device_unknown_rounded, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    node.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          node.verificationBadge,
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: badgeColor),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${node.hopCount} hops',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${node.rssi} dBm',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  node.signalLabel.split(' ').first,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RadarSweepPainter extends CustomPainter {
  final double sweepAngle;
  final List<RadarNodeItem> nodes;
  final bool isDark;

  _RadarSweepPainter({
    required this.sweepAngle,
    required this.nodes,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2 - 16;

    final circlePaint = Paint()
      ..color = Colors.teal.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw concentric radar rings
    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, maxRadius * (i / 3), circlePaint);
    }

    // Draw crosshairs
    canvas.drawLine(Offset(center.dx - maxRadius, center.dy), Offset(center.dx + maxRadius, center.dy), circlePaint);
    canvas.drawLine(Offset(center.dx, center.dy - maxRadius), Offset(center.dx, center.dy + maxRadius), circlePaint);

    // Draw sweeping radar beam
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: FractionalOffset.center,
        startAngle: sweepAngle - 0.4,
        endAngle: sweepAngle,
        colors: [Colors.transparent, Colors.teal.withValues(alpha: 0.35)],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, maxRadius, sweepPaint);

    // Plot nodes on radar display
    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final angle = (i * (2 * math.pi / math.max(nodes.length, 1))) + 0.3;
      final dist = maxRadius * node.radarRadiusFraction;

      final nodePos = Offset(
        center.dx + dist * math.cos(angle),
        center.dy + dist * math.sin(angle),
      );

      final dotPaint = Paint()
        ..color = node.isTrusted ? Colors.tealAccent : Colors.amber
        ..style = PaintingStyle.fill;

      canvas.drawCircle(nodePos, 5, dotPaint);

      final ringPaint = Paint()
        ..color = dotPaint.color.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(nodePos, 8, ringPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarSweepPainter oldDelegate) => true;
}
