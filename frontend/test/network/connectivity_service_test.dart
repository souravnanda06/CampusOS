import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:attendance_app/core/network/connectivity_service.dart';
import 'package:attendance_app/core/network/connectivity_state.dart';

/// Lightweight controllable Connectivity fake for testing.
class FakeConnectivity implements Connectivity {
  List<ConnectivityResult> _current;
  final StreamController<List<ConnectivityResult>> _controller =
      StreamController<List<ConnectivityResult>>.broadcast();

  FakeConnectivity(this._current);

  void emit(List<ConnectivityResult> results) {
    _current = results;
    _controller.add(results);
  }

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => _current;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;

  void dispose() => _controller.close();
}

/// Lightweight controllable HTTP client fake for testing.
class FakeHttpClient extends http.BaseClient {
  Future<http.Response> Function(http.BaseRequest request)? handler;

  FakeHttpClient([this.handler]);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (handler != null) {
      final response = await handler!(request);
      return http.StreamedResponse(
        Stream.value(response.bodyBytes),
        response.statusCode,
        headers: response.headers,
      );
    }
    return http.StreamedResponse(
      Stream.value(const [123, 125]), // '{}'
      200,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeConnectivity fakeConnectivity;
  late FakeHttpClient fakeHttpClient;
  late ConnectivityService service;

  setUp(() {
    fakeConnectivity = FakeConnectivity([ConnectivityResult.wifi]);
    fakeHttpClient = FakeHttpClient(
      (req) async => http.Response('{"status":"healthy"}', 200),
    );
    service = ConnectivityService.forTesting(
      connectivity: fakeConnectivity,
      httpClient: fakeHttpClient,
      baseUrl: 'http://127.0.0.1:5000',
      probeTimeout: const Duration(milliseconds: 300),
    );
  });

  tearDown(() {
    service.dispose();
    fakeConnectivity.dispose();
  });

  group('Phase 3A — Connectivity Engine & Network State Tests', () {
    test('1. No network interface produces OFFLINE state without HTTP call', () async {
      int httpCalls = 0;
      fakeHttpClient.handler = (req) async {
        httpCalls++;
        return http.Response('{"status":"healthy"}', 200);
      };

      fakeConnectivity._current = [ConnectivityResult.none];
      final status = await service.checkReachability(force: true);

      expect(status.state, equals(ConnectivityState.offline));
      expect(status.isOnline, isFalse);
      expect(status.isOffline, isTrue);
      expect(status.hasNetworkInterface, isFalse);
      expect(httpCalls, equals(0)); // Proves no HTTP ping wasted when interface is down
    });

    test('2. Network interface available with 200 OK produces BACKEND_REACHABLE (ONLINE)', () async {
      fakeConnectivity._current = [ConnectivityResult.wifi];
      fakeHttpClient.handler = (req) async {
        expect(req.url.path, equals('/health'));
        return http.Response('{"status":"healthy"}', 200);
      };

      final status = await service.checkReachability(force: true);

      expect(status.state, equals(ConnectivityState.backendReachable));
      expect(status.isOnline, isTrue);
      expect(status.isOffline, isFalse);
      expect(status.hasNetworkInterface, isTrue);
      expect(status.latency, isNotNull);
    });

    test('3. Mobile cellular interface also produces BACKEND_REACHABLE when verified', () async {
      fakeConnectivity._current = [ConnectivityResult.mobile];
      fakeHttpClient.handler = (req) async => http.Response('{"status":"healthy"}', 200);

      final status = await service.checkReachability(force: true);

      expect(status.state, equals(ConnectivityState.backendReachable));
      expect(status.activeInterfaces, contains(ConnectivityResult.mobile));
      expect(status.isOnline, isTrue);
    });

    test('4. Network interface available but backend returns 500 produces BACKEND_UNREACHABLE', () async {
      fakeConnectivity._current = [ConnectivityResult.wifi];
      fakeHttpClient.handler = (req) async => http.Response('{"error":"Internal Error"}', 500);

      final status = await service.checkReachability(force: true);

      expect(status.state, equals(ConnectivityState.backendUnreachable));
      expect(status.isOnline, isFalse);
      expect(status.isOffline, isTrue);
      expect(status.hasNetworkInterface, isTrue);
      expect(status.failureReason, contains('500'));
    });

    test('5. Backend probe timeout produces BACKEND_UNREACHABLE with timeout explanation', () async {
      fakeConnectivity._current = [ConnectivityResult.wifi];
      fakeHttpClient.handler = (req) async {
        // Sleep longer than probeTimeout (300ms)
        await Future.delayed(const Duration(milliseconds: 500));
        return http.Response('{"status":"healthy"}', 200);
      };

      final status = await service.checkReachability(force: true);

      expect(status.state, equals(ConnectivityState.backendUnreachable));
      expect(status.isOnline, isFalse);
      expect(status.failureReason, contains('timed out'));
    });

    test('6. SocketException / connection refused produces BACKEND_UNREACHABLE', () async {
      fakeConnectivity._current = [ConnectivityResult.wifi];
      fakeHttpClient.handler = (req) async {
        throw const SocketException('Connection refused');
      };

      final status = await service.checkReachability(force: true);

      expect(status.state, equals(ConnectivityState.backendUnreachable));
      expect(status.isOnline, isFalse);
      expect(status.failureReason, contains('Connection refused'));
    });

    test('7. App startup initializes listeners and triggers reachability probe', () async {
      final startupConnectivity = FakeConnectivity([ConnectivityResult.wifi]);
      final startupService = ConnectivityService.forTesting(
        connectivity: startupConnectivity,
        httpClient: fakeHttpClient,
      );

      startupService.init();
      // Allow async initial check to process
      await Future.delayed(const Duration(milliseconds: 50));

      expect(startupService.state, equals(ConnectivityState.backendReachable));
      startupService.dispose();
      startupConnectivity.dispose();
    });

    test('8. Network interface restoration automatically triggers backend probe and notifies listeners', () async {
      service.init();
      await Future.delayed(const Duration(milliseconds: 30));

      final stateHistory = <ConnectivityState>[];
      service.addListener(() {
        stateHistory.add(service.state);
      });

      // 1. Lose network (Airplane mode)
      fakeConnectivity.emit([ConnectivityResult.none]);
      await Future.delayed(const Duration(milliseconds: 30));
      expect(service.state, equals(ConnectivityState.offline));

      // 2. Restore network (Wi-Fi reconnects)
      fakeConnectivity.emit([ConnectivityResult.wifi]);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(service.state, equals(ConnectivityState.backendReachable));

      // Verified transition history: went offline, then restored to reachable
      expect(stateHistory, contains(ConnectivityState.offline));
      expect(stateHistory, contains(ConnectivityState.backendReachable));
    });

    test('9. App lifecycle resume triggers fresh reachability probe', () async {
      service.init();
      await Future.delayed(const Duration(milliseconds: 30));

      int probeCount = 0;
      fakeHttpClient.handler = (req) async {
        probeCount++;
        return http.Response('{"status":"healthy"}', 200);
      };

      // Simulate app resuming from background
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future.delayed(const Duration(milliseconds: 30));

      expect(service.state, equals(ConnectivityState.backendReachable));
      expect(probeCount, greaterThanOrEqualTo(1));
    });
  });
}
