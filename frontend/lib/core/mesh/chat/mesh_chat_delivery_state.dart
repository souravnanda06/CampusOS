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
        return 'Broadcasted';
      case MeshChatDeliveryState.received:
        return 'Delivered ✓✓';
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
      this == MeshChatDeliveryState.relayed;

  /// Resolves an enum value from its serialized string representation.
  static MeshChatDeliveryState fromString(String value) {
    for (final state in MeshChatDeliveryState.values) {
      if (state.name.toLowerCase() == value.toLowerCase().trim()) {
        return state;
      }
    }
    return MeshChatDeliveryState.received;
  }
}
