import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_app/core/mesh/campus_mesh_service.dart';
import 'package:attendance_app/core/mesh/emergency/campus_mesh_emergency_service.dart';
import 'package:attendance_app/core/mesh/emergency/emergency_alert.dart';
import 'package:attendance_app/core/mesh/emergency/emergency_notifier.dart';
import 'package:attendance_app/core/mesh/emergency/mesh_emergency_repository.dart';
import 'package:attendance_app/core/mesh/mesh_deduplication_store.dart';
import 'package:attendance_app/core/mesh/mesh_peer_registry.dart';
import 'package:attendance_app/core/mesh/mesh_relay_engine.dart';
import 'package:attendance_app/shared/screens/campus_mesh_emergency_screen.dart';

import 'campus_mesh_service_test.dart';

void main() {
  group('CampusOS Mesh — CampusMeshEmergencyScreen Widget Tests', () {
    late FakeMeshBleAdapter fakeAdapter;
    late MeshEmergencyRepository repository;
    late CampusMeshService meshService;
    late CampusMeshEmergencyService emergencyService;
    late MockEmergencyNotifier notifier;

    setUp(() async {
      fakeAdapter = FakeMeshBleAdapter();
      repository = MeshEmergencyRepository.inMemory();
      notifier = MockEmergencyNotifier();

      meshService = CampusMeshService(
        localDeviceId: 'dean_tester',
        localRole: 'dean',
        adapter: fakeAdapter,
        deduplicationStore: MeshDeduplicationStore(maxSize: 50),
        peerRegistry: MeshPeerRegistry(),
        relayEngine: MeshRelayEngine(
          localDeviceId: 'dean_tester',
          deduplicationStore: MeshDeduplicationStore(maxSize: 50),
        ),
      );

      emergencyService = CampusMeshEmergencyService(
        meshService: meshService,
        repository: repository,
        notifier: notifier,
      );

      await emergencyService.initialize();
      await meshService.start();
    });

    tearDown(() async {
      await emergencyService.dispose();
      await meshService.dispose();
      await repository.close();
    });

    testWidgets('Renders active emergency alerts, critical banner, and trust badges', (tester) async {
      final now = DateTime.now();
      await repository.saveAlert(EmergencyAlert(
        alertId: 'flare_test_01',
        issuerDeviceId: 'dean_tester',
        issuerUserId: 'dean_sharma',
        issuerRole: 'dean',
        scope: EmergencyScope.campus,
        severity: EmergencySeverity.critical,
        category: EmergencyCategory.cyclone,
        title: 'Cyclone Dana Warning',
        message: 'Severe storm landfall expected. Stay indoors.',
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 4)),
        firstSeenAt: now,
        lastSeenAt: now,
        hopCount: 2,
        deliveryState: EmergencyDeliveryState.received,
        verificationState: 'TRUSTED',
        isAcknowledged: false,
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: CampusMeshEmergencyScreen(emergencyService: emergencyService),
        ),
      );

      await tester.pumpAndSettle();

      // Top bar title
      expect(find.text('Emergency Disaster Flare'), findsOneWidget);

      // Card severity & category
      expect(find.text('CRITICAL'), findsOneWidget);
      expect(find.text('Cyclone'), findsOneWidget);
      expect(find.text('[DEAN]'), findsOneWidget);

      // Title & message
      expect(find.text('Cyclone Dana Warning'), findsOneWidget);
      expect(find.text('Severe storm landfall expected. Stay indoors.'), findsOneWidget);

      // Telemetry & Trust
      expect(find.text('3 hops · Relayed'), findsOneWidget);
      expect(find.text('Scope: campus'), findsOneWidget);
      expect(find.text('Verified Authority'), findsOneWidget);

      // Acknowledge button
      expect(find.text('ACKNOWLEDGE'), findsOneWidget);
    });

    testWidgets('Tapping ACKNOWLEDGE marks alert acknowledged and updates UI', (tester) async {
      final now = DateTime.now();
      await repository.saveAlert(EmergencyAlert(
        alertId: 'flare_ack_test',
        issuerDeviceId: 'warden_hostel_b',
        issuerRole: 'warden',
        scope: EmergencyScope.hostel,
        severity: EmergencySeverity.warning,
        category: EmergencyCategory.fire,
        title: 'Hostel Fire Drill',
        message: 'Proceed to evacuation point B.',
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 2)),
        firstSeenAt: now,
        lastSeenAt: now,
        isAcknowledged: false,
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: CampusMeshEmergencyScreen(emergencyService: emergencyService),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Status: Active'), findsOneWidget);
      expect(find.text('ACKNOWLEDGE'), findsOneWidget);

      // Tap acknowledge
      await tester.tap(find.text('ACKNOWLEDGE'));
      await tester.pumpAndSettle();

      expect(find.text('Status: Acknowledged ✓'), findsOneWidget);
      expect(find.text('ACKNOWLEDGE'), findsNothing);
    });

    testWidgets('Toggling history view displays expired emergency alerts', (tester) async {
      final now = DateTime.now();
      // Expired alert
      await repository.saveAlert(EmergencyAlert(
        alertId: 'flare_expired_test',
        issuerDeviceId: 'admin_sys',
        issuerRole: 'admin',
        scope: EmergencyScope.campus,
        severity: EmergencySeverity.advisory,
        category: EmergencyCategory.power,
        title: 'Power Restored',
        message: 'Grid online.',
        createdAt: now.subtract(const Duration(hours: 5)),
        expiresAt: now.subtract(const Duration(hours: 2)), // Expired
        firstSeenAt: now,
        lastSeenAt: now,
        isAcknowledged: true,
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: CampusMeshEmergencyScreen(emergencyService: emergencyService),
        ),
      );

      await tester.pumpAndSettle();

      // In active view: should show all clear empty state
      expect(find.text('All Clear · No Active Alerts'), findsOneWidget);

      // Tap history toggle icon in app bar
      await tester.tap(find.byIcon(Icons.history));
      await tester.pumpAndSettle();

      // In history view: should show expired alert
      expect(find.text('Power Restored'), findsOneWidget);
      expect(find.text('Status: Expired'), findsOneWidget);
    });
  });
}
