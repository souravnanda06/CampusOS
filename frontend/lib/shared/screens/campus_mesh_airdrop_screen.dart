import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/mesh/airdrop/campus_mesh_airdrop_service.dart';
import '../../core/mesh/airdrop/mesh_airdrop_models.dart';
import '../../core/mesh/airdrop/transport/localsend_udp_discovery.dart';
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

class _CampusMeshAirDropScreenState extends State<CampusMeshAirDropScreen> {
  String? _selectedPeerDeviceId;
  File? _selectedFile;
  String _selectedFileName = 'DBMS_Unit_3_Notes.pdf';
  int _selectedFileSize = 842 * 1024; // 842 KB
  MeshTransportType? _selectedTransport;
  bool _isOffering = false;

  @override
  void initState() {
    super.initState();
    // Ensure services and LocalSend UDP discovery are active
    widget.airdropService.initialize();
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
        final name = picked.name.isNotEmpty ? picked.name : file.path.split(Platform.pathSeparator).last;
        setState(() {
          _selectedFile = file;
          _selectedFileName = name;
          _selectedFileSize = length;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Selected: $name (${(length / (1024 * 1024)).toStringAsFixed(2)} MB)'),
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
      final List<Directory> searchDirs = [];
      try {
        final appDoc = await getApplicationDocumentsDirectory();
        searchDirs.add(appDoc);
      } catch (_) {}

      try {
        final downloads = await getDownloadsDirectory();
        if (downloads != null) searchDirs.add(downloads);
      } catch (_) {}

      final List<File> discovered = [];
      for (final dir in searchDirs) {
        if (await dir.exists()) {
          try {
            final entities = dir.listSync(recursive: false);
            for (final entity in entities) {
              if (entity is File) discovered.add(entity);
            }
          } catch (_) {}
        }
      }

      if (!mounted) return;

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _DocumentPickerSheet(
          discoveredFiles: discovered,
          onFileSelected: (File file, String name, int size) {
            setState(() {
              _selectedFile = file;
              _selectedFileName = name;
              _selectedFileSize = size;
            });
            Navigator.pop(ctx);
          },
        ),
      );
    } catch (e) {
      debugPrint('Error picking document: $e');
    }
  }

  Future<void> _handleSendOffer() async {
    if (_isOffering) return;
    setState(() => _isOffering = true);

    try {
      File fileToSend = _selectedFile ?? await _createSampleAcademicFile(_selectedFileName, _selectedFileSize);

      final mime = _selectedFileName.endsWith('.zip')
          ? 'application/zip'
          : _selectedFileName.endsWith('.mp4')
              ? 'video/mp4'
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
            content: Text('File offer sent for $_selectedFileName'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to offer file: $e'),
            backgroundColor: AppColors.danger,
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
                child: Row(
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
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<MeshFileTransferSession>>(
        stream: _service.repository.transfersStream,
        builder: (context, snapshot) {
          return FutureBuilder<List<MeshFileTransferSession>>(
            future: _service.repository.getAllTransfers(),
            builder: (context, futureSnapshot) {
              final allTransfers = snapshot.data ?? futureSnapshot.data ?? [];
              final pendingOffers = allTransfers
                  .where((t) => t.direction == MeshTransferDirection.incoming && t.state == MeshFileTransferState.offered)
                  .toList();
              final activeTransfers = allTransfers
                  .where((t) => !t.state.isTerminal && t.state != MeshFileTransferState.offered)
                  .toList();
              final completedTransfers = allTransfers
                  .where((t) => t.state == MeshFileTransferState.completed)
                  .toList();
              final failedTransfers = allTransfers
                  .where((t) => t.state == MeshFileTransferState.integrityFailure || t.state == MeshFileTransferState.failed)
                  .toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildIdentityHeader(context),
                  const SizedBox(height: 16),
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
                ],
              );
            },
          );
        },
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.school, color: AppColors.primary, size: 24),
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
                    fontWeight: FontWeight.w500,
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.4),
          width: 1.5,
        ),
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
                  borderRadius: BorderRadius.circular(8),
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
    final blePeers = _mesh.peerRegistry.activePeers;
    final wifiPeers = _service.udpDiscovery?.activePeers ?? [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
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

          // File Picker Buttons
          Row(
            children: [
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
              const SizedBox(width: 8),
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
            ],
          ),
          const SizedBox(height: 12),

          // Selected File Preview
          if (_selectedFile != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.insert_drive_file_rounded, color: AppColors.primary, size: 28),
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

          // Discovered Peers Section
          if (wifiPeers.isNotEmpty || blePeers.isNotEmpty) ...[
            const Text(
              'Discovered Nearby Devices (Tap to Select):',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
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
                        label: Text('${wp.displayName} (Wi-Fi 50MB/s)', style: TextStyle(fontSize: 11, color: isSel ? Colors.white : null)),
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
                        label: Text('${bp.deviceId} (BLE)', style: TextStyle(fontSize: 11, color: isSel ? Colors.white : null)),
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
                  : const Icon(Icons.send),
              label: Text(_isOffering ? 'Sending Offer...' : 'Send File Offer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isOutgoing ? Icons.arrow_circle_up : Icons.arrow_circle_down,
                color: isOutgoing ? AppColors.primary : AppColors.info,
                size: 20,
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
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: transfer.progress,
              backgroundColor: isDark ? AppColors.surfaceAltDark : AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 6,
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
        borderRadius: BorderRadius.circular(10),
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
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('File ready at: ${transfer.localFilePath ?? transfer.filename}'),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ],
      ),
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

class _DocumentPickerSheet extends StatefulWidget {
  final List<File> discoveredFiles;
  final void Function(File file, String name, int size) onFileSelected;

  const _DocumentPickerSheet({
    required this.discoveredFiles,
    required this.onFileSelected,
  });

  @override
  State<_DocumentPickerSheet> createState() => _DocumentPickerSheetState();
}

class _DocumentPickerSheetState extends State<_DocumentPickerSheet> {
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

      widget.onFileSelected(targetFile, filename, sizeBytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate benchmark file: $e'),
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

  IconData _iconForExtension(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
    if (lower.endsWith('.zip') || lower.endsWith('.tar') || lower.endsWith('.gz')) {
      return Icons.folder_zip_rounded;
    }
    if (lower.endsWith('.mp4') || lower.endsWith('.mkv') || lower.endsWith('.mov')) {
      return Icons.video_file_rounded;
    }
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png')) {
      return Icons.image_rounded;
    }
    if (lower.endsWith('.docx') || lower.endsWith('.doc')) {
      return Icons.description_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Select Academic Document',
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
            'Device Documents & High-Speed Benchmark Datasets',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
          const SizedBox(height: 16),
          if (_isGenerating) ...[
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
            ),
          ] else ...[
            const Text(
              'INSTANT SPEED BENCHMARKS (LOCALSEND 50 MB/s)',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildBenchmarkChip(
                  label: '2 MB Assignment (PDF)',
                  bytes: 2 * 1024 * 1024,
                  name: 'Semester_Assignment_2MB.pdf',
                  icon: Icons.picture_as_pdf,
                ),
                _buildBenchmarkChip(
                  label: '10 MB Codebase (ZIP)',
                  bytes: 10 * 1024 * 1024,
                  name: 'Lab_Project_Codebase_10MB.zip',
                  icon: Icons.folder_zip,
                ),
                _buildBenchmarkChip(
                  label: '25 MB Lecture Video (MP4)',
                  bytes: 25 * 1024 * 1024,
                  name: 'Recorded_Lecture_25MB.mp4',
                  icon: Icons.movie_outlined,
                ),
                _buildBenchmarkChip(
                  label: '50 MB Research Dataset (ZIP)',
                  bytes: 50 * 1024 * 1024,
                  name: 'Research_Dataset_50MB.zip',
                  icon: Icons.storage_rounded,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'DISCOVERED DEVICE STORAGE FILES',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: widget.discoveredFiles.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open_rounded, size: 40, color: Colors.grey.withValues(alpha: 0.6)),
                            const SizedBox(height: 8),
                            Text(
                              'No documents found in local app directories',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Use one of the instant benchmark datasets above or Pick Media from your gallery.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11, color: Colors.grey.withValues(alpha: 0.8)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: widget.discoveredFiles.length,
                      itemBuilder: (ctx, idx) {
                        final file = widget.discoveredFiles[idx];
                        final filename = file.path.split(Platform.pathSeparator).last;
                        final size = file.lengthSync();
                        return ListTile(
                          leading: Icon(_iconForExtension(file.path), color: AppColors.primary),
                          title: Text(filename, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            size >= 1024 * 1024
                                ? '${(size / (1024 * 1024)).toStringAsFixed(2)} MB'
                                : '${(size / 1024).toStringAsFixed(1)} KB',
                          ),
                          onTap: () => widget.onFileSelected(file, filename, size),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBenchmarkChip({
    required String label,
    required int bytes,
    required String name,
    required IconData icon,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: AppColors.primary),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: () => _generateAndSelect(filename: name, sizeBytes: bytes),
    );
  }
}

