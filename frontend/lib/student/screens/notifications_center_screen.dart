import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/expansion_models.dart';
import '../../../core/services/expansion_api_service.dart';
import '../../../core/theme/app_colors.dart';

class NotificationsCenterScreen extends StatefulWidget {
  final String userId;

  const NotificationsCenterScreen({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<NotificationsCenterScreen> createState() =>
      _NotificationsCenterScreenState();
}

class _NotificationsCenterScreenState extends State<NotificationsCenterScreen> {
  bool _isLoading = true;
  bool _unreadOnly = false;
  List<NotificationItemModel> _notifications = [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final data = await ExpansionApiService.instance
        .getNotifications(widget.userId, unreadOnly: _unreadOnly);
    if (mounted) {
      setState(() {
        _notifications = data['notifications'] as List<NotificationItemModel>;
        _unreadCount = data['unreadCount'] as int;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllAsRead() async {
    await ExpansionApiService.instance.markAllNotificationsAsRead(widget.userId);
    _loadNotifications();
  }

  Future<void> _onNotificationTap(NotificationItemModel item) async {
    if (!item.isRead) {
      await ExpansionApiService.instance
          .markNotificationAsRead(item.id, widget.userId);
      _loadNotifications();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Opening ${item.actionLabel}: ${item.title}'),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: Text(
                'Mark all read',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: !_unreadOnly,
                  onSelected: (val) {
                    if (_unreadOnly) {
                      setState(() => _unreadOnly = false);
                      _loadNotifications();
                    }
                  },
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.primary,
                  labelStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: !_unreadOnly ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text('Unread ($_unreadCount)'),
                  selected: _unreadOnly,
                  onSelected: (val) {
                    if (!_unreadOnly) {
                      setState(() => _unreadOnly = true);
                      _loadNotifications();
                    }
                  },
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.primary,
                  labelStyle: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _unreadOnly ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Notification List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _notifications.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.notifications_none_rounded,
                              size: 48,
                              color: AppColors.textSecondary.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No notifications to show',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadNotifications,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _notifications.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = _notifications[index];
                            final iconData = _getIconForType(item.notificationType);
                            final color = _getColorForType(item.notificationType);

                            return InkWell(
                              onTap: () => _onNotificationTap(item),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: item.isRead
                                      ? Colors.white
                                      : const Color(0xFFEFF6FF), // soft blue tint for unread
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: item.isRead
                                        ? const Color(0xFFE2E8F0)
                                        : const Color(0xFFBFDBFE),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(iconData, color: color, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  item.title,
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 13.5,
                                                    fontWeight: item.isRead
                                                        ? FontWeight.w700
                                                        : FontWeight.w800,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                ),
                                              ),
                                              if (!item.isRead)
                                                Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: const BoxDecoration(
                                                    color: AppColors.primary,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            item.body,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 12,
                                              color: AppColors.textSecondary,
                                              height: 1.3,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                item.createdAt.split('T').first,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                  color: const Color(0xFF94A3B8),
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  Text(
                                                    item.actionLabel,
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 3),
                                                  const Icon(
                                                    Icons.arrow_forward_ios_rounded,
                                                    size: 9,
                                                    color: AppColors.primary,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type.toUpperCase()) {
      case 'DOCUMENT':
        return Icons.workspace_premium_rounded;
      case 'CLASS_UPDATE':
        return Icons.event_busy_rounded;
      case 'FEE':
        return Icons.account_balance_wallet_rounded;
      case 'VISITOR':
        return Icons.badge_rounded;
      case 'HOSTEL':
        return Icons.hotel_rounded;
      case 'COMPLAINT':
        return Icons.report_problem_rounded;
      case 'GATE_PASS':
        return Icons.door_sliding_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }

  Color _getColorForType(String type) {
    switch (type.toUpperCase()) {
      case 'DOCUMENT':
        return const Color(0xFF4F46E5);
      case 'CLASS_UPDATE':
        return const Color(0xFFDC2626);
      case 'FEE':
        return const Color(0xFFD97706);
      case 'VISITOR':
        return const Color(0xFF059669);
      case 'HOSTEL':
        return const Color(0xFF0284C7);
      case 'COMPLAINT':
        return const Color(0xFFEA580C);
      case 'GATE_PASS':
        return const Color(0xFF7C3AED);
      default:
        return AppColors.primary;
    }
  }
}
