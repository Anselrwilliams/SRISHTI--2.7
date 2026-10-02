import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/time_formatter.dart';
import '../../../core/widgets/unified/unified_design_system.dart';
import '../../auth/models/volunteer_model.dart';
import '../../checkin/models/attendance_mode.dart';
import '../../checkin/services/checkin_service.dart';
import '../../events/models/event_model.dart';
import '../../events/screens/event_detail_sheet.dart';
import '../../history/models/activity_item.dart';
import '../../history/screens/history_screen.dart';
import '../../participants/screens/participant_search_screen.dart';

/// Volunteer Home Dashboard displaying greetings, real Supabase metrics,
/// prominent Festival Arrival Scan QR hero, and live event previews.
class HomeScreen extends StatefulWidget {
  final VoidCallback onScanPressed;
  final VoidCallback onEventsPressed;
  final VolunteerModel? volunteer;

  const HomeScreen({
    super.key,
    required this.onScanPressed,
    required this.onEventsPressed,
    this.volunteer,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CheckinService _checkinService = CheckinService();

  int _todayCheckinsCount = 0;
  int _todayAttendanceCount = 0;
  List<ActivityItem> _recentActivities = [];
  EventModel? _featuredEvent;

  @override
  void initState() {
    super.initState();
    _loadRealStats();
  }

  Future<void> _loadRealStats() async {
    try {
      final arrivals = await _checkinService.getTodayArrivalCheckinsCount();
      final attendance = await _checkinService.getTodayEventAttendanceCount();
      final activities = await _checkinService.getRecentActivities(limit: 3);

      EventModel? featured;
      try {
        final events = await _checkinService.getActiveEvents();
        if (events.isNotEmpty) {
          final first = EventModel.fromMap(events.first);
          final counts = await _checkinService.getEventCounts(first.id);
          featured = first.copyWith(
            registrationCount: counts['registered'] ?? 0,
            attendanceCount: counts['attended'] ?? 0,
          );
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _todayCheckinsCount = arrivals;
        _todayAttendanceCount = attendance;
        _recentActivities = activities;
        _featuredEvent = featured;
      });
    } catch (_) {}
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.volunteer?.name.isNotEmpty == true
        ? widget.volunteer!.name
        : (SupabaseService.instance.currentUserEmail?.split('@').first ?? 'Volunteer');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: UnifiedBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadRealStats,
            color: AppColors.electricBlue,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 100.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Unified App Header
                  UnifiedAppHeader(
                    dateText: _getFormattedDate(),
                    greeting: _getGreeting(),
                    highlightedText: displayName,
                    roleSubtitle: 'General Volunteer • Operations',
                    statusIndicatorColor: AppColors.cyan,
                  ),
                  const SizedBox(height: 18),

                  // Unified Search Bar
                  UnifiedSearchBar(
                    placeholder: 'Search participant code, name, phone...',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const ParticipantSearchScreen(
                            mode: AttendanceMode.arrival,
                          ),
                        ),
                      ).then((_) => _loadRealStats());
                    },
                  ),
                  const SizedBox(height: 18),

                  // Unified Primary Content Event Card
                  if (_featuredEvent != null)
                    UnifiedEventCard(
                      category: _featuredEvent!.category.isNotEmpty
                          ? _featuredEvent!.category
                          : 'EVENT',
                      eventCode: _featuredEvent!.eventCode,
                      title: _featuredEvent!.name,
                      venue: _featuredEvent!.venue ?? 'Main Campus',
                      date: _featuredEvent!.date ?? 'Today',
                      time: TimeFormatter.formatTimeOrRange(_featuredEvent!.time).isNotEmpty
                          ? TimeFormatter.formatTimeOrRange(_featuredEvent!.time)
                          : (_featuredEvent!.time ?? 'Active'),
                      onTap: () {
                        EventDetailSheet.show(
                          context,
                          event: _featuredEvent!,
                          onAttendanceMarked: _loadRealStats,
                        );
                      },
                    )
                  else
                    UnifiedEventCard(
                      category: 'OPERATIONS',
                      eventCode: 'SRI-2026',
                      title: 'SRISHTI 2.7 Festival',
                      venue: 'Main Campus',
                      date: 'Today',
                      time: 'Full Day',
                      onTap: widget.onEventsPressed,
                    ),
                  const SizedBox(height: 18),

                  // Unified Primary Action Card (FEST CHECK-IN)
                  UnifiedPrimaryActionCard(
                    title: 'FEST CHECK-IN',
                    subtitle: 'Festival gate verification',
                    onTap: widget.onScanPressed,
                  ),
                  const SizedBox(height: 18),

                  // Unified Statistics Cards (2 compact cards)
                  Row(
                    children: [
                      Expanded(
                        child: UnifiedStatsCard(
                          label: 'CHECK-INS',
                          value: '$_todayCheckinsCount',
                          subtitle: 'FEST Arrivals',
                          icon: Icons.how_to_reg_rounded,
                          accentColor: AppColors.success,
                          showWave: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: UnifiedStatsCard(
                          label: 'ATTENDANCE',
                          value: '$_todayAttendanceCount',
                          subtitle: 'Event Scans',
                          icon: Icons.fact_check_rounded,
                          accentColor: AppColors.blue,
                          showWave: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Unified Activity Section
                  UnifiedActivitySection(
                    title: 'Recent Activity',
                    actionLabel: 'History',
                    onActionTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const HistoryScreen(),
                        ),
                      ).then((_) => _loadRealStats());
                    },
                    emptyMessage: 'No check-ins recorded yet today.',
                    children: _recentActivities.map((act) {
                      final isArrival = act.actionType == 'Arrival Check-in';
                      return UnifiedActivityCard(
                        participantName: act.participantName,
                        participantCode: act.participantCode,
                        source: act.source,
                        statusLabel: isArrival ? 'Arrived' : 'Attended',
                        statusColor: isArrival ? AppColors.success : AppColors.blue,
                        timeString: _formatTimestamp(act.timestamp),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
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
