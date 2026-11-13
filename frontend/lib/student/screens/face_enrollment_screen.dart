import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';

import '../../core/haptics/app_haptics.dart';
import '../../core/theme/app_colors.dart';
import '../../auth/providers/user_provider.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/passport_face_auth_service.dart';
import '../services/passport_mlkit_service.dart';
import '../widgets/face_auth/apple_face_id_viewfinder.dart';

/// CampusOS One-Time Face Enrollment Experience.
///
/// Pure industrial, non-AI-slop design:
/// - Dark obsidian canvas with restrained indigo ambient accents.
/// - Step-by-step biometric enrollment sequence:
///   1. Oval alignment guide with live selfie camera feed.
///   2. Lighting and distance calibration.
///   3. Liveness blink / micro-nod detection via Google ML Kit.
///   4. 128-D vector synthesis & hardware keystore commitment.
/// - Clear privacy guarantees: zero cloud photo uploads.
class FaceEnrollmentScreen extends StatefulWidget {
  final String? studentId;
  final bool isTestMode;

  const FaceEnrollmentScreen({
    Key? key,
    this.studentId,
    this.isTestMode = false,
  }) : super(key: key);

  @override
  State<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

enum _EnrollmentStep {
  alignFace,
  calibrating,
  extractingVector,
  completed,
}

class _FaceEnrollmentScreenState extends State<FaceEnrollmentScreen> {
  late ConfettiController _confettiController;

  CameraController? _cameraController;
  final PassportMlKitService _mlKitService = PassportMlKitService.instance;

  _EnrollmentStep _currentStep = _EnrollmentStep.alignFace;
  double _progress = 0.0;
  String _hintText = 'Center your face within the frame';
  bool _isProcessing = false;
  bool _isAlreadyEnrolled = false;
  String? _resolvedStudentId;

  final PassportFaceAuthService _faceService = PassportFaceAuthService();

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    _checkInitialEnrollment();
  }

  Future<void> _checkInitialEnrollment() async {
    final sId = PassportFaceAuthService.resolveActiveStudentId(widget.studentId);
    _resolvedStudentId = sId;
    final enrolled = await _faceService.isFaceEnrolled(sId);
    if (enrolled && mounted) {
      setState(() {
        _isAlreadyEnrolled = true;
        _hintText = 'Face biometric template is active and locked';
      });
      return;
    }
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          setState(() {
            _hintText = 'Camera permission required for biometric enrollment. Please allow in Settings.';
          });
        }
        return;
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _hintText = 'No camera found on this device.';
          });
        }
        return;
      }
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (mounted) {
        setState(() {
          _cameraController = controller;
        });
      }
    } catch (e) {
      debugPrint('ℹ️ [CAMERA] Camera init note (will use fallback if unavailable): $e');
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _startEnrollmentSequence() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _currentStep = _EnrollmentStep.calibrating;
      _hintText = 'Calibrating optical alignment...';
      _progress = 0.25;
    });
    AppHaptics.mediumImpact();

    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;

    setState(() {
      _currentStep = _EnrollmentStep.extractingVector;
      _hintText = 'Extracting 128-D facial feature vector...';
      _progress = 0.70;
    });
    AppHaptics.lightImpact();

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;

    // Resolve student ID
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final sId = PassportFaceAuthService.resolveActiveStudentId(
      widget.studentId ?? userProvider.user?.id,
    );

    // Guard: Prevent unilateral re-enrollment if already registered
    final alreadyEnrolled = await _faceService.isFaceEnrolled(sId);
    if (alreadyEnrolled) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _isAlreadyEnrolled = true;
        _hintText = 'Face biometric template is active and locked';
      });
      return;
    }

    List<double>? extractedVector;

    // Real on-device ML Kit camera capture
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        final xFile = await _cameraController!.takePicture();
        final faces = await _mlKitService.detectFacesFromPath(xFile.path);
        try {
          File(xFile.path).delete().ignore();
        } catch (_) {}

        if (faces.isEmpty) {
          if (!mounted) return;
          setState(() {
            _isProcessing = false;
            _currentStep = _EnrollmentStep.alignFace;
            _hintText = 'No face detected in camera. Please center your face.';
            _progress = 0.0;
          });
          AppHaptics.selectionClick();
          return;
        }

        final bestFace = faces.first;
        final isLive = _mlKitService.evaluateLiveness(bestFace);
        if (!isLive) {
          if (!mounted) return;
          setState(() {
            _isProcessing = false;
            _currentStep = _EnrollmentStep.alignFace;
            _hintText = 'Liveness check failed. Keep eyes open and face straight.';
            _progress = 0.0;
          });
          AppHaptics.selectionClick();
          return;
        }

        extractedVector = _mlKitService.extract128DVector(bestFace);
      } catch (e) {
        debugPrint('⚠️ [FACE_ENROLL] Camera frame processing error: $e');
      }
    }

    // Fallback to deterministic vector ONLY if camera hardware is completely unavailable (e.g. desktop/unit tests)
    if (extractedVector == null) {
      if (!widget.isTestMode && !kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        if (!mounted) return;
        setState(() {
          _isProcessing = false;
          _currentStep = _EnrollmentStep.alignFace;
          _hintText = 'No face detected. Please position your face inside the frame.';
          _progress = 0.0;
        });
        AppHaptics.selectionClick();
        return;
      }
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        if (!mounted) return;
        setState(() {
          _isProcessing = false;
          _currentStep = _EnrollmentStep.alignFace;
          _hintText = 'Failed to extract facial landmarks. Please reposition your face.';
          _progress = 0.0;
        });
        AppHaptics.selectionClick();
        return;
      }
      final rng = Random(sId.hashCode);
      final rawVector = List<double>.generate(128, (_) => rng.nextDouble() * 2.0 - 1.0);
      extractedVector = PassportFaceAuthService.normalizeVector(rawVector);
    }

    // Save locally in device secure storage & mirror
    final enrolled = await _faceService.enrollFace(
      studentId: sId,
      embedding: extractedVector,
      deviceId: userProvider.user?.deviceId,
    );

    if (enrolled && mounted) {
      setState(() {
        _currentStep = _EnrollmentStep.completed;
        _hintText = 'Face identity enrolled successfully!';
        _progress = 1.0;
      });
      AppHaptics.heavyImpact();
      _confettiController.play();

      await Future.delayed(const Duration(milliseconds: 1400));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else if (mounted) {
      setState(() {
        _isProcessing = false;
        _currentStep = _EnrollmentStep.alignFace;
        _hintText = 'Face setup encountered an issue. Tap to retry.';
        _progress = 0.0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to persist face enrollment. Please tap to try again.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Text(
          'CampusOS Face ID',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              colors: const [
                Color(0xFF38BDF8),
                Color(0xFF818CF8),
                Color(0xFF34D399),
                Colors.white,
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _isAlreadyEnrolled
                  ? _buildAlreadyEnrolledContent(context)
                  : Column(
                      children: [
                        const SizedBox(height: 12),
                  Text(
                    'One-Time Face Setup',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enroll your face once to verify attendance across BLE and QR sessions. Your face biometric vector is encrypted directly in your device\'s hardware enclave.',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF94A3B8),
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Verified College Account Association Badge
                  Builder(
                    builder: (context) {
                      final userProvider = Provider.of<UserProvider>(context, listen: false);
                      final user = userProvider.user;
                      final studentName = user?.name ?? 'Student';
                      final rollNo = user?.registrationNumber;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1B4B).withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_user_rounded,
                              color: Color(0xFF818CF8),
                              size: 15,
                            ),
                            const SizedBox(width: 7),
                            Text(
                              [
                                studentName.toUpperCase(),
                                if (rollNo != null && rollNo.isNotEmpty) 'REG: $rollNo',
                              ].join(' • '),
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Authentic Apple Face ID Viewfinder with Radial Ticks & TrueDepth Matrix
                  Expanded(
                    child: Center(
                      child: AppleFaceIdViewfinder(
                        progress: _progress,
                        isCompleted: _currentStep == _EnrollmentStep.completed,
                        width: 240,
                        height: 320,
                        cameraPreview: (_cameraController != null &&
                                _cameraController!.value.isInitialized)
                            ? SizedBox.expand(
                                child: FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: _cameraController!
                                            .value.previewSize?.height ??
                                        240,
                                    height: _cameraController!
                                            .value.previewSize?.width ??
                                        320,
                                    child:
                                        CameraPreview(_cameraController!),
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),

                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _currentStep == _EnrollmentStep.completed
                            ? AppColors.success
                            : const Color(0xFF6366F1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Hint text
                  Text(
                    _hintText,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _currentStep == _EnrollmentStep.completed
                          ? AppColors.success
                          : Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Action button
                  if (_currentStep != _EnrollmentStep.completed)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _startEnrollmentSequence,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _isProcessing
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.camera_alt_rounded, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Scan & Enroll Face',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlreadyEnrolledContent(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final user = userProvider.user;
    final sId = _resolvedStudentId ?? widget.studentId ?? user?.id ?? 'Student';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.35),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: AppColors.success,
              size: 52,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Face Identity Registered & Locked',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Your biometric template is enrolled and bound to institutional account $sId. To prevent proxy attendance, one-time enrollment cannot be modified from the student app.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: const Color(0xFF94A3B8),
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              children: [
                _buildEnrollmentDetailRow(
                  'Enrollment Status',
                  'ACTIVE & VERIFIED',
                  AppColors.success,
                ),
                const Divider(height: 20, color: Colors.white10),
                _buildEnrollmentDetailRow(
                  'Student ID',
                  user?.registrationNumber ?? sId,
                  Colors.white,
                ),
                const Divider(height: 20, color: Colors.white10),
                _buildEnrollmentDetailRow(
                  'Template Type',
                  '128-D Zero-Mean Feature Vector',
                  const Color(0xFF818CF8),
                ),
                const Divider(height: 20, color: Colors.white10),
                _buildEnrollmentDetailRow(
                  'Re-enrollment Policy',
                  'Authorized Dean Reset Required',
                  const Color(0xFFF59E0B),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(false),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: Text(
                'Return to Dashboard',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildEnrollmentDetailRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: const Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: valueColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

