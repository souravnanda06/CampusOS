import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_colors.dart';
import '../../models/notice_model.dart';
import '../../../../shared/widgets/motion/apple_context_menu.dart';
import '../../../../shared/widgets/motion/apple_continuous_expansion.dart';
import 'apple_notice_expanded_view.dart';
import '../../../../core/haptics/app_haptics.dart';
import 'package:flutter/services.dart';

class NoticeCard extends StatefulWidget {
  final NoticeModel notice;
  final VoidCallback onTap;

  const NoticeCard({
    Key? key,
    required this.notice,
    required this.onTap,
  }) : super(key: key);

  @override
  State<NoticeCard> createState() => _NoticeCardState();
}

class _NoticeCardState extends State<NoticeCard> {
  final GlobalKey<AppleContinuousExpansionCardState> _expansionKey =
      GlobalKey<AppleContinuousExpansionCardState>();

  Color _getPriorityColor() {
    switch (widget.notice.priority) {
      case 'URGENT':
        return AppColors.danger;
      case 'HIGH':
        return Colors.deepOrange;
      default:
        return AppColors.primary;
    }
  }

  Color _getCategoryColor() {
    switch (widget.notice.category) {
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

  void _handleOpen() {
    _expansionKey.currentState?.open();
  }

  @override
  Widget build(BuildContext context) {
    final notice = widget.notice;
    final priorityColor = _getPriorityColor();
    final categoryColor = _getCategoryColor();
    final isUnread = !notice.isRead;

    return AppleContinuousExpansionCard(
      key: _expansionKey,
      cardRadius: 20,
      onExpand: widget.onTap,
      expandedBuilder: (context, dismiss) => AppleNoticeExpandedView(
        notice: widget.notice,
        onDismiss: dismiss,
      ),
      child: AppleContextMenu(
        onTap: _handleOpen,
        actions: [
          AppleContextMenuItem(
            title: "Read Notice",
            icon: Icons.mark_email_read_outlined,
            onTap: _handleOpen,
          ),
        AppleContextMenuItem(
          title: "Copy Notice",
          icon: Icons.copy_rounded,
          onTap: () {
            Clipboard.setData(ClipboardData(
                text: "${notice.title}\n\n${notice.body}"));
            AppHaptics.selectionClick();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Notice copied to clipboard"),
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
        AppleContextMenuItem(
          title: "Share",
          icon: Icons.ios_share_rounded,
          onTap: () {
            AppHaptics.selectionClick();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Sharing: ${notice.title}"),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
      ],
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUnread
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.border.withValues(alpha: 0.8),
          width: isUnread ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isUnread
                ? AppColors.primary.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: _handleOpen,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Category, Priority, Unread dot
                Row(
                  children: [
                    // Category chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        notice.category,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: categoryColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Priority tag
                    if (notice.priority != 'NORMAL') ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: priorityColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              notice.isUrgent
                                  ? Icons.error_outline_rounded
                                  : Icons.warning_amber_rounded,
                              size: 12,
                              color: priorityColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              notice.priority,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: priorityColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    const Spacer(),

                    // Unread badge / dot
                    if (isUnread) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "NEW",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    // Timestamp
                    Text(
                      notice.relativeTime,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                        color: isUnread ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Title
                Text(
                  notice.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15.5,
                    fontWeight: isUnread ? FontWeight.w800 : FontWeight.bold,
                    color: AppColors.textPrimary,
                    height: 1.3,
                  ),
                ),

                const SizedBox(height: 6),

                // Body preview
                Text(
                  notice.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),

                // Action tag if notice has action
                if (notice.hasAction) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        notice.isOpenUrlAction
                            ? Icons.open_in_new_rounded
                            : Icons.arrow_circle_right_outlined,
                        size: 14,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        notice.isOpenUrlAction ? "Link attached" : "Action required",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
    ),
  );
}
}
