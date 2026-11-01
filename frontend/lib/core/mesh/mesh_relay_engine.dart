import 'dart:async';
import 'mesh_deduplication_store.dart';
import 'mesh_packet.dart';

/// The decision reached by the [MeshRelayEngine] for an incoming packet.
enum MeshRelayDecision {
  /// Packet validated and accepted for forwarding.
  acceptedForRelay,

  /// Packet dropped because it originated from the local device.
  droppedSelfOrigin,

  /// Packet dropped because its 16-byte ID was already seen recently.
  droppedDuplicate,

  /// Packet dropped because its TTL is <= 0 or reached 0 after decrement.
  droppedTtlExpired,

  /// Packet dropped because its creation timestamp exceeded the maximum packet age.
  droppedPacketExpired,

  /// Packet dropped because it exceeded maximum allowable protocol hops (loop guard).
  droppedLoop,

  /// Packet dropped to prevent relay floods/storms (rate limit cooldown).
  droppedCooldown,

  /// Packet dropped because it is structurally invalid.
  droppedInvalid,
}

/// Priority tiers for mesh packet relay forwarding.
enum MeshRelayPriority {
  normal(1),
  high(2),
  critical(3);

  final int rank;
  const MeshRelayPriority(this.rank);
}

/// The evaluation result of an attempted mesh packet relay.
class MeshRelayResult {
  final MeshRelayDecision decision;
  final String reason;
  final MeshPacket? relayedPacket;
  final MeshRelayPriority priority;

  const MeshRelayResult({
    required this.decision,
    required this.reason,
    this.relayedPacket,
    this.priority = MeshRelayPriority.normal,
  });

  /// Whether the packet was approved and modified for relay.
  bool get isAccepted => decision == MeshRelayDecision.acceptedForRelay;

  @override
  String toString() => 'MeshRelayResult(decision: $decision, reason: $reason, priority: $priority, hasRelayedPacket: ${relayedPacket != null})';
}

/// Event emitted every time the relay engine inspects an incoming packet.
class MeshRelayEvent {
  final MeshPacket incomingPacket;
  final MeshRelayDecision decision;
  final String reason;
  final DateTime timestamp;
  final MeshPacket? relayedPacket;
  final MeshRelayPriority priority;

  const MeshRelayEvent({
    required this.incomingPacket,
    required this.decision,
    required this.reason,
    required this.timestamp,
    this.relayedPacket,
    this.priority = MeshRelayPriority.normal,
  });
}

/// Engine governing the validation, loop prevention, deduplication, and forwarding of mesh packets.
///
/// Follows CampusOS Phase M1 relay rules:
/// - Default protocol TTL: 7 (maximum hop ceiling, not physical range guarantee).
/// - Validates packet structure and expiration.
/// - Never relays packets originating from the local device.
/// - Rejects duplicate packet IDs.
/// - Decrements TTL and increments hop count prior to forwarding.
/// - Drops packet if decremented TTL reaches 0.
/// - Applies configurable relay cooldown to prevent broadcast storms.
class MeshRelayEngine {
  /// Default protocol hop ceiling.
  static const int defaultProtocolTtl = 7;

  /// Absolute hard ceiling for network hops to eliminate forwarding cycles.
  static const int maxProtocolHops = 16;

  /// Default cooldown required between consecutive packet relays.
  static const Duration defaultRelayCooldown = Duration(milliseconds: 100);

  /// Default maximum age of a packet before being dropped as stale.
  static const Duration defaultMaxPacketAge = Duration(minutes: 5);

  /// Identifier of the local device running this engine.
  final String localDeviceId;

  /// Deduplication store used to prevent duplicate transmissions.
  final MeshDeduplicationStore deduplicationStore;

  /// Minimum duration between consecutive relays.
  final Duration relayCooldown;

  /// Maximum acceptable age for packet timestamps.
  final Duration maxPacketAge;

  /// Timestamp of the last accepted relay.
  DateTime? _lastRelayTimestamp;

  /// Timestamp of the last accepted emergency relay.
  DateTime? _lastEmergencyRelayTimestamp;

  final StreamController<MeshRelayEvent> _relayEventsController =
      StreamController<MeshRelayEvent>.broadcast();

  MeshRelayEngine({
    required this.localDeviceId,
    required this.deduplicationStore,
    this.relayCooldown = defaultRelayCooldown,
    this.maxPacketAge = defaultMaxPacketAge,
  }) {
    if (localDeviceId.trim().isEmpty) {
      throw ArgumentError.value(localDeviceId, 'localDeviceId', 'localDeviceId cannot be empty');
    }
  }

  /// Reactive stream of relay decisions for testing, monitoring, and telemetry.
  Stream<MeshRelayEvent> get relayEvents => _relayEventsController.stream;

  /// Resolves the relay priority tier for a given packet.
  static MeshRelayPriority getPacketPriority(MeshPacket packet) {
    if (packet.packetType == MeshPacketType.emergency) {
      final payloadStr = String.fromCharCodes(packet.payload);
      if (payloadStr.contains('"p":"c"') || payloadStr.contains('"v":"c"') || payloadStr.contains('"critical"')) {
        return MeshRelayPriority.critical;
      }
      if (payloadStr.contains('"p":"h"') || payloadStr.contains('"v":"w"') || payloadStr.contains('"warning"')) {
        return MeshRelayPriority.high;
      }
      return MeshRelayPriority.high;
    }
    return MeshRelayPriority.normal;
  }

  /// Calculates the cooldown duration applicable to a given priority tier.
  Duration getCooldownForPriority(MeshRelayPriority priority) {
    switch (priority) {
      case MeshRelayPriority.critical:
        final ms = relayCooldown.inMilliseconds ~/ 5;
        return Duration(milliseconds: ms < 10 ? 10 : ms);
      case MeshRelayPriority.high:
        final ms = relayCooldown.inMilliseconds ~/ 2;
        return Duration(milliseconds: ms < 25 ? 25 : ms);
      case MeshRelayPriority.normal:
        return relayCooldown;
    }
  }

  /// Priority comparator: sorts higher priority first, then earlier timestamp first.
  static int compareByPriority(MeshPacket a, MeshPacket b) {
    final prioA = getPacketPriority(a);
    final prioB = getPacketPriority(b);
    if (prioA.rank != prioB.rank) {
      return prioB.rank.compareTo(prioA.rank);
    }
    return a.timestamp.compareTo(b.timestamp);
  }

  /// Evaluates an incoming [MeshPacket] and prepares it for relay if accepted.
  ///
  /// Returns a [MeshRelayResult] detailing the decision and providing the updated [MeshPacket]
  /// with decremented TTL and incremented hopCount.
  MeshRelayResult evaluateAndPrepareRelay(MeshPacket packet, [DateTime? now]) {
    final currentTime = now ?? DateTime.now();
    final priority = getPacketPriority(packet);

    // 1. Self-origin check: never relay packets that originated from this device
    if (packet.senderDeviceId == localDeviceId) {
      final result = MeshRelayResult(
        decision: MeshRelayDecision.droppedSelfOrigin,
        reason: 'Packet originated from local device ($localDeviceId). Suppressed to prevent echo.',
        priority: priority,
      );
      _emitEvent(packet, result, currentTime);
      return result;
    }

    // 2. TTL <= 0 check
    if (packet.ttl <= 0) {
      final result = MeshRelayResult(
        decision: MeshRelayDecision.droppedTtlExpired,
        reason: 'Packet TTL is 0 or negative. Hop budget exhausted.',
        priority: priority,
      );
      _emitEvent(packet, result, currentTime);
      return result;
    }

    // 3. Loop guard check: exceed max allowed hops
    if (packet.hopCount >= maxProtocolHops) {
      final result = MeshRelayResult(
        decision: MeshRelayDecision.droppedLoop,
        reason: 'Packet hop count (${packet.hopCount}) exceeds max protocol hops ($maxProtocolHops). Loop detected.',
        priority: priority,
      );
      _emitEvent(packet, result, currentTime);
      return result;
    }

    // 4. Stale packet / expiration check
    final packetAge = currentTime.difference(packet.timestamp);
    if (packetAge.abs() > maxPacketAge) {
      final result = MeshRelayResult(
        decision: MeshRelayDecision.droppedPacketExpired,
        reason: 'Packet timestamp expired (age: ${packetAge.inSeconds}s, max allowed: ${maxPacketAge.inSeconds}s).',
        priority: priority,
      );
      _emitEvent(packet, result, currentTime);
      return result;
    }

    // 5. Deduplication check: was this packet ID already processed or relayed?
    if (deduplicationStore.contains(packet.packetId, currentTime)) {
      final result = MeshRelayResult(
        decision: MeshRelayDecision.droppedDuplicate,
        reason: 'Packet ID ${packet.packetIdHex} is duplicate in local cache.',
        priority: priority,
      );
      _emitEvent(packet, result, currentTime);
      return result;
    }

    // 6. Relay cooldown check to prevent storms, with priority adaptation
    final applicableCooldown = getCooldownForPriority(priority);
    final lastTimestamp = (priority != MeshRelayPriority.normal)
        ? _lastEmergencyRelayTimestamp
        : _lastRelayTimestamp;

    if (lastTimestamp != null) {
      final elapsed = currentTime.difference(lastTimestamp);
      if (elapsed < applicableCooldown) {
        final result = MeshRelayResult(
          decision: MeshRelayDecision.droppedCooldown,
          reason: 'Relay rate limit active (priority: ${priority.name}, cooldown: ${applicableCooldown.inMilliseconds}ms, elapsed: ${elapsed.inMilliseconds}ms).',
          priority: priority,
        );
        _emitEvent(packet, result, currentTime);
        return result;
      }
    }

    // 7. Decrement TTL and increment hop count for forward relay
    final nextTtl = packet.ttl - 1;
    final nextHopCount = packet.hopCount + 1;

    // If decremented TTL reaches 0, the packet has reached its terminal destination boundary
    if (nextTtl <= 0) {
      // Register in deduplication store so we don't process it repeatedly
      deduplicationStore.add(packet.packetId, currentTime);

      final result = MeshRelayResult(
        decision: MeshRelayDecision.droppedTtlExpired,
        reason: 'Packet decremented TTL reached 0. Terminal hop reached; forwarding halted.',
        priority: priority,
      );
      _emitEvent(packet, result, currentTime);
      return result;
    }

    // Prepare relayed packet
    final relayedPacket = packet.copyWith(
      ttl: nextTtl,
      hopCount: nextHopCount,
    );

    // Register into deduplication store
    deduplicationStore.add(packet.packetId, currentTime);
    _lastRelayTimestamp = currentTime;
    if (priority != MeshRelayPriority.normal) {
      _lastEmergencyRelayTimestamp = currentTime;
    }

    final result = MeshRelayResult(
      decision: MeshRelayDecision.acceptedForRelay,
      reason: 'Packet validated for forwarding (new TTL: $nextTtl, hops: $nextHopCount).',
      relayedPacket: relayedPacket,
      priority: priority,
    );

    _emitEvent(packet, result, currentTime);
    return result;
  }

  void _emitEvent(MeshPacket incoming, MeshRelayResult result, DateTime timestamp) {
    if (!_relayEventsController.isClosed) {
      _relayEventsController.add(MeshRelayEvent(
        incomingPacket: incoming,
        decision: result.decision,
        reason: result.reason,
        timestamp: timestamp,
        relayedPacket: result.relayedPacket,
      ));
    }
  }

  /// Resets the relay cooldown timer (e.g. for testing).
  void resetCooldown() {
    _lastRelayTimestamp = null;
  }

  /// Disposes resources and closes stream controllers.
  Future<void> dispose() async {
    await _relayEventsController.close();
  }
}
