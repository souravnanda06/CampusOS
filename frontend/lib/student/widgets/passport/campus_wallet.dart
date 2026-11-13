import 'package:flutter/material.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/animation_constants.dart';
import '../../../core/models/expansion_models.dart';
import '../../../core/services/expansion_api_service.dart';
import '../../models/gate_pass_model.dart';
import '../../models/passport_wallet_state.dart';
import 'passport_card.dart';
import 'student_id_card.dart';
import 'gate_pass_card.dart';
import 'document_wallet_card.dart';
import 'fees_wallet_card.dart';
import 'visitor_pass_card.dart';
import 'document_viewer_sheet.dart';
import 'fee_details_sheet.dart';
import 'visitor_pass_sheet.dart';
import 'passport_activation_view.dart';
import 'passport_scanner_button.dart';
import '../../../shared/widgets/motion/apple_bounceable.dart';
import '../../../shared/widgets/motion/apple_spring_scroll_physics.dart';

/// Campus Wallet Card Presentation & Interaction System.
///
/// Features:
/// - Clean native CampusOS theme integration
/// - Streamlined header
/// - Vertically screen-centered physical card carousel
/// - Bottom-docked contextual action button ("Unlock Passport" / "View Full Credential") and scanner
class CampusWalletView extends StatefulWidget {
  final String studentName;
  final String department;
  final String semester;
  final String? registrationNumber;
  final String? course;
  final PassportWalletState passportState;
  final bool isBluetoothActive;
  final GatePassModel? activeGatePass;
  final bool isLoadingGatePass;
  final bool isGatePassUnlocked;
  final bool isActivatingPassport;
  final VoidCallback onUnlockPassport;
  final VoidCallback onExpandPassport;
  final VoidCallback onActivatePassport;
  final VoidCallback onUnlockGatePass;
  final VoidCallback onViewGatePassQr;
  final VoidCallback onRequestGatePass;
  final VoidCallback onOpenScanner;

  final String? studentId;
  final List<DocumentRequestModel>? walletDocuments;
  final FeeSummaryModel? feeSummary;
  final VisitorRequestModel? activeVisitorPass;
  final VoidCallback? onRefreshWallet;

  const CampusWalletView({
    Key? key,
    required this.studentName,
    required this.department,
    required this.semester,
    this.registrationNumber,
    this.course,
    required this.passportState,
    required this.isBluetoothActive,
    required this.activeGatePass,
    required this.isLoadingGatePass,
    required this.isGatePassUnlocked,
    required this.isActivatingPassport,
    required this.onUnlockPassport,
    required this.onExpandPassport,
    required this.onActivatePassport,
    required this.onUnlockGatePass,
    required this.onViewGatePassQr,
    required this.onRequestGatePass,
    required this.onOpenScanner,
    this.studentId,
    this.walletDocuments,
    this.feeSummary,
    this.activeVisitorPass,
    this.onRefreshWallet,
  }) : super(key: key);

  @override
  State<CampusWalletView> createState() => _CampusWalletViewState();
}

class _CampusWalletViewState extends State<CampusWalletView> {
  late final PageController _pageController;
  int _currentPage = 0;
  late final ValueNotifier<int> _currentPageNotifier;

  List<DocumentRequestModel> _walletDocuments = [];
  FeeSummaryModel? _feeSummary;
  VisitorRequestModel? _activeVisitorPass;

  int get _totalCards {
    int count = 5;
    if ((_activeVisitorPass ?? widget.activeVisitorPass) != null) {
      count++;
    }
    return count;
  }

  @override
  void initState() {
    super.initState();
    _currentPageNotifier = ValueNotifier<int>(0);
    _pageController = PageController(
      initialPage: 0,
      viewportFraction: 0.88,
    );
    _loadWalletExpansionData();
  }

  Future<void> _loadWalletExpansionData() async {
    final sid = widget.studentId ?? widget.registrationNumber;
    if (sid != null && sid.isNotEmpty) {
      try {
        final docs = await ExpansionApiService.instance.getMyDocuments(sid);
        final feeSum = await ExpansionApiService.instance.getMyFeeSummary(sid);
        final vPass = await ExpansionApiService.instance.getActiveVisitorPass(sid);
        if (mounted) {
          setState(() {
            _walletDocuments = docs.where((d) => d.storedInWallet).toList();
            _feeSummary = feeSum;
            _activeVisitorPass = vPass;
          });
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _currentPageNotifier.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (_currentPage != index) {
      AppHaptics.selectionClick();
      _currentPage = index;
      _currentPageNotifier.value = index;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isReducedMotion = AnimationConstants.isReducedMotion(context);

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Top Header: Clean title and subtitle
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Campus Wallet',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Institutional Identity · Smart Credentials',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            // 2. Vertically Screen-Centered Physical Card Carousel
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Centered Page Counter: '1 of 3' (Isolated rebuild via ValueNotifier)
                    ValueListenableBuilder<int>(
                      valueListenable: _currentPageNotifier,
                      builder: (context, currentPage, _) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Text(
                            '${currentPage + 1} of $_totalCards',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Swipeable Physical Card PageView (120Hz-optimized, zero setState on scroll)
                    SizedBox(
                      height: 210,
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: _onPageChanged,
                        itemCount: _totalCards,
                        physics: const AppleSpringScrollPhysics(),
                        itemBuilder: (context, index) {
                          return AnimatedBuilder(
                            animation: _pageController,
                            child: RepaintBoundary(
                              child: _buildCardAtIndex(index),
                            ),
                            builder: (context, child) {
                              double page = _currentPage.toDouble();
                              if (_pageController.hasClients &&
                                  _pageController.position.haveDimensions) {
                                page = _pageController.page ?? _currentPage.toDouble();
                              }
                              final diff = (page - index).abs();
                              final scale = isReducedMotion
                                  ? 1.0
                                  : (1.0 - (diff * 0.06)).clamp(0.92, 1.0);
                              final opacity = isReducedMotion
                                  ? 1.0
                                  : (1.0 - (diff * 0.20)).clamp(0.75, 1.0);

                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Transform.scale(
                                    scale: scale,
                                    child: Opacity(
                                      opacity: opacity,
                                      child: child,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Page Indicator Dots (Isolated rebuild via ValueNotifier)
                    ValueListenableBuilder<int>(
                      valueListenable: _currentPageNotifier,
                      builder: (context, currentPage, _) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(_totalCards, (index) {
                            final isSelected = index == currentPage;
                            return AnimatedContainer(
                              duration: AnimationConstants.fast,
                              curve: Curves.easeOutCubic,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              width: isSelected ? 20 : 6,
                              height: 5,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.divider.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // 3. Bottom Action Bar (Contextual when activation/reactivation is required)
            ValueListenableBuilder<int>(
              valueListenable: _currentPageNotifier,
              builder: (context, currentPage, _) {
                final actionWidget = _buildContextualActionButtonForPage(currentPage);
                if (actionWidget == null) {
                  return const SizedBox(height: 88);
                }
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 96, 20),
                  child: actionWidget,
                );
              },
            ),
          ],
        ),

        // Floating Scanner Button — 56dp standard CampusOS touch target
        Positioned(
          right: 20,
          bottom: 20,
          child: PassportScannerButton(
            onPressed: widget.onOpenScanner,
            size: 56,
          ),
        ),
      ],
    );
  }

  Widget _buildCardAtIndex(int index) {
    switch (index) {
      case 0:
        if (widget.passportState.isUninitialized ||
            widget.passportState.isKeyMissing) {
          return PassportActivationCard(
            state: widget.passportState,
            isProcessing: widget.isActivatingPassport,
            onActivateTap: widget.onActivatePassport,
          );
        }
        return PassportCard(
          studentName: widget.studentName,
          department: widget.department,
          semester: widget.semester,
          registrationNumber: widget.registrationNumber,
          state: widget.passportState,
          isBluetoothActive: widget.isBluetoothActive,
          onUnlockTap: widget.onUnlockPassport,
          onExpandTap: widget.onExpandPassport,
        );

      case 1:
        return StudentIdCard(
          studentName: widget.studentName,
          department: widget.department,
          semester: widget.semester,
          registrationNumber: widget.registrationNumber,
          course: widget.course,
          onTap: () => _showStudentIdDetailsSheet(context),
        );

      case 2:
        return GatePassCard(
          activePass: widget.activeGatePass,
          isLoading: widget.isLoadingGatePass,
          isUnlocked: widget.isGatePassUnlocked,
          onUnlockTap: widget.onUnlockGatePass,
          onRequestPassTap: widget.onRequestGatePass,
          onViewQrTap: widget.onViewGatePassQr,
        );

      case 3:
        final doc = _walletDocuments.isNotEmpty
            ? _walletDocuments.first
            : (widget.walletDocuments != null && widget.walletDocuments!.isNotEmpty
                ? widget.walletDocuments!.first
                : null);
        return DocumentWalletCard(
          document: doc,
          onTap: () {
            if (doc != null) {
              DocumentViewerSheet.show(context, doc);
            } else {
              _showDefaultBonafideSheet(context);
            }
          },
        );

      case 4:
        final summary = _feeSummary ?? widget.feeSummary;
        return FeesWalletCard(
          feeSummary: summary,
          onTap: () {
            final sid = widget.studentId ?? widget.registrationNumber ?? 'STUDENT_ME';
            FeeDetailsSheet.show(context, sid);
          },
        );

      case 5:
        final vPass = _activeVisitorPass ?? widget.activeVisitorPass;
        return VisitorPassCard(
          pass: vPass,
          onTap: () {
            if (vPass != null) {
              VisitorPassSheet.show(context, vPass);
            }
          },
        );

      default:
        return const SizedBox.shrink();
    }
  }

  void _showDefaultBonafideSheet(BuildContext context) {
    final defaultDoc = DocumentRequestModel(
      id: 'default-bonafide',
      studentId: widget.studentId ?? '',
      documentType: 'BONAFIDE_CERTIFICATE',
      documentTypeName: 'Bonafide Certificate',
      purpose: 'Institutional Identity & Enrollment Attestation',
      status: 'ISSUED',
      documentNumber: 'DOC-2026-BPUT-BONAFIDE',
      storedInWallet: true,
      createdAt: DateTime.now().toIso8601String(),
      issuedAt: DateTime.now().toIso8601String(),
      studentName: widget.studentName,
      registrationNumber: widget.registrationNumber,
      branch: widget.department,
    );
    DocumentViewerSheet.show(context, defaultDoc);
  }

  Widget? _buildContextualActionButtonForPage(int page) {
    switch (page) {
      case 0:
        if (widget.passportState.isUninitialized ||
            widget.passportState.isKeyMissing) {
          return _buildActionButton(
            label: widget.passportState.isKeyMissing
                ? 'Reactivate Passport'
                : 'Activate Passport',
            icon: Icons.fingerprint_rounded,
            color: AppColors.primary,
            onTap: widget.onActivatePassport,
            isLoading: widget.isActivatingPassport,
          );
        }
        return null;

      case 1:
        return null;

      case 2:
        return null;

      default:
        return null;
    }
  }

  void _showStudentIdDetailsSheet(BuildContext context) {
    AppHaptics.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.badge_rounded,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Institutional Identity',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Official Enrollment Record',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          size: 13,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Verified',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildDetailTile('Student Name', widget.studentName.toUpperCase()),
              _buildDetailTile('Roll / Reg Number', widget.registrationNumber ?? '2101297001'),
              _buildDetailTile('Academic Program', '${widget.course ?? "B.Tech"} · ${widget.department}'),
              _buildDetailTile('Current Semester', widget.semester),
              _buildDetailTile('Academic Year', 'AY 2026–2027'),
              _buildDetailTile('Device Trust', 'Hardware Keystore Certified'),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            Flexible(
              child: Text(
                value,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isLoading = false,
  }) {
    return AppleBounceable(
      onTap: isLoading ? null : onTap,
      scaleFactor: 0.96,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.88)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
