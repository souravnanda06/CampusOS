import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_app/core/mesh/airdrop/campus_mesh_airdrop_service.dart';
import 'package:attendance_app/core/mesh/airdrop/mesh_airdrop_models.dart';
import 'package:attendance_app/core/mesh/airdrop/mesh_airdrop_repository.dart';
import 'package:attendance_app/core/mesh/airdrop/mesh_airdrop_storage.dart';
import 'package:attendance_app/core/mesh/campus_mesh_service.dart';
import 'package:attendance_app/core/mesh/mesh_deduplication_store.dart';
import 'package:attendance_app/core/mesh/mesh_peer_registry.dart';
import 'package:attendance_app/core/mesh/mesh_relay_engine.dart';
import 'package:attendance_app/shared/screens/campus_mesh_airdrop_screen.dart';

import 'campus_mesh_service_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CampusOS Mesh — CampusMeshAirDropScreen Widget Tests', () {
    late FakeMeshBleAdapter fakeAdapter;
    late MeshAirDropRepository repository;
    late Directory tempDir;
    late MeshAirDropStorage storage;
    late CampusMeshService meshService;
    late CampusMeshAirDropService airdropService;

    setUp(() async {
      fakeAdapter = FakeMeshBleAdapter();
      repository = MeshAirDropRepository.inMemory();
      tempDir = await Directory.systemTemp.createTemp('airdrop_widget_test_');
      storage = MeshAirDropStorage(customBaseDir: tempDir);

      meshService = CampusMeshService(
        localDeviceId: 'dev_sourav',
        localRole: 'student',
        adapter: fakeAdapter,
        deduplicationStore: MeshDeduplicationStore(maxSize: 50),
        peerRegistry: MeshPeerRegistry(),
        relayEngine: MeshRelayEngine(
          localDeviceId: 'dev_sourav',
          deduplicationStore: MeshDeduplicationStore(maxSize: 50),
        ),
      );

      airdropService = CampusMeshAirDropService(
        meshService: meshService,
        repository: repository,
        storage: storage,
      );

      await airdropService.initialize();
      await meshService.start();
    });

    tearDown(() async {
      await airdropService.dispose();
      await meshService.dispose();
      await repository.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    testWidgets('Renders mesh status, identity header, and academic file selector', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CampusMeshAirDropScreen(airdropService: airdropService),
        ),
      );

      await tester.pumpAndSettle();

      // App bar & status
      expect(find.text('Academic Mesh AirDrop'), findsOneWidget);
      expect(find.text('Mesh Active'), findsOneWidget);

      // Identity header
      expect(find.text('STUDENT'), findsOneWidget);
      expect(find.text('Verified Identity'), findsOneWidget);
      expect(find.text('Local Node: dev_sourav'), findsOneWidget);

      // File sender card
      expect(find.text('Send Academic File (<= 2 MB)'), findsOneWidget);
      expect(find.text('Send File Offer'), findsOneWidget);
    });

    testWidgets('Displays incoming file offer with verified badge and action buttons', (tester) async {
      final incomingOffer = MeshFileTransferSession(
        transferId: 'transfer_in_001',
        fileId: 'file_001',
        peerDeviceId: 'dev_teacher',
        peerDisplayName: 'Prof. Mohapatra',
        peerRole: 'teacher',
        isPeerVerified: true,
        direction: MeshTransferDirection.incoming,
        state: MeshFileTransferState.offered,
        filename: 'CS204_Lab_Manual.pdf',
        mimeType: 'application/pdf',
        fileSize: 1200 * 1024,
        transferredBytes: 0,
        totalChunks: 12,
        transferredChunks: 0,
        sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );

      await repository.saveTransfer(incomingOffer);

      await tester.pumpWidget(
        MaterialApp(
          home: CampusMeshAirDropScreen(airdropService: airdropService),
        ),
      );

      await tester.pumpAndSettle();

      // Incoming offer card
      expect(find.text('INCOMING FILE OFFERS'), findsOneWidget);
      expect(find.text('[TEACHER]'), findsOneWidget);
      expect(find.text('Prof. Mohapatra'), findsOneWidget);
      expect(find.text('Verified ✓'), findsOneWidget);
      expect(find.text('CS204_Lab_Manual.pdf'), findsOneWidget);
      expect(find.text('SHA-256 verified after transfer'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
    });

    testWidgets('Displays active transfer with progress, chunk counts, and cancel action', (tester) async {
      final activeTransfer = MeshFileTransferSession(
        transferId: 'transfer_active_001',
        fileId: 'file_002',
        peerDeviceId: 'peer_123',
        peerRole: 'student',
        direction: MeshTransferDirection.incoming,
        state: MeshFileTransferState.receiving,
        filename: 'DBMS_Notes.pdf',
        mimeType: 'application/pdf',
        fileSize: 1000 * 1024,
        transferredBytes: 720 * 1024,
        totalChunks: 33,
        transferredChunks: 24,
        sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );

      await repository.saveTransfer(activeTransfer);

      await tester.pumpWidget(
        MaterialApp(
          home: CampusMeshAirDropScreen(airdropService: airdropService),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('ACTIVE TRANSFERS'), findsOneWidget);
      expect(find.text('DBMS_Notes.pdf'), findsOneWidget);
      expect(find.text('Receiving'), findsOneWidget);
      expect(find.text('24 / 33 chunks'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Displays completed transfer with SHA-256 verified badge', (tester) async {
      final completedTransfer = MeshFileTransferSession(
        transferId: 'transfer_done_001',
        fileId: 'file_003',
        peerDeviceId: 'peer_123',
        peerRole: 'student',
        direction: MeshTransferDirection.incoming,
        state: MeshFileTransferState.completed,
        filename: 'DBMS_Unit3.pdf',
        mimeType: 'application/pdf',
        fileSize: 842 * 1024,
        transferredBytes: 842 * 1024,
        totalChunks: 33,
        transferredChunks: 33,
        sha256: 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        localFilePath: '/mock/path/DBMS_Unit3.pdf',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(minutes: 5)),
      );

      await repository.saveTransfer(completedTransfer);

      await tester.pumpWidget(
        MaterialApp(
          home: CampusMeshAirDropScreen(airdropService: airdropService),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('COMPLETED TRANSFERS'), findsOneWidget);
      expect(find.text('DBMS_Unit3.pdf'), findsOneWidget);
      expect(find.text('SHA-256 Verified ✓'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
    });
  });
}
