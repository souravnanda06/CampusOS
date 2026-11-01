import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/mesh/campus_mesh_manager.dart';
import 'campus_mesh_chat_screen.dart';
import 'campus_mesh_emergency_screen.dart';
import 'campus_mesh_airdrop_screen.dart';
import 'campus_mesh_emergency_dispatcher_screen.dart';
import 'campus_mesh_node_radar_screen.dart';
import 'campus_mesh_physical_validation_screen.dart';
import 'campus_mesh_stage_simulator_screen.dart';

/// Central CampusOS Mesh Network Hub (Phases M1 through M7).
///
/// Provides direct access to:
/// - M1/M2: Decentralized BLE Mesh Engine & Cryptographic Identity
/// - M3: Offline P2P Mesh Chat (Text & Compressed Image Transfer)
/// - M4: Disaster Flare Emergency Alerts
/// - M5A/M5B: Academic AirDrop & Hybrid File Transfer
/// - M6: Dean Emergency Dispatcher & Audit Trail
/// - M7: Live Node Radar, Physical Validation Harness, & Stage Simulator
class CampusMeshHubScreen extends StatefulWidget {
  const CampusMeshHubScreen({super.key});

  @override
  State<CampusMeshHubScreen> createState() => _CampusMeshHubScreenState();
}

class _CampusMeshHubScreenState extends State<CampusMeshHubScreen> {
  final CampusMeshManager _meshManager = CampusMeshManager.instance;
  bool _isToggling = false;

  @override
  void initState() {
    super.initState();
    _meshManager.addListener(_onMeshStateChanged);
    _autoStartMesh();
  }

  Future<void> _autoStartMesh() async {
    if (!_meshManager.isMeshRunning) {
      await _meshManager.startMesh();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _meshManager.removeListener(_onMeshStateChanged);
    super.dispose();
  }


  void _onMeshStateChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _toggleMesh() async {
    setState(() => _isToggling = true);
    if (_meshManager.isMeshRunning) {
      await _meshManager.stopMesh();
    } else {
      await _meshManager.startMesh();
    }
    if (mounted) setState(() => _isToggling = false);
  }

  void _copyNodeId(BuildContext context, String nodeId) {
    Clipboard.setData(ClipboardData(text: nodeId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
            const SizedBox(width: 8),
            Text('Mesh Node ID copied to clipboard', style: GoogleFonts.plusJakartaSans(fontSize: 13)),
          ],
        ),
        backgroundColor: const Color(0xFF1E2433),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isRunning = _meshManager.isMeshRunning;
    final peerCount = _meshManager.activePeerCount;

    final bgMain = isDark ? const Color(0xFF080B11) : const Color(0xFFF6F8FC);
    final cardBg = isDark ? const Color(0xFF111624) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1E2638) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bgMain,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0E131F) : Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.hub_rounded, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'CampusOS Mesh',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        'P2P CORE',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF818CF8),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Zero-Internet Decentralized BLE Relay Network',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: InkWell(
                onTap: _isToggling ? null : _toggleMesh,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isRunning
                        ? const Color(0xFF10B981).withValues(alpha: 0.12)
                        : (isDark ? const Color(0xFF19202E) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isRunning
                          ? const Color(0xFF10B981).withValues(alpha: 0.4)
                          : (isDark ? const Color(0xFF2C3549) : const Color(0xFFCBD5E1)),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isToggling)
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF6366F1)),
                        )
                      else ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isRunning ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                            shape: BoxShape.circle,
                            boxShadow: isRunning
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.5),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          isRunning ? 'Radio ON' : 'Standby',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isRunning ? const Color(0xFF10B981) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Live Telemetry Command Hero
            _buildCommandHero(isDark, isRunning, peerCount),
            const SizedBox(height: 18),

            // 2. M7 Stage Simulator Hackathon Showcase Banner
            _buildStageSimulatorHero(context),
            const SizedBox(height: 22),

            // 3. Section Title: Mesh Subsystems
            Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'DECENTRALIZED SUBSYSTEMS',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Subsystem Card: Chat (Highlighted with Rich Media Badge)
            _buildSubsystemCard(
              context: context,
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              title: 'Offline P2P Mesh Chat',
              description: 'Zero-cellular decentralized chat with automatic multi-hop packet routing and instant camera/gallery photo transfer.',
              icon: Icons.chat_bubble_outline_rounded,
              accentColor: const Color(0xFF3B82F6),
              badgeText: 'TEXT + PHOTOS',
              badgeColor: const Color(0xFF3B82F6),
              extraPill: 'Multi-Hop Relay',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CampusMeshChatScreen(
                      chatService: _meshManager.chatService,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Subsystem Card: Emergency Flare
            _buildSubsystemCard(
              context: context,
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              title: 'Emergency Disaster Flare',
              description: 'Authoritative crisis alerts signed with Ed25519 identity, broadcast across nearby peer hops with high priority.',
              icon: Icons.warning_amber_rounded,
              accentColor: const Color(0xFFEF4444),
              badgeText: 'CRISIS FLARE',
              badgeColor: const Color(0xFFEF4444),
              extraPill: 'SOS Beacon',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CampusMeshEmergencyScreen(
                      emergencyService: _meshManager.emergencyService,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Subsystem Card: Academic AirDrop
            _buildSubsystemCard(
              context: context,
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              title: 'Academic AirDrop',
              description: 'High-speed peer-to-peer course file transfer over BLE Mesh with optional local Wi-Fi acceleration and SHA-256 verification.',
              icon: Icons.file_download_outlined,
              accentColor: const Color(0xFF10B981),
              badgeText: 'HYBRID AIRDROP',
              badgeColor: const Color(0xFF10B981),
              extraPill: 'Wi-Fi Turbo',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CampusMeshAirDropScreen(
                      airdropService: _meshManager.airdropService,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Subsystem Card: Node Radar
            _buildSubsystemCard(
              context: context,
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              title: 'Live Node Radar',
              description: 'Concentric 360° circular sweep radar tracking nearby campus nodes, RSSI proximity, and institutional trust badges.',
              icon: Icons.radar_rounded,
              accentColor: const Color(0xFF8B5CF6),
              badgeText: 'NODE RADAR',
              badgeColor: const Color(0xFF8B5CF6),
              extraPill: '360° Sweep',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CampusMeshNodeRadarScreen(
                      radarService: _meshManager.radarService,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Subsystem Card: Physical Hardware Validation
            _buildSubsystemCard(
              context: context,
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              title: 'Physical Mesh Validation',
              description: 'Hardware testbed for multi-device relay topology (A → B → C) with honest packet metrics and RFC 4180 CSV export.',
              icon: Icons.science_outlined,
              accentColor: const Color(0xFFF59E0B),
              badgeText: 'HARDWARE TESTBED',
              badgeColor: const Color(0xFFF59E0B),
              extraPill: 'Telemetry Log',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CampusMeshPhysicalValidationScreen(
                      harnessService: _meshManager.physicalHarness,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Subsystem Card: Dean Emergency Dispatcher
            _buildSubsystemCard(
              context: context,
              isDark: isDark,
              cardBg: cardBg,
              borderColor: borderColor,
              title: 'Dean Emergency Dispatcher',
              description: 'Institutional crisis command console: certified incident creation, broadcast cancellation, and tamper-proof audit trails.',
              icon: Icons.security_rounded,
              accentColor: const Color(0xFFEC4899),
              badgeText: 'AUTHORITY CONSOLE',
              badgeColor: const Color(0xFFEC4899),
              extraPill: 'Audit Trail',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CampusMeshEmergencyDispatcherScreen(
                      dispatcherService: _meshManager.dispatcherService,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 22),

            // 4. Protocol Architecture Box
            _buildProtocolSpecsCard(isDark),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildCommandHero(bool isDark, bool isRunning, int peerCount) {
    final nodeId = _meshManager.localDeviceId;
    final displayNodeId = nodeId.length > 20
        ? '${nodeId.substring(0, 10)}...${nodeId.substring(nodeId.length - 8)}'
        : nodeId;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111726) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isRunning
              ? const Color(0xFF10B981).withValues(alpha: 0.35)
              : (isDark ? const Color(0xFF222C3F) : const Color(0xFFE2E8F0)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Status Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161E30) : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF222C3F) : const Color(0xFFE2E8F0),
                  width: 0.8,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: isRunning
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : Colors.grey.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isRunning ? Icons.wifi_tethering_rounded : Icons.wifi_tethering_off_rounded,
                        size: 16,
                        color: isRunning ? const Color(0xFF10B981) : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isRunning ? 'BLE MESH RELAY ACTIVE' : 'RADIO STANDBY',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isRunning ? const Color(0xFF10B981) : Colors.grey,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF222C3F) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bluetooth_audio_rounded, size: 13, color: Color(0xFF6366F1)),
                      const SizedBox(width: 5),
                      Text(
                        '$peerCount ${peerCount == 1 ? "Peer" : "Peers"} Nearby',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main Node Info Area
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LOCAL MESH IDENTITY',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () => _copyNodeId(context, nodeId),
                            borderRadius: BorderRadius.circular(6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  displayNodeId,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.copy_rounded,
                                  size: 13,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _meshManager.localRole.toUpperCase(),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Telemetry Quick Badges
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF090D15) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniMetric(
                        icon: Icons.shield_outlined,
                        color: const Color(0xFF10B981),
                        label: 'SECURITY',
                        value: 'Ed25519 Anchor',
                        isDark: isDark,
                      ),
                      Container(
                        height: 24,
                        width: 1,
                        color: isDark ? const Color(0xFF222C3F) : const Color(0xFFCBD5E1),
                      ),
                      _buildMiniMetric(
                        icon: Icons.alt_route_rounded,
                        color: const Color(0xFF6366F1),
                        label: 'ROUTING',
                        value: 'Loop-Guard Flooding',
                        isDark: isDark,
                      ),
                      Container(
                        height: 24,
                        width: 1,
                        color: isDark ? const Color(0xFF222C3F) : const Color(0xFFCBD5E1),
                      ),
                      _buildMiniMetric(
                        icon: Icons.bolt_rounded,
                        color: const Color(0xFFF59E0B),
                        label: 'HOP LIMIT',
                        value: 'TTL 7 (Max 16)',
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniMetric({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[200] : const Color(0xFF1E293B),
          ),
        ),
      ],
    );
  }

  Widget _buildStageSimulatorHero(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CampusMeshStageSimulatorScreen(
              controller: _meshManager.stageSimulatorController,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF3730A3), Color(0xFF5B21B6), Color(0xFF6D28D9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5B21B6).withValues(alpha: 0.4),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.hub_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          'TOPOLOGY LAB',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          'JUDGE DEMO',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Campus Topology Stage Simulator',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Interactive multi-node canvas, 8 real protocol stress scenarios, and automated 60s benchmark evaluation.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.85),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubsystemCard({
    required BuildContext context,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required String title,
    required String description,
    required IconData icon,
    required Color accentColor,
    required String badgeText,
    required Color badgeColor,
    required String extraPill,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: accentColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          extraPill,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: badgeColor.withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          badgeText,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: badgeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
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
                    description,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Icon(
                Icons.chevron_right_rounded,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProtocolSpecsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1420) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF1E283C) : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF6366F1)),
              const SizedBox(width: 8),
              Text(
                'PROTOCOL ARCHITECTURE SPECIFICATIONS',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSpecRow('Transport Layer', 'BLE 5 Extended Advertising + Multi-Frame GATT (64 KB)'),
          _buildSpecRow('Routing Strategy', 'Controlled Flooding · Loop-Guard · Suppressed Cooldown'),
          _buildSpecRow('Hop Boundary', 'TTL = 7 default hops (16 hard network ceiling)'),
          _buildSpecRow('Cryptographic Signatures', 'Ed25519 (64-byte payload signatures) · SHA-256 integrity'),
          _buildSpecRow('Trust Anchors', 'Pre-shared Institutional Passport Trust Bundle'),
          _buildSpecRow('Packet Deduplication', 'In-memory LRU cache (5-minute TTL suppression)'),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey[400],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

