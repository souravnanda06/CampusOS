import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_app/auth/models/user_model.dart';
import 'package:attendance_app/core/mesh/campus_mesh_service.dart';
import 'package:attendance_app/core/mesh/emergency/campus_mesh_emergency_service.dart';
import 'package:attendance_app/core/mesh/emergency/emergency_alert.dart';
import 'package:attendance_app/core/mesh/emergency/emergency_notifier.dart';
import 'package:attendance_app/core/mesh/emergency/mesh_emergency_repository.dart';
import 'package:attendance_app/core/mesh/mesh_deduplication_store.dart';
import 'package:attendance_app/core/mesh/mesh_peer_registry.dart';
import 'package:attendance_app/core/mesh/mesh_relay_engine.dart';
import 'package:attendance_app/student/screens/student_emergency_screen.dart';
import 'package:attendance_app/student/widgets/emergency/student_emergency_section.dart';

import '../mesh/campus_mesh_service_test.dart';

void main() {
  final testStudent = UserModel(
    id: 'std_emergency_01',
    name: 'Aarav Verma',
    email: 'aarav@campusos.edu',
    role: 'STUDENT',
    branch: 'CSE',
    course: 'B.Tech',
    year: '3rd',
  );

  group('Student Emergency Section & Siren UI Tests', () {
    late FakeMeshBleAdapter fakeAdapter;
    late MeshEmergencyRepository repository;
    late CampusMeshService meshService;
    late MockEmergencyNotifier notifier;
    late CampusMeshEmergencyService emergencyService;

    setUp(() async {
      fakeAdapter = FakeMeshBleAdapter();
      repository = MeshEmergencyRepository.inMemory();
      notifier = MockEmergencyNotifier();
      meshService = CampusMeshService(
        localDeviceId: 'std_emergency_01',
        localRole: 'student',
        adapter: fakeAdapter,
        deduplicationStore: MeshDeduplicationStore(maxSize: 50),
        peerRegistry: MeshPeerRegistry(),
        relayEngine: MeshRelayEngine(
          localDeviceId: 'std_emergency_01',
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

    testWidgets('StudentEmergencySection shows standby card and transitions to active siren card', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StudentEmergencySection(
              user: testStudent,
              emergencyService: emergencyService,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Emergency & SOS'), findsOneWidget);
      expect(find.text('READY'), findsOneWidget);

      final now = DateTime.now();
      final alert = EmergencyAlert(
        alertId: 'siren_alert_01',
        issuerDeviceId: 'dean_01',
        issuerRole: 'dean',
        scope: EmergencyScope.campus,
        severity: EmergencySeverity.critical,
        category: EmergencyCategory.fire,
        title: 'Block B Fire Evacuation',
        message: 'Evacuate Block B via north stairwell immediately.',
        createdAt: now,
        expiresAt: now.add(const Duration(hours: 2)),
        firstSeenAt: now,
        lastSeenAt: now,
        sirenEnabled: true,
        sirenPattern: EmergencySirenPattern.yelp,
      );
      await repository.saveAlert(alert);
      await notifier.notifyEmergency(alert);
      await tester.pumpAndSettle();

      expect(find.text('Block B Fire Evacuation'), findsOneWidget);
      expect(find.text('Silence Siren'), findsOneWidget);

      await tester.tap(find.text('Silence Siren'));
      await tester.pumpAndSettle();

      expect(notifier.stopCount, equals(1));
      expect(notifier.activeSirenAlert.value, isNull);
    });

    testWidgets('StudentEmergencyScreen broadcasts SOS with siren and tests local siren', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: StudentEmergencyScreen(
            user: testStudent,
            emergencyService: emergencyService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Emergency & Safety'), findsOneWidget);
      expect(find.text('Personal SOS & Siren Beacon'), findsOneWidget);
      expect(find.text('SEND SOS + SIREN'), findsOneWidget);
      expect(find.text('Campus Emergency Helplines'), findsOneWidget);

      await tester.ensureVisible(find.text('Test'));
      await tester.tap(find.text('Test'));
      await tester.pumpAndSettle();
      expect(notifier.sirenTestCount, equals(1));

      await tester.ensureVisible(find.text('SEND SOS + SIREN'));
      await tester.tap(find.text('SEND SOS + SIREN'));
      await tester.pumpAndSettle();

      expect(fakeAdapter.advertisedPackets.isNotEmpty, isTrue);
      final active = await emergencyService.getActiveEmergencies();
      expect(active.length, equals(1));
      expect(active.first.hasSiren, isTrue);
    });
  });
}
