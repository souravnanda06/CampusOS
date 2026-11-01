import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_app/core/mesh/campus_mesh_service.dart';
import 'package:attendance_app/core/mesh/chat/mesh_chat_channel.dart';
import 'package:attendance_app/core/mesh/chat/mesh_chat_delivery_state.dart';
import 'package:attendance_app/core/mesh/chat/mesh_chat_message.dart';
import 'package:attendance_app/core/mesh/chat/mesh_chat_repository.dart';
import 'package:attendance_app/core/mesh/chat/mesh_chat_service.dart';
import 'package:attendance_app/core/mesh/mesh_deduplication_store.dart';
import 'package:attendance_app/core/mesh/mesh_peer_registry.dart';
import 'package:attendance_app/core/mesh/mesh_relay_engine.dart';
import 'package:attendance_app/shared/screens/campus_mesh_chat_screen.dart';

import 'campus_mesh_service_test.dart';

void main() {
  group('CampusOS Mesh — CampusMeshChatScreen Widget Tests', () {
    late FakeMeshBleAdapter fakeAdapter;
    late MeshChatRepository repository;
    late CampusMeshService meshService;
    late MeshChatService chatService;

    setUp(() async {
      fakeAdapter = FakeMeshBleAdapter();
      repository = MeshChatRepository.inMemory();
      meshService = CampusMeshService(
        localDeviceId: 'student_tester',
        localRole: 'student',
        adapter: fakeAdapter,
        deduplicationStore: MeshDeduplicationStore(maxSize: 50),
        peerRegistry: MeshPeerRegistry(),
        relayEngine: MeshRelayEngine(
          localDeviceId: 'student_tester',
          deduplicationStore: MeshDeduplicationStore(maxSize: 50),
        ),
      );

      chatService = MeshChatService(
        meshService: meshService,
        repository: repository,
      );

      await chatService.initialize();
      await meshService.start();
    });

    tearDown(() async {
      await chatService.dispose();
      await meshService.dispose();
      await repository.close();
    });

    testWidgets('Renders mesh status, channels, messages, and composer', (tester) async {
      // Seed a message into repository
      final testMsg = MeshChatMessage(
        messageId: 'seed_msg_001',
        senderDeviceId: 'dev_sourav',
        senderUserId: 'sourav_nanda',
        senderDisplayName: 'Sourav Nanda',
        senderRole: 'student',
        channelId: MeshChatChannel.general.id,
        text: 'Does anyone have the DBMS lab manual?',
        createdAt: DateTime.now(),
        hopCount: 3,
        deliveryState: MeshChatDeliveryState.received,
        verificationState: 'TRUSTED',
      );
      await repository.saveMessage(testMsg);

      await tester.pumpWidget(
        MaterialApp(
          home: CampusMeshChatScreen(chatService: chatService),
        ),
      );

      await tester.pumpAndSettle();

      // Top bar & status
      expect(find.text('CampusOS Mesh'), findsOneWidget);
      expect(find.text('🟢 Offline Mesh Active'), findsOneWidget);

      // Channel selectors
      expect(find.text('#general'), findsOneWidget);
      expect(find.text('#hostel-b'), findsOneWidget);
      expect(find.text('#study-group'), findsOneWidget);

      // Message content & telemetry
      expect(find.text('Sourav Nanda'), findsOneWidget);
      expect(find.text('[STUDENT]'), findsOneWidget);
      expect(find.text('Does anyone have the DBMS lab manual?'), findsOneWidget);
      expect(find.text('3 hops · Relayed'), findsOneWidget);
      expect(find.text('Verified ✓'), findsOneWidget);

      // Composer field & send button
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    });

    testWidgets('Switching channels filters messages cleanly', (tester) async {
      // General message
      await repository.saveMessage(MeshChatMessage(
        messageId: 'gen_1',
        senderDeviceId: 'dev_alice',
        senderDisplayName: 'Alice Student',
        senderRole: 'student',
        channelId: MeshChatChannel.general.id,
        text: 'General Announcement',
        createdAt: DateTime.now(),
        verificationState: 'TRUSTED',
      ));

      // Hostel message
      await repository.saveMessage(MeshChatMessage(
        messageId: 'hostel_1',
        senderDeviceId: 'dev_warden',
        senderDisplayName: 'Hostel Warden',
        senderRole: 'warden',
        channelId: MeshChatChannel.hostelB.id,
        text: 'Curfew is 9 PM tonight',
        createdAt: DateTime.now(),
        verificationState: 'TRUSTED',
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: CampusMeshChatScreen(chatService: chatService),
        ),
      );
      await tester.pumpAndSettle();

      // #general is active by default
      expect(find.text('General Announcement'), findsOneWidget);
      expect(find.text('Curfew is 9 PM tonight'), findsNothing);

      // Tap on #hostel-b chip
      await tester.tap(find.text('#hostel-b'));
      await tester.pumpAndSettle();

      // Now hostel message should be visible, and general message hidden
      expect(find.text('Curfew is 9 PM tonight'), findsOneWidget);
      expect(find.text('General Announcement'), findsNothing);
    });
  });
}
