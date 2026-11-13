import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';

import '../../core/mesh/airdrop/campus_mesh_airdrop_service.dart';
import '../../core/mesh/airdrop/mesh_airdrop_models.dart';
import '../../core/mesh/airdrop/transport/localsend_udp_discovery.dart';
import '../../core/mesh/campus_mesh_manager.dart';
import '../../core/mesh/campus_mesh_service.dart';
import '../../core/mesh/mesh_peer.dart';
import '../../core/theme/app_colors.dart';

/// CampusOS Mesh AirDrop Screen (Phase M5A & M5B).
///
/// Enables completely offline academic peer-to-peer file transfer over BLE Mesh
/// and high-speed LocalSend-compatible local Wi-Fi / Hotspot LAN streaming.
/// Displays nearby peers, institutional trust verification badges, streaming transfer progress,
/// real-time KB/s throughput, and end-to-end SHA-256 cryptographic verification results.
class CampusMeshAirDropScreen extends StatefulWidget {
  final CampusMeshAirDropService airdropService;

  const CampusMeshAirDropScreen({
    super.key,
    required this.airdropService,
  });

  @override
  State<CampusMeshAirDropScreen> createState() => _CampusMeshAirDropScreenState();
}

class _CampusMeshAirDropScreenState extends State<CampusMeshAirDropScreen>
    with SingleTickerProviderStateMixin {
  String? _selectedPeerDeviceId;
  File? _selectedFile;
  String _selectedFileName = 'DBMS_Unit_3_Notes.pdf';
  int _selectedFileSize = 842 * 1024; // 842 KB
  MeshTransportType? _selectedTransport;
  bool _isOffering = false;

  late final ConfettiController _confettiController;
  late final AnimationController _radarAnimController;

  StreamSubscription<List<MeshPeer>>? _blePeersSub;
  StreamSubscription<List<LocalSendPeer>>? _wifiPeersSub;
  StreamSubscription<MeshFileTransferSession>? _incomingOfferSub;
  Timer? _periodicRefreshTimer;

  List<MeshPeer> _blePeers = [];
  List<LocalSendPeer> _wifiPeers = [];
  final Set<String> _promptedOfferIds = {};

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _radarAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    // Ensure services and LocalSend UDP discovery are active
    widget.airdropService.initialize();
    CampusMeshManager.instance.startMesh();

    // Listen to live peer updates
    _blePeers = _mesh.peerRegistry.activePeers;
    _blePeersSub = _mesh.peerUpdates.listen((peers) {
      if (mounted) setState(() => _blePeers = peers);
    });

    final udp = widget.airdropService.udpDiscovery;
    if (udp != null) {
      _wifiPeers = udp.activePeers;
      _wifiPeersSub = udp.peersStream.listen((peers) {
        if (mounted) setState(() => _wifiPeers = peers);
      });
    }

    // High-priority modal prompt for incoming file offers (Apple AirDrop style)
    _incomingOfferSub = widget.airdropService.incomingOffers.listen((offer) {
      if (!mounted) return;
      if (!_promptedOfferIds.contains(offer.fileId)) {
        _promptedOfferIds.add(offer.fileId);
        _showIncomingAirDropModal(offer);
      }
    });

    // Periodic UI tick to refresh throughput, discovery lists, and transfer status
    _periodicRefreshTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        final currentUdp = widget.airdropService.udpDiscovery;
        if (currentUdp != null && currentUdp.activePeers.length != _wifiPeers.length) {
          setState(() {
            _wifiPeers = currentUdp.activePeers;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _radarAnimController.dispose();
    _blePeersSub?.cancel();
    _wifiPeersSub?.cancel();
    _incomingOfferSub?.cancel();
    _periodicRefreshTimer?.cancel();
    super.dispose();
  }

  CampusMeshAirDropService get _service => widget.airdropService;
  CampusMeshService get _mesh => _service.meshService;

  Future<void> _pickDeviceMedia() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickMedia();
      if (picked != null) {
        final file = File(picked.path);
        final length = await file.length();
        final name = picked.name.isNotEmpty
            ? picked.name
            : file.path.split(Platform.pathSeparator).last;
        setState(() {
          _selectedFile = file;
          _selectedFileName = name;
          _selectedFileSize = length;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Selected: $name (${(length / (1024 * 1024)).toStringAsFixed(2)} MB)',
              ),
              backgroundColor: AppColors.primary,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking media: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _pickDeviceDocument() async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: false,
        type: FileType.any,
      );

      if (result != null &&
          result.files.isNotEmpty &&
          result.files.first.path != null) {
        final path = result.files.first.path!;
        final file = File(path);
        final length = await file.length();
        final name = result.files.first.name;

        setState(() {
          _selectedFile = file;
          _selectedFileName = name;
          _selectedFileSize = length;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Selected: $name (${(length / (1024 * 1024)).toStringAsFixed(2)} MB)',
              ),
              backgroundColor: AppColors.primary,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }
    } catch (e) {
      debugPrint('Native file picker error, falling back to preset sheet: $e');
    }

    if (!mounted) return;
    _openAcademicPresetsSheet();
  }

  void _openAcademicPresetsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AcademicDocumentPresetsSheet(
        onPresetSelected: (File file, String name, int size) {
          setState(() {
            _selectedFile = file;
            _selectedFileName = name;
            _selectedFileSize = size;
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _handleSendOffer() async {
    if (_isOffering) return;
    setState(() => _isOffering = true);

    try {
      File fileToSend = _selectedFile ??
          await _createSampleAcademicFile(_selectedFileName, _selectedFileSize);

      final lowerName = _selectedFileName.toLowerCase();
      final mime = lowerName.endsWith('.zip')
          ? 'application/zip'
          : lowerName.endsWith('.mp4') || lowerName.endsWith('.mkv')
              ? 'video/mp4'
              : lowerName.endsWith('.png')
                  ? 'image/png'
                  : lowerName.endsWith('.jpg') || lowerName.endsWith('.jpeg')
                      ? 'image/jpeg'
                      : lowerName.endsWith('.docx')
                          ? 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
                          : 'application/pdf';

      await _service.sendFileOffer(
        file: fileToSend,
        targetDeviceId: _selectedPeerDeviceId,
        mimeType: mime,
        preferredTransport: _selectedTransport,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'File offer broadcasted: $_selectedFileName',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to offer file: $e')),
              ],
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isOffering = false);
      }
    }
  }

  Future<File> _createSampleAcademicFile(String name, int sizeBytes) async {
    final base = await _service.storage.getBaseDirectory();
    final sampleFile = File('${base.path}/$name');
    if (!await sampleFile.exists() || await sampleFile.length() != sizeBytes) {
      final raf = await sampleFile.open(mode: FileMode.write);
      final chunk = List<int>.generate(100, (i) => (i + 42) % 256);
      int written = 0;
      while (written < sizeBytes) {
        final toWrite = (written + 100 <= sizeBytes) ? 100 : (sizeBytes - written);
        await raf.writeFrom(chunk.sublist(0, toWrite));
        written += toWrite;
      }
      await raf.close();
    }
    return sampleFile;
  }

  void _showIncomingAirDropModal(MeshFileTransferSession offer) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = AppColors.isDark(ctx);
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.air_rounded, color: Colors.white, size: 32),
              ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
              const SizedBox(height: 12),
              Text(
                'CampusOS AirDrop',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '[${offer.peerRole.toUpperCase()}]',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    offer.peerDisplayName ?? offer.peerDeviceId,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  if (offer.isPeerVerified) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.verified, color: AppColors.success, size: 14),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceAltDark : AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      _iconForFilename(offer.filename),
                      color: AppColors.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            offer.filename,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            offer.fileSize >= 1024 * 1024
                                ? '${(offer.fileSize / (1024 * 1024)).toStringAsFixed(1)} MB · ${offer.transportType.label}'
                                : '${(offer.fileSize / 1024).toStringAsFixed(1)} KB · ${offer.transportType.label}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _service.rejectOffer(offer.fileId);
                        Navigator.pop(ctx);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _service.acceptOffer(offer.fileId);
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: const Text('Accept', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _iconForFilename(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
    if (lower.endsWith('.zip') || lower.endsWith('.tar') || lower.endsWith('.gz') || lower.endsWith('.rar')) {
      return Icons.folder_zip_rounded;
    }
    if (lower.endsWith('.mp4') || lower.endsWith('.mkv') || lower.endsWith('.mov')) {
      return Icons.video_file_rounded;
    }
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.webp')) {
      return Icons.image_rounded;
    }
    if (lower.endsWith('.docx') || lower.endsWith('.doc')) return Icons.description_rounded;
    return Icons.insert_drive_file_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Scaffold(
      backgroundColor: AppColors.bgOf(context),
      appBar: AppBar(
        title: const Text('Academic Mesh AirDrop'),
        elevation: 0,
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
        foregroundColor: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        actions: [
          StreamBuilder<MeshServiceState>(
            stream: _mesh.meshState,
            initialData: _mesh.currentState,
            builder: (context, snapshot) {
              final active = snapshot.data?.status == MeshStateStatus.active;
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: InkWell(
                  onTap: () {
                    if (active) {
                      CampusMeshManager.instance.stopMesh();
                    } else {
                      CampusMeshManager.instance.startMesh();
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: (active ? AppColors.success : AppColors.warning).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: (active ? AppColors.success : AppColors.warning).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: active ? AppColors.success : AppColors.warning,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          active ? 'Mesh Active' : 'Mesh Standby',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<List<MeshFileTransferSession>>(
            stream: _service.repository.transfersStream,
            builder: (context, snapshot) {
              return FutureBuilder<List<MeshFileTransferSession>>(
                future: _service.repository.getAllTransfers(),
                builder: (context, futureSnapshot) {
                  final allTransfers = snapshot.data ?? futureSnapshot.data ?? [];
                  final pendingOffers = allTransfers
                      .where((t) =>
                          t.direction == MeshTransferDirection.incoming &&
                          t.state == MeshFileTransferState.offered)
                      .toList();
                  final activeTransfers = allTransfers
                      .where((t) =>
                          !t.state.isTerminal && t.state != MeshFileTransferState.offered)
                      .toList();
                  final completedTransfers = allTransfers
                      .where((t) => t.state == MeshFileTransferState.completed)
                      .toList();
                  final failedTransfers = allTransfers
                      .where((t) =>
                          t.state == MeshFileTransferState.integrityFailure ||
                          t.state == MeshFileTransferState.failed)
                      .toList();

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: [
                      _buildIdentityHeader(context),
                      const SizedBox(height: 14),
                      _buildRadarScannerHero(context),
                      const SizedBox(height: 14),
                      if (pendingOffers.isNotEmpty) ...[
                        _buildSectionHeader('INCOMING FILE OFFERS', pendingOffers.length),
                        const SizedBox(height: 8),
                        ...pendingOffers.map((offer) => _buildIncomingOfferCard(context, offer)),
                        const SizedBox(height: 16),
                      ],
                      _buildSendAcademicFileCard(context),
                      const SizedBox(height: 16),
                      if (activeTransfers.isNotEmpty) ...[
                        _buildSectionHeader('ACTIVE TRANSFERS', activeTransfers.length),
                        const SizedBox(height: 8),
                        ...activeTransfers.map((t) => _buildActiveTransferCard(context, t)),
                        const SizedBox(height: 16),
                      ],
                      if (completedTransfers.isNotEmpty) ...[
                        _buildSectionHeader('COMPLETED TRANSFERS', completedTransfers.length),
                        const SizedBox(height: 8),
                        ...completedTransfers.map((t) => _buildCompletedTransferCard(context, t)),
                        const SizedBox(height: 16),
                      ],
                      if (failedTransfers.isNotEmpty) ...[
                        _buildSectionHeader('FAILED / INTEGRITY ALERTS', failedTransfers.length),
                        const SizedBox(height: 8),
                        ...failedTransfers.map((t) => _buildFailedTransferCard(context, t)),
                      ],
                      const SizedBox(height: 40),
                    ],
                  );
                },
              );
            },
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                AppColors.primary,
                AppColors.success,
                Colors.amber,
                Colors.blueAccent,
                Colors.purpleAccent,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityHeader(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final role = _mesh.localRole.toUpperCase();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.school_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        role,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, color: AppColors.success, size: 14),
                    const SizedBox(width: 2),
                    const Text(
                      'Verified Identity',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Local Node: ${_mesh.localDeviceId}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarScannerHero(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final totalPeers = _wifiPeers.length + _blePeers.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFEFF6FF), const Color(0xFFDBEAFE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          // Animated Radar Pulse
          Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _radarAnimController,
                builder: (context, child) {
                  final val = _radarAnimController.value;
                  return Container(
                    width: 54 + (val * 18),
                    height: 54 + (val * 18),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: (1.0 - val) * 0.6),
                        width: 2,
                      ),
                    ),
                  );
                },
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.wifi_tethering_rounded, color: Colors.white, size: 24),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Nearby Peer Radar',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$totalPeers Found',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Zero-Cloud Wi-Fi LAN & BLE Mesh scanning active',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.wifi, size: 13, color: AppColors.success),
                    const SizedBox(width: 4),
                    Text(
                      '${_wifiPeers.length} Wi-Fi (50 MB/s)',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.success),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.bluetooth, size: 13, color: AppColors.info),
                    const SizedBox(width: 4),
                    Text(
                      '${_blePeers.length} BLE Mesh',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.info),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIncomingOfferCard(BuildContext context, MeshFileTransferSession offer) {
    final isDark = AppColors.isDark(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
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
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.description, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '[${offer.peerRole.toUpperCase()}]',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: offer.isHighSpeed
                                ? AppColors.info.withValues(alpha: 0.15)
                                : AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            offer.transportType.label,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: offer.isHighSpeed ? AppColors.info : AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (offer.isPeerVerified) ...[
                          const Icon(Icons.verified, color: AppColors.success, size: 13),
                          const SizedBox(width: 2),
                          const Text(
                            'Verified ✓',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      offer.peerDisplayName ?? offer.peerDeviceId,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            offer.filename,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            offer.fileSize >= 1024 * 1024
                ? '${(offer.fileSize / (1024 * 1024)).toStringAsFixed(1)} MB · ${offer.hopDescription}'
                : '${(offer.fileSize / 1024).toStringAsFixed(1)} KB · ${offer.totalChunks} chunks · ${offer.hopDescription}',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            children: [
              Icon(Icons.shield_outlined, size: 12, color: AppColors.textSecondary),
              SizedBox(width: 4),
              Text(
                'SHA-256 verified after transfer',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _service.rejectOffer(offer.fileId),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _service.acceptOffer(offer.fileId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSendAcademicFileCard(BuildContext context) {
    final isDark = AppColors.isDark(context);
    final blePeers = _blePeers;
    final wifiPeers = _wifiPeers;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.share_rounded, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Send Academic File (<= 2 MB)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Hybrid BLE Mesh + LocalSend Wi-Fi LAN (50 MB/s)',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // File Picker Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDeviceDocument,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.folder_open_rounded, size: 18, color: AppColors.primary),
                  label: const Text('Browse Files', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDeviceMedia,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.perm_media_rounded, size: 18, color: AppColors.primary),
                  label: const Text('Pick Media', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Selected File Preview Card
          if (_selectedFile != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(_iconForFilename(_selectedFileName), color: AppColors.primary, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedFileName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Size: ${(_selectedFileSize / 1024).toStringAsFixed(1)} KB · Real Device File',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      setState(() {
                        _selectedFile = null;
                        _selectedFileName = 'DBMS_Unit_3_Notes.pdf';
                        _selectedFileSize = 842 * 1024;
                      });
                    },
                  ),
                ],
              ),
            )
          else ...[
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Select Academic Document',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              initialValue: _selectedFileName,
              items: const [
                DropdownMenuItem(
                  value: 'DBMS_Unit_3_Notes.pdf',
                  child: Text('DBMS Unit-3 Notes.pdf (842 KB)'),
                ),
                DropdownMenuItem(
                  value: 'Lab_Manual_CS204.pdf',
                  child: Text('CS204 Lab Manual.pdf (1.2 MB)'),
                ),
                DropdownMenuItem(
                  value: 'Lecture_Unit_4.zip',
                  child: Text('Lecture Unit-4.zip (18.4 MB)'),
                ),
                DropdownMenuItem(
                  value: 'Engineering_Dataset_CS502.zip',
                  child: Text('Dataset CS502.zip (10.5 MB)'),
                ),
                DropdownMenuItem(
                  value: 'Syllabus_BPUT_2026.pdf',
                  child: Text('BPUT 2026 Syllabus.pdf (310 KB)'),
                ),
                DropdownMenuItem(
                  value: 'Timetable_Sem6.pdf',
                  child: Text('Timetable Sem-6.pdf (150 KB)'),
                ),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedFileName = val;
                    if (val.contains('842')) _selectedFileSize = 842 * 1024;
                    if (val.contains('1.2')) _selectedFileSize = 1200 * 1024;
                    if (val.contains('18.4')) _selectedFileSize = 18400 * 1024;
                    if (val.contains('10.5')) _selectedFileSize = 10500 * 1024;
                    if (val.contains('310')) _selectedFileSize = 310 * 1024;
                    if (val.contains('150')) _selectedFileSize = 150 * 1024;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
          ],

          DropdownButtonFormField<MeshTransportType?>(
            decoration: InputDecoration(
              labelText: 'Transfer Transport',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            initialValue: _selectedTransport,
            items: const [
              DropdownMenuItem(
                value: null,
                child: Text('Auto (Hybrid Wi-Fi / BLE)'),
              ),
              DropdownMenuItem(
                value: MeshTransportType.localWifi,
                child: Text('Local Wi-Fi (High-Speed P2P · 50 MB/s)'),
              ),
              DropdownMenuItem(
                value: MeshTransportType.bleMesh,
                child: Text('BLE Mesh (Low-Power <= 2 MB)'),
              ),
            ],
            onChanged: (val) => setState(() => _selectedTransport = val),
          ),
          const SizedBox(height: 12),

          // Discovered Peers Interactive Strip
          if (wifiPeers.isNotEmpty || blePeers.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Discovered Nearby Devices (Tap to Select):',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                Text(
                  '${wifiPeers.length + blePeers.length} online',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...wifiPeers.map((wp) {
                    final isSel = _selectedPeerDeviceId == wp.deviceId;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        avatar: const Icon(Icons.wifi, size: 14, color: AppColors.success),
                        label: Text(
                          '${wp.displayName} (Wi-Fi 50MB/s)',
                          style: TextStyle(fontSize: 11, color: isSel ? Colors.white : null),
                        ),
                        selected: isSel,
                        selectedColor: AppColors.primary,
                        onSelected: (val) {
                          setState(() {
                            _selectedPeerDeviceId = val ? wp.deviceId : null;
                            if (val) _selectedTransport = MeshTransportType.localWifi;
                          });
                        },
                      ),
                    );
                  }),
                  ...blePeers.map((bp) {
                    final isSel = _selectedPeerDeviceId == bp.deviceId;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        avatar: const Icon(Icons.bluetooth, size: 14, color: AppColors.info),
                        label: Text(
                          '${bp.deviceId} (BLE)',
                          style: TextStyle(fontSize: 11, color: isSel ? Colors.white : null),
                        ),
                        selected: isSel,
                        selectedColor: AppColors.primary,
                        onSelected: (val) {
                          setState(() {
                            _selectedPeerDeviceId = val ? bp.deviceId : null;
                          });
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          DropdownButtonFormField<String?>(
            decoration: InputDecoration(
              labelText: 'Target Mesh Peer',
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            initialValue: _selectedPeerDeviceId,
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All Nearby Peers (Broadcast)'),
              ),
              ...wifiPeers.map((LocalSendPeer wp) => DropdownMenuItem<String?>(
                    value: wp.deviceId,
                    child: Text('⚡ ${wp.displayName} · [WI-FI 50MB/S]'),
                  )),
              ...blePeers.map((MeshPeer p) => DropdownMenuItem<String?>(
                    value: p.deviceId,
                    child: Text('📡 ${p.deviceId} · [${p.role.toUpperCase()}]'),
                  )),
            ],
            onChanged: (val) => setState(() => _selectedPeerDeviceId = val),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isOffering ? null : _handleSendOffer,
              icon: _isOffering
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_isOffering ? 'Sending Offer...' : 'Send File Offer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveTransferCard(BuildContext context, MeshFileTransferSession transfer) {
    final isDark = AppColors.isDark(context);
    final isOutgoing = transfer.direction == MeshTransferDirection.outgoing;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isOutgoing ? Icons.arrow_circle_up_rounded : Icons.arrow_circle_down_rounded,
                color: isOutgoing ? AppColors.primary : AppColors.info,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  transfer.filename,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: transfer.isHighSpeed
                      ? AppColors.info.withValues(alpha: 0.15)
                      : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      transfer.isHighSpeed ? Icons.wifi : Icons.bluetooth,
                      size: 11,
                      color: transfer.isHighSpeed ? AppColors.info : AppColors.primary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      transfer.transportType.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: transfer.isHighSpeed ? AppColors.info : AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: transfer.state == MeshFileTransferState.fallback
                      ? AppColors.warning.withValues(alpha: 0.15)
                      : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  transfer.state.label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: transfer.state == MeshFileTransferState.fallback
                        ? AppColors.warning
                        : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: transfer.progress,
              backgroundColor: isDark ? AppColors.surfaceAltDark : AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                transfer.fileSize >= 1024 * 1024
                    ? '${(transfer.transferredBytes / (1024 * 1024)).toStringAsFixed(1)} MB / ${(transfer.fileSize / (1024 * 1024)).toStringAsFixed(1)} MB · ${(transfer.progress * 100).toInt()}%'
                    : '${(transfer.transferredBytes / 1024).toStringAsFixed(0)} KB / ${(transfer.fileSize / 1024).toStringAsFixed(0)} KB · ${(transfer.progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                ),
              ),
              Text(
                transfer.isHighSpeed
                    ? 'High-Speed'
                    : '${transfer.transferredChunks} / ${transfer.totalChunks} chunks',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${transfer.formattedSpeed} · ${transfer.hopDescription}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
              InkWell(
                onTap: () => _service.cancelTransfer(transfer.transferId),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedTransferCard(BuildContext context, MeshFileTransferSession transfer) {
    final isDark = AppColors.isDark(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.check_circle, color: AppColors.success, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transfer.filename,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: transfer.isHighSpeed
                            ? AppColors.info.withValues(alpha: 0.15)
                            : AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        transfer.transportType.label,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: transfer.isHighSpeed ? AppColors.info : AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      transfer.fileSize >= 1024 * 1024
                          ? '${(transfer.fileSize / (1024 * 1024)).toStringAsFixed(1)} MB'
                          : '${(transfer.fileSize / 1024).toStringAsFixed(1)} KB',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, size: 11, color: AppColors.success),
                    const SizedBox(width: 2),
                    const Text(
                      'SHA-256 Verified ✓',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _openCompletedFile(transfer),
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }

  void _openCompletedFile(MeshFileTransferSession transfer) async {
    final path = transfer.localFilePath;
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('File ready at: ${transfer.filename}')),
      );
      return;
    }

    final file = File(path);
    final exists = await file.exists();

    if (!mounted) return;

    final lower = transfer.filename.toLowerCase();
    final isImage = lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp');

    if (exists && isImage) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.file(file, fit: BoxFit.contain),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        transfer.filename,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    // Attempt system launch or show details sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = AppColors.isDark(ctx);
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_iconForFilename(transfer.filename), color: AppColors.primary, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      transfer.filename,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Location: $path', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 6),
              Text('SHA-256: ${transfer.sha256}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: path));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('File path copied to clipboard')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy Path'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        try {
                          final uri = Uri.file(path);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                          } else {
                            throw 'Cannot launch';
                          }
                        } catch (_) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('File stored at: $path')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Open in App'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFailedTransferCard(BuildContext context, MeshFileTransferSession transfer) {
    final isDark = AppColors.isDark(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.error, color: AppColors.danger, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transfer.filename,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  transfer.errorMessage ?? 'Integrity verification failed',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AcademicDocumentPresetsSheet extends StatefulWidget {
  final void Function(File file, String name, int size) onPresetSelected;

  const _AcademicDocumentPresetsSheet({
    required this.onPresetSelected,
  });

  @override
  State<_AcademicDocumentPresetsSheet> createState() => _AcademicDocumentPresetsSheetState();
}

class _AcademicDocumentPresetsSheetState extends State<_AcademicDocumentPresetsSheet> {
  bool _isGenerating = false;

  Future<void> _generateAndSelect({
    required String filename,
    required int sizeBytes,
  }) async {
    setState(() => _isGenerating = true);
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final targetFile = File('${docDir.path}/$filename');
      final raf = await targetFile.open(mode: FileMode.write);
      final chunk = List<int>.generate(1024, (i) => (i + 37) % 256);
      int written = 0;
      while (written < sizeBytes) {
        final toWrite = (written + 1024 <= sizeBytes) ? 1024 : (sizeBytes - written);
        await raf.writeFrom(chunk.sublist(0, toWrite));
        written += toWrite;
      }
      await raf.close();

      widget.onPresetSelected(targetFile, filename, sizeBytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to prepare payload: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Academic Document Payloads',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          Text(
            'Instant high-speed test datasets for BLE Mesh & LocalSend Wi-Fi',
            style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
          ),
          const SizedBox(height: 20),
          if (_isGenerating)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Preparing benchmark payload...'),
                  ],
                ),
              ),
            )
          else ...[
            _buildPresetTile(
              label: 'Semester Assignment (PDF)',
              sizeStr: '2 MB · BLE / Wi-Fi',
              bytes: 2 * 1024 * 1024,
              name: 'Semester_Assignment_2MB.pdf',
              icon: Icons.picture_as_pdf_rounded,
              color: Colors.redAccent,
            ),
            _buildPresetTile(
              label: 'Lab Project Codebase (ZIP)',
              sizeStr: '10 MB · High-Speed Wi-Fi',
              bytes: 10 * 1024 * 1024,
              name: 'Lab_Project_Codebase_10MB.zip',
              icon: Icons.folder_zip_rounded,
              color: Colors.amber,
            ),
            _buildPresetTile(
              label: 'Recorded Lecture (MP4)',
              sizeStr: '25 MB · High-Speed Wi-Fi',
              bytes: 25 * 1024 * 1024,
              name: 'Recorded_Lecture_25MB.mp4',
              icon: Icons.movie_outlined,
              color: Colors.blueAccent,
            ),
            _buildPresetTile(
              label: 'Research Dataset (ZIP)',
              sizeStr: '50 MB · High-Speed Wi-Fi',
              bytes: 50 * 1024 * 1024,
              name: 'Research_Dataset_50MB.zip',
              icon: Icons.storage_rounded,
              color: Colors.purpleAccent,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPresetTile({
    required String label,
    required String sizeStr,
    required int bytes,
    required String name,
    required IconData icon,
    required Color color,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
      subtitle: Text(sizeStr, style: const TextStyle(fontSize: 11)),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
      onTap: () => _generateAndSelect(filename: name, sizeBytes: bytes),
    );
  }
}
