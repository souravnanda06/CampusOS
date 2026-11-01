import 'dart:collection';
import 'dart:typed_data';

/// In-memory bounded deduplication store for CampusOS Mesh packet identifiers.
///
/// Ensures that a received packet is never processed or relayed twice by the same device.
/// Eviction adheres to entry TTL and LRU-style bounded capacity.
class MeshDeduplicationStore {
  /// Default maximum number of packet IDs retained in memory.
  static const int defaultMaxSize = 1000;

  /// Default time-to-live before a packet ID record expires.
  static const Duration defaultEntryTtl = Duration(minutes: 5);

  /// Configurable maximum capacity.
  final int maxSize;

  /// Configurable entry TTL.
  final Duration entryTtl;

  /// Map of packet ID hex string -> recorded timestamp.
  /// Uses [LinkedHashMap] to maintain insertion ordering for LRU eviction.
  final LinkedHashMap<String, DateTime> _store = LinkedHashMap();

  MeshDeduplicationStore({
    this.maxSize = defaultMaxSize,
    this.entryTtl = defaultEntryTtl,
  }) {
    if (maxSize <= 0) {
      throw ArgumentError.value(maxSize, 'maxSize', 'maxSize must be greater than zero');
    }
  }

  /// Converts a 16-byte [Uint8List] into a canonical hex key.
  String _toKey(Uint8List packetId) {
    if (packetId.length != 16) {
      throw ArgumentError('Packet ID must be exactly 16 bytes');
    }
    return packetId.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Checks if the given 16-byte [packetId] is currently registered in the store and unexpired.
  bool contains(Uint8List packetId, [DateTime? now]) {
    final key = _toKey(packetId);
    final recordedAt = _store[key];
    if (recordedAt == null) return false;

    final currentTime = now ?? DateTime.now();
    if (currentTime.difference(recordedAt) > entryTtl) {
      // Entry is expired, remove it proactively
      _store.remove(key);
      return false;
    }

    return true;
  }

  /// Checks if the hex string representation of a packet ID is registered.
  bool containsHex(String packetIdHex, [DateTime? now]) {
    final recordedAt = _store[packetIdHex];
    if (recordedAt == null) return false;

    final currentTime = now ?? DateTime.now();
    if (currentTime.difference(recordedAt) > entryTtl) {
      _store.remove(packetIdHex);
      return false;
    }

    return true;
  }

  /// Registers a 16-byte [packetId].
  ///
  /// Returns `true` if the packet was newly recorded.
  /// Returns `false` if the packet was already present and unexpired (duplicate).
  bool add(Uint8List packetId, [DateTime? timestamp]) {
    final key = _toKey(packetId);
    final currentTime = timestamp ?? DateTime.now();

    // If already present and unexpired, treat as duplicate
    if (_store.containsKey(key)) {
      final existingTime = _store[key]!;
      if (currentTime.difference(existingTime) <= entryTtl) {
        return false;
      }
      // If expired, remove old record and re-add
      _store.remove(key);
    }

    // Capacity management
    if (_store.length >= maxSize) {
      cleanupExpired(currentTime);
    }

    // If still at capacity, evict the oldest entry (front of LinkedHashMap)
    if (_store.length >= maxSize) {
      _store.remove(_store.keys.first);
    }

    _store[key] = currentTime;
    return true;
  }

  /// Cleans up all expired entries.
  ///
  /// Returns the number of expired entries removed.
  int cleanupExpired([DateTime? now]) {
    final currentTime = now ?? DateTime.now();
    final expiredKeys = <String>[];

    for (final entry in _store.entries) {
      if (currentTime.difference(entry.value) > entryTtl) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _store.remove(key);
    }

    return expiredKeys.length;
  }

  /// Returns the current number of tracked packet IDs in the store.
  int get count => _store.length;

  /// Clears all recorded packet IDs.
  void clear() {
    _store.clear();
  }
}
