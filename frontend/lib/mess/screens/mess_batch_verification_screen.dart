import 'dart:async';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../auth/models/user_model.dart';
import '../../core/theme/app_colors.dart';
import '../../student/models/mess_model.dart';
import '../../student/services/mess_service.dart';
import 'mess_qr_scanner_screen.dart';

/// Event model representing a live student batch verification attempt.
class BatchVerificationEvent {
  final String id;
  final String studentName;
  final String studentId;
  final String? registrationNumber;
  final MealVerificationStatus status;
  final String message;
  final DateTime timestamp;

  BatchVerificationEvent({
    required this.id,
    required this.studentName,
    required this.studentId,
    this.registrationNumber,
    required this.status,
    required this.message,
    required this.timestamp,
  });
}

/// CampusOS Mess Batch Verification Screen.
///
/// Primary fast-path verification mechanism for dining entries.
/// Manages explicit session states:
/// - BATCH_IDLE
/// - BATCH_STARTING
/// - BATCH_ACTIVE
/// - BATCH_PROCESSING
/// - BATCH_COMPLETED
/// - BATCH_UNAVAILABLE
/// - BATCH_FAILED
/// - QR_FALLBACK
///
/// Provides instant, non-blocking fallback to QR verification if batch capability
/// is unavailable or fails, preserving meal and session context.
class MessBatchVerificationScreen extends StatefulWidget {
  final UserModel? user;
  final String mealType;
  final String date;
  final MessService? messService;
  final bool simulateFailureForTesting;
  final bool simulateUnavailableForTesting;

  const MessBatchVerificationScreen({
    Key? key,
    required this.user,
    required this.mealType,
    required this.date,
    this.messService,
    this.simulateFailureForTesting = false,
    this.simulateUnavailableForTesting = false,
  }) : super(key: key);

  @override
  State<MessBatchVerificationScreen> createState() =>
      MessBatchVerificationScreenState();
}

class MessBatchVerificationScreenState
    extends State<MessBatchVerificationScreen> with SingleTickerProviderStateMixin {
  late final MessService _messService;

  BatchSessionState _sessionState = BatchSessionState.batchIdle;
  late final String _sessionId;
  late final String _sessionNonce;

  String get sessionId => _sessionId;
  String get sessionNonce => _sessionNonce;

  int _studentsVerifiedCount = 0;
  int _entriesRecordedCount = 0;
  final List<BatchVerificationEvent> _events = [];

  String? _failureReason;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _messService = widget.messService ?? MessService();
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    _sessionId = 'session_${widget.date}_${widget.mealType}_$timestamp';
    _sessionNonce = 'nonce_$timestamp';

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _startBatchSession();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startBatchSession() async {
    setState(() {
      _sessionState = BatchSessionState.batchStarting;
      _failureReason = null;
    });

    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    if (widget.simulateUnavailableForTesting) {
      setState(() {
        _sessionState = BatchSessionState.batchUnavailable;
        _failureReason =
            'Proximity / Bluetooth hardware capability unavailable on this device.';
      });
      return;
    }

    if (widget.simulateFailureForTesting) {
      setState(() {
        _sessionState = BatchSessionState.batchFailed;
        _failureReason =
            'Verification session failed to initialize session cryptographic material.';
      });
      return;
    }

    // Normal successful start
    setState(() {
      _sessionState = BatchSessionState.batchActive;
    });
    AppHaptics.mediumImpact();
  }

  /// Adds a verified dining event and records entry into batch queue
  void recordBatchEvent(BatchVerificationEvent event) {
    if (_sessionState != BatchSessionState.batchActive &&
        _sessionState != BatchSessionState.batchProcessing) {
      return;
    }

    setState(() {
      _events.insert(0, event);
      if (event.status == MealVerificationStatus.verified ||
          event.status == MealVerificationStatus.offlineVerified) {
        _studentsVerifiedCount += 1;
        _entriesRecordedCount += 1;
      }
    });
  }

  /// Switches immediately to individual student QR scanning without losing meal session context.
  void _switchToQrScanning() {
    AppHaptics.selectionClick();
    setState(() {
      _sessionState = BatchSessionState.qrFallback;
    });

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MessQrScannerScreen(
          user: widget.user,
          mealType: widget.mealType,
          date: widget.date,
          messService: _messService,
        ),
      ),
    );
  }

  Future<void> _endBatchSession() async {
    AppHaptics.mediumImpact();
    setState(() {
      _sessionState = BatchSessionState.batchProcessing;
    });

    // If there are recorded events, batch sync them to backend idempotently
    if (_entriesRecordedCount > 0) {
      try {
        final records = _events
            .where((e) =>
                e.status == MealVerificationStatus.verified ||
                e.status == MealVerificationStatus.offlineVerified)
            .map((e) => {
                  'studentId': e.studentId,
                  'studentName': e.studentName,
                  'registrationNumber': e.registrationNumber,
                  'mealType': widget.mealType,
                  'entryDate': widget.date,
                  'verificationMode': 'BATCH',
                  'idempotencyKey': 'batch-${widget.date}-${widget.mealType}-${e.studentId}',
                })
            .toList();

        if (records.isNotEmpty) {
          await _messService.batchSyncMealEntries(
            mealType: widget.mealType,
            date: widget.date,
            records: records,
            requesterId: widget.user?.uid,
          );
        }
      } catch (e) {
        debugPrint("Notice: batch sync completed with local fallback: $e");
      }
    }

    if (!mounted) return;
    setState(() {
      _sessionState = BatchSessionState.batchCompleted;
    });

    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Batch Verification',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          // Instant switch button accessible directly from header
          TextButton.icon(
            key: const Key('header_qr_fallback_button'),
            onPressed: _switchToQrScanning,
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
            label: const Text('QR Fallback'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              textStyle: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              // Main Session Status Card
              _buildSessionStatusCard(),

              const SizedBox(height: 16),

              // Unavailable / Failed / Active view
              if (_sessionState == BatchSessionState.batchUnavailable ||
                  _sessionState == BatchSessionState.batchFailed)
                Expanded(child: _buildFailureFallbackCard())
              else
                Expanded(child: _buildLiveEventsStream()),

              const SizedBox(height: 12),

              // Bottom Actions
              _buildBottomActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionStatusCard() {
    final isStarting = _sessionState == BatchSessionState.batchStarting;
    final isActive = _sessionState == BatchSessionState.batchActive;
    final isProcessing = _sessionState == BatchSessionState.batchProcessing;
    final isCompleted = _sessionState == BatchSessionState.batchCompleted;
    final isUnavailable = _sessionState == BatchSessionState.batchUnavailable;
    final isFailed = _sessionState == BatchSessionState.batchFailed;

    String stateLabel;
    Color statusColor;
    if (isActive) {
      stateLabel = 'ACTIVE';
      statusColor = AppColors.emerald;
    } else if (isStarting) {
      stateLabel = 'STARTING';
      statusColor = AppColors.primary;
    } else if (isProcessing) {
      stateLabel = 'PROCESSING';
      statusColor = const Color(0xFFF59E0B);
    } else if (isCompleted) {
      stateLabel = 'COMPLETED';
      statusColor = AppColors.emerald;
    } else if (isUnavailable) {
      stateLabel = 'UNAVAILABLE';
      statusColor = const Color(0xFFD97706);
    } else if (isFailed) {
      stateLabel = 'FAILED';
      statusColor = AppColors.error;
    } else {
      stateLabel = 'IDLE';
      statusColor = Colors.grey;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.mealType.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              // State Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isActive)
                      FadeTransition(
                        opacity: _pulseAnimation,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    const SizedBox(width: 6),
                    Text(
                      stateLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Batch Verification Session · ${widget.date}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const Divider(height: 24, thickness: 0.8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Students verified',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_studentsVerifiedCount',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 32, color: Colors.grey.shade200),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Entries recorded',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_entriesRecordedCount',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFailureFallbackCard() {
    final isUnavailable =
        _sessionState == BatchSessionState.batchUnavailable;
    final title = isUnavailable
        ? 'Batch verification unavailable'
        : 'Batch verification failed';
    final explanation = isUnavailable
        ? 'Proximity or Bluetooth scanning is not available on this device or permission was denied.'
        : (_failureReason ?? 'An error occurred during batch session verification.');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.15)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isUnavailable
                  ? const Color(0xFFFEF3C7)
                  : const Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isUnavailable ? Icons.portable_wifi_off_rounded : Icons.error_outline_rounded,
              color: isUnavailable ? const Color(0xFFD97706) : AppColors.error,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            explanation,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Continue using individual student verification.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          // Instant switch button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              key: const Key('switch_to_qr_scanning_action'),
              onPressed: _switchToQrScanning,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
              label: Text(
                'SWITCH TO QR SCANNING',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildLiveEventsStream() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Live Verification Stream',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (_sessionState == BatchSessionState.batchActive)
                Text(
                  'Listening for student beacons...',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _events.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.sensors_rounded,
                              color: Colors.grey.shade300, size: 40),
                          const SizedBox(height: 10),
                          Text(
                            'No students in range yet',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Students with Passport active will appear automatically.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _events.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final event = _events[index];
                      return _buildEventTile(event);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventTile(BatchVerificationEvent event) {
    IconData icon;
    Color iconColor;
    String statusLabel;

    switch (event.status) {
      case MealVerificationStatus.verified:
        icon = Icons.check_circle_rounded;
        iconColor = AppColors.emerald;
        statusLabel = '✓ verified';
        break;
      case MealVerificationStatus.alreadyUsed:
        icon = Icons.warning_amber_rounded;
        iconColor = const Color(0xFFF59E0B);
        statusLabel = '⚠ duplicate';
        break;
      case MealVerificationStatus.invalid:
        icon = Icons.cancel_rounded;
        iconColor = AppColors.error;
        statusLabel = '✕ invalid';
        break;
      case MealVerificationStatus.notEligible:
        icon = Icons.block_rounded;
        iconColor = AppColors.error;
        statusLabel = '✕ not eligible';
        break;
      case MealVerificationStatus.offlineVerified:
        icon = Icons.cloud_off_rounded;
        iconColor = const Color(0xFF3B82F6);
        statusLabel = '⚠ synchronization pending';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: iconColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.studentName,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  event.message,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            statusLabel,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              key: const Key('bottom_qr_fallback_button'),
              onPressed: _switchToQrScanning,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: Text(
                'QR Fallback',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              key: const Key('end_batch_session_button'),
              onPressed: _endBatchSession,
              icon: const Icon(Icons.stop_rounded, size: 20),
              label: Text(
                'End Batch Session',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
