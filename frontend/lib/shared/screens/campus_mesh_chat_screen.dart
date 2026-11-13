import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/mesh/chat/mesh_chat_service.dart';
import '../../core/mesh/chat/providers/mesh_chat_providers.dart';
import '../../core/mesh/chat/screens/mesh_channels_screen.dart';
import '../../core/mesh/chat/screens/mesh_chat_screen.dart';

// Re-export all requested Deliverables for seamless access
export '../../core/mesh/theme/mesh_theme.dart'
    show AppColors, AppRadii, AppShadows, AppTextStyles, createMeshTheme;
export '../../core/mesh/chat/widgets/channel_row.dart' show ChannelRow;
export '../../core/mesh/chat/widgets/mesh_status_card.dart' show MeshStatusCard;
export '../../core/mesh/chat/widgets/message_bubble.dart' show MessageBubble;
export '../../core/mesh/chat/widgets/message_group.dart' show MessageGroup;
export '../../core/mesh/chat/widgets/flagged_message.dart' show FlaggedMessage;
export '../../core/mesh/chat/widgets/composer.dart' show Composer;
export '../../core/mesh/chat/widgets/chat_header.dart' show ChatHeader;
export '../../core/mesh/chat/widgets/glass_container.dart' show GlassContainer;
export '../../core/mesh/chat/widgets/mesh_action_sheets.dart'
    show NearbyPeersSheet, NewChannelSheet;
export '../../core/mesh/chat/screens/mesh_channels_screen.dart'
    show MeshChannelsScreen, createMeshSlideRoute;
export '../../core/mesh/chat/screens/mesh_chat_screen.dart' show MeshChatScreen;
export '../../core/mesh/chat/providers/mesh_chat_providers.dart';

/// CampusOS Mesh Chat entry screen hosting the Riverpod state hierarchy.
///
/// Presents the Apple-quality Telegram-style messenger with two screens:
/// - Screen 1: Channels list (stacked list, status card, channel previews)
/// - Screen 2: Chat screen (messages reversed, grouping, frosted composer)
class CampusMeshChatScreen extends StatelessWidget {
  final MeshChatService? chatService;
  final String? initialChannelId;

  const CampusMeshChatScreen({
    super.key,
    this.chatService,
    this.initialChannelId,
  });

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        if (chatService != null)
          meshChatServiceProvider.overrideWithValue(chatService),
        if (initialChannelId != null)
          activeChannelIdProvider.overrideWith((ref) => initialChannelId!),
      ],
      child: initialChannelId != null
          ? MeshChatScreen(channelId: initialChannelId!)
          : const MeshChannelsScreen(),
    );
  }
}
