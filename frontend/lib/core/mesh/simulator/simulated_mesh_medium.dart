import 'dart:async';
import 'dart:typed_data';

import 'virtual_mesh_node.dart';

/// Represents a communication link between two nodes in the virtual campus topology.
class VirtualMeshLink {
  final String nodeA;
  final String nodeB;
  bool isEnabled;

  VirtualMeshLink(this.nodeA, this.nodeB, {this.isEnabled = true});

  bool connects(String id1, String id2) {
    return (nodeA == id1 && nodeB == id2) || (nodeA == id2 && nodeB == id1);
  }

  String get otherNodeId => '$nodeA<->$nodeB';
}

/// Event recording RF advertisement propagation across the simulated medium.
class MediumPropagationRecord {
  final String senderNodeId;
  final String receiverNodeId;
  final int byteLength;
  final int rssi;
  final DateTime timestamp;

  MediumPropagationRecord({
    required this.senderNodeId,
    required this.receiverNodeId,
    required this.byteLength,
    required this.rssi,
    required this.timestamp,
  });
}

/// Simulated multi-node BLE RF medium.
///
/// Connects virtual nodes and faithfully models:
/// - Directed/undirected topological adjacency (e.g., Dean A <-> Relay B <-> Student C)
/// - Node offline/online status (unreachable when node is down)
/// - Link disconnection (RF occlusion / out-of-range)
/// - Configurable propagation delay
class SimulatedMeshMedium {
  final Map<String, VirtualMeshNode> _nodes = {};
  final List<VirtualMeshLink> _links = [];
  final StreamController<MediumPropagationRecord> _propagationController =
      StreamController<MediumPropagationRecord>.broadcast();

  Duration transmissionDelay;

  SimulatedMeshMedium({this.transmissionDelay = Duration.zero});

  /// Stream of all packet propagation hops across the simulated medium.
  Stream<MediumPropagationRecord> get onPropagation =>
      _propagationController.stream;

  /// Unmodifiable view of registered nodes.
  Map<String, VirtualMeshNode> get nodes => Map.unmodifiable(_nodes);

  /// Unmodifiable view of active topological links.
  List<VirtualMeshLink> get links => List.unmodifiable(_links);

  /// Registers a virtual node into the medium.
  void registerNode(VirtualMeshNode node) {
    _nodes[node.nodeId] = node;
    node.adapter.onTransmit = (senderId, rawBytes) {
      _handleNodeTransmission(senderId, rawBytes);
    };
  }

  /// Establishes a bidirectional RF communication link between two nodes.
  void addLink(String nodeA, String nodeB) {
    if (!hasLink(nodeA, nodeB)) {
      _links.add(VirtualMeshLink(nodeA, nodeB));
    }
  }

  /// Removes an RF communication link between two nodes.
  void removeLink(String nodeA, String nodeB) {
    _links.removeWhere((link) => link.connects(nodeA, nodeB));
  }

  /// Enables or disables a specific link (simulating RF occlusion).
  void setLinkEnabled(String nodeA, String nodeB, bool enabled) {
    for (final link in _links) {
      if (link.connects(nodeA, nodeB)) {
        link.isEnabled = enabled;
      }
    }
  }

  /// Checks if a communication link exists and is enabled between two nodes.
  bool hasActiveLink(String nodeA, String nodeB) {
    for (final link in _links) {
      if (link.connects(nodeA, nodeB) && link.isEnabled) {
        return true;
      }
    }
    return false;
  }

  /// Checks if a link definition exists regardless of enabled state.
  bool hasLink(String nodeA, String nodeB) {
    return _links.any((link) => link.connects(nodeA, nodeB));
  }

  /// Internal handler invoked when a node's BLE adapter advertises raw bytes.
  void _handleNodeTransmission(String senderId, Uint8List rawBytes) {
    final senderNode = _nodes[senderId];
    if (senderNode == null || !senderNode.isOnline) return;

    senderNode.stats.packetsSent++;

    // Find all directly adjacent nodes
    for (final entry in _nodes.entries) {
      final targetId = entry.key;
      final targetNode = entry.value;

      if (targetId == senderId) continue;

      if (hasActiveLink(senderId, targetId) && targetNode.isOnline) {
        final record = MediumPropagationRecord(
          senderNodeId: senderId,
          receiverNodeId: targetId,
          byteLength: rawBytes.length,
          rssi: -62,
          timestamp: DateTime.now(),
        );

        if (!_propagationController.isClosed) {
          _propagationController.add(record);
        }

        if (transmissionDelay > Duration.zero) {
          Future.delayed(transmissionDelay, () {
            if (targetNode.isOnline && hasActiveLink(senderId, targetId)) {
              targetNode.stats.packetsReceived++;
              targetNode.adapter.deliverInbound(rawBytes, rssi: -62);
            }
          });
        } else {
          targetNode.stats.packetsReceived++;
          targetNode.adapter.deliverInbound(rawBytes, rssi: -62);
        }
      }
    }
  }

  /// Clears all registered nodes and links.
  Future<void> dispose() async {
    for (final node in _nodes.values) {
      node.adapter.onTransmit = null;
    }
    _nodes.clear();
    _links.clear();
    await _propagationController.close();
  }
}
