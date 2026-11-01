import 'dart:convert';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/theme/app_colors.dart';
import '../../auth/models/user_model.dart';

/// Student-facing Campus Scanner Screen.
///
/// Features:
/// - Clean UPI-style camera viewfinder with dark overlay & white corner brackets
/// - "Scan any QR ⓘ" header
/// - Torch toggle button
/// - Smooth pinch-to-zoom support
/// - Institutional check-in & event token scanning
///
/// CRITICAL RBAC INVARIANT:
/// Students cannot verify other students' Passports.
class CampusScannerScreen extends StatefulWidget {
  final UserModel? user;
  final MobileScannerController? controller;

  const CampusScannerScreen({
    Key? key,
    this.user,
    this.controller,
  }) : super(key: key);

  @override
  State<CampusScannerScreen> createState() => _CampusScannerScreenState();
}

class _CampusScannerScreenState extends State<CampusScannerScreen> {
  late final MobileScannerController _controller;
  bool _ownsController = false;
  bool _isProcessing = false;
  bool _torchEnabled = false;

  double _currentZoom = 0.0;
  double _baseZoom = 0.0;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        facing: CameraFacing.back,
        torchEnabled: false,
      );
      _ownsController = true;
    }
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null || barcode.rawValue!.isEmpty) {
      return;
    }

    final raw = barcode.rawValue!.trim();
    setState(() {
      _isProcessing = true;
    });

    AppHaptics.mediumImpact();

    // Check if scanned QR is another student's Passport credential
    bool isPeerPassport = false;
    try {
      if (raw.startsWith('{') && raw.endsWith('}')) {
        final Map<String, dynamic> parsed = jsonDecode(raw);
        if (parsed.containsKey('studentId') ||
            parsed.containsKey('presentation') ||
            parsed.containsKey('credentialType')) {
          isPeerPassport = true;
        }
      }
    } catch (_) {}

    if (isPeerPassport) {
      _showPeerPassportNotice();
      return;
    }

    _showScannedResult(raw);
  }

  void _showPeerPassportNotice() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1B4B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: AppColors.warning,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Student Passport Detected',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This QR contains a student campus identity credential. Students are not authorized to verify peer passports. Only certified faculty and security staff can verify student credentials.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: Colors.white70,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _isProcessing = false;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Got it',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    });
  }

  void _showScannedResult(String rawPayload) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1B4B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.qr_code_2_rounded,
                      color: AppColors.success,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Campus QR Scanned',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Verified format',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: SelectableText(
                  rawPayload,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Done',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    });
  }

  void _showScannerInfo() {
    AppHaptics.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1B4B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Color(0xFFA5B4FC),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan Any Campus QR',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Official CampusOS Scanner',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _buildInfoRow(
                icon: Icons.event_available_rounded,
                title: 'Campus Events & Workshops',
                subtitle: 'Scan check-in QRs for university events and lectures',
              ),
              _buildInfoRow(
                icon: Icons.restaurant_rounded,
                title: 'Mess & Canteen Tokens',
                subtitle: 'Scan dining terminal tokens to redeem active meals',
              ),
              _buildInfoRow(
                icon: Icons.door_sliding_rounded,
                title: 'Facility & Gate Access',
                subtitle: 'Scan approved transit and facility access codes',
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Got it',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF00D084)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    // Viewfinder dimensions matching the reference UI
    final scanSize = min(screenWidth * 0.72, 275.0);
    // Positioned slightly above center (at 40% height)
    final scanWindow = Rect.fromCenter(
      center: Offset(screenWidth / 2, screenHeight * 0.40),
      width: scanSize,
      height: scanSize,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Camera Feed
          MobileScanner(
            controller: _controller,
            scanWindow: scanWindow,
            onDetect: _handleBarcode,
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

          // 5. Top Bar: Back button on left, "Scan any QR ⓘ" in middle, balanced right
          Positioned(
            top: mediaQuery.padding.top + 8,
            left: 8,
            right: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  tooltip: 'Back to Wallet',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Scan any QR',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 7),
                    GestureDetector(
                      onTap: _showScannerInfo,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.9),
                            width: 1.4,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'i',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Keeps title centered while omitting 3-dot and QR logo
                const SizedBox(width: 48),
              ],
            ),
          ),

          // 6. Subtitle Guide Text below Viewfinder
          Positioned(
            top: scanWindow.bottom + 22,
            left: 28,
            right: 28,
            child: Text(
              'Align the QR code to fit inside the frame.\nPinch to zoom for better focus.',
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

          // 7. Torch Circular Button
          Positioned(
            top: scanWindow.bottom + 92,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      AppHaptics.selectionClick();
                      setState(() {
                        _torchEnabled = !_torchEnabled;
                      });
                      _controller.toggleTorch();
                    },
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _torchEnabled
                            ? Colors.amber.withValues(alpha: 0.35)
                            : Colors.white.withValues(alpha: 0.16),
                        border: Border.all(
                          color: _torchEnabled
                              ? Colors.amberAccent
                              : Colors.white.withValues(alpha: 0.28),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          _torchEnabled
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          color: _torchEnabled
                              ? Colors.amberAccent
                              : Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Torch',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 8. Bottom Institutional Support Badge
          Positioned(
            bottom: mediaQuery.padding.bottom + 20,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Supports',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.verified_user_rounded,
                      size: 13,
                      color: Color(0xFF00D084),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'CAMPUSOS · SMART QR',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints a semi-transparent dark overlay with a clear rounded rectangular cutout.
class ScannerHoleOverlayPainter extends CustomPainter {
  final Rect scanWindow;
  final double borderRadius;
  final Color overlayColor;

  ScannerHoleOverlayPainter({
    required this.scanWindow,
    this.borderRadius = 20.0,
    required this.overlayColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fullRect = Offset.zero & size;
    final cutoutRRect = RRect.fromRectAndRadius(
      scanWindow,
      Radius.circular(borderRadius),
    );

    final path = Path()
      ..addRect(fullRect)
      ..addRRect(cutoutRRect)
      ..fillType = PathFillType.evenOdd;

    final paint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant ScannerHoleOverlayPainter oldDelegate) {
    return oldDelegate.scanWindow != scanWindow ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.overlayColor != overlayColor;
  }
}

/// Paints the 4 rounded white corner brackets framing the viewfinder window.
class ScannerCornersPainter extends CustomPainter {
  final Rect scanWindow;
  final double cornerLength;
  final double strokeWidth;
  final double cornerRadius;
  final Color cornerColor;

  ScannerCornersPainter({
    required this.scanWindow,
    this.cornerLength = 32.0,
    this.strokeWidth = 3.8,
    this.cornerRadius = 20.0,
    this.cornerColor = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = cornerColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final r = cornerRadius;
    final l = cornerLength;

    final left = scanWindow.left;
    final top = scanWindow.top;
    final right = scanWindow.right;
    final bottom = scanWindow.bottom;

    // 1. Top-Left Corner
    final tlPath = Path()
      ..moveTo(left, top + l)
      ..lineTo(left, top + r)
      ..arcTo(Rect.fromLTWH(left, top, 2 * r, 2 * r), pi, pi / 2, false)
      ..lineTo(left + l, top);
    canvas.drawPath(tlPath, paint);

    // 2. Top-Right Corner
    final trPath = Path()
      ..moveTo(right - l, top)
      ..lineTo(right - r, top)
      ..arcTo(Rect.fromLTWH(right - 2 * r, top, 2 * r, 2 * r), 1.5 * pi, pi / 2, false)
      ..lineTo(right, top + l);
    canvas.drawPath(trPath, paint);

    // 3. Bottom-Right Corner
    final brPath = Path()
      ..moveTo(right, bottom - l)
      ..lineTo(right, bottom - r)
      ..arcTo(Rect.fromLTWH(right - 2 * r, bottom - 2 * r, 2 * r, 2 * r), 0, pi / 2, false)
      ..lineTo(right - l, bottom);
    canvas.drawPath(brPath, paint);

    // 4. Bottom-Left Corner
    final blPath = Path()
      ..moveTo(left + l, bottom)
      ..lineTo(left + r, bottom)
      ..arcTo(Rect.fromLTWH(left, bottom - 2 * r, 2 * r, 2 * r), 0.5 * pi, pi / 2, false)
      ..lineTo(left, bottom - l);
    canvas.drawPath(blPath, paint);
  }

  @override
  bool shouldRepaint(covariant ScannerCornersPainter oldDelegate) {
    return oldDelegate.scanWindow != scanWindow ||
        oldDelegate.cornerLength != cornerLength ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.cornerRadius != cornerRadius ||
        oldDelegate.cornerColor != cornerColor;
  }
}
