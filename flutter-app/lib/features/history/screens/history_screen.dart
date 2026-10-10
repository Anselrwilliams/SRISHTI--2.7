import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/time_formatter.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../checkin/services/checkin_service.dart';
import '../models/activity_item.dart';

/// Screen displaying chronological history of scans, arrival check-ins, and event attendance
/// with real Supabase queries.
class HistoryScreen extends StatefulWidget {
  final String initialFilter;
  final CheckinService? checkinService;

  const HistoryScreen({
    super.key,
    this.initialFilter = 'All',
    this.checkinService,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late final CheckinService _checkinService;
  late String _selectedFilter;
  bool _isLoading = true;
  String? _errorMessage;
  List<ActivityItem> _activities = [];

  @override
  void initState() {
    super.initState();
    _checkinService = widget.checkinService ?? CheckinService();
    _selectedFilter = widget.initialFilter;
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final items = await _checkinService.getRecentActivities(limit: 50);
      if (!mounted) return;
      setState(() {
        _activities = items;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load activity history. Please check your connection and try again.';
      });
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
                : _errorMessage != null && _activities.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.cloud_off_rounded,
                                size: 48,
                                color: AppColors.error,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _loadHistory,
                                icon: const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text('Retry'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.electricBlue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
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
    final timeStr = TimeFormatter.formatRelativeTime(item.timestamp);
    final exactTimeStr = TimeFormatter.formatExactTime(item.timestamp);
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
                    Expanded(
                      child: Text(
                        item.participantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          timeStr,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (exactTimeStr.isNotEmpty && timeStr != 'Time unavailable')
                          Text(
                            exactTimeStr,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
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
                    ] else if (item.gateOrVenue != null && item.gateOrVenue!.isNotEmpty) ...[
                      const Text(' • ', style: TextStyle(color: AppColors.textMuted)),
                      Expanded(
                        child: Text(
                          item.gateOrVenue!,
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
}
