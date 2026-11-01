import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/core/mesh/mesh_crypto.dart';

void main() {
  group('CampusOS Mesh — MeshCryptoService Tests', () {
    test('TEST 1: CampusMeshCryptoService signs and verifies Ed25519 signature successfully', () async {
      final algorithm = Ed25519();
      final keyPair = await algorithm.newKeyPair();
      final pubKey = await keyPair.extractPublicKey();

      final cryptoService = CampusMeshCryptoService(
        algorithm: algorithm,
        localKeyPair: keyPair,
      );

      final signableData = Uint8List.fromList([1, 2, 3, 4, 5, 42]);
      final signature = await cryptoService.sign(signableData);

      expect(signature.length, equals(64));

      final isValid = await cryptoService.verify(
        signableBytes: signableData,
        signature: signature,
        senderDeviceId: 'node_ed25519',
        senderPublicKey: Uint8List.fromList(pubKey.bytes),
      );

      expect(isValid, isTrue);
    });

    test('TEST 2: Corrupted signature fails verification without throwing', () async {
      final algorithm = Ed25519();
      final keyPair = await algorithm.newKeyPair();
      final pubKey = await keyPair.extractPublicKey();

      final cryptoService = CampusMeshCryptoService(algorithm: algorithm);

      final signableData = Uint8List.fromList([10, 20, 30]);
      final badSignature = Uint8List(64); // Zero signature

      final isValid = await cryptoService.verify(
        signableBytes: signableData,
        signature: badSignature,
        senderDeviceId: 'node_bad_sig',
        senderPublicKey: Uint8List.fromList(pubKey.bytes),
      );

      expect(isValid, isFalse);
    });

    test('TEST 3: Signing without configured keypair throws MeshCryptoException', () async {
      final cryptoService = CampusMeshCryptoService(); // No keypair
      final data = Uint8List.fromList([1, 2, 3]);

      expect(
        () => cryptoService.sign(data),
        throwsA(isA<MeshCryptoException>()),
      );
    });
  });
}
