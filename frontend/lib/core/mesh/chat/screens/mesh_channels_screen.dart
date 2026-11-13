import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/mesh_theme.dart';
import '../providers/mesh_chat_providers.dart';
import '../widgets/channel_row.dart';
import '../widgets/mesh_action_sheets.dart';
import '../widgets/mesh_status_card.dart';
import 'mesh_chat_screen.dart';

/// Screen 1: Channels List (Telegram-style stacked channel list).
///
/// Features:
/// - CustomScrollView with slivers, safe-area aware
/// - Vertical multi-stop gradient background (#ECEEFF to #F4F0FF to #EEF3FB)
/// - Overline "CampusOS" in accent color
/// - 36px "Channels" title with subtle dark-indigo ShaderMask gradient
/// - Action buttons in header: Create Channel / DM Peer (+) and 42px App Icon
/// - Indigo-violet MeshStatusCard with live peer telemetry (tap to view & chat with peers)
/// - Section label "ALL CHANNELS" (12px, weight 600, letter-spaced)
/// - Frosted white inset-grouped card holding channel rows
/// - Custom PageRouteBuilder slide transition from right (320ms, Cubic(.2,.8,.2,1))
class MeshChannelsScreen extends ConsumerStatefulWidget {
  const MeshChannelsScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(
      builder: (_) => const MeshChannelsScreen(),
    );
  }

  @override
  ConsumerState<MeshChannelsScreen> createState() => _MeshChannelsScreenState();
}

class _MeshChannelsScreenState extends ConsumerState<MeshChannelsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final chatService = ref.read(meshChatServiceProvider);
      if (chatService != null) {
        try {
          await chatService.initialize();
          if (!chatService.meshService.isRunning) {
            await chatService.meshService.start();
          }
          chatService.syncService?.syncPendingAndPull();
        } catch (e) {
          debugPrint('⚠️ [MESH_INIT] Error starting mesh radio/sync: $e');
        }
      }
    });
  }

  void _showNewConversationOptions(BuildContext context) {
    final container = ProviderScope.containerOf(context);
    showModalBottomSheet(
      context: context,
      useRootNavigator: false,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => UncontrolledProviderScope(
        container: container,
        child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: AppShadows.softCard,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            ListTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentIndigo.withValues(alpha: 0.12),
                ),
                child: const Icon(
                  Icons.tag_rounded,
                  color: AppColors.accentIndigo,
                  size: 22,
                ),
              ),
              title: Text(
                'New Broadcast Channel',
                style: AppTextStyles.channelName.copyWith(fontSize: 16),
              ),
              subtitle: Text(
                'Create a public campus topic for multi-hop mesh sharing',
                style: AppTextStyles.channelPreview.copyWith(fontSize: 12.5),
              ),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(bottomSheetContext).pop();
                NewChannelSheet.show(context);
              },
            ),
            const SizedBox(height: 6),
            ListTile(
              leading: Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.successGreenLight,
                ),
                child: const Icon(
                  Icons.bluetooth_searching_rounded,
                  color: AppColors.successGreen,
                  size: 22,
                ),
              ),
              title: Text(
                'Direct Message a Peer',
                style: AppTextStyles.channelName.copyWith(fontSize: 16),
              ),
              subtitle: Text(
                'Private encrypted 1-to-1 conversation with nearby peers',
                style: AppTextStyles.channelPreview.copyWith(fontSize: 12.5),
              ),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.of(bottomSheetContext).pop();
                NearbyPeersSheet.show(context);
              },
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final liveStatusAsync = ref.watch(meshLiveStatusProvider);
    final summaries = ref.watch(channelSummariesProvider);
    final status = liveStatusAsync.value ?? const MeshLiveStatus();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: AppColors.accentIndigo,
            backgroundColor: Colors.white,
            onRefresh: () async {
              HapticFeedback.lightImpact();
              final chatService = ref.read(meshChatServiceProvider);
              if (chatService != null) {
                await chatService.syncService?.syncPendingAndPull();
              } else {
                await Future<void>.delayed(const Duration(milliseconds: 600));
              }
            },
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                const SliverToBoxAdapter(
                  child: SizedBox(height: 16),
                ),

                // Header: "CampusOS" overline, "Channels" title + Actions
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'CampusOS',
                              style: AppTextStyles.headerOverline,
                            ),
                            const SizedBox(height: 2),
                            ShaderMask(
                              shaderCallback: (bounds) {
                                return const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF14142B),
                                    Color(0xFF2E2B5F),
                                  ],
                                ).createShader(bounds);
                              },
                              child: Text(
                                'Channels',
                                style: AppTextStyles.headerTitle.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Right Actions: Create/New (+) Button and 42px App Icon
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Semantics(
                              label: 'New channel or message a peer',
                              button: true,
                              child: Tooltip(
                                message: 'New channel or peer chat',
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(13),
                                    onTap: () => _showNewConversationOptions(context),
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.85),
                                        borderRadius: BorderRadius.circular(13),
                                        border: Border.all(
                                          color: AppColors.hairlineBorder,
                                          width: 1.0,
                                        ),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Color(0x0A14142B),
                                            blurRadius: 10,
                                            offset: Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.add_rounded,
                                          color: AppColors.accentIndigo,
                                          size: 26,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const _MeshNodeAppIcon(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 18),
                ),

                // Mesh Status Card (Tapping opens Nearby Mesh Peers Sheet)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: MeshStatusCard(
                      status: status,
                      onTap: () => NearbyPeersSheet.show(context),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 24),
                ),

                // Section Label: "ALL CHANNELS"
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ALL CHANNELS',
                          style: AppTextStyles.sectionLabel,
                        ),
                        Text(
                          '${summaries.length} available',
                          style: AppTextStyles.sectionLabel.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMeta,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                  child: SizedBox(height: 10),
                ),

                // Frosted white inset-grouped card holding channel rows
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  sliver: SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(AppRadii.card),
                          border: Border.all(
                            color: AppColors.hairlineBorder,
                            width: 1.0,
                          ),
                          boxShadow: AppShadows.softCard,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadii.card),
                          child: Column(
                            children: [
                              for (int i = 0; i < summaries.length; i++)
                                ChannelRow(
                                  summary: summaries[i],
                                  showDivider: i < summaries.length - 1,
                                  onTap: () {
                                    ref.read(activeChannelIdProvider.notifier).state =
                                        summaries[i].id;
                                    Navigator.of(context).push(
                                      createMeshSlideRoute(
                                        page: UncontrolledProviderScope(
                                          container: ProviderScope.containerOf(context),
                                          child: MeshChatScreen(
                                            channelId: summaries[i].id,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom safe-area padding
                const SliverToBoxAdapter(
                  child: SizedBox(height: 48),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 42px Rounded-Square App Icon with Mesh-Node glyph matching Apple aesthetic.
class _MeshNodeAppIcon extends StatelessWidget {
  const _MeshNodeAppIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        gradient: AppColors.accentGradient,
        boxShadow: AppShadows.appIconShadow,
      ),
      child: Center(
        child: CustomPaint(
          size: const Size(22, 22),
          painter: _MeshNodeGlyphPainter(),
        ),
      ),
    );
  }
}

class _MeshNodeGlyphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final nodePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final centerBottom = Offset(size.width * 0.5, size.height * 0.72);
    final topLeft = Offset(size.width * 0.22, size.height * 0.28);
    final topRight = Offset(size.width * 0.78, size.height * 0.28);

    // Connecting lines
    canvas.drawLine(centerBottom, topLeft, linePaint);
    canvas.drawLine(centerBottom, topRight, linePaint);

    // Nodes
    const double radius = 3.6;
    canvas.drawCircle(centerBottom, radius, nodePaint);
    canvas.drawCircle(topLeft, radius, nodePaint);
    canvas.drawCircle(topRight, radius, nodePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom PageRouteBuilder providing a 320ms Cubic(.2,.8,.2,1) slide from right.
PageRouteBuilder<T> createMeshSlideRoute<T>({required Widget page}) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: const Cubic(0.2, 0.8, 0.2, 1.0),
        reverseCurve: const Cubic(0.2, 0.8, 0.2, 1.0),
      );
      final offsetAnimation = Tween<Offset>(
        begin: const Offset(1.0, 0.0),
        end: Offset.zero,
      ).animate(curved);

      return SlideTransition(
        position: offsetAnimation,
        child: child,
      );
    },
  );
}
