import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/mesh/campus_mesh_service.dart';
import '../../core/mesh/chat/mesh_chat_channel.dart';
import '../../core/mesh/chat/mesh_chat_message.dart';
import '../../core/mesh/chat/mesh_chat_service.dart';
import '../../core/theme/app_colors.dart';

/// CampusOS Mesh Chat Screen.
///
/// Provides a zero-internet, offline-first peer-to-peer messaging interface
/// communicating directly over Bluetooth Low Energy mesh relays.
class CampusMeshChatScreen extends StatefulWidget {
  final MeshChatService chatService;

  const CampusMeshChatScreen({
    super.key,
    required this.chatService,
  });

  @override
  State<CampusMeshChatScreen> createState() => _CampusMeshChatScreenState();
}

class _CampusMeshChatScreenState extends State<CampusMeshChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  late String _selectedChannelId;
  bool _isSending = false;
  Uint8List? _selectedImageBytes;
  String? _selectedImageBase64;

  @override
  void initState() {
    super.initState();
    _selectedChannelId = widget.chatService.channels.first.id;
    _initMeshRadio();
  }

  Future<void> _initMeshRadio() async {
    try {
      await widget.chatService.initialize();
      if (!widget.chatService.meshService.isRunning) {
        await widget.chatService.meshService.start();
      }
    } catch (e) {
      debugPrint('⚠️ [MESH_CHAT] Failed to start mesh radio: $e');
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 320,
        maxHeight: 320,
        imageQuality: 40,
      );
      if (pickedFile == null) return;
      Uint8List bytes = await pickedFile.readAsBytes();

      // Defensive budget protection: if file still exceeds 26 KB, resize further
      if (bytes.lengthInBytes > 26000) {
        try {
          final codec = await ui.instantiateImageCodec(
            bytes,
            targetWidth: 240,
            targetHeight: 240,
          );
          final frame = await codec.getNextFrame();
          final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null && byteData.lengthInBytes < bytes.lengthInBytes) {
            bytes = byteData.buffer.asUint8List();
          }
        } catch (_) {}
      }

      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageBase64 = base64Encode(bytes);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to select image: $e')),
              ],
            ),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showImageSourceSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF111726) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_photo_alternate_rounded, color: Color(0xFF6366F1), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Attach Photo to Mesh',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF3B82F6), size: 22),
                ),
                title: Text(
                  'Take Photo',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: Text(
                  'Capture camera picture · Auto-compressed for BLE mesh (~12 KB)',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: Colors.grey[500]),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 4),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: Color(0xFF10B981), size: 22),
                ),
                title: Text(
                  'Choose from Gallery',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: Text(
                  'Pick from existing photos · Instant offline transmission',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: Colors.grey[500]),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullScreenImage(String base64Str) {
    try {
      final bytes = base64Decode(base64Str);
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.black.withValues(alpha: 0.95),
          insetPadding: EdgeInsets.zero,
          child: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                panEnabled: true,
                minScale: 0.8,
                maxScale: 4.0,
                child: Center(
                  child: Image.memory(
                    bytes,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              Positioned(
                top: 40,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bluetooth_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Mesh Transfer · ${bytes.lengthInBytes ~/ 1024} KB',
                        style: GoogleFonts.jetBrainsMono(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 36,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('⚠️ [MESH_CHAT] Failed to decode full screen image: $e');
    }
  }

  Future<void> _handleSendMessage() async {
    final text = _textController.text.trim();
    final imageBase64 = _selectedImageBase64;
    if ((text.isEmpty && imageBase64 == null) || _isSending) return;

    final cachedImageBytes = _selectedImageBytes;
    final cachedImageBase64 = _selectedImageBase64;

    setState(() {
      _isSending = true;
      _selectedImageBytes = null;
      _selectedImageBase64 = null;
    });
    _textController.clear();

    try {
      if (!widget.chatService.meshService.isRunning) {
        await widget.chatService.meshService.start();
      }
      await widget.chatService.sendMessage(
        channelId: _selectedChannelId,
        text: text,
        imageBase64: imageBase64,
      );

      // Scroll to bottom
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 140,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      setState(() {
        _selectedImageBytes = cachedImageBytes;
        _selectedImageBase64 = cachedImageBase64;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to broadcast mesh message: $e'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF080B11) : const Color(0xFFF6F8FC);
    final surfaceColor = isDark ? const Color(0xFF0E131F) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: surfaceColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.chat_bubble_rounded, size: 16, color: Colors.white),
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
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'OFFLINE',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                StreamBuilder<MeshServiceState>(
                  stream: widget.chatService.meshService.meshState,
                  initialData: widget.chatService.meshService.currentState,
                  builder: (context, snapshot) {
                    final state = snapshot.data;
                    final isActive = state?.status == MeshStateStatus.active;
                    final statusText = isActive
                        ? '🟢 Offline Mesh Active'
                        : '🟡 ${state?.status.name.toUpperCase() ?? "CONNECTING"}';

                    return Text(
                      statusText,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: isActive ? const Color(0xFF10B981) : Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),

        actions: [
          StreamBuilder<List<dynamic>>(
            stream: widget.chatService.meshService.peerUpdates,
            initialData: widget.chatService.meshService.peerRegistry.activePeers,
            builder: (context, snapshot) {
              final count = snapshot.data?.length ?? 0;
              return Container(
                margin: const EdgeInsets.only(right: 14),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF19202E) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bluetooth_audio_rounded,
                      size: 13,
                      color: Color(0xFF6366F1),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '$count ${count == 1 ? "peer" : "peers"}',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF6366F1),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Channel Selector Bar
            _buildChannelSelector(isDark),

            // Messages List
            Expanded(
              child: _buildMessagesList(isDark),
            ),

            // Message Composer
            _buildComposer(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelSelector(bool isDark) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0E131F) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E283C) : const Color(0xFFE2E8F0),
            width: 0.8,
          ),
        ),
      ),
      child: StreamBuilder<List<MeshChatChannel>>(
        stream: widget.chatService.channelsStream,
        initialData: widget.chatService.channels,
        builder: (context, snapshot) {
          final channels = snapshot.data ?? MeshChatChannel.defaultChannels;

          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: channels.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final channel = channels[index];
              final isSelected = channel.id == _selectedChannelId;
              final isEmergency = channel.id == MeshChatChannel.emergency.id;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedChannelId = channel.id;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? (isEmergency
                            ? const LinearGradient(colors: [Color(0xFFDC2626), Color(0xFFB91C1C)])
                            : const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF4F46E5)]))
                        : null,
                    color: isSelected
                        ? null
                        : (isDark ? const Color(0xFF161C2A) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : (isDark ? const Color(0xFF222C3F) : const Color(0xFFCBD5E1)),
                      width: 0.8,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: (isEmergency ? const Color(0xFFDC2626) : const Color(0xFF6366F1))
                                  .withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getChannelIcon(channel.id),
                        size: 13,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        channel.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _getChannelIcon(String channelId) {
    if (channelId.contains('emergency')) return Icons.warning_amber_rounded;
    if (channelId.contains('study')) return Icons.menu_book_rounded;
    if (channelId.contains('hostel')) return Icons.home_rounded;
    if (channelId.contains('market')) return Icons.storefront_rounded;
    return Icons.tag_rounded;
  }

  Widget _buildMessagesList(bool isDark) {
    return StreamBuilder<List<MeshChatMessage>>(
      stream: widget.chatService.watchChannel(_selectedChannelId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)));
        }

        final messages = snapshot.data ?? [];

        if (messages.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF6366F1).withValues(alpha: 0.2),
                          Colors.transparent,
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF161E30) : const Color(0xFFEEF2F6),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.bluetooth_searching_rounded,
                          size: 28,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No messages in this mesh channel yet',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Broadcast a text message or share a photo with nearby offline peers over Bluetooth!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final msg = messages[index];
            return _buildMessageCard(msg, isDark);
          },
        );
      },
    );
  }

  Widget _buildMessageCard(MeshChatMessage message, bool isDark) {
    final isOutbound = message.isOutgoing;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isOutbound ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82,
            ),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: isOutbound
                    ? const LinearGradient(
                        colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isOutbound
                    ? null
                    : (isDark ? const Color(0xFF111726) : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isOutbound ? 16 : 4),
                  bottomRight: Radius.circular(isOutbound ? 4 : 16),
                ),
                border: Border.all(
                  color: isOutbound
                      ? const Color(0xFF818CF8).withValues(alpha: 0.3)
                      : (isDark ? const Color(0xFF1E283C) : const Color(0xFFE2E8F0)),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isOutbound
                        ? const Color(0xFF4F46E5).withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sender Header (for incoming messages)
                  if (!isOutbound) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            message.senderDisplayName,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _buildRoleBadge(message.senderRole),
                      ],
                    ),
                    const SizedBox(height: 6),
                  ],

                  // Attached Image Thumbnail
                  if (message.hasImage && message.imageBase64 != null) ...[
                    GestureDetector(
                      onTap: () => _showFullScreenImage(message.imageBase64!),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 240, maxWidth: double.infinity),
                              child: Image.memory(
                                base64Decode(message.imageBase64!),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  height: 80,
                                  color: Colors.grey.withValues(alpha: 0.2),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '⚠️ Failed to load mesh photo',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 11),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 14),
                                    const SizedBox(width: 3),
                                    Text(
                                      'View',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (message.text.isNotEmpty) const SizedBox(height: 6),
                  ],

                  // Message Text Body
                  if (message.text.isNotEmpty)
                    Text(
                      message.text,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        height: 1.35,
                        color: isOutbound
                            ? Colors.white
                            : (isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A)),
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                  const SizedBox(height: 8),

                  // Message Meta Footer (Time, Hops, Verification)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Hop telemetry pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isOutbound
                              ? Colors.black.withValues(alpha: 0.18)
                              : (isDark ? const Color(0xFF1E283C) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          message.hopDescription,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: isOutbound
                                ? Colors.white.withValues(alpha: 0.85)
                                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Verification Badge (if incoming)
                      if (!isOutbound) ...[
                        if (message.isTrusted)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified, size: 12, color: Color(0xFF10B981)),
                              const SizedBox(width: 2),
                              Text(
                                'Verified ✓',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.sensors_rounded, size: 12, color: Color(0xFF6366F1)),
                              const SizedBox(width: 2),
                              Text(
                                'P2P',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF6366F1),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(width: 6),
                      ],

                      // Timestamp
                      Text(
                        _formatTime(message.createdAt),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: isOutbound
                              ? Colors.white.withValues(alpha: 0.75)
                              : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                        ),
                      ),

                      if (isOutbound) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.done_all_rounded,
                          size: 13,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color color;
    switch (role.toLowerCase()) {
      case 'admin':
      case 'dean':
        color = const Color(0xFFEF4444);
        break;
      case 'teacher':
      case 'faculty':
        color = const Color(0xFF3B82F6);
        break;
      case 'warden':
        color = const Color(0xFFF59E0B);
        break;
      case 'student':
      default:
        color = const Color(0xFF10B981);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Text(
        '[${role.toUpperCase()}]',
        style: GoogleFonts.jetBrainsMono(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _buildComposer(bool isDark) {
    final surfaceColor = isDark ? const Color(0xFF0E131F) : Colors.white;
    final isEmergencyChannel = _selectedChannelId == MeshChatChannel.emergency.id;

    if (isEmergencyChannel) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF260A0A) : const Color(0xFFFFEEEE),
          border: Border(
            top: BorderSide(
              color: AppColors.danger.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_rounded, size: 18, color: AppColors.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '#emergency is restricted to verified institutional crisis flares. Normal messages cannot be broadcast here.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.danger,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final hasContentToSend = _textController.text.trim().isNotEmpty || _selectedImageBase64 != null;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF1E283C) : const Color(0xFFE2E8F0),
            width: 0.8,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Image Attachment Preview Strip
          if (_selectedImageBytes != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161E30) : const Color(0xFFF1F5F9),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF222C3F) : const Color(0xFFE2E8F0),
                    width: 0.8,
                  ),
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _selectedImageBytes!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attached Mesh Photo',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${(_selectedImageBytes!.lengthInBytes / 1024).toStringAsFixed(1)} KB · BLE Compressed for P2P Transfer',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10.5,
                            color: const Color(0xFF10B981),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Remove photo',
                    onPressed: () {
                      setState(() {
                        _selectedImageBytes = null;
                        _selectedImageBase64 = null;
                      });
                    },
                  ),
                ],
              ),
            ),

          // Composer Input Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: _selectedImageBase64 != null
                        ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: _isSending ? null : _showImageSourceSheet,
                    tooltip: 'Attach Photo (Mesh)',
                    icon: Icon(
                      Icons.add_photo_alternate_rounded,
                      color: _selectedImageBase64 != null
                          ? const Color(0xFF6366F1)
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      size: 24,
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    maxLength: MeshChatPayload.maxTextLength,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                    onChanged: (_) => setState(() {}),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: _selectedImageBytes != null
                          ? 'Add a caption (optional)...'
                          : 'Write an offline mesh message...',
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF161E30) : const Color(0xFFF1F5F9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (_) => _handleSendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: hasContentToSend && !_isSending
                        ? const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: (hasContentToSend && !_isSending)
                        ? null
                        : (isDark ? const Color(0xFF1E283C) : const Color(0xFFE2E8F0)),
                    shape: BoxShape.circle,
                    boxShadow: hasContentToSend && !_isSending
                        ? [
                            BoxShadow(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: IconButton(
                    onPressed: (_isSending || !hasContentToSend) ? null : _handleSendMessage,
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Icon(
                            Icons.send_rounded,
                            size: 19,
                            color: hasContentToSend ? Colors.white : Colors.grey,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}


