import 'dart:convert';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_app/core/mesh/campus_mesh_service.dart';
import 'package:attendance_app/core/mesh/chat/mesh_chat_channel.dart';
import 'package:attendance_app/core/mesh/chat/mesh_chat_delivery_state.dart';
import 'package:attendance_app/core/mesh/chat/mesh_chat_message.dart';
import 'package:attendance_app/core/mesh/chat/mesh_chat_repository.dart';
import 'package:attendance_app/core/mesh/chat/mesh_chat_service.dart';
import 'package:attendance_app/core/mesh/mesh_crypto.dart';
import 'package:attendance_app/core/mesh/mesh_deduplication_store.dart';
import 'package:attendance_app/core/mesh/mesh_packet.dart';
import 'package:attendance_app/core/mesh/mesh_packet_codec.dart';
import 'package:attendance_app/core/mesh/mesh_peer_registry.dart';
import 'package:attendance_app/core/mesh/mesh_relay_engine.dart';
import 'package:attendance_app/student/models/passport_trust_bundle_model.dart';

class ChatTestBleAdapter implements MeshBleAdapter {
  final List<Uint8List> advertised = [];
  void Function(Uint8List rawBytes, int rssi)? packetDiscoveredCallback;

  @override
  Future<bool> isBluetoothAvailable() async => true;

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<bool> startScanning({
    required void Function(Uint8List rawBytes, int rssi) onPacketDiscovered,
  }) async {
    packetDiscoveredCallback = onPacketDiscovered;
    return true;
  }

  @override
  Future<void> stopScanning() async {
    packetDiscoveredCallback = null;
  }

  @override
  Future<bool> advertisePacket(Uint8List rawBytes) async {
    advertised.add(rawBytes);
    return true;
  }

  @override
  Future<void> stopAdvertising() async {}

  @override
  Future<void> dispose() async {}

  void simulateInboundAdvertisement(Uint8List rawBytes, {int rssi = -60}) {
    packetDiscoveredCallback?.call(rawBytes, rssi);
  }
}

void main() {
  group('CampusOS Mesh — Phase M3: Offline P2P Mesh Chat Tests', () {
    late Ed25519 algorithm;
    late SimpleKeyPair aliceKeyPair;
    late SimpleKeyPair bobKeyPair;
    late SimpleKeyPair rootKeyPair;

    late SimplePublicKey alicePubKey;
    late SimplePublicKey bobPubKey;
    late SimplePublicKey rootPubKey;

    late PassportTrustBundle trustBundle;
    late CampusMeshCryptoService aliceCryptoService;
    late CampusMeshCryptoService bobCryptoService;

    late ChatTestBleAdapter aliceAdapter;
    late ChatTestBleAdapter bobAdapter;

    late MeshChatRepository aliceRepo;
    late MeshChatRepository bobRepo;

    late CampusMeshService aliceMeshService;
    late CampusMeshService bobMeshService;

    late MeshChatService aliceChatService;
    late MeshChatService bobChatService;

    const codec = MeshPacketCodec();
    final now = DateTime.now();
    final nowSec = now.toUtc().millisecondsSinceEpoch ~/ 1000;

    setUp(() async {
      algorithm = Ed25519();
      rootKeyPair = await algorithm.newKeyPair();
      aliceKeyPair = await algorithm.newKeyPair();
      bobKeyPair = await algorithm.newKeyPair();

      rootPubKey = await rootKeyPair.extractPublicKey();
      alicePubKey = await aliceKeyPair.extractPublicKey();
      bobPubKey = await bobKeyPair.extractPublicKey();

      trustBundle = PassportTrustBundle(
        version: 1,
        issuerKeyId: 'campusos-root-test',
        generatedAt: nowSec - 3600,
        expiresAt: nowSec + 86400,
        institution: PassportInstitutionTrust(
          keyId: 'campusos-root-test',
          publicKey: base64Encode(rootPubKey.bytes),
          issuer: 'CampusOS',
        ),
        identities: [
          PassportTrustIdentity(
            keyId: 'key-alice',
            userId: 'user_alice',
            publicKey: base64Encode(alicePubKey.bytes),
            certificateId: 'cert-alice',
            issuerKeyId: 'campusos-root-test',
            validFrom: nowSec - 3600,
            validTo: nowSec + 86400,
            status: 'ACTIVE',
            userName: 'Alice Student',
          ),
          PassportTrustIdentity(
            keyId: 'key-bob',
            userId: 'user_bob',
            publicKey: base64Encode(bobPubKey.bytes),
            certificateId: 'cert-bob',
            issuerKeyId: 'campusos-root-test',
            validFrom: nowSec - 3600,
            validTo: nowSec + 86400,
            status: 'ACTIVE',
            userName: 'Bob Warden',
          ),
        ],
        revokedKeyIds: const [],
        signature: 'dummy_sig',
        rawPayload: const {},
      );

      aliceCryptoService = CampusMeshCryptoService(
        algorithm: algorithm,
        localKeyPair: aliceKeyPair,
        mockTrustBundle: trustBundle,
      );

      bobCryptoService = CampusMeshCryptoService(
        algorithm: algorithm,
        localKeyPair: bobKeyPair,
        mockTrustBundle: trustBundle,
      );

      aliceAdapter = ChatTestBleAdapter();
      bobAdapter = ChatTestBleAdapter();

      aliceRepo = MeshChatRepository.inMemory();
      bobRepo = MeshChatRepository.inMemory();

      aliceMeshService = CampusMeshService(
        localDeviceId: 'user_alice',
        localRole: 'student',
        adapter: aliceAdapter,
        cryptoService: aliceCryptoService,
        deduplicationStore: MeshDeduplicationStore(maxSize: 100),
        peerRegistry: MeshPeerRegistry(),
        relayEngine: MeshRelayEngine(
          localDeviceId: 'user_alice',
          deduplicationStore: MeshDeduplicationStore(maxSize: 100),
        ),
      );

      bobMeshService = CampusMeshService(
        localDeviceId: 'user_bob',
        localRole: 'warden',
        adapter: bobAdapter,
        cryptoService: bobCryptoService,
        deduplicationStore: MeshDeduplicationStore(maxSize: 100),
        peerRegistry: MeshPeerRegistry(),
        relayEngine: MeshRelayEngine(
          localDeviceId: 'user_bob',
          deduplicationStore: MeshDeduplicationStore(maxSize: 100),
        ),
      );

      aliceChatService = MeshChatService(
        meshService: aliceMeshService,
        repository: aliceRepo,
        cryptoService: aliceCryptoService,
        mockTrustBundle: trustBundle,
      );

      bobChatService = MeshChatService(
        meshService: bobMeshService,
        repository: bobRepo,
        cryptoService: bobCryptoService,
        mockTrustBundle: trustBundle,
      );

      await aliceChatService.initialize();
      await bobChatService.initialize();
      await aliceMeshService.start();
      await bobMeshService.start();
    });

    tearDown(() async {
      await aliceChatService.dispose();
      await bobChatService.dispose();
      await aliceMeshService.dispose();
      await bobMeshService.dispose();
    });

    test('TEST 1: Create chat message with valid fields', () {
      final msg = MeshChatMessage(
        messageId: 'msg_001',
        senderDeviceId: 'dev_alice',
        senderUserId: 'user_alice',
        senderDisplayName: 'Alice Student',
        senderRole: 'student',
        channelId: MeshChatChannel.general.id,
        text: 'Hello CampusOS Mesh!',
        createdAt: DateTime.now(),
        hopCount: 0,
        ttl: 7,
      );

      expect(msg.messageId, equals('msg_001'));
      expect(msg.senderDisplayName, equals('Alice Student'));
      expect(msg.channelId, equals('channel:general'));
      expect(msg.hopDescription, equals('1 hop · Direct'));
    });

    test('TEST 2 & 3: Serialize and deserialize chat payload roundtrip', () {
      const payload = MeshChatPayload(
        messageId: 'msg_roundtrip_123',
        channelId: 'channel:hostel-b',
        text: 'Hostel mess dinner timings changed.',
        senderDisplayName: 'Bob Warden',
        recipientDeviceId: 'user_alice',
      );

      final bytes = payload.toBytes();
      expect(bytes.isNotEmpty, isTrue);

      final decoded = MeshChatPayload.fromBytes(bytes);
      expect(decoded.messageId, equals(payload.messageId));
      expect(decoded.channelId, equals(payload.channelId));
      expect(decoded.text, equals(payload.text));
      expect(decoded.senderDisplayName, equals(payload.senderDisplayName));
      expect(decoded.recipientDeviceId, equals(payload.recipientDeviceId));
    });

    test('TEST 4: Send message through CampusMeshService broadcasts signed packet', () async {
      final sent = await aliceChatService.sendMessage(
        channelId: MeshChatChannel.general.id,
        text: 'Does anyone have the DBMS lab manual?',
      );

      expect(sent.isOutgoing, isTrue);
      expect(sent.deliveryState, equals(MeshChatDeliveryState.relayed));
      expect(aliceAdapter.advertised.length, equals(1));

      // Verify advertised packet is valid signed MeshPacket
      final advertisedBytes = aliceAdapter.advertised.first;
      final packet = codec.decode(advertisedBytes);

      expect(packet.packetType, equals(MeshPacketType.chat));
      expect(packet.senderDeviceId, equals('user_alice'));
      expect(packet.signature.length, equals(64));
    });

    test('TEST 5: Valid incoming chat packet reaches receiver repository with verified status', () async {
      // Alice sends message
      await aliceChatService.sendMessage(
        channelId: MeshChatChannel.general.id,
        text: 'Meeting at library at 5 PM',
      );

      // Simulate Bob receiving Alice's broadcast advertisement
      final advertisedPacket = aliceAdapter.advertised.last;
      bobAdapter.simulateInboundAdvertisement(advertisedPacket, rssi: -62);

      await pumpEventQueue();

      final bobMessages = await bobRepo.getMessagesForChannel(MeshChatChannel.general.id);
      expect(bobMessages.length, equals(1));

      final msg = bobMessages.first;
      expect(msg.text, equals('Meeting at library at 5 PM'));
      expect(msg.senderDisplayName, equals('Alice Student'));
      expect(msg.senderRole, equals('student'));
      expect(msg.isTrusted, isTrue);
      expect(msg.verificationState, equals('TRUSTED'));
      expect(msg.deliveryState, equals(MeshChatDeliveryState.received));
    });

    test('TEST 6: Invalid signature never reaches chat repository', () async {
      final forgedPayload = const MeshChatPayload(
        messageId: 'forged_001',
        channelId: 'channel:general',
        text: 'Tampered announcement',
      ).toBytes();

      final forgedPacket = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        ttl: 7,
        hopCount: 0,
        senderDeviceId: 'user_alice',
        senderRole: 'student',
        timestamp: DateTime.now(),
        payload: forgedPayload,
        signature: Uint8List(64), // Invalid signature
      );

      final encoded = codec.encode(forgedPacket);
      bobAdapter.simulateInboundAdvertisement(encoded);

      await pumpEventQueue();

      final bobMessages = await bobRepo.getAllMessages();
      expect(bobMessages.isEmpty, isTrue); // Dropped by security boundary!
    });

    test('TEST 7: Unknown sender never becomes verified institutional chat', () async {
      final foreignKeyPair = await algorithm.newKeyPair();
      final foreignCrypto = CampusMeshCryptoService(
        algorithm: algorithm,
        localKeyPair: foreignKeyPair,
        mockTrustBundle: trustBundle,
      );

      final roguePayload = const MeshChatPayload(
        messageId: 'rogue_001',
        channelId: 'channel:general',
        text: 'Spam broadcast',
      ).toBytes();

      final roguePacket = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        senderDeviceId: 'unknown_unregistered_node',
        senderRole: 'student',
        timestamp: DateTime.now(),
        payload: roguePayload,
      );

      final signedRogue = await foreignCrypto.signPacket(roguePacket);
      bobAdapter.simulateInboundAdvertisement(codec.encode(signedRogue));

      await pumpEventQueue();

      final messages = await bobRepo.getAllMessages();
      expect(messages.isEmpty, isTrue); // Rejected: unknownSender
    });

    test('TEST 8: Duplicate message is ignored and does not create duplicate record', () async {
      await aliceChatService.sendMessage(
        channelId: MeshChatChannel.general.id,
        text: 'Duplicate test message',
      );

      final packetBytes = aliceAdapter.advertised.last;

      // Deliver twice
      bobAdapter.simulateInboundAdvertisement(packetBytes);
      await pumpEventQueue();

      bobAdapter.simulateInboundAdvertisement(packetBytes);
      await pumpEventQueue();

      final messages = await bobRepo.getMessagesForChannel(MeshChatChannel.general.id);
      expect(messages.length, equals(1)); // Exactly 1, no duplicate!
    });

    test('TEST 9 & 15: Channel filtering isolates messages between channels', () async {
      await aliceChatService.sendMessage(
        channelId: MeshChatChannel.general.id,
        text: 'General chat message',
      );

      await aliceChatService.sendMessage(
        channelId: MeshChatChannel.hostelB.id,
        text: 'Hostel B only message',
      );

      // Deliver both to Bob
      bobAdapter.simulateInboundAdvertisement(aliceAdapter.advertised[0]);
      bobAdapter.simulateInboundAdvertisement(aliceAdapter.advertised[1]);
      await pumpEventQueue();

      final generalMsgs = await bobRepo.getMessagesForChannel(MeshChatChannel.general.id);
      final hostelMsgs = await bobRepo.getMessagesForChannel(MeshChatChannel.hostelB.id);
      final studyMsgs = await bobRepo.getMessagesForChannel(MeshChatChannel.studyGroup.id);

      expect(generalMsgs.length, equals(1));
      expect(generalMsgs.first.text, equals('General chat message'));

      expect(hostelMsgs.length, equals(1));
      expect(hostelMsgs.first.text, equals('Hostel B only message'));

      expect(studyMsgs.isEmpty, isTrue);
    });

    test('TEST 10 & 11: Direct message conversation ID is deterministic and order-invariant', () {
      final dmId1 = MeshChatChannel.computeDirectMessageId('user_alice', 'user_bob');
      final dmId2 = MeshChatChannel.computeDirectMessageId('user_bob', 'user_alice');

      expect(dmId1, equals(dmId2));
      expect(dmId1, equals('dm:user_alice:user_bob'));

      final ch1 = MeshChatChannel.directMessage(participantA: 'node_b', participantB: 'node_a');
      final ch2 = MeshChatChannel.directMessage(participantA: 'node_a', participantB: 'node_b');
      expect(ch1.id, equals(ch2.id));
      expect(ch1.id, equals('dm:node_a:node_b'));
    });

    test('TEST 12: Hop count is preserved from packet telemetry', () async {
      // Alice creates message
      final msg = MeshChatMessage(
        messageId: 'relayed_001',
        senderDeviceId: 'user_alice',
        senderDisplayName: 'Alice Student',
        senderRole: 'student',
        channelId: 'channel:general',
        text: 'Multi-hop test',
        createdAt: DateTime.now(),
        hopCount: 3, // 3 hops observed
      );

      await aliceRepo.saveMessage(msg);
      final stored = (await aliceRepo.getMessagesForChannel('channel:general')).first;

      expect(stored.hopCount, equals(3));
      expect(stored.hopDescription, equals('3 hops · Relayed'));
    });

    test('TEST 13 & 14: Offline persistence survives service restart', () async {
      final sharedMemoryRepo = MeshChatRepository.inMemory();

      final service1 = MeshChatService(
        meshService: aliceMeshService,
        repository: sharedMemoryRepo,
      );
      await service1.initialize();

      await service1.sendMessage(
        channelId: MeshChatChannel.general.id,
        text: 'Persistent offline message',
      );

      final msgsBefore = await sharedMemoryRepo.getMessagesForChannel(MeshChatChannel.general.id);
      expect(msgsBefore.length, equals(1));

      // Simulate app restart by disposing service1 and launching service2 with same repository
      await service1.dispose();

      final service2 = MeshChatService(
        meshService: aliceMeshService,
        repository: sharedMemoryRepo,
      );
      await service2.initialize();

      final msgsAfter = await service2.getMessagesForChannel(MeshChatChannel.general.id);
      expect(msgsAfter.length, equals(1));
      expect(msgsAfter.first.text, equals('Persistent offline message'));

      await service2.dispose();
      await sharedMemoryRepo.close();
    });

    test('TEST 16 & 17: Outgoing and received message states are correctly represented', () async {
      final outgoing = await aliceChatService.sendMessage(
        channelId: MeshChatChannel.general.id,
        text: 'State test',
      );

      expect(outgoing.isOutgoing, isTrue);
      expect(outgoing.deliveryState, equals(MeshChatDeliveryState.relayed));

      // Deliver to Bob
      bobAdapter.simulateInboundAdvertisement(aliceAdapter.advertised.last);
      await pumpEventQueue();

      final received = (await bobRepo.getMessagesForChannel(MeshChatChannel.general.id)).first;
      expect(received.isOutgoing, isFalse);
      expect(received.deliveryState, equals(MeshChatDeliveryState.received));
    });

    test('TEST 18: Expired message outside clock skew is rejected by security boundary', () async {
      final oldTimestamp = DateTime.now().subtract(const Duration(minutes: 15));
      final payload = const MeshChatPayload(
        messageId: 'old_001',
        channelId: 'channel:general',
        text: 'Expired message',
      ).toBytes();

      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        senderDeviceId: 'user_alice',
        senderRole: 'student',
        timestamp: oldTimestamp,
        payload: payload,
      );

      final signed = await aliceCryptoService.signPacket(packet);
      bobAdapter.simulateInboundAdvertisement(codec.encode(signed));

      await pumpEventQueue();

      final messages = await bobRepo.getAllMessages();
      expect(messages.isEmpty, isTrue); // Rejected: staleTimestamp
    });

    test('TEST 19: Malformed chat payload bytes are handled gracefully without crash', () async {
      final garbagePayload = Uint8List.fromList([0xFF, 0xFE, 0x00, 0x11]);
      final packet = MeshPacket(
        packetId: MeshPacket.generatePacketId(),
        packetType: MeshPacketType.chat,
        senderDeviceId: 'user_alice',
        senderRole: 'student',
        timestamp: DateTime.now(),
        payload: garbagePayload,
      );

      final signed = await aliceCryptoService.signPacket(packet);
      bobAdapter.simulateInboundAdvertisement(codec.encode(signed));

      await pumpEventQueue();

      // Should not throw or crash, and repository remains clean
      final messages = await bobRepo.getAllMessages();
      expect(messages.isEmpty, isTrue);
    });

    test('TEST 20: Private keys and security credentials never stored in chat repository', () async {
      await aliceChatService.sendMessage(
        channelId: MeshChatChannel.general.id,
        text: 'Privacy verification',
      );

      final rawMessages = await aliceRepo.getAllMessages();
      expect(rawMessages.length, equals(1));
      final msg = rawMessages.first;

      final map = msg.toMap();
      final serialized = jsonEncode(map);

      // Verify no private key keywords or seeds appear
      expect(serialized.toLowerCase().contains('private'), isFalse);
      expect(serialized.toLowerCase().contains('secret'), isFalse);
      expect(serialized.toLowerCase().contains('seed'), isFalse);
      expect(serialized.toLowerCase().contains('jwt'), isFalse);
      expect(serialized.toLowerCase().contains('password'), isFalse);
    });

    test('TEST 21: MeshChatPayload and MeshChatMessage serialize and deserialize imageBase64', () {
      final sampleImageBase64 = base64Encode(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46]));
      final payload = MeshChatPayload(
        channelId: 'channel:general',
        text: 'Photo from campus library',
        senderDisplayName: 'Alice',
        imageBase64: sampleImageBase64,
      );

      final bytes = payload.toBytes();
      final decoded = MeshChatPayload.fromBytes(bytes);

      expect(decoded.channelId, equals('channel:general'));
      expect(decoded.text, equals('Photo from campus library'));
      expect(decoded.senderDisplayName, equals('Alice'));
      expect(decoded.imageBase64, equals(sampleImageBase64));

      final message = MeshChatMessage(
        messageId: 'msg-img-1',
        senderDeviceId: 'dev-alice',
        senderDisplayName: 'Alice',
        senderRole: 'student',
        channelId: 'channel:general',
        text: 'Look at this!',
        createdAt: DateTime.now(),
        imageBase64: sampleImageBase64,
      );

      expect(message.hasImage, isTrue);
      final map = message.toMap();
      final fromDb = MeshChatMessage.fromMap(map);
      expect(fromDb.hasImage, isTrue);
      expect(fromDb.imageBase64, equals(sampleImageBase64));
    });

    test('TEST 22: Alice sends image over mesh and Bob receives and stores imageBase64', () async {
      final sampleImageBase64 = base64Encode(Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]));
      
      final sent = await aliceChatService.sendMessage(
        channelId: MeshChatChannel.general.id,
        text: 'Check this diagram',
        imageBase64: sampleImageBase64,
      );

      expect(sent.hasImage, isTrue);
      expect(sent.imageBase64, equals(sampleImageBase64));

      // Alice's adapter advertised the packet
      expect(aliceAdapter.advertised.isNotEmpty, isTrue);
      final rawAdv = aliceAdapter.advertised.last;

      // Bob's radio receives the packet
      bobAdapter.simulateInboundAdvertisement(rawAdv);
      await pumpEventQueue();

      final bobMessages = await bobRepo.getMessagesForChannel(MeshChatChannel.general.id);
      expect(bobMessages.length, equals(1));
      final received = bobMessages.first;
      expect(received.text, equals('Check this diagram'));
      expect(received.hasImage, isTrue);
      expect(received.imageBase64, equals(sampleImageBase64));
    });
  });
}

