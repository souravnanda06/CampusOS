import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../auth/models/user_model.dart';
import '../../auth/providers/user_provider.dart';
import '../../core/theme/app_colors.dart';
import '../models/passport_proximity_observation.dart';
import '../models/passport_trust_bundle_model.dart';
import '../models/passport_verification_result.dart';
import '../services/passport_verifier_service.dart';
import '../services/passport_trust_bundle_service.dart';
import '../services/passport_offline_verifier_service.dart';
import '../../core/performance/performance.dart';
import '../../shared/widgets/campus_scanner_overlay.dart';
import '../../shared/widgets/motion/apple_spring_scroll_physics.dart';

/// CampusOS Passport Verifier Terminal (Phase 1E & 1F).
///
/// Enables authorized campus staff, wardens, teachers, and gate operators to verify
/// a student's rotating dynamic Passport QR:
/// 1. ONLINE mode: authoritative real-time verification via POST /passport/verify
/// 2. OFFLINE mode: 100% offline verification using local certified trust bundle
///
/// Features:
/// - Camera scanner with duplicate scan suppression and lifecycle safety.
/// - Dynamic ONLINE / OFFLINE mode selector.
/// - Local trust bundle synchronization, expiration tracking, and management sheet.
/// - Clear, authoritative presentation verification cards with offline limitation disclosure.
/// - Resettable "Scan Again" flow without controller leaks or navigation stacking.
/// - Role-based access gating preventing unauthorized student-to-student verification.
class PassportVerifierScreen extends StatefulWidget {
  final UserModel? user;
  final PassportVerifierService? verifierService;
  final PassportOfflineVerifierService? offlineVerifierService;
  final PassportTrustBundleService? trustBundleService;
  final MobileScannerController? controller;
  final bool initialOfflineMode;

  const PassportVerifierScreen({
    Key? key,
    this.user,
    this.verifierService,
    this.offlineVerifierService,
    this.trustBundleService,
    this.controller,
    this.initialOfflineMode = false,
  }) : super(key: key);

  @override
  State<PassportVerifierScreen> createState() => _PassportVerifierScreenState();
}

class _PassportVerifierScreenState extends State<PassportVerifierScreen> {
  late final PassportVerifierService _verifierService;
  late final PassportOfflineVerifierService _offlineVerifierService;
  late final PassportTrustBundleService _bundleService;
  late final MobileScannerController _controller;
  bool _ownsController = false;

  late bool _isOfflineMode;
  bool _isVerifying = false;
  bool _isProcessingScan = false;
  PassportVerificationResult? _verificationResult;
  String? _scannerErrorMessage;
  bool _isTorchOn = false;
  double _currentZoom = 0.0;
  double _baseZoom = 0.0;

  Timer? _validityCountdownTimer;
  PassportTrustBundle? _localBundle;

  @override
  void initState() {
    super.initState();
    _isOfflineMode = widget.initialOfflineMode;
    _bundleService = widget.trustBundleService ?? PassportTrustBundleService();
    _verifierService = widget.verifierService ?? PassportVerifierService();
    _offlineVerifierService = widget.offlineVerifierService ??
        PassportOfflineVerifierService(bundleService: _bundleService);

    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      final scannerConfig = PerformanceEngine.instance.profile.scannerProfile;
      _controller = MobileScannerController(
        cameraResolution: scannerConfig.targetResolution,
        detectionSpeed: DetectionSpeed.noDuplicates,
        returnImage: scannerConfig.returnImage,
      );
      _ownsController = true;
    }

    _loadLocalBundleMeta();
  }

  Future<void> _loadLocalBundleMeta() async {
    try {
      final b = await _bundleService.getLocalBundle();
      if (mounted) {
        setState(() {
          _localBundle = b;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _validityCountdownTimer?.cancel();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessingScan || _isVerifying || _verificationResult != null) {
      return;
    }

    final barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final code = barcode.rawValue;
      if (code != null && code.trim().isNotEmpty) {
        _handleDetectedQr(code.trim());
        break;
      }
    }
  }

  Future<void> _handleDetectedQr(String rawQr) async {
    setState(() {
      _isProcessingScan = true;
      _isVerifying = true;
      _scannerErrorMessage = null;
    });

    try {
      // Pause scanner while verification is underway
      await _controller.stop();
    } catch (_) {}

    try {
      final PassportVerificationResult result;
      if (_isOfflineMode) {
        // 100% Offline verification using local trust bundle
        result = await _offlineVerifierService.verifyOffline(qrPayload: rawQr);
      } else {
        // Online verification via POST /passport/verify
        result = await _verifierService.verifyQrString(rawQr);
      }

      if (!mounted) return;

      setState(() {
        _verificationResult = result;
        _isVerifying = false;
        _isProcessingScan = false;
      });

      if (result.isValid && result.expiresAt != null) {
        _startValidityCountdown();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verificationResult = _isOfflineMode
            ? PassportVerificationResult.offlineInvalidFormat(e.toString())
            : PassportVerificationResult.networkError(e.toString());
        _isVerifying = false;
        _isProcessingScan = false;
      });
    }
  }

  void _startValidityCountdown() {
    _validityCountdownTimer?.cancel();
    _validityCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_verificationResult == null || !_verificationResult!.isValid) {
        timer.cancel();
        return;
      }
      setState(() {});
    });
  }

  void _resetScanner() async {
    _validityCountdownTimer?.cancel();
    setState(() {
      _verificationResult = null;
      _isVerifying = false;
      _isProcessingScan = false;
      _scannerErrorMessage = null;
    });

    try {
      await _controller.start();
    } catch (e) {
      if (mounted) {
        setState(() {
          _scannerErrorMessage = "Unable to restart camera: $e";
        });
      }
    }
  }

  Future<void> _refreshTrustBundle() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Downloading latest CampusOS trust bundle..."),
          duration: Duration(seconds: 2),
        ),
      );
      final b = await _bundleService.downloadAndSaveBundle();
      if (mounted) {
        setState(() {
          _localBundle = b;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.success,
            content: Text("Trust bundle synced (${b.identities.length} active identities)."),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text("Sync failed: $e"),
          ),
        );
      }
    }
  }

  bool _isAuthorizedRole(UserModel? currentUser) {
    if (currentUser == null) return false;
    final r = currentUser.role.toLowerCase().trim();
    // Allow admin, warden, staff, teacher
    return r == 'admin' || r == 'warden' || r == 'staff' || r == 'teacher';
  }

  @override
  Widget build(BuildContext context) {
    final activeUser = widget.user ?? Provider.of<UserProvider>(context, listen: false).user;

    // Role-based verification gate
    if (activeUser != null && !_isAuthorizedRole(activeUser)) {
      return _buildAccessRestrictedScaffold();
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "Verify Passport",
                  style: GoogleFonts.plusJakartaSans(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                if (_isOfflineMode) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.info.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      "OFFLINE",
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Text(
              _isOfflineMode
                  ? "Offline cryptographic verification"
                  : "Scan a student's CampusOS Passport",
              style: GoogleFonts.plusJakartaSans(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          // Trust Bundle status / management sheet
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shield_outlined, color: AppColors.primary),
                if (_localBundle != null && !_localBundle!.isExpired())
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: "Trust Bundle",
            onPressed: _showTrustBundleSheet,
          ),

          if (_verificationResult == null && !_isVerifying) ...[
            IconButton(
              icon: Icon(
                _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                color: _isTorchOn ? AppColors.warning : AppColors.textSecondary,
              ),
              tooltip: "Toggle Flashlight",
              onPressed: () async {
                try {
                  await _controller.toggleTorch();
                  setState(() {
                    _isTorchOn = !_isTorchOn;
                  });
                } catch (_) {}
              },
            ),
            IconButton(
              icon: const Icon(Icons.flip_camera_ios_rounded, color: AppColors.textSecondary),
              tooltip: "Switch Camera",
              onPressed: () => _controller.switchCamera(),
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Mode Toggle Selector
            if (_verificationResult == null && !_isVerifying) _buildModeToggleBar(),

            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _verificationResult != null
                    ? _buildResultView(_verificationResult!)
                    : _isVerifying
                        ? _buildVerifyingOverlay()
                        : _buildScannerView(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeToggleBar() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (_isOfflineMode) {
                        setState(() {
                          _isOfflineMode = false;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: !_isOfflineMode ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_done_rounded,
                            size: 15,
                            color: !_isOfflineMode ? Colors.white : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "ONLINE",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: !_isOfflineMode ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (!_isOfflineMode) {
                        setState(() {
                          _isOfflineMode = true;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _isOfflineMode ? AppColors.info : Colors.transparent,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.cloud_off_rounded,
                            size: 15,
                            color: _isOfflineMode ? Colors.white : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "OFFLINE",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _isOfflineMode ? Colors.white : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isOfflineMode
                ? "Uses last trusted campus snapshot"
                : "Connected verification",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showTrustBundleSheet() async {
    await _loadLocalBundleMeta();
    if (!mounted) return;

    final bundle = _localBundle;
    final status = _bundleService.getBundleStatus(bundle);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Color statusColor;
            String statusLabel;
            switch (status) {
              case TrustBundleStatus.fresh:
                statusColor = AppColors.success;
                statusLabel = "Fresh & Valid";
                break;
              case TrustBundleStatus.expiringSoon:
                statusColor = AppColors.warning;
                statusLabel = "Expiring Soon";
                break;
              case TrustBundleStatus.expired:
                statusColor = AppColors.danger;
                statusLabel = "Expired";
                break;
              case TrustBundleStatus.missing:
                statusColor = AppColors.textSecondary;
                statusLabel = "Not Downloaded";
                break;
            }

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Passport Trust Data",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                "Local cryptographic anchors for offline verification",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 12),

                    // Metadata rows matching Section 17
                    _buildMetaRow("Status", "● $statusLabel", valueColor: statusColor),
                    _buildMetaRow(
                      "Last updated",
                      bundle != null
                          ? DateTime.fromMillisecondsSinceEpoch(bundle.generatedAt * 1000).toLocal().toString().split('.').first
                          : "Never",
                    ),
                    _buildMetaRow(
                      "Expires",
                      bundle != null
                          ? (bundle.isExpired()
                              ? "Expired"
                              : DateTime.fromMillisecondsSinceEpoch(bundle.expiresAt * 1000).toLocal().toString().split('.').first)
                          : "N/A",
                    ),
                    _buildMetaRow(
                      "Identities",
                      bundle != null ? "${bundle.identities.length}" : "0",
                    ),
                    _buildMetaRow(
                      "Institution",
                      bundle?.institution.keyId.isNotEmpty == true
                          ? bundle!.institution.keyId
                          : "CampusOS Root 2026",
                    ),

                    const SizedBox(height: 20),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              if (bundle != null) {
                                final isValid = await _bundleService.verifyBundleIntegrity(bundle);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: isValid ? AppColors.success : AppColors.danger,
                                      content: Text(
                                        isValid
                                            ? "✓ Institutional signature verified over bundle."
                                            : "❌ Bundle signature check failed.",
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                            label: const Text("Verify Bundle"),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(color: Colors.white24),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await _refreshTrustBundle();
                            },
                            icon: const Icon(Icons.sync_rounded, size: 16),
                            label: const Text("Refresh Trust Data"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMetaRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessRestrictedScaffold() {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          "Verify Passport",
          style: GoogleFonts.plusJakartaSans(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_person_rounded, size: 48, color: AppColors.danger),
              ),
              const SizedBox(height: 24),
              Text(
                "Staff & Authority Access Only",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                "Students cannot verify other passports. Only authorized staff, wardens, and checkpoint operators have access to the verification terminal.",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text("Return to Passport"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScannerView() {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = constraints.maxWidth;
              final screenHeight = constraints.maxHeight;
              final cutOutSize = min(screenWidth * 0.72, 275.0);
              final cutOutTop = (screenHeight * 0.38) - (cutOutSize / 2);
              final cutOutLeft = (screenWidth - cutOutSize) / 2;
              final cutOutRect = Rect.fromLTWH(cutOutLeft, cutOutTop, cutOutSize, cutOutSize);

              return Stack(
                children: [
                  Semantics(
                    label: "Passport QR camera scanner. Point camera at student's rotating Passport QR.",
                    child: GestureDetector(
                      onScaleStart: (_) => _baseZoom = _currentZoom,
                      onScaleUpdate: (details) {
                        final newZoom = (_baseZoom * details.scale).clamp(0.0, 1.0);
                        if (newZoom != _currentZoom) {
                          _currentZoom = newZoom;
                          _controller.setZoomScale(newZoom);
                        }
                      },
                      child: MobileScanner(
                        controller: _controller,
                        onDetect: _onDetect,
                        errorBuilder: (context, error) {
                          return Container(
                            color: Colors.black,
                            padding: const EdgeInsets.all(24),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.videocam_off_rounded, color: AppColors.danger, size: 44),
                                const SizedBox(height: 12),
                                Text(
                                  "Camera Initialization Error",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "${error.errorCode}: ${error.errorDetails?.message ?? 'Please ensure camera permissions are granted.'}",
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  // Dim overlay with rounded cutout
                  Positioned.fill(
                    child: CustomPaint(
                      painter: ScannerHoleOverlayPainter(
                        cutOutRect: cutOutRect,
                        borderRadius: 20.0,
                      ),
                    ),
                  ),

                  // 4 corner brackets
                  Positioned.fill(
                    child: CustomPaint(
                      painter: ScannerCornersPainter(
                        cutOutRect: cutOutRect,
                        cornerLength: 32.0,
                        cornerStroke: 3.8,
                        borderRadius: 20.0,
                      ),
                    ),
                  ),

                  // Subtitle guide text below viewfinder
                  Positioned(
                    top: cutOutTop + cutOutSize + 24,
                    left: 24,
                    right: 24,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Align student's Passport QR within frame",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 14.0,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Pinch to zoom for better focus",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 12.0,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Floating Torch Button
                  Positioned(
                    bottom: 24,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: CampusTorchButton(
                        isTorchOn: _isTorchOn,
                        onTap: () {
                          _controller.toggleTorch();
                          setState(() => _isTorchOn = !_isTorchOn);
                        },
                      ),
                    ),
                  ),

                  if (_scannerErrorMessage != null)
                    Positioned(
                      top: 16,
                      left: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _scannerErrorMessage!,
                          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),

        // Bottom instruction panel
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20.0),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isOfflineMode ? Icons.shield_outlined : Icons.qr_code_scanner_rounded,
                    color: _isOfflineMode ? AppColors.info : AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isOfflineMode
                        ? "Point at QR for Offline Verification"
                        : "Point the camera at the Passport QR",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _isOfflineMode
                    ? "Validates against cached CampusOS trust bundle. Zero network required."
                    : "Hold steady. Scans short-lived ~30s signed presentation.",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVerifyingOverlay() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 54,
            height: 54,
            child: CircularProgressIndicator(
              strokeWidth: 3.0,
              color: _isOfflineMode ? AppColors.info : AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _isOfflineMode ? "Verifying Offline..." : "Verifying Passport...",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isOfflineMode
                ? "Checking Ed25519 signature against local trust bundle."
                : "Validating cryptographic signature with CampusOS authority.",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ).animate().fadeIn(duration: 200.ms),
    );
  }

  Widget _buildResultView(PassportVerificationResult result) {
    if (result.isValid) {
      return _buildValidResultCard(result);
    } else {
      return _buildInvalidResultCard(result);
    }
  }

  Widget _buildValidResultCard(PassportVerificationResult result) {
    final user = result.user;
    final studentName = user?.name.toUpperCase() ?? 'VERIFIED STUDENT';
    final branch = user?.branch ?? 'Certified Campus Student';
    final year = user?.year ?? 'Active Semester';
    final regNo = user?.registrationNumber;
    final remainingSec = result.remainingSeconds;
    final isOffline = result.isOffline;

    return Semantics(
      label: "Passport valid. Identity certificate active for student $studentName.",
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        physics: AppleSpringScrollPhysics.always,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Success Card
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: AppColors.darkCardGradient,
                border: Border.all(
                  color: isOffline
                      ? AppColors.info.withValues(alpha: 0.7)
                      : AppColors.success.withValues(alpha: 0.6),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isOffline ? AppColors.info : AppColors.success).withValues(alpha: 0.18),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: (isOffline ? AppColors.info : AppColors.success).withValues(alpha: 0.15),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isOffline ? Icons.offline_pin_rounded : Icons.verified_rounded,
                              color: isOffline ? AppColors.info : AppColors.success,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "PASSPORT VALID",
                              style: GoogleFonts.plusJakartaSans(
                                color: isOffline ? AppColors.info : AppColors.success,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 0.8,
                              ),
                            ),
                            if (isOffline) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppColors.info.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.info.withValues(alpha: 0.6)),
                                ),
                                child: Text(
                                  "OFFLINE",
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.info,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (remainingSec > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (isOffline ? AppColors.info : AppColors.success).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: 13,
                                  color: isOffline ? AppColors.info : AppColors.success,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "Expires in ${remainingSec}s",
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isOffline ? AppColors.info : AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        // Verification Checkmark Icon
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: (isOffline ? AppColors.info : AppColors.success).withValues(alpha: 0.2),
                            border: Border.all(
                              color: isOffline ? AppColors.info : AppColors.success,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            color: isOffline ? AppColors.info : AppColors.success,
                            size: 36,
                          ),
                        ).animate().scale(duration: 350.ms, curve: Curves.easeOutBack),
                        const SizedBox(height: 20),

                        // Student Name
                        Text(
                          studentName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),

                        // Branch & Year
                        Text(
                          "$branch • $year",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        if (regNo != null && regNo.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            "ID: $regNo",
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),
                        const Divider(color: Colors.white24, height: 1),
                        const SizedBox(height: 16),

                        // Certified Status Chips
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _buildStatusTag("KEY ACTIVE", AppColors.success),
                            _buildStatusTag("CERTIFICATE ACTIVE", AppColors.success),
                            if (isOffline)
                              _buildStatusTag(
                                "SNAPSHOT: ${result.snapshotAgeDescription.toUpperCase()}",
                                AppColors.info,
                              ),
                            if (result.isChallengeBound)
                              _buildStatusTag("CHALLENGE-BOUND", AppColors.primary),
                            if (result.isProximityNear)
                              _buildStatusTag("BLE NEARBY", AppColors.success),
                            if (result.isProximityFar)
                              _buildStatusTag("BLE DISTANT", AppColors.warning),
                            if (result.isProximityUnstable)
                              _buildStatusTag("BLE UNSTABLE", AppColors.warning),
                          ],
                        ),

                        // Phase 1H: BLE Proximity Observation Card
                        if (result.hasProximitySignal || result.proximityObservation != null)
                          _buildProximityObservationCard(result),

                        if (isOffline) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.info.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.security_rounded, size: 14, color: AppColors.info),
                                    const SizedBox(width: 6),
                                    Text(
                                      "OFFLINE VERIFICATION",
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.info,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "Verified against CampusOS trust data${result.snapshotAgeDescription.isNotEmpty ? '\nupdated ${result.snapshotAgeDescription}' : ''}.",
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Divider(color: Colors.white12, height: 1),
                                const SizedBox(height: 8),
                                _buildCheckItem("Cryptographic signature valid"),
                                const SizedBox(height: 4),
                                _buildCheckItem("Institution certificate valid"),
                                const SizedBox(height: 4),
                                _buildCheckItem("Identity key trusted"),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),

                        // Boundary Note
                        Text(
                          isOffline
                              ? "Verified against CampusOS trust snapshot (${result.snapshotAgeDescription.isNotEmpty ? result.snapshotAgeDescription : 'cached'}). Does not reflect real-time revocations occurring after snapshot."
                              : "Certified CampusOS Identity Presentation • Proves device control. Not a gate or attendance authorization.",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.5),
                            height: 1.35,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.08),

            const SizedBox(height: 28),

            // Scan Again Button
            Semantics(
              label: "Scan another student's Passport QR",
              button: true,
              child: ElevatedButton.icon(
                onPressed: _resetScanner,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text("Scan Another Passport"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvalidResultCard(PassportVerificationResult result) {
    Color cardColor;
    IconData icon;

    if (result.isNetworkError) {
      cardColor = AppColors.textSecondary;
      icon = Icons.wifi_off_rounded;
    } else if (result.isExpired || result.isRevoked || result.isTrustDataExpired) {
      cardColor = AppColors.warning;
      icon = Icons.history_toggle_off_rounded;
    } else {
      cardColor = AppColors.danger;
      icon = Icons.gpp_bad_rounded;
    }

    return Semantics(
      label: "Passport verification failed. ${result.displayTitle}. ${result.displayMessage}",
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        physics: AppleSpringScrollPhysics.always,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: AppColors.darkCardGradient,
                border: Border.all(color: cardColor.withValues(alpha: 0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: cardColor.withValues(alpha: 0.15),
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Status Header Strip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: cardColor.withValues(alpha: 0.12),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                    ),
                    child: Row(
                      children: [
                        Icon(icon, color: cardColor, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          result.isOffline ? "OFFLINE VERIFICATION" : "VERIFICATION RESULT",
                          style: GoogleFonts.plusJakartaSans(
                            color: cardColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(28.0),
                    child: Column(
                      children: [
                        // Status Icon
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cardColor.withValues(alpha: 0.18),
                            border: Border.all(color: cardColor, width: 2),
                          ),
                          child: Icon(icon, color: cardColor, size: 34),
                        ).animate().scale(duration: 350.ms, curve: Curves.easeOutBack),
                        const SizedBox(height: 22),

                        // Title
                        Text(
                          result.displayTitle.toUpperCase(),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),

                        // Description
                        Text(
                          result.displayMessage,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.75),
                            height: 1.45,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        if (result.isTrustDataExpired || result.isTrustDataMissing) ...[
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            onPressed: _refreshTrustBundle,
                            icon: const Icon(Icons.cloud_download_rounded, size: 16),
                            label: const Text("Download Trust Data"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),
                        const Divider(color: Colors.white24, height: 1),
                        const SizedBox(height: 16),

                        // Code Tag
                        _buildStatusTag("STATUS: ${result.reason}", cardColor),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.08),

            const SizedBox(height: 28),

            // Scan Again Button
            Semantics(
              label: "Try scanning Passport QR again",
              button: true,
              child: ElevatedButton.icon(
                onPressed: _resetScanner,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text("Scan Again"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCheckItem(String text) {
    return Row(
      children: [
        const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }

  /// Phase 1H: Builds a BLE proximity observation card within the valid result view.
  ///
  /// CRITICAL ANTI-RELAY LANGUAGE:
  /// - NEVER says "Relay-proof", "Guaranteed nearby", "Impossible to spoof",
  ///   or "Physical presence verified".
  /// - Proximity is an additional physical-world signal, not cryptographic proof.
  Widget _buildProximityObservationCard(PassportVerificationResult result) {
    final obs = result.proximityObservation;
    final tier = obs?.proximityTier ?? PassportProximityTier.unknown;
    final confidence = obs?.confidence ?? PassportProximityConfidence.none;
    final medianRssi = obs?.medianRssi ?? result.medianRssi;
    final sampleCount = obs?.sampleCount ?? 0;
    final spread = obs?.spread;
    final description = result.proximitySummary;

    // Tier-specific colors and icons
    Color tierColor;
    IconData tierIcon;
    String tierLabel;
    switch (tier) {
      case PassportProximityTier.near:
        tierColor = AppColors.success;
        tierIcon = Icons.bluetooth_connected_rounded;
        tierLabel = 'Nearby Signal';
        break;
      case PassportProximityTier.far:
        tierColor = AppColors.warning;
        tierIcon = Icons.bluetooth_searching_rounded;
        tierLabel = 'Distant Signal';
        break;
      case PassportProximityTier.unstable:
        tierColor = AppColors.warning;
        tierIcon = Icons.bluetooth_disabled_rounded;
        tierLabel = 'Unstable Signal';
        break;
      case PassportProximityTier.unknown:
        tierColor = AppColors.textSecondary;
        tierIcon = Icons.bluetooth_rounded;
        tierLabel = 'No BLE Signal';
        break;
    }

    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: tierColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tierColor.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: icon + tier + confidence
              Row(
                children: [
                  Icon(tierIcon, size: 16, color: tierColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'BLE PROXIMITY SIGNAL',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: tierColor,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: tierColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      tierLabel.toUpperCase(),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: tierColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Description text (anti-relay compliant)
              Text(
                description,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.8),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              const Divider(color: Colors.white12, height: 1),
              const SizedBox(height: 10),

              // Metric rows
              Row(
                children: [
                  Expanded(
                    child: _buildProximityMetric(
                      'Samples',
                      '$sampleCount',
                      tierColor,
                    ),
                  ),
                  if (medianRssi != null)
                    Expanded(
                      child: _buildProximityMetric(
                        'Median',
                        '$medianRssi dBm',
                        tierColor,
                      ),
                    ),
                  if (spread != null)
                    Expanded(
                      child: _buildProximityMetric(
                        'Spread',
                        '$spread dBm',
                        tierColor,
                      ),
                    ),
                  Expanded(
                    child: _buildProximityMetric(
                      'Confidence',
                      confidence.displayName,
                      tierColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Disclaimer (MANDATORY anti-relay language)
              Text(
                'Proximity is an additional signal, not proof of physical presence. '
                'Identity authority is cryptographic (Ed25519 + certificate).',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.4),
                  height: 1.3,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProximityMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}
