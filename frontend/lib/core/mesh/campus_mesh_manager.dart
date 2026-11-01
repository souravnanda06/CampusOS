import 'dart:async';
import 'package:flutter/foundation.dart';

import 'campus_mesh_service.dart';
import 'mesh_crypto.dart';
import 'chat/mesh_chat_service.dart';
import 'chat/mesh_chat_repository.dart';
import 'emergency/campus_mesh_emergency_service.dart';
import 'emergency/mesh_emergency_repository.dart';
import 'emergency/dispatcher/emergency_dispatcher_service.dart';
import 'emergency/dispatcher/emergency_dispatcher_repository.dart';
import 'emergency/dispatcher/emergency_audit_repository.dart';
import 'airdrop/campus_mesh_airdrop_service.dart';
import 'airdrop/mesh_airdrop_repository.dart';
import 'simulator/mesh_node_radar.dart';
import 'simulator/physical_validation_harness.dart';
import 'simulator/stage_simulation_controller.dart';
import '../../auth/models/user_model.dart';
import '../../student/services/passport_crypto_service.dart';
import '../../student/services/passport_trust_bundle_service.dart';

/// Central singleton coordinator managing all CampusOS Mesh subsystems (Phases M1–M7).
///
/// Ensures unified lifecycle management, hardware radio reuse, and seamless access
/// from the student home screen, staff consoles, and hackathon stage simulators.
class CampusMeshManager with ChangeNotifier {
  CampusMeshManager._();
  static final CampusMeshManager instance = CampusMeshManager._();

  bool _isInitialized = false;
  String _localDeviceId = 'device_local';
  String _localRole = 'student';
  String _localDisplayName = 'Student';

  // Subsystem instances
  CampusMeshService? _meshService;
  CampusMeshCryptoService? _cryptoService;
  MeshChatService? _chatService;
  CampusMeshEmergencyService? _emergencyService;
  CampusMeshAirDropService? _airdropService;
  MeshEmergencyDispatcherService? _dispatcherService;
  MeshNodeRadarService? _radarService;
  PhysicalValidationHarnessService? _physicalHarness;
  StageSimulationController? _stageSimulatorController;

  StreamSubscription? _peerSubscription;
  int _activePeerCount = 0;

  bool get isInitialized => _isInitialized;
  String get localDeviceId => _localDeviceId;
  String get localRole => _localRole;
  String get localDisplayName => _localDisplayName;
  int get activePeerCount => _activePeerCount;

  bool get isMeshRunning => _meshService?.isRunning ?? false;

  CampusMeshService get meshService {
    _ensureInitialized();
    return _meshService!;
  }

  CampusMeshCryptoService get cryptoService {
    _ensureInitialized();
    return _cryptoService!;
  }

  MeshChatService get chatService {
    _ensureInitialized();
    return _chatService!;
  }

  CampusMeshEmergencyService get emergencyService {
    _ensureInitialized();
    return _emergencyService!;
  }

  CampusMeshAirDropService get airdropService {
    _ensureInitialized();
    return _airdropService!;
  }

  MeshEmergencyDispatcherService get dispatcherService {
    _ensureInitialized();
    return _dispatcherService!;
  }

  MeshNodeRadarService get radarService {
    _ensureInitialized();
    return _radarService!;
  }

  PhysicalValidationHarnessService get physicalHarness {
    _ensureInitialized();
    return _physicalHarness!;
  }

  StageSimulationController get stageSimulatorController {
    if (_stageSimulatorController == null) {
      _stageSimulatorController = StageSimulationController();
      _stageSimulatorController!.initializeTopology();
    }
    return _stageSimulatorController!;
  }

  /// Initializes the mesh stack with the current user credentials and certified keys.
  Future<void> initialize({UserModel? user}) async {
    if (_isInitialized && user?.id == _localDeviceId && user?.role == _localRole) {
      return;
    }

    if (user != null) {
      _localDeviceId = user.id.isNotEmpty ? user.id : 'user_${user.email.split('@')[0]}';
      _localRole = user.role.isNotEmpty ? user.role.toLowerCase() : 'student';
      _localDisplayName = user.name.isNotEmpty ? user.name : 'Student';
    }

    // 1. Cryptographic Identity & Trust Services
    final passportCrypto = PassportCryptoService();
    final trustBundleService = PassportTrustBundleService();
    _cryptoService = CampusMeshCryptoService(
      passportCryptoService: passportCrypto,
      trustBundleService: trustBundleService,
    );

    // 2. Core BLE Mesh Transport Service (M1 & M2)
    _meshService = CampusMeshService(
      localDeviceId: _localDeviceId,
      localRole: _localRole,
      cryptoService: _cryptoService,
    );

    // 3. Offline P2P Chat Service (M3)
    final chatRepo = MeshChatRepository.inMemory();
    _chatService = MeshChatService(
      meshService: _meshService!,
      repository: chatRepo,
      cryptoService: _cryptoService,
      trustBundleService: trustBundleService,
      localDisplayName: _localDisplayName,
    );
    unawaited(_chatService!.initialize());

    // 4. Disaster Flare Emergency Service (M4)
    final emergencyRepo = MeshEmergencyRepository.inMemory();
    _emergencyService = CampusMeshEmergencyService(
      meshService: _meshService!,
      repository: emergencyRepo,
      cryptoService: _cryptoService,
      trustBundleService: trustBundleService,
    );
    unawaited(_emergencyService!.initialize());

    // 5. Academic AirDrop Service (M5A & M5B)
    final airdropRepo = MeshAirDropRepository.inMemory();
    _airdropService = CampusMeshAirDropService(
      meshService: _meshService!,
      repository: airdropRepo,
      cryptoService: _cryptoService,
      trustBundleService: trustBundleService,
    );
    unawaited(_airdropService!.initialize());

    // 6. Dean Emergency Dispatcher Service (M6)
    final dispatcherRepo = MeshEmergencyDispatcherRepository.inMemory();
    final auditRepo = EmergencyAuditRepository.inMemory();
    _dispatcherService = MeshEmergencyDispatcherService(
      emergencyService: _emergencyService!,
      dispatcherRepository: dispatcherRepo,
      auditRepository: auditRepo,
      meshService: _meshService!,
      cryptoService: _cryptoService,
    );
    unawaited(_dispatcherService!.initialize());

    // 7. Node Radar & Physical Harness (M7)
    _radarService = MeshNodeRadarService(liveMeshService: _meshService!);
    _physicalHarness = PhysicalValidationHarnessService(
      meshService: _meshService!,
      cryptoService: _cryptoService,
    );

    // Listen to live peer count
    _peerSubscription?.cancel();
    _peerSubscription = _meshService!.peerUpdates.listen((peers) {
      _activePeerCount = peers.length;
      notifyListeners();
    });

    _isInitialized = true;
    notifyListeners();

    // Auto-start mesh radio in background so zero-touch P2P discovery is immediate
    unawaited(startMesh());
  }

  /// Dynamically updates the local node's role for duty delegation and drills.
  void setLocalRole(String newRole) {
    _localRole = newRole.trim().toLowerCase();
    _meshService?.setLocalRole(_localRole);
    notifyListeners();
  }

  /// Starts the background mesh BLE scanning engine.
  Future<bool> startMesh() async {
    _ensureInitialized();
    await _chatService?.initialize();
    await _emergencyService?.initialize();
    await _airdropService?.initialize();
    await _dispatcherService?.initialize();
    final ok = await _meshService!.start();
    notifyListeners();
    return ok;
  }

  /// Stops mesh scanning and advertising.
  Future<void> stopMesh() async {
    if (_meshService != null) {
      await _meshService!.stop();
      notifyListeners();
    }
  }

  /// Temporarily pauses background mesh BLE advertising to yield hardware advertiser
  /// slots to high-priority operations (e.g. Teacher or Student attendance broadcast).
  Future<void> pauseAdvertisingForAttendance() async {
    try {
      await _meshService?.pauseAdvertising();
    } catch (_) {}
  }

  /// Resumes background mesh BLE advertising after attendance finishes.
  Future<void> resumeAdvertisingAfterAttendance() async {
    try {
      await _meshService?.resumeAdvertising();
    } catch (_) {}
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      initialize();
    }
  }

  @override
  void dispose() {
    _peerSubscription?.cancel();
    _meshService?.stop();
    super.dispose();
  }
}
