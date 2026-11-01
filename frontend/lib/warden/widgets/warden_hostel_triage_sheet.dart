import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/models/expansion_models.dart';
import '../../core/services/expansion_api_service.dart';
import '../../core/theme/app_colors.dart';

class WardenHostelTriageSheet extends StatefulWidget {
  final String wardenId;

  const WardenHostelTriageSheet({Key? key, required this.wardenId})
      : super(key: key);

  static void show(BuildContext context, {required String wardenId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WardenHostelTriageSheet(wardenId: wardenId),
    );
  }

  @override
  State<WardenHostelTriageSheet> createState() =>
      _WardenHostelTriageSheetState();
}

class _WardenHostelTriageSheetState extends State<WardenHostelTriageSheet> {
  final ExpansionApiService _api = ExpansionApiService.instance;
  int _selectedTab = 0; // 0: Visitor Passes, 1: Room Requests, 2: Asset Issues
  bool _isLoading = true;

  List<VisitorRequestModel> _pendingVisitors = [];
  List<HostelRequestModel> _pendingHostelRequests = [];
  List<AssetIssueModel> _pendingAssetIssues = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    try {
      final visitors = await _api.getWardenPendingVisitors(widget.wardenId);
      final roomReqs = await _api.getWardenPendingRequests(widget.wardenId);
      final assets = await _api.getWardenPendingAssetIssues(widget.wardenId);

      if (mounted) {
        setState(() {
          _pendingVisitors = visitors;
          _pendingHostelRequests = roomReqs;
          _pendingAssetIssues = assets;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _actionVisitor(VisitorRequestModel visitor, String action) async {
    try {
      await _api.actionVisitorRequest(
        requestId: visitor.id,
        wardenId: widget.wardenId,
        action: action,
        remarks: action == 'APPROVE' ? 'Approved by Warden' : 'Rejected by Warden',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'APPROVE'
                  ? 'Visitor pass approved for ${visitor.visitorName}'
                  : 'Visitor pass rejected',
            ),
            backgroundColor: action == 'APPROVE' ? AppColors.success : AppColors.danger,
          ),
        );
        _loadAll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _actionHostelRequest(HostelRequestModel req, String action) async {
    try {
      await _api.actionHostelRequest(
        requestId: req.id,
        wardenId: widget.wardenId,
        action: action,
        remarks: action == 'APPROVE' ? 'Room allocation confirmed' : 'Request rejected by Warden',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Room request $action'),
            backgroundColor: action == 'APPROVE' ? AppColors.success : AppColors.danger,
          ),
        );
        _loadAll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _actionAssetIssue(AssetIssueModel issue, String status) async {
    try {
      await _api.actionAssetIssue(
        issueId: issue.id,
        wardenId: widget.wardenId,
        status: status,
        remarks: status == 'RESOLVED' ? 'Replaced/repaired by maintenance' : 'Scheduled for repair',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Asset issue marked as $status'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadAll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Hostel & Visitor Control",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                onPressed: _loadAll,
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Sub tabs
          Row(
            children: [
              _buildTabButton(0, "Visitors (${_pendingVisitors.length})"),
              const SizedBox(width: 8),
              _buildTabButton(1, "Room (${_pendingHostelRequests.length})"),
              const SizedBox(width: 8),
              _buildTabButton(2, "Assets (${_pendingAssetIssues.length})"),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _buildTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String title) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent() {
    if (_selectedTab == 0) {
      if (_pendingVisitors.isEmpty) {
        return _buildEmpty("No Pending Visitor Requests",
            "All campus guest gate passes have been processed.");
      }
      return ListView.separated(
        itemCount: _pendingVisitors.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final v = _pendingVisitors[index];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      v.visitorName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      v.relation,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: const Color(0xFFD97706),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "Phone: ${v.visitorPhone}  •  Date: ${v.visitDate}",
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(
                  "Window: ${v.expectedEntryTime} - ${v.expectedExitTime}",
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                Text(
                  "Purpose: ${v.purpose}",
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => _actionVisitor(v, 'REJECT'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                      ),
                      child: const Text("Reject"),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _actionVisitor(v, 'APPROVE'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Approve & Issue Pass"),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    } else if (_selectedTab == 1) {
      if (_pendingHostelRequests.isEmpty) {
        return _buildEmpty("No Room Requests",
            "No students currently requesting room changes or reallocation.");
      }
      return ListView.separated(
        itemCount: _pendingHostelRequests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final r = _pendingHostelRequests[index];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.requestType.replaceAll('_', ' '),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Reason: ${r.reason}",
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                if (r.preferredHostel != null)
                  Text(
                    "Preferred: ${r.preferredHostel} • ${r.preferredBlock ?? ''} • ${r.preferredRoomType ?? ''}",
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: AppColors.primary),
                  ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => _actionHostelRequest(r, 'REJECT'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                      ),
                      child: const Text("Reject"),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _actionHostelRequest(r, 'APPROVE'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Approve Change"),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    } else {
      if (_pendingAssetIssues.isEmpty) {
        return _buildEmpty("No Pending Asset Issues",
            "All room assets & furniture verified in good order.");
      }
      return ListView.separated(
        itemCount: _pendingAssetIssues.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final a = _pendingAssetIssues[index];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${a.assetName} (${a.issueType})",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: a.urgency == 'CRITICAL'
                            ? AppColors.danger.withValues(alpha: 0.15)
                            : AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        a.urgency,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: a.urgency == 'CRITICAL'
                              ? AppColors.danger
                              : AppColors.warning,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  a.description,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () => _actionAssetIssue(a, 'RESOLVED'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text("Mark Resolved"),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    }
  }

  Widget _buildEmpty(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              size: 40, color: AppColors.success),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
