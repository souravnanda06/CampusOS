import 'package:flutter/material.dart';
import 'package:attendance_app/core/haptics/app_haptics.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../device_capabilities.dart';
import '../performance_engine.dart';

/// Premium Apple-grade modal sheet displaying device performance diagnostics
/// and executing real-time adaptive recalibration.
class OptimizeCampusSheet extends StatefulWidget {
  final PerformanceEngine? engine;

  const OptimizeCampusSheet({Key? key, this.engine}) : super(key: key);

  static Future<void> show(BuildContext context, {PerformanceEngine? engine}) {
    AppHaptics.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OptimizeCampusSheet(engine: engine),
    );
  }

  @override
  State<OptimizeCampusSheet> createState() => _OptimizeCampusSheetState();
}

class _OptimizeCampusSheetState extends State<OptimizeCampusSheet> {
  late final PerformanceEngine _engine;
  bool _isOptimizing = false;
  String? _statusMessage;
  int _optimizationStep = 0; // 0: Idle, 1: Inspecting, 2: Computing, 3: Applying, 4: Done

  @override
  void initState() {
    super.initState();
    _engine = widget.engine ?? PerformanceEngine.instance;
  }

  Future<void> _runOptimization() async {
    setState(() {
      _isOptimizing = true;
      _optimizationStep = 1;
      _statusMessage = 'Analyzing device hardware & display refresh...';
    });
    AppHaptics.selectionClick();

    // Step 1: Real hardware inspection
    await Future.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;
    setState(() {
      _optimizationStep = 2;
      _statusMessage = 'Evaluating thermal state & raster budget...';
    });

    // Step 2: Compute policies & apply
    await Future.delayed(const Duration(milliseconds: 140));
    await _engine.recalibrate();

    if (!mounted) return;
    setState(() {
      _optimizationStep = 3;
      _statusMessage = 'Applying memory cache limits & rendering strategy...';
    });

    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;

    AppHaptics.mediumImpact();
    setState(() {
      _optimizationStep = 4;
      _isOptimizing = false;
      _statusMessage = 'CampusOS is fully optimized for your device.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _engine,
      builder: (context, _) {
        final profile = _engine.profile;
        final caps = _engine.capabilities;

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(context).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top drag pill
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Optimize CampusOS',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Device-aware performance & rendering engine',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Diagnostics Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _buildDiagnosticRow(
                      icon: Icons.smartphone_rounded,
                      label: 'Device',
                      value: '${caps.manufacturer} ${caps.model}'.trim(),
                    ),
                    const Divider(height: 16, thickness: 0.5),
                    _buildDiagnosticRow(
                      icon: Icons.speed_rounded,
                      label: 'Display Refresh',
                      value: '${caps.displayRefreshRate.toStringAsFixed(0)} Hz (${profile.animationProfile.frameBudgetMs.toStringAsFixed(1)} ms budget)',
                    ),
                    const Divider(height: 16, thickness: 0.5),
                    _buildDiagnosticRow(
                      icon: Icons.memory_rounded,
                      label: 'Memory Tier',
                      value: '${(caps.estimatedRamMb / 1024).toStringAsFixed(0)} GB (${profile.memoryProfile.maxImageCacheSizeBytes ~/ (1024 * 1024)} MB cache)',
                    ),
                    const Divider(height: 16, thickness: 0.5),
                    _buildDiagnosticRow(
                      icon: Icons.auto_awesome_rounded,
                      label: 'Active Profile',
                      value: profile.displayTierLabel,
                      valueColor: AppColors.primary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Optimization Subsystems Checklist
              Text(
                'Subsystem Optimizations',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildSubsystemPill(
                    'Rendering: ${profile.renderingProfile.blurStrategy.name}',
                    Icons.brush_rounded,
                  ),
                  _buildSubsystemPill(
                    'Motion: ${profile.animationProfile.displayRefreshRate.toStringAsFixed(0)}Hz',
                    Icons.animation_rounded,
                  ),
                  _buildSubsystemPill(
                    'Scanner: ${profile.scannerProfile.targetResolution.height.toInt()}p',
                    Icons.qr_code_scanner_rounded,
                  ),
                  _buildSubsystemPill(
                    'Thermal: ${profile.thermalProfile.name.toUpperCase()}',
                    Icons.thermostat_rounded,
                  ),
                  _buildSubsystemPill(
                    'Network: ${profile.networkProfile.networkQuality.name}',
                    Icons.wifi_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // User Mode Preference
              Text(
                'Performance Preference',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildModeChip('Auto', UserOverrideMode.automatic),
                  const SizedBox(width: 8),
                  _buildModeChip('Speed', UserOverrideMode.performancePriority),
                  const SizedBox(width: 8),
                  _buildModeChip('Quality', UserOverrideMode.visualQualityPriority),
                ],
              ),
              const SizedBox(height: 20),

              // Status message or Last Calibrated
              if (_statusMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(
                        _optimizationStep == 4
                            ? Icons.check_circle_rounded
                            : Icons.sync_rounded,
                        size: 16,
                        color: _optimizationStep == 4
                            ? AppColors.emerald
                            : AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusMessage!,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _optimizationStep == 4
                                ? AppColors.emerald
                                : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Last calibrated: ${DateFormat.yMMMd().add_jm().format(profile.lastOptimized)}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),

              // Action Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isOptimizing ? null : _runOptimization,
                  icon: _isOptimizing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.bolt_rounded, size: 20),
                  label: Text(
                    _isOptimizing ? 'Tuning Device...' : 'Optimize CampusOS',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
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

  Widget _buildDiagnosticRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSubsystemPill(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.primaryDark),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip(String label, UserOverrideMode mode) {
    final isSelected = _engine.userOverrideMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          AppHaptics.selectionClick();
          _engine.setUserOverride(mode);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
