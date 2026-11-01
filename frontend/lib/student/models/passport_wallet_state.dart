/// CampusOS Campus Wallet & Passport State Machine Models.
///
/// Explicitly models the lifecycle states of the Campus Wallet:
/// - Uninitialized (first-time device activation required)
/// - Initializing (keypair generation & server public key registration)
/// - Key Missing (local private key absent while enrolled; reactivation required)
/// - Reactivating (re-registering device identity)
/// - Locked (biometric protection active; credential hidden)
/// - Authenticating (biometric/PIN prompt active)
/// - Active (biometric unlocked, dynamic QR rotating, BLE ready)
/// - Auth Failed (biometric rejected or cancelled)
/// - Error (network, hardware, or crypto failure)
library passport_wallet_state;

/// Lifecycle state machine for the student's Campus Passport credential.
enum PassportWalletState {
  uninitialized,
  initializing,
  keyMissing,
  reactivating,
  locked,
  authenticating,
  active,
  authFailed,
  error;

  bool get isLocked => this == PassportWalletState.locked;
  bool get isActive => this == PassportWalletState.active;
  bool get isUninitialized => this == PassportWalletState.uninitialized;
  bool get isKeyMissing => this == PassportWalletState.keyMissing;
  bool get isProcessing =>
      this == PassportWalletState.initializing ||
      this == PassportWalletState.reactivating ||
      this == PassportWalletState.authenticating;
}

/// Identifies the extensible set of credential cards in the Campus Wallet.
enum WalletCardType {
  campusPassport(
    title: 'Campus Passport',
    subtitle: 'Verified Campus Identity',
  ),
  studentId(
    title: 'Student ID',
    subtitle: 'Institutional Identity Card',
  ),
  gatePass(
    title: 'Gate Pass',
    subtitle: 'Campus Transit Permission',
  );

  final String title;
  final String subtitle;

  const WalletCardType({
    required this.title,
    required this.subtitle,
  });
}
