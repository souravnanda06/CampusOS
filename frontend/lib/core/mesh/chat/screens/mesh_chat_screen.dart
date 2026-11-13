import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/mesh_theme.dart';
import '../mesh_chat_message.dart';
import '../providers/mesh_chat_providers.dart';
import '../widgets/chat_header.dart';
import '../widgets/composer.dart';
import '../widgets/glass_container.dart';
import '../widgets/message_group.dart';

/// Screen 2: Conversation View (Apple-quality Telegram-style chat screen).
///
/// Features:
/// - Frosted glass ChatHeader with status and back navigation
/// - Messages displayed in ListView(reverse: true) with newest pinned at bottom
/// - Centered "Today" date chip
/// - Telegram-style grouping with mono green role tags and avatars
/// - Incoming & Outgoing bubbles with precise transport telemetry
/// - Moderation safety shield with AnimatedCrossFade reveal
/// - Pop entrance animation for new messages
/// - Centered frosted empty state card
/// - Floating frosted Composer pill above keyboard with zero jank
class MeshChatScreen extends ConsumerStatefulWidget {
  final String channelId;

  const MeshChatScreen({
    super.key,
    required this.channelId,
  });

  @override
  ConsumerState<MeshChatScreen> createState() => _MeshChatScreenState();
}

class _MeshChatScreenState extends ConsumerState<MeshChatScreen>
    with WidgetsBindingObserver {
  final ImagePicker _picker = ImagePicker();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _composerFocusNode = FocusNode();
  String? _newestMessageId;
  Timer? _activeChannelSyncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _composerFocusNode.addListener(_onFocusChanged);

    // Mark channel read and trigger immediate cloud sync & pull
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final chatService = ref.read(meshChatServiceProvider);
      chatService?.markChannelRead(widget.channelId);
      chatService?.syncService?.syncPendingAndPull(activeChannelId: widget.channelId);
    });

    // Periodically sync active channel to update blue ticks and catch replies in real-time
    _activeChannelSyncTimer = Timer.periodic(const Duration(milliseconds: 3500), (_) {
      if (!mounted) return;
      final chatService = ref.read(meshChatServiceProvider);
      chatService?.markChannelRead(widget.channelId);
      chatService?.syncService?.syncPendingAndPull(activeChannelId: widget.channelId);
    });
  }

  void _onFocusChanged() {
    if (_composerFocusNode.hasFocus) {
      _scrollToBottom(animate: true);
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // When keyboard appears, scroll to bottom so messages move up cleanly
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bottomInset = MediaQuery.of(context).viewInsets.bottom;
      if (bottomInset > 0) {
        _scrollToBottom(animate: true);
      }
    });
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      if (animate) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      } else {
        _scrollController.jumpTo(0.0);
      }
    });
  }

  @override
  void dispose() {
    _activeChannelSyncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _composerFocusNode.removeListener(_onFocusChanged);
    _composerFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSendMessage(String text) {
    if (text.trim().isEmpty) return;

    ref.read(channelMessagesProvider.notifier).appendOutgoingMessage(
          channelId: widget.channelId,
          text: text.trim(),
        );

    // Track newest message for pop entrance animation
    final allMessages = ref.read(messagesByChannelProvider(widget.channelId));
    if (allMessages.isNotEmpty) {
      setState(() {
        _newestMessageId = allMessages.last.messageId;
      });
    }

    _scrollToBottom(animate: true);

    // Clear draft text
    ref.read(draftTextProvider(widget.channelId).notifier).state = '';
  }

  Future<void> _onAttachImage() async {
    try {
      final xFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 480,
        maxHeight: 480,
        imageQuality: 40,
      );
      if (xFile == null) return;

      final bytes = await xFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      ref.read(channelMessagesProvider.notifier).appendOutgoingMessage(
            channelId: widget.channelId,
            text: '📷 Photo transfer via mesh',
            imageBase64: base64Image,
          );
      _scrollToBottom(animate: true);
    } catch (e) {
      debugPrint('Image attachment error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final allChannels = ref.watch(channelsListProvider);
    final channel = allChannels.firstWhere(
      (c) => c.id == widget.channelId,
      orElse: () => ref.watch(activeChannelProvider),
    );
    final messages = ref.watch(messagesByChannelProvider(widget.channelId));
    final liveStatus = ref.watch(meshLiveStatusProvider).value ?? const MeshLiveStatus();
    final revealedFlaggedIds = ref.watch(revealedFlaggedMessagesProvider);
    final draftText = ref.watch(draftTextProvider(widget.channelId));

    // Group messages consecutively by sender
    final groups = _groupMessages(messages);
    final reversedGroups = groups.reversed.toList();

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Column(
          children: [
            // Frosted Chat Header
            ChatHeader(
              channel: channel,
              peerCount: liveStatus.peerCount,
              onBack: () => Navigator.of(context).pop(),
            ),

            // Message Area
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => FocusScope.of(context).unfocus(),
                child: messages.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        physics: const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        ),
                        padding: const EdgeInsets.only(
                          left: 14,
                          right: 14,
                          top: 16,
                          bottom: 12,
                        ),
                        itemCount: reversedGroups.length + 1,
                        itemBuilder: (context, index) {
                          // The top-most item in reverse: true is the date chip
                          if (index == reversedGroups.length) {
                            return _buildDateChip('Today');
                          }

                          final group = reversedGroups[index];
                          return MessageGroup(
                            key: ValueKey(group.messages.first.messageId),
                            messages: group.messages,
                            isOutgoing: group.isOutgoing,
                            revealedFlaggedIds: revealedFlaggedIds,
                            newestMessageId: _newestMessageId,
                            onFlaggedRevealChanged: (messageId, revealed) {
                              ref
                                  .read(revealedFlaggedMessagesProvider.notifier)
                                  .toggle(messageId);
                            },
                          );
                        },
                      ),
              ),
            ),

            // Floating Frosted Composer Pill or Dismantled/Restricted Channel Banner
            if (channel.isRestricted)
              SafeArea(
                top: false,
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFFECDD3), width: 1.2),
                    boxShadow: AppShadows.composerShadow,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock_rounded,
                        color: Color(0xFFE11D48),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          channel.restrictedReason != null && channel.restrictedReason!.isNotEmpty
                              ? 'Channel Restricted: ${channel.restrictedReason}'
                              : 'This channel has been dismantled & restricted by campus moderators. Messaging is disabled.',
                          style: const TextStyle(
                            color: Color(0xFF9F1239),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Composer(
                focusNode: _composerFocusNode,
                initialText: draftText,
                onSend: _onSendMessage,
                onAttachImage: _onAttachImage,
                onDraftChanged: (draft) {
                  ref.read(draftTextProvider(widget.channelId).notifier).state =
                      draft;
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Groups consecutive messages from the same sender
  List<_MessageGroupData> _groupMessages(List<MeshChatMessage> all) {
    if (all.isEmpty) return [];

    final result = <_MessageGroupData>[];
    String? currentSender;
    bool? currentOutgoing;
    var currentList = <MeshChatMessage>[];

    for (final msg in all) {
      final senderKey = msg.isOutgoing ? 'local_user' : msg.senderDeviceId;
      if (currentSender == null || currentSender != senderKey) {
        if (currentList.isNotEmpty) {
          result.add(_MessageGroupData(
            messages: currentList,
            isOutgoing: currentOutgoing ?? false,
          ));
        }
        currentSender = senderKey;
        currentOutgoing = msg.isOutgoing;
        currentList = [msg];
      } else {
        currentList.add(msg);
      }
    }

    if (currentList.isNotEmpty) {
      result.add(_MessageGroupData(
        messages: currentList,
        isOutgoing: currentOutgoing ?? false,
      ));
    }

    return result;
  }

  Widget _buildDateChip(String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0x3814142B),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.25),
              width: 0.6,
            ),
          ),
          child: Text(
            text,
            style: AppTextStyles.dateChip,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: GlassContainer(
          borderRadius: BorderRadius.circular(AppRadii.card),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accentIndigo.withValues(alpha: 0.12),
                ),
                child: const Center(
                  child: Icon(
                    Icons.chat_bubble_outline_rounded,
                    color: AppColors.accentIndigo,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No messages yet',
                style: AppTextStyles.headerTitle.copyWith(
                  fontSize: 20,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Messages hop phone to phone over Bluetooth, and sync over the internet when it is available.',
                textAlign: TextAlign.center,
                style: AppTextStyles.channelPreview.copyWith(
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageGroupData {
  final List<MeshChatMessage> messages;
  final bool isOutgoing;

  const _MessageGroupData({
    required this.messages,
    required this.isOutgoing,
  });
}
