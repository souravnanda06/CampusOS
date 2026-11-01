import 'dart:async';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../auth/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../student/models/mess_model.dart';
import '../../student/models/passport_verification_result.dart';
import '../../student/services/mess_service.dart';
import '../../student/services/passport_verifier_service.dart';
import '../../student/services/passport_offline_verifier_service.dart';
import '../../core/performance/performance.dart';
import '../../shared/widgets/campus_scanner_overlay.dart';

/// Result state displayed in HUD overlay after scanning a student's Passport QR.
class MessScanResult {
  final MealVerificationStatus status;
  final String title;
  final String message;
  final String? studentName;
  final String? registrationNumber;
  final String mealType;
  final bool isOffline;

  MessScanResult({
    required this.status,
    required this.title,
    required this.message,
    this.studentName,
    this.registrationNumber,
    required this.mealType,
    this.isOffline = false,
  });
}

/// CampusOS Mess QR Scanner Fallback Screen.
///
/// High-throughput dining verification terminal using student's rotating Passport QR.
/// Implements authentic cryptographic verification via Ed25519 and institutional trust bundle.
/// Provides continuous hands-free scanning with fast HUD confirmations, duplicate detection,
/// offline local trust verification and queuing, and explicit [ End QR Verification ] action.
class MessQrScannerScreen extends StatefulWidget {
  final UserModel? user;
  final String mealType;
  final String date;
  final MessService? messService;
  final PassportVerifierService? passportVerifierService;
  final PassportOfflineVerifierService? offlineVerifierService;
  final MobileScannerController? controller;
  final bool initialOfflineMode;

  const MessQrScannerScreen({
    Key? key,
    required this.user,
    required this.mealType,
    required this.date,
    this.messService,
    this.passportVerifierService,
    this.offlineVerifierService,
    this.controller,
    this.initialOfflineMode = false,
  }) : super(key: key);

  @override
  State<MessQrScannerScreen> createState() => MessQrScannerScreenState();
}

class MessQrScannerScreenState extends State<MessQrScannerScreen> {
  late final MessService _messService;
  late final PassportVerifierService _verifierService;
  late final PassportOfflineVerifierService _offlineVerifierService;
  late final MobileScannerController _controller;
  bool _ownsController = false;

  late bool _isOfflineMode;
  bool _isProcessingScan = false;
  bool _isTorchOn = false;
  MessScanResult? _currentResult;
  Timer? _autoResetTimer;
  double _currentZoom = 0.0;
  double _baseZoom = 0.0;

  int _sessionScanCount = 0;
  int _sessionSuccessCount = 0;

  int get sessionScanCount => _sessionScanCount;
  int get sessionSuccessCount => _sessionSuccessCount;

  @override
  void initState() {
    super.initState();
    _isOfflineMode = widget.initialOfflineMode;
    _messService = widget.messService ?? MessService();
    _verifierService = widget.passportVerifierService ?? PassportVerifierService();
    _offlineVerifierService =
        widget.offlineVerifierService ?? PassportOfflineVerifierService();

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
  }

  @override
  void dispose() {
    _autoResetTimer?.cancel();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> handleDetectedBarcode(BarcodeCapture capture) => _onDetect(capture);

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessingScan || _currentResult != null) return;

    final barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final code = barcode.rawValue;
      if (code != null && code.trim().isNotEmpty) {
        await _handleScannedPayload(code.trim());
        break;
      }
    }
  }

  Future<void> _handleScannedPayload(String rawQr) async {
    setState(() {
      _isProcessingScan = true;
      _currentResult = null;
    });

    try {
      _controller.stop();
    } catch (_) {}

    try {
      _sessionScanCount += 1;

      // 1. Cryptographic credential verification
      final PassportVerificationResult cryptoResult;
      if (_isOfflineMode) {
        cryptoResult = await _offlineVerifierService.verifyOffline(qrPayload: rawQr);
      } else {
        cryptoResult = await _verifierService.verifyQrString(rawQr);
      }

      if (!cryptoResult.valid) {
        // Cryptographic check failed
        AppHaptics.heavyImpact();
        _showResult(
          MessScanResult(
            status: MealVerificationStatus.invalid,
            title: '✕ VERIFICATION FAILED',
            message: cryptoResult.reason.isNotEmpty
                ? cryptoResult.reason
                : 'Invalid credential signature or tampered QR.',
            mealType: widget.mealType,
          ),
        );
        return;
      }

      final studentId = cryptoResult.userId ?? '';
      final studentName = cryptoResult.user?.name ?? 'Student';
      final regNumber = cryptoResult.user?.registrationNumber;

      if (studentId.isEmpty) {
        AppHaptics.heavyImpact();
        _showResult(
          MessScanResult(
            status: MealVerificationStatus.invalid,
            title: '✕ VERIFICATION FAILED',
            message: 'Student identifier missing from verified credential.',
            mealType: widget.mealType,
          ),
        );
        return;
      }

      // 2. Meal eligibility, duplicate protection & entry recording
      if (_isOfflineMode) {
        // Offline: record in local queue and prevent local duplicates
        final queued = await _messService.getQueuedOfflineMealEntries();
        final alreadyQueued = queued.any((r) =>
            r.studentId == studentId &&
            r.mealType == widget.mealType &&
            r.entryDate == widget.date);

        if (alreadyQueued) {
          AppHaptics.vibrate();
          _showResult(
            MessScanResult(
              status: MealVerificationStatus.alreadyUsed,
              title: '⚠ ALREADY USED',
              message: 'Student already checked in for this meal (local queue).',
              studentName: studentName,
              registrationNumber: regNumber,
              mealType: widget.mealType,
              isOffline: true,
            ),
          );
          return;
        }

        final record = MealEntryRecord(
          id: 'offline_${DateTime.now().microsecondsSinceEpoch}',
          mealType: widget.mealType,
          entryDate: widget.date,
          studentId: studentId,
          studentName: studentName,
          registrationNumber: regNumber,
          verifiedBy: widget.user?.uid ?? 'mess_staff',
          verificationMode: 'QR_FALLBACK',
          idempotencyKey: 'offline-${widget.date}-${widget.mealType}-$studentId',
          createdAt: DateTime.now(),
          isOffline: true,
        );

        await _messService.queueOfflineMealEntry(record);
        _sessionSuccessCount += 1;
        AppHaptics.mediumImpact();

        _showResult(
          MessScanResult(
            status: MealVerificationStatus.offlineVerified,
            title: '⚠ LOCAL VERIFIED',
            message: 'Credential verified locally. Entry queued for synchronization.',
            studentName: studentName,
            registrationNumber: regNumber,
            mealType: widget.mealType,
            isOffline: true,
          ),
        );
      } else {
        // Online authoritative verification & record
        final verifyRes = await _messService.verifyMealEntry(
          studentId: studentId,
          studentName: studentName,
          registrationNumber: regNumber,
          mealType: widget.mealType,
          date: widget.date,
          verificationMode: 'QR_FALLBACK',
          idempotencyKey: 'qr-${widget.date}-${widget.mealType}-$studentId',
          qrPayload: rawQr,
          requesterId: widget.user?.uid,
        );

        final status = verifyRes['status'];
        if (status == 'VERIFIED') {
          _sessionSuccessCount += 1;
          AppHaptics.lightImpact();
          _showResult(
            MessScanResult(
              status: MealVerificationStatus.verified,
              title: '✓ VERIFIED',
              message: 'Student eligible · Meal entry recorded',
              studentName: studentName,
              registrationNumber: regNumber,
              mealType: widget.mealType,
            ),
          );
        } else if (status == 'ALREADY_USED') {
          AppHaptics.vibrate();
          _showResult(
            MessScanResult(
              status: MealVerificationStatus.alreadyUsed,
              title: '⚠ ALREADY USED',
              message: verifyRes['message'] ?? 'Student already checked in for this meal',
              studentName: studentName,
              registrationNumber: regNumber,
              mealType: widget.mealType,
            ),
          );
        } else if (status == 'NOT_ELIGIBLE') {
          AppHaptics.heavyImpact();
          _showResult(
            MessScanResult(
              status: MealVerificationStatus.notEligible,
              title: '✕ NOT ELIGIBLE',
              message: verifyRes['message'] ?? 'Valid student but not eligible for meal',
              studentName: studentName,
              registrationNumber: regNumber,
              mealType: widget.mealType,
            ),
          );
        } else {
          AppHaptics.heavyImpact();
          _showResult(
            MessScanResult(
              status: MealVerificationStatus.invalid,
              title: '✕ VERIFICATION FAILED',
              message: verifyRes['message'] ?? 'Credential rejected',
              studentName: studentName,
              registrationNumber: regNumber,
              mealType: widget.mealType,
            ),
          );
        }
      }
    } catch (e) {
      AppHaptics.heavyImpact();
      _showResult(
        MessScanResult(
          status: MealVerificationStatus.invalid,
          title: '✕ SCAN ERROR',
          message: MessService.sanitizeError(e),
          mealType: widget.mealType,
        ),
      );
    }
  }

  void _showResult(MessScanResult result) {
    if (!mounted) return;
    setState(() {
      _currentResult = result;
      _isProcessingScan = false;
    });

    // Continuous scanning: automatically reset scanner after 1.5 seconds for high throughput
    _autoResetTimer?.cancel();
    _autoResetTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _resetScannerForNextStudent();
      }
    });
  }

  void _resetScannerForNextStudent() {
    _autoResetTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _currentResult = null;
      _isProcessingScan = false;
    });

    try {
      _controller.start();
    } catch (_) {}
  }

  void _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      setState(() {
        _isTorchOn = !_isTorchOn;
      });
    } catch (_) {}
  }

  void _toggleOfflineMode() {
    AppHaptics.selectionClick();
    setState(() {
      _isOfflineMode = !_isOfflineMode;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isOfflineMode
              ? 'Switched to OFFLINE verification (Local trust bundle)'
              : 'Switched to ONLINE verification (Backend authoritative)',
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          children: [
            Text(
              '${widget.mealType.toUpperCase()} · QR FALLBACK',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              '$_sessionSuccessCount recorded this session',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          // Offline / Online toggle pill
          GestureDetector(
            onTap: _toggleOfflineMode,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _isOfflineMode
                    ? const Color(0xFFD97706).withValues(alpha: 0.3)
                    : AppColors.emerald.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isOfflineMode
                      ? const Color(0xFFF59E0B)
                      : AppColors.emerald,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isOfflineMode ? Icons.cloud_off_rounded : Icons.cloud_done_rounded,
                    size: 14,
                    color: _isOfflineMode ? const Color(0xFFF59E0B) : AppColors.emerald,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isOfflineMode ? 'OFFLINE' : 'ONLINE',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: Colors.white,
            ),
            onPressed: _toggleTorch,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;
          final screenHeight = constraints.maxHeight;

          final scanSize = min(screenWidth * 0.72, 275.0);
          final scanWindow = Rect.fromCenter(
            center: Offset(screenWidth / 2, screenHeight * 0.38),
            width: scanSize,
            height: scanSize,
          );

          return Stack(
            fit: StackFit.expand,
            children: [
              // 1. Camera View
              MobileScanner(
                controller: _controller,
                scanWindow: scanWindow,
                onDetect: _onDetect,
              ),

              // 2. Pinch-To-Zoom Gesture Recognizer
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onScaleStart: (_) => _baseZoom = _currentZoom,
                onScaleUpdate: (details) {
                  final newZoom = (_baseZoom + (details.scale - 1.0) * 0.5).clamp(0.0, 1.0);
                  if ((newZoom - _currentZoom).abs() > 0.01) {
                    try {
                      _controller.setZoomScale(newZoom);
                    } catch (_) {}
                    _currentZoom = newZoom;
                  }
                },
              ),

              // 3. Dark Overlay with Cutout Hole
              CustomPaint(
                painter: ScannerHoleOverlayPainter(
                  scanWindow: scanWindow,
                  borderRadius: 20.0,
                  overlayColor: Colors.black.withValues(alpha: 0.58),
                ),
              ),

              // 4. White Corner Brackets
              CustomPaint(
                painter: ScannerCornersPainter(
                  scanWindow: scanWindow,
                  cornerLength: 32.0,
                  strokeWidth: 3.8,
                  cornerRadius: 20.0,
                  cornerColor: Colors.white,
                ),
              ),

              // 5. Subtitle Guide Text below Viewfinder
              Positioned(
                top: scanWindow.bottom + 20,
                left: 28,
                right: 28,
                child: Text(
                  'Align student Passport QR within frame.\nPinch to zoom for better focus.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.92),
                    height: 1.35,
                    shadows: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.7),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),

              // 6. Circular Torch Button below Guide
              Positioned(
                top: scanWindow.bottom + 85,
                left: 0,
                right: 0,
                child: Center(
                  child: CampusTorchButton(
                    torchEnabled: _isTorchOn,
                    onToggle: _toggleTorch,
                  ),
                ),
              ),

              // 7. Processing / Result HUD Card
              if (_isProcessingScan)
                Center(child: _buildProcessingHud())
              else if (_currentResult != null)
                Center(child: _buildResultHud(_currentResult!)),

              // 8. Bottom Controls: End QR Verification
              Positioned(
                bottom: 30,
                left: 20,
                right: 20,
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    key: const Key('end_qr_verification_button'),
                    onPressed: () {
                      AppHaptics.mediumImpact();
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                    label: Text(
                      'End QR Verification',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0F172A),
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProcessingHud() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Text(
            'Verifying credential...',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultHud(MessScanResult res) {
    Color hudBg;
    Color iconColor;
    IconData icon;

    switch (res.status) {
      case MealVerificationStatus.verified:
        hudBg = const Color(0xFF065F46); // Rich Emerald
        iconColor = const Color(0xFF6EE7B7);
        icon = Icons.check_circle_rounded;
        break;
      case MealVerificationStatus.alreadyUsed:
        hudBg = const Color(0xFF78350F); // Deep Amber
        iconColor = const Color(0xFFFDE68A);
        icon = Icons.warning_amber_rounded;
        break;
      case MealVerificationStatus.offlineVerified:
        hudBg = const Color(0xFF1E3A8A); // Deep Blue
        iconColor = const Color(0xFF93C5FD);
        icon = Icons.cloud_off_rounded;
        break;
      case MealVerificationStatus.notEligible:
      case MealVerificationStatus.invalid:
        hudBg = const Color(0xFF7F1D1D); // Deep Crimson
        iconColor = const Color(0xFFFCA5A5);
        icon = Icons.cancel_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: hudBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 36),
          const SizedBox(height: 10),
          Text(
            res.title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          if (res.studentName != null) ...[
            Text(
              res.studentName!,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            if (res.registrationNumber != null && res.registrationNumber!.isNotEmpty)
              Text(
                'Registration: ${res.registrationNumber}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
            const SizedBox(height: 6),
          ],
          Text(
            res.message,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Ready for next scan...',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }
}
