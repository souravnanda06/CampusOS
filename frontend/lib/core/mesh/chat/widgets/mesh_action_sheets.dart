import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/mesh_theme.dart';
import '../providers/mesh_chat_providers.dart';
import '../screens/mesh_channels_screen.dart';
import '../screens/mesh_chat_screen.dart';

/// Bottom Sheet displaying nearby active mesh peers with direct 1-to-1 messaging action.
class NearbyPeersSheet extends ConsumerWidget {
  const NearbyPeersSheet({super.key});

  static Future<void> show(BuildContext context) {
    final container = ProviderScope.containerOf(context);
    return showModalBottomSheet(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UncontrolledProviderScope(
        container: container,
        child: const NearbyPeersSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peersAsync = ref.watch(nearbyPeersProvider);
    final peers = peersAsync.value ?? [];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: AppShadows.softCard,
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFD4D6E2),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header Row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentIndigo.withValues(alpha: 0.12),
                ),
                child: const Center(
                  child: Icon(
                    Icons.bluetooth_searching_rounded,
                    color: AppColors.accentIndigo,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nearby Mesh Peers',
                      style: AppTextStyles.headerTitle.copyWith(fontSize: 20),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Direct peer-to-peer radio contact within range',
                      style: AppTextStyles.channelPreview.copyWith(fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.successGreenLight,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(
                    color: AppColors.successGreen.withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '${peers.length} active',
                  style: AppTextStyles.roleTag.copyWith(fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.hairlineBorder),
          const SizedBox(height: 12),

          // Peers List
          if (peers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Scanning for nearby BLE / Wi-Fi mesh nodes...',
                  style: AppTextStyles.channelPreview,
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 340),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: peers.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final peer = peers[index];
                  return _buildPeerTile(context, ref, peer);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPeerTile(BuildContext context, WidgetRef ref, MeshPeerProfile peer) {
    String cleanName = peer.displayName.isNotEmpty ? peer.displayName : 'Peer';
    if (cleanName.contains('-') && cleanName.length > 16) {
      final chatService = ref.read(meshChatServiceProvider);
      final cached = chatService?.getPeerDisplayName(peer.deviceId);
      if (cached != null && cached.isNotEmpty && !cached.contains('-')) {
        cleanName = cached;
      } else {
        cleanName = 'Campus Peer (${cleanName.substring(0, 6)})';
      }
    }
    final initial = cleanName[0].toUpperCase();
    final colors = [
      const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
      const [Color(0xFF0EA5E9), Color(0xFF06B6D4)],
      const [Color(0xFF10B981), Color(0xFF059669)],
      const [Color(0xFFF59E0B), Color(0xFFD97706)],
    ];
    final gradient = colors[cleanName.hashCode.abs() % colors.length];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgStop1.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairlineBorder, width: 0.8),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradient,
              ),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Peer Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        cleanName,
                        style: AppTextStyles.channelName.copyWith(fontSize: 15.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppColors.successGreenLight,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        peer.role,
                        style: AppTextStyles.roleTag.copyWith(fontSize: 9.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.cell_tower_rounded,
                      size: 13,
                      color: AppColors.textMeta,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${peer.rssi} dBm · ${peer.hopCount} ${peer.hopCount == 1 ? 'hop' : 'hops'}',
                      style: AppTextStyles.metaIncoming.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // "Chat" Action Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                HapticFeedback.lightImpact();
                final navigator = Navigator.of(context);
                final container = ProviderScope.containerOf(context);
                navigator.pop(); // Close sheet

                // Open or create DM channel
                final dmChannel = await ref
                    .read(channelsListProvider.notifier)
                    .openDirectMessageWithPeer(
                      peerDeviceId: peer.deviceId,
                      peerDisplayName: cleanName,
                    );

                ref.read(activeChannelIdProvider.notifier).state = dmChannel.id;

                navigator.push(
                  createMeshSlideRoute(
                    page: UncontrolledProviderScope(
                      container: container,
                      child: MeshChatScreen(channelId: dmChannel.id),
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentIndigo.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'Chat',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom Sheet allowing the creation of a new broadcast channel.
class NewChannelSheet extends ConsumerStatefulWidget {
  const NewChannelSheet({super.key});

  static Future<void> show(BuildContext context) {
    final container = ProviderScope.containerOf(context);
    return showModalBottomSheet(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UncontrolledProviderScope(
        container: container,
        child: const NewChannelSheet(),
      ),
    );
  }

  @override
  ConsumerState<NewChannelSheet> createState() => _NewChannelSheetState();
}

class _NewChannelSheetState extends ConsumerState<NewChannelSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _handleCreate() async {
    final rawName = _nameController.text.trim();
    if (rawName.isEmpty) return;

    HapticFeedback.lightImpact();
    setState(() => _isCreating = true);

    try {
      final newChannel = await ref
          .read(channelsListProvider.notifier)
          .createChannel(
            name: rawName,
            description: _descController.text.trim().isNotEmpty
                ? _descController.text.trim()
                : null,
          );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close sheet

      ref.read(activeChannelIdProvider.notifier).state = newChannel.id;

      Navigator.of(context).push(
        createMeshSlideRoute(
          page: UncontrolledProviderScope(
            container: ProviderScope.containerOf(context),
            child: MeshChatScreen(channelId: newChannel.id),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: AppShadows.softCard,
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: bottomInset + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFD4D6E2),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          const SizedBox(height: 18),

          Text(
            'Create New Channel',
            style: AppTextStyles.headerTitle.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 4),
          Text(
            'Broadcasts to nearby phones over Bluetooth + Wi-Fi mesh hops',
            style: AppTextStyles.channelPreview.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 18),

          // Channel Name Field
          TextField(
            controller: _nameController,
            autofocus: true,
            style: AppTextStyles.composerInput,
            decoration: InputDecoration(
              prefixText: '# ',
              prefixStyle: const TextStyle(
                color: AppColors.accentIndigo,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
              hintText: 'e.g. robotics-club or hackathon',
              hintStyle: AppTextStyles.composerHint,
              filled: true,
              fillColor: AppColors.bgStop1.withValues(alpha: 0.6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.hairlineBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.hairlineBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.accentIndigo, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 12),

          // Description Field
          TextField(
            controller: _descController,
            style: AppTextStyles.composerInput.copyWith(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Optional channel purpose / description',
              hintStyle: AppTextStyles.composerHint.copyWith(fontSize: 13.5),
              filled: true,
              fillColor: AppColors.bgStop1.withValues(alpha: 0.6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.hairlineBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.hairlineBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.accentIndigo, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 20),

          // Create Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: _isCreating ? null : _handleCreate,
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentIndigo.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isCreating
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Create Channel',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
