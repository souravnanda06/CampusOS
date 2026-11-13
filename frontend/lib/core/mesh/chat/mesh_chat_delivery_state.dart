/// Delivery lifecycle state of a CampusOS Mesh chat message.
///
/// Follows strict offline mesh semantics:
/// - Does not fabricate end-to-end receipts unless an explicit acknowledgment is observed.
/// - Outgoing broadcast is designated as [relayed] (relaying over the peer mesh).
/// - Incoming messages are designated as [received].
enum MeshChatDeliveryState {
  queued,
  broadcasting,
  relayed,
  received,
  seen,
  failed,
  expired;

  /// User-facing label describing the delivery condition.
  String get label {
    switch (this) {
      case MeshChatDeliveryState.queued:
        return 'Queued';
      case MeshChatDeliveryState.broadcasting:
        return 'Broadcasting';
      case MeshChatDeliveryState.relayed:
        return 'Sent ✓';
      case MeshChatDeliveryState.received:
        return 'Delivered ✓✓';
      case MeshChatDeliveryState.seen:
        return 'Seen ✓✓';
      case MeshChatDeliveryState.failed:
        return 'Failed';
      case MeshChatDeliveryState.expired:
        return 'Expired';
    }
  }

  /// Whether this state indicates an outbound message from the local device.
  bool get isOutbound =>
      this == MeshChatDeliveryState.queued ||
      this == MeshChatDeliveryState.broadcasting ||
      this == MeshChatDeliveryState.relayed ||
      this == MeshChatDeliveryState.received ||
      this == MeshChatDeliveryState.seen;

  /// Resolves an enum value from its serialized string representation.
  static MeshChatDeliveryState fromString(String value) {
    final clean = value.toLowerCase().trim();
    if (clean == 'seen' || clean == 'read') {
      return MeshChatDeliveryState.seen;
    }
    if (clean == 'received' || clean == 'delivered') {
      return MeshChatDeliveryState.received;
    }
    if (clean == 'relayed' || clean == 'sent' || clean == 'broadcasted') {
      return MeshChatDeliveryState.relayed;
    }
    for (final state in MeshChatDeliveryState.values) {
      if (state.name.toLowerCase() == clean) {
        return state;
      }
    }
    return MeshChatDeliveryState.received;
  }
}
