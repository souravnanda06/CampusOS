import 'dart:async';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../auth/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../models/gate_security_models.dart';
import '../services/security_ble_verification_service.dart';
import '../services/security_gate_pass_service.dart';
import '../../core/performance/performance.dart';
import '../../shared/widgets/campus_scanner_overlay.dart';

/// Operational Gate Pass Verification Screen with BLE Primary + HMAC QR Fallback.
class SecurityVerifyScreen extends StatefulWidget {
  final UserModel user;
  final String gateName;
  final bool startWithQr;

  const SecurityVerifyScreen({
    Key? key,
    required this.user,
    this.gateName = 'Main Gate',
    this.startWithQr = false,
  }) : super(key: key);

  @override
  State<SecurityVerifyScreen> createState() => _SecurityVerifyScreenState();
}

class _SecurityVerifyScreenState extends State<SecurityVerifyScreen> with SingleTickerProviderStateMixin {
  final SecurityGatePassService _gateService = SecurityGatePassService();
  final SecurityBleVerificationService _bleService = SecurityBleVerificationService();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  StreamSubscription<GateBleState>? _bleStateSub;
  StreamSubscription<String>? _bleMessageSub;

  GateBleState _currentBleState = GateBleState.idle;
  String _statusMessage = 'Initializing verification radar...';

  bool _isQrMode = false;
  bool _isProcessing = false;
  bool _isTorchOn = false;
  double _currentZoom = 0.0;
  double _baseZoom = 0.0;
  MobileScannerController? _qrController;


  @override
  void initState() {
    super.initState();
    _isQrMode = widget.startWithQr;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _bleStateSub = _bleService.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _currentBleState = state;
        });
        if (state == GateBleState.qrFallback && !_isQrMode) {
          _switchToQrMode();
        }
      }
    });

    _bleMessageSub = _bleService.messageStream.listen((msg) {
      if (mounted) {
        setState(() {
          _statusMessage = msg;
        });
      }
    });

    if (_isQrMode) {
      _initQrScanner();
    } else {
      _startBleRadar();
    }
  }

  @override
  void dispose() {
    _bleStateSub?.cancel();
    _bleMessageSub?.cancel();
    _bleService.dispose();
    try {
      _qrController?.dispose();
    } catch (_) {}
    _qrController = null;
    _pulseController.dispose();
    super.dispose();
  }

  void _startBleRadar() {
    if (!_isQrMode && _currentBleState == GateBleState.active) return;
    try {
      _qrController?.dispose();
    } catch (_) {}
    _qrController = null;
    setState(() {
      _isQrMode = false;
      _currentBleState = GateBleState.starting;
      _statusMessage = 'Initializing BLE radar...';
    });
    _bleService.startScanning();
  }

  void _switchToQrMode() {
    if (_isQrMode && _qrController != null) return;
    _bleService.stopScanning();
    setState(() {
      _isQrMode = true;
      _currentBleState = GateBleState.qrFallback;
      _statusMessage = 'Scan student Gate Pass QR code';
    });
    _initQrScanner();
  }

  void _initQrScanner() {
    if (_qrController != null) return;
    final scannerConfig = PerformanceEngine.instance.profile.scannerProfile;
    _qrController = MobileScannerController(
      cameraResolution: scannerConfig.targetResolution,
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
      returnImage: scannerConfig.returnImage,
    );
  }

  Future<void> _handleQrScanned(String rawValue) async {
    if (_isProcessing || !mounted) return;
    _isProcessing = true;
    AppHaptics.mediumImpact();

    setState(() {
      _currentBleState = GateBleState.processing;
      _statusMessage = 'Validating HMAC credential...';
    });

    try {
      final result = await _gateService.verifyGatePass(
        rawValue,
        gateName: widget.gateName,
        guardId: widget.user.id,
      );

      if (!mounted) return;

      if (result.valid) {
        AppHaptics.heavyImpact();
        setState(() {
          _currentBleState = GateBleState.verified;
          _statusMessage = result.message;
        });
        _showVerificationModal(result);
      } else {
        AppHaptics.vibrate();
        setState(() {
          _currentBleState = result.resultCode == 'ALREADY_PROCESSED'
              ? GateBleState.duplicate
              : GateBleState.invalid;
          _statusMessage = result.message;
        });

        _showErrorSnackBar(result.message);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _isProcessing = false;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar("Verification error: $e");
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showVerificationModal(GateVerificationResult result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final pass = result.pass;
        final student = result.student;
        final isExit = result.action == 'EXIT';
        final isOffline = result.isOfflineVerified;

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (isExit ? AppColors.success : AppColors.primary).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isExit ? Icons.logout_rounded : Icons.login_rounded,
                          color: isExit ? AppColors.success : AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isExit ? "Gate Exit Verification" : "Gate Return Verification",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            isOffline ? "Verified Locally (Offline)" : "Verified via HMAC Gate Authority",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: isOffline ? AppColors.warning : AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      pass?.status ?? 'ISSUED',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Student Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      Icons.person_rounded,
                      "Student Name",
                      student?['name'] ?? 'Unknown',
                    ),
                    const Divider(height: 16, color: AppColors.border),
                    _buildDetailRow(
                      Icons.badge_rounded,
                      "Registration No",
                      student?['registrationNumber'] ?? 'N/A',
                    ),
                    const Divider(height: 16, color: AppColors.border),
                    _buildDetailRow(
                      Icons.location_on_rounded,
                      "Destination",
                      pass?.destination ?? 'Campus Transit',
                    ),
                    if (pass?.reason != null && pass!.reason.isNotEmpty) ...[
                      const Divider(height: 16, color: AppColors.border),
                      _buildDetailRow(
                        Icons.info_outline_rounded,
                        "Reason",
                        pass.reason,
                      ),
                    ],
                    const Divider(height: 16, color: AppColors.border),
                    _buildDetailRow(
                      Icons.timer_outlined,
                      "Valid Until",
                      pass != null
                          ? DateFormat('MMM dd, hh:mm a').format(pass.expectedReturnTime)
                          : 'Valid Today',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action CTA Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isExit ? const Color(0xFF10B981) : const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _executeGateTransition(result);
                },
                child: Text(
                  isExit ? "ALLOW EXIT" : "MARK RETURNED",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: const BorderSide(color: AppColors.border),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _resumeVerification();
                },
                child: Text(
                  "Dismiss",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      _resumeVerification();
    });
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Future<void> _executeGateTransition(GateVerificationResult result) async {
    final passId = result.gatePassId ?? result.pass?.id;
    if (passId == null) return;

    final isExit = result.action == 'EXIT';
    setState(() {
      _isProcessing = true;
      _statusMessage = isExit ? 'Recording student exit...' : 'Recording student return...';
    });

    try {
      final transitionResult = isExit
          ? await _gateService.recordExit(
              passId,
              guardId: widget.user.id,
              gateName: widget.gateName,
              verificationMode: _isQrMode ? 'QR_FALLBACK' : 'BLE',
            )
          : await _gateService.recordReturn(
              passId,
              guardId: widget.user.id,
              gateName: widget.gateName,
              verificationMode: _isQrMode ? 'QR_FALLBACK' : 'BLE',
            );

      AppHaptics.heavyImpact();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    transitionResult.message,
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar("Error executing transit: $e");
      }
    } finally {
      _resumeVerification();
    }
  }

  void _resumeVerification() {
    if (mounted) {
      setState(() {
        _isProcessing = false;
        _currentBleState = _isQrMode ? GateBleState.qrFallback : GateBleState.active;
        _statusMessage = _isQrMode ? 'Scan student Gate Pass QR' : 'Scanning for nearby gate passes...';
      });
    }
  }

  Color _getStatusColor() {
    switch (_currentBleState) {
      case GateBleState.verified:
        return AppColors.success;
      case GateBleState.duplicate:
      case GateBleState.qrFallback:
      case GateBleState.syncPending:
        return AppColors.warning;
      case GateBleState.failed:
      case GateBleState.invalid:
      case GateBleState.unavailable:
        return AppColors.error;
      case GateBleState.active:
      case GateBleState.starting:
      case GateBleState.processing:
        return AppColors.primary;
      case GateBleState.idle:
      case GateBleState.offline:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          "Gate Pass Verification",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: _isQrMode ? "Switch to BLE Radar" : "Switch to QR Scanner",
            icon: Icon(
              _isQrMode ? Icons.bluetooth_searching_rounded : Icons.qr_code_scanner_rounded,
              color: AppColors.primary,
            ),
            onPressed: () {
              if (_isQrMode) {
                _startBleRadar();
              } else {
                _switchToQrMode();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Explicit Status Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              border: Border(bottom: BorderSide(color: statusColor.withValues(alpha: 0.3))),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _currentBleState.displayName,
                  style: GoogleFonts.jetBrainsMono(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _statusMessage,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Main Interactive Area
          Expanded(
            child: _isQrMode ? _buildQrScannerView() : _buildBleRadarView(),
          ),

          // Bottom Toggle Controls
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(
                          color: !_isQrMode ? AppColors.primary : AppColors.border,
                          width: !_isQrMode ? 1.5 : 1,
                        ),
                      ),
                      icon: const Icon(Icons.bluetooth_searching_rounded, size: 20),
                      label: const Text("BLE Radar"),
                      onPressed: _startBleRadar,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(
                          color: _isQrMode ? AppColors.primary : AppColors.border,
                          width: _isQrMode ? 1.5 : 1,
                        ),
                      ),
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                      label: const Text("Use Gate Pass QR"),
                      onPressed: _switchToQrMode,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBleRadarView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.08),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.15),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.bluetooth_searching_rounded,
                        size: 54,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              "Listening for Nearby Gate Passes",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Students nearby will be verified automatically.\nIf signal is weak or BLE is unavailable, switch to QR code.",
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.qr_code_rounded, size: 20),
              label: const Text("Use Gate Pass QR Fallback"),
              onPressed: _switchToQrMode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrScannerView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        final cutOutSize = min(screenWidth * 0.72, 275.0);
        final cutOutTop = (screenHeight * 0.38) - (cutOutSize / 2);
        final cutOutLeft = (screenWidth - cutOutSize) / 2;
        final cutOutRect = Rect.fromLTWH(cutOutLeft, cutOutTop, cutOutSize, cutOutSize);

        return Stack(
          children: [
            if (_qrController != null)
              GestureDetector(
                onScaleStart: (_) => _baseZoom = _currentZoom,
                onScaleUpdate: (details) {
                  final newZoom = (_baseZoom * details.scale).clamp(0.0, 1.0);
                  if (newZoom != _currentZoom) {
                    _currentZoom = newZoom;
                    _qrController?.setZoomScale(newZoom);
                  }
                },
                child: MobileScanner(
                  controller: _qrController!,
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
                        _handleQrScanned(barcode.rawValue!);
                        break;
                      }
                    }
                  },
                  errorBuilder: (context, error) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.videocam_off_rounded, size: 54, color: AppColors.error),
                            const SizedBox(height: 16),
                            Text(
                              "Camera Access Required",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Please allow camera access in your device settings to scan Gate Pass QR codes.",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  try {
                                    _qrController?.dispose();
                                  } catch (_) {}
                                  _qrController = null;
                                });
                                _initQrScanner();
                                setState(() {});
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text("Retry Camera"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              )
            else
              Container(color: Colors.black),

            // Dim Overlay with rounded cutout hole
            Positioned.fill(
              child: CustomPaint(
                painter: ScannerHoleOverlayPainter(
                  cutOutRect: cutOutRect,
                  borderRadius: 20.0,
                ),
              ),
            ),

            // Viewfinder 4 corner brackets
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
                    "Align student Gate Pass QR within frame",
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

            // Floating Torch button
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: CampusTorchButton(
                  isTorchOn: _isTorchOn,
                  onTap: () {
                    _qrController?.toggleTorch();
                    setState(() => _isTorchOn = !_isTorchOn);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
