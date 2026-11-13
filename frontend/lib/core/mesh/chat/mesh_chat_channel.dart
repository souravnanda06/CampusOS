/// Represents a broadcast channel or direct 1-to-1 conversation in CampusOS Mesh Chat.
class MeshChatChannel {
  /// Stable identifier for the channel (e.g., "channel:general" or "dm:devA:devB").
  final String id;

  /// User-facing display name (e.g., "#general", "#hostel-b", "Direct: Alice").
  final String name;

  /// Optional description of the channel purpose.
  final String? description;

  /// Whether this channel represents a 1-to-1 direct message conversation.
  final bool isDirectMessage;

  /// Participants involved if direct message (sorted deterministically).
  final List<String> participants;

  /// Administrative status of the channel: 'ACTIVE', 'RESTRICTED', or 'DISMANTLED'.
  final String status;

  /// Optional administrative reason when channel is restricted/dismantled.
  final String? restrictedReason;

  const MeshChatChannel({
    required this.id,
    required this.name,
    this.description,
    this.isDirectMessage = false,
    this.participants = const [],
    this.status = 'ACTIVE',
    this.restrictedReason,
  });

  /// Whether messaging in this channel is restricted or dismantled by administrators.
  bool get isRestricted =>
      status.toUpperCase() == 'RESTRICTED' ||
      status.toUpperCase() == 'DISMANTLED';

  MeshChatChannel copyWith({
    String? id,
    String? name,
    String? description,
    bool? isDirectMessage,
    List<String>? participants,
    String? status,
    String? restrictedReason,
  }) {
    return MeshChatChannel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isDirectMessage: isDirectMessage ?? this.isDirectMessage,
      participants: participants ?? this.participants,
      status: status ?? this.status,
      restrictedReason: restrictedReason ?? this.restrictedReason,
    );
  }

  /// Default broadcast channels available offline in CampusOS.
  static const MeshChatChannel general = MeshChatChannel(
    id: 'channel:general',
    name: '#general',
    description: 'Campus-wide public discussion channel',
  );

  static const MeshChatChannel hostelB = MeshChatChannel(
    id: 'channel:hostel-b',
    name: '#hostel-b',
    description: 'Hostel Block B resident updates and notices',
  );

  static const MeshChatChannel studyGroup = MeshChatChannel(
    id: 'channel:study-group',
    name: '#study-group',
    description: 'Peer collaborative study & lab materials discussion',
  );

  /// Official emergency disaster flare channel (restricted to verified authorities).
  static const MeshChatChannel emergency = MeshChatChannel(
    id: 'channel:emergency',
    name: '#emergency',
    description: 'Official institutional emergency disaster flare alerts',
  );

  /// Predefined default channels list.
  static const List<MeshChatChannel> defaultChannels = [
    general,
    hostelB,
    studyGroup,
    emergency,
  ];

  /// Creates a deterministic 1-to-1 Direct Message conversation channel.
  ///
  /// Uses the canonical lexicographical ordering:
  /// `DM(min(A, B), max(A, B))`
  ///
  /// This guarantees that `A -> B` and `B -> A` resolve to the exact same channel ID,
  /// independent of who originated the message or display names.
  factory MeshChatChannel.directMessage({
    required String participantA,
    required String participantB,
    String? displayName,
  }) {
    if (participantA.trim().isEmpty || participantB.trim().isEmpty) {
      throw ArgumentError('Direct message participant identifiers cannot be empty');
    }

    final sorted = [participantA.trim(), participantB.trim()]..sort();
    final first = sorted[0];
    final second = sorted[1];
    final channelId = 'dm:$first:$second';

    return MeshChatChannel(
      id: channelId,
      name: displayName ?? 'DM: $participantB',
      description: 'Private 1-to-1 direct mesh conversation',
      isDirectMessage: true,
      participants: [first, second],
    );
  }

  /// Helper to compute the deterministic direct message channel ID between two nodes.
  static String computeDirectMessageId(String participantA, String participantB) {
    final sorted = [participantA.trim(), participantB.trim()]..sort();
    return 'dm:${sorted[0]}:${sorted[1]}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! MeshChatChannel) return false;
    return id == other.id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'MeshChatChannel(id: $id, name: $name, isDM: $isDirectMessage)';
}
