import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../checkin/services/checkin_service.dart';
import '../models/activity_item.dart';

/// Screen displaying chronological history of scans, arrival check-ins, and event attendance
/// with real Supabase queries.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final CheckinService _checkinService = CheckinService();
  String _selectedFilter = 'All';
  bool _isLoading = true;
  List<ActivityItem> _activities = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);

    try {
      final items = await _checkinService.getRecentActivities(limit: 50);
      if (!mounted) return;
      setState(() {
        _activities = items;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _selectedFilter == 'All'
        ? _activities
        : _activities.where((a) {
            if (_selectedFilter == 'Arrival') return a.actionType == 'Arrival Check-in';
            if (_selectedFilter == 'Events') return a.actionType == 'Event Attendance';
            if (_selectedFilter == 'Manual') return a.source == 'Manual Search';
            if (_selectedFilter == 'QR') return a.source == 'QR Scan';
            return true;
          }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Recent Activity'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: ['All', 'Arrival', 'Events', 'QR', 'Manual'].map((filter) {
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => _selectedFilter = filter);
                    },
                    selectedColor: AppColors.surfaceDark,
                    backgroundColor: AppColors.backgroundSecondary,
                    labelStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? AppColors.cyan : AppColors.textSecondary,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected ? AppColors.surfaceDark : AppColors.border,
                      ),
                    ),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.electricBlue),
                    ),
                  )
                : filteredList.isEmpty
                    ? const EmptyStateView(
                        icon: Icons.history_rounded,
                        title: 'No Activity Found',
                        description: 'No scans or check-in records recorded for this filter yet.',
                      )
                    : RefreshIndicator(
                        onRefresh: _loadHistory,
                        color: AppColors.electricBlue,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: filteredList.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = filteredList[index];
                            return _buildActivityCard(item);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(ActivityItem item) {
    final isQr = item.source == 'QR Scan';
    final timeStr = _formatTimestamp(item.timestamp);
    final isArrival = item.actionType == 'Arrival Check-in';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isArrival
                  ? AppColors.success.withAlpha(20)
                  : AppColors.electricBlue.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isArrival ? Icons.how_to_reg_rounded : Icons.event_available_rounded,
              color: isArrival ? AppColors.success : AppColors.electricBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.participantName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      item.participantCode,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.electricBlue,
                      ),
                    ),
                    if (item.eventName != null) ...[
                      const Text(' • ', style: TextStyle(color: AppColors.textMuted)),
                      Expanded(
                        child: Text(
                          item.eventName!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isArrival ? AppColors.successBg : AppColors.infoBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isArrival ? AppColors.successBorder : AppColors.infoBorder,
                        ),
                      ),
                      child: Text(
                        item.actionType,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isArrival ? AppColors.success : AppColors.electricBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isQr ? AppColors.cyan.withAlpha(20) : AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Text(
                        item.source,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isQr ? AppColors.electricBlue : AppColors.textSecondary,
                        ),
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

  String _formatTimestamp(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
