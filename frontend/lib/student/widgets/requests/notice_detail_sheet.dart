import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../models/notice_model.dart';
import '../../services/notice_service.dart';
import '../../../shared/widgets/motion/apple_spring_scroll_physics.dart';

class NoticeDetailSheet extends StatefulWidget {
  final NoticeModel notice;
  final String? studentId;
  final VoidCallback? onNoticeRead;
  final Function(String complaintId)? onViewComplaint;

  const NoticeDetailSheet({
    Key? key,
    required this.notice,
    this.studentId,
    this.onNoticeRead,
    this.onViewComplaint,
  }) : super(key: key);

  @override
  State<NoticeDetailSheet> createState() => _NoticeDetailSheetState();
}

class _NoticeDetailSheetState extends State<NoticeDetailSheet> {
  final NoticeService _noticeService = NoticeService();
  late NoticeModel _notice;

  @override
  void initState() {
    super.initState();
    _notice = widget.notice;
    _markReadAsync();
  }

  void _markReadAsync() {
    final studentId = widget.studentId;
    if (studentId != null && studentId.isNotEmpty && !_notice.isRead) {
      _noticeService.markNoticeRead(_notice.id, requesterId: studentId).then((success) {
        if (success && mounted) {
          setState(() {
            _notice = _notice.copyWith(isRead: true, readAt: DateTime.now());
          });
          widget.onNoticeRead?.call();
        }
      }).catchError((_) {
        // Non-blocking: fail quietly per low-bandwidth & UX requirements
      });
    }
  }

  Color _getPriorityColor() {
    switch (_notice.priority) {
      case 'URGENT':
        return AppColors.danger;
      case 'HIGH':
        return Colors.deepOrange;
      default:
        return AppColors.primary;
    }
  }

  Color _getCategoryColor() {
    switch (_notice.category) {
      case 'ACADEMIC':
      case 'EXAM':
        return AppColors.primary;
      case 'SECURITY':
      case 'HOSTEL':
        return Colors.indigo;
      case 'EVENT':
        return Colors.purple;
      case 'FEE':
        return Colors.teal;
      default:
        return AppColors.textSecondary;
    }
  }

  Future<void> _handleAction() async {
    if (_notice.isOpenUrlAction) {
      final rawUrl = _notice.actionPayload?.toString().trim() ?? '';
      if (rawUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No URL link provided in notice action")),
        );
        return;
      }

      final uri = Uri.tryParse(rawUrl);
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        try {
          final canLaunch = await canLaunchUrl(uri);
          if (canLaunch) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Could not open link: $rawUrl")),
              );
            }
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Error opening link: $e")),
            );
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid URL format attached to notice")),
        );
      }
    } else if (_notice.isViewComplaintAction) {
      final complaintId = _notice.actionPayload?.toString().trim();
      if (complaintId != null && complaintId.isNotEmpty) {
        Navigator.pop(context);
        widget.onViewComplaint?.call(complaintId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No complaint reference specified")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final priorityColor = _getPriorityColor();
    final categoryColor = _getCategoryColor();
    final dateFormat = DateFormat('MMMM dd, yyyy • hh:mm a');

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Chips and Close button row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _notice.category,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: categoryColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: priorityColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _notice.isUrgent
                          ? Icons.error_outline_rounded
                          : _notice.isHigh
                              ? Icons.warning_amber_rounded
                              : Icons.info_outline_rounded,
                      size: 13,
                      color: priorityColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _notice.priority,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: priorityColor,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Title
          Text(
            _notice.title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 8),

          // Metadata row
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 5),
              Text(
                dateFormat.format(_notice.createdAt),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          if (_notice.expiresAt != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.event_busy_rounded,
                  size: 14,
                  color: _notice.isExpired ? AppColors.danger : Colors.orange,
                ),
                const SizedBox(width: 5),
                Text(
                  _notice.isExpired
                      ? "Expired on ${DateFormat('MMM dd, yyyy').format(_notice.expiresAt!)}"
                      : "Valid until ${DateFormat('MMM dd, yyyy').format(_notice.expiresAt!)}",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: _notice.isExpired ? AppColors.danger : Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 16),

          // Body text
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: SingleChildScrollView(
              physics: AppleSpringScrollPhysics.always,
              child: Text(
                _notice.body,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14.5,
                  color: AppColors.textPrimary.withValues(alpha: 0.9),
                  height: 1.6,
                ),
              ),
            ),
          ),

          // Action button
          if (_notice.hasAction) ...[
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _handleAction,
                icon: Icon(
                  _notice.isOpenUrlAction
                      ? Icons.open_in_browser_rounded
                      : Icons.arrow_forward_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                label: Text(
                  _notice.isOpenUrlAction
                      ? "Open Official Link"
                      : _notice.isViewComplaintAction
                          ? "View Related Issue"
                          : "Take Action",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
