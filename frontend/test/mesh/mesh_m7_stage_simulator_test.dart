import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:attendance_app/core/mesh/simulator/mesh_node_radar.dart';
import 'package:attendance_app/core/mesh/simulator/mesh_validation_exporter.dart';
import 'package:attendance_app/core/mesh/simulator/physical_validation_harness.dart';
import 'package:attendance_app/core/mesh/simulator/stage_simulation_controller.dart';
import 'package:attendance_app/shared/screens/campus_mesh_node_radar_screen.dart';
import 'package:attendance_app/shared/screens/campus_mesh_physical_validation_screen.dart';
import 'package:attendance_app/shared/screens/campus_mesh_stage_simulator_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CampusOS Mesh — Phase M7: Stage Simulator & Physical Validation Tests', () {
    late StageSimulationController controller;

    setUp(() async {
      controller = StageSimulationController();
      await controller.initializeTopology();
    });

    tearDown(() async {
      await controller.dispose();
    });

    // =========================================================================
    // GROUP A: Simulator Node Creation & Roles
    // =========================================================================
    test('Group A: 4 virtual nodes created with distinct roles and coordinates', () {
      expect(controller.virtualNodes.length, 4);

      final dean = controller.nodeDean;
      expect(dean.nodeId, 'node_dean_a');
      expect(dean.role, 'dean');
      expect(dean.isOnline, isTrue);
      expect(dean.isTrusted, isTrue);

      final relay = controller.nodeRelay;
      expect(relay.nodeId, 'node_relay_b');
      expect(relay.isOnline, isTrue);

      final student = controller.nodeStudent;
      expect(student.nodeId, 'node_student_c');
      expect(student.role, 'student');

      final warden = controller.nodeWarden;
      expect(warden.nodeId, 'node_warden_d');
      expect(warden.role, 'warden');
    });

    // =========================================================================
    // GROUP B: Virtual Topology Connectivity & Link States
    // =========================================================================
    test('Group B: Topological links match campus layout and support dynamic enable/disable', () {
      final medium = controller.medium;

      expect(medium.hasActiveLink('node_dean_a', 'node_relay_b'), isTrue);
      expect(medium.hasActiveLink('node_relay_b', 'node_student_c'), isTrue);
      expect(medium.hasActiveLink('node_relay_b', 'node_warden_d'), isTrue);
      // Dean A is NOT directly linked to Student C (must hop through Relay B)
      expect(medium.hasActiveLink('node_dean_a', 'node_student_c'), isFalse);

      // Disable link A <-> B
      medium.setLinkEnabled('node_dean_a', 'node_relay_b', false);
      expect(medium.hasActiveLink('node_dean_a', 'node_relay_b'), isFalse);

      // Re-enable link
      medium.setLinkEnabled('node_dean_a', 'node_relay_b', true);
      expect(medium.hasActiveLink('node_dean_a', 'node_relay_b'), isTrue);
    });

    // =========================================================================
    // GROUP C: Scenario 1 — Emergency Propagation (A -> B -> C & D)
    // =========================================================================
    test('Group C: Scenario 1 dispatches signed emergency alert multi-hop across topology', () async {
      await controller.runEmergencyPropagationScenario();

      expect(controller.activeEmergencyAlertId, isNotNull);
      expect(controller.timeline.isNotEmpty, isTrue);

      // Verify event sequence in timeline
      final events = controller.timeline;
      final createdEvent = events.any((e) => e.eventType == SimulationEventType.packetCreated);
      final signedEvent = events.any((e) => e.eventType == SimulationEventType.packetSigned);
      final relayEvent = events.any((e) => e.eventType == SimulationEventType.hopRelayed);
      final verifiedEvent = events.any((e) => e.eventType == SimulationEventType.packetVerified);

      expect(createdEvent, isTrue);
      expect(signedEvent, isTrue);
      expect(relayEvent, isTrue);
      expect(verifiedEvent, isTrue);

      // Check stats: Relay B must have forwarded packet
      expect(controller.nodeRelay.stats.packetsRelayed, greaterThanOrEqualTo(1));
    });

    // =========================================================================
    // GROUP D: Scenario 2 — Mesh Chat Simulation (C -> B -> A)
    // =========================================================================
    test('Group D: Scenario 2 transmits chat message from Student C through Relay B to Dean A', () async {
      await controller.runMeshChatScenario(messageText: 'Testing P2P Chat');

      final events = controller.timeline;
      final chatCreated = events.any((e) => e.summary.contains('Testing P2P Chat'));
      final chatRelayed = events.any((e) => e.sourceNodeId == 'node_relay_b' && e.eventType == SimulationEventType.hopRelayed);

      expect(chatCreated, isTrue);
      expect(chatRelayed, isTrue);
    });

    // =========================================================================
    // GROUP E: Scenario 3 — AirDrop Transfer & SHA-256
    // =========================================================================
    test('Group E: Scenario 3 simulates AirDrop offer, acceptance, streaming, and SHA-256 check', () async {
      await controller.runAirDropScenario();

      final events = controller.timeline;
      final airdropDone = events.any((e) => e.eventType == SimulationEventType.airDropCompleted);
      expect(airdropDone, isTrue);
    });

    // =========================================================================
    // GROUP F: Scenario 4 — Signed Emergency Cancellation
    // =========================================================================
    test('Group F: Scenario 4 broadcasts signed cancellation and transitions nodes to cancelled', () async {
      // First create active emergency
      await controller.runEmergencyPropagationScenario();

      // Then cancel
      await controller.runEmergencyCancellationScenario();

      final events = controller.timeline;
      final cancelledEvents = events.where((e) => e.eventType == SimulationEventType.cancelled);
      expect(cancelledEvents.isNotEmpty, isTrue);
    });

    // =========================================================================
    // GROUP G: Scenario 5 — Node Failure & Route Interruption
    // =========================================================================
    test('Group G: Scenario 5 demonstrates that taking Relay B offline breaks path A -> C', () async {
      await controller.runNodeFailureScenario();

      final events = controller.timeline;
      final offlineRecorded = events.any((e) => e.summary.contains('went OFFLINE'));
      final routeFailed = events.any((e) => e.summary.contains('failed to reach Student Alice'));

      expect(offlineRecorded, isTrue);
      expect(routeFailed, isTrue);
      expect(controller.nodeRelay.isOnline, isTrue); // Restored
    });

    // =========================================================================
    // GROUP H: Scenario 6 — Duplicate Packet Suppression
    // =========================================================================
    test('Group H: Scenario 6 suppresses duplicate packet retransmission at Relay B', () async {
      await controller.runDuplicatePacketScenario();

      final events = controller.timeline;
      final dupEvent = events.any((e) => e.eventType == SimulationEventType.deduplicated);
      expect(dupEvent, isTrue);
      expect(controller.nodeRelay.stats.packetsDeduplicated, greaterThanOrEqualTo(1));
    });

    // =========================================================================
    // GROUP I: Scenario 7 — Tampered Packet & Signature Failure
    // =========================================================================
    test('Group I: Scenario 7 detects payload tampering and rejects packet', () async {
      await controller.runTamperedSignatureScenario();

      final events = controller.timeline;
      final rejected = events.any((e) => e.summary.contains('Signature Verification FAILED'));
      expect(rejected, isTrue);
      expect(controller.nodeRelay.stats.packetsRejected, greaterThanOrEqualTo(1));
    });

    // =========================================================================
    // GROUP J: Scenario 8 — TTL Expiration & Hop Bounding
    // =========================================================================
    test('Group J: Scenario 8 bounds routing: packet with TTL=1 is dropped after first hop', () async {
      await controller.runTtlExpirationScenario();

      final events = controller.timeline;
      final expired = events.any((e) => e.eventType == SimulationEventType.ttlExpired);
      expect(expired, isTrue);
    });

    // =========================================================================
    // GROUP K: Physical Validation Harness State Machine
    // =========================================================================
    test('Group K: PhysicalValidationHarnessService operates in Source role and records telemetry', () async {
      final harness = PhysicalValidationHarnessService(
        meshService: controller.nodeDean.meshService,
        cryptoService: controller.nodeDean.cryptoService,
      );

      final preflight = await harness.checkPreflight();
      expect(preflight.isReadyForTest, isTrue);

      final telemetry = await harness.runSourceBroadcastTest(
        testType: PhysicalTestType.emergency,
        testMessage: 'Physical validation unit test',
      );

      expect(telemetry.status, PhysicalTestStatus.pass);
      expect(telemetry.operatorRole, PhysicalTestRole.source);
      expect(telemetry.testType, PhysicalTestType.emergency);
      expect(harness.testHistory.length, 1);

      await harness.dispose();
    });

    // =========================================================================
    // GROUP L: Truthful Telemetry Separation
    // =========================================================================
    test('Group L: Truthful telemetry strictly separates simulation from physical hardware', () {
      final simJson = MeshValidationExporter.exportSimulationEventsToJson(controller.timeline);
      expect(simJson.contains('SOFTWARE_SIMULATION'), isTrue);
      expect(simJson.contains('SIMULATED DATA · NOT PHYSICAL RADIO MEASUREMENT'), isTrue);

      final physTele = PhysicalTestTelemetry(
        testId: 'M7-PHYS-TEST-001',
        testType: PhysicalTestType.emergency,
        operatorRole: PhysicalTestRole.receiver,
        sourceDeviceId: 'node_dean',
        packetIdHex: '1234567890abcdef',
        hopCount: 2,
        latencyMs: 145,
        status: PhysicalTestStatus.pass,
      );

      final physJson = MeshValidationExporter.exportPhysicalTelemetryToJson([physTele]);
      expect(physJson.contains('PHYSICAL_HARDWARE'), isTrue);
      expect(physJson.contains('M7-PHYS-TEST-001'), isTrue);
    });

    // =========================================================================
    // GROUP M: Telemetry Exporter (CSV & JSON)
    // =========================================================================
    test('Group M: MeshValidationExporter exports valid CSV and JSON without secrets', () {
      final telemetry = PhysicalTestTelemetry(
        testId: 'M7-TEST-CSV',
        testType: PhysicalTestType.chat,
        operatorRole: PhysicalTestRole.relay,
        sourceDeviceId: 'dev_a',
        relayDeviceId: 'dev_b',
        packetIdHex: 'aabbccddeeff0011',
        hopCount: 1,
        ttl: 6,
        latencyMs: 42,
        status: PhysicalTestStatus.pass,
      );

      final csv = MeshValidationExporter.exportPhysicalTelemetryToCsv([telemetry]);
      expect(csv.contains('test_id,test_type,operator_role'), isTrue);
      expect(csv.contains('M7-TEST-CSV,chat,relay,dev_a,dev_b'), isTrue);

      // Verify ZERO private keys exported
      expect(csv.contains('privateKey'), isFalse);
      expect(csv.contains('secret'), isFalse);
    });

    // =========================================================================
    // GROUP N: UI Widget Tests (Simulator, Radar, Physical Test Screen)
    // =========================================================================
    testWidgets('Group N: CampusMeshStageSimulatorScreen renders simulation banner, topology, and scenarios', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: CampusMeshStageSimulatorScreen(controller: controller),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('STAGE SIMULATOR · SIMULATED NETWORK'), findsOneWidget);
      expect(find.text('CAMPUS MESH TOPOLOGY'), findsOneWidget);
      expect(find.text('60s M7 HACKATHON DEMO RUNNER'), findsOneWidget);
      expect(find.text('1. Emergency Flare'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Group N: CampusMeshNodeRadarScreen renders radar visualizer and peer list', (tester) async {
      final radarService = MeshNodeRadarService();
      radarService.setSimulatedNodes([
        RadarNodeItem(
          deviceId: 'node_dean_a',
          displayName: 'Dean Sharma',
          role: 'dean',
          isTrusted: true,
          rssi: -58,
          hopCount: 0,
          lastSeen: DateTime.now(),
        ),
      ]);

      await tester.pumpWidget(MaterialApp(
        home: CampusMeshNodeRadarScreen(radarService: radarService),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Mesh Node Radar'), findsOneWidget);
      expect(find.text('Dean Sharma'), findsOneWidget);
      expect(find.text('DEAN · VERIFIED'), findsOneWidget);

      await radarService.dispose();
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Group N: CampusMeshPhysicalValidationScreen renders physical banner and role selector', (tester) async {
      final harness = PhysicalValidationHarnessService(
        meshService: controller.nodeDean.meshService,
        cryptoService: controller.nodeDean.cryptoService,
      );

      await tester.pumpWidget(MaterialApp(
        home: CampusMeshPhysicalValidationScreen(harnessService: harness),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('PHYSICAL MESH TEST · NOT SIMULATION'), findsOneWidget);
      expect(find.text('ASSIGN DEVICE TEST ROLE'), findsOneWidget);
      expect(find.text('HARDWARE PRE-FLIGHT CHECKLIST'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await harness.dispose();
    });
  });
}
