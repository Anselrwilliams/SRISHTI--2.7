import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/srishti_logo.dart';
import '../../../core/widgets/stat_card.dart';
import '../../checkin/models/attendance_mode.dart';
import '../../checkin/services/checkin_service.dart';
import '../../events/models/event_model.dart';
import '../../events/screens/event_detail_sheet.dart';
import '../../events/widgets/event_card.dart';
import '../../history/models/activity_item.dart';
import '../../history/screens/history_screen.dart';
import '../../participants/screens/participant_search_screen.dart';

/// Volunteer Home Dashboard displaying greetings, real Supabase metrics,
/// prominent Festival Arrival Scan QR hero, and live event previews.
class HomeScreen extends StatefulWidget {
  final VoidCallback onScanPressed;
  final VoidCallback onEventsPressed;

  const HomeScreen({
    super.key,
    required this.onScanPressed,
    required this.onEventsPressed,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _glowAnimation;
  final CheckinService _checkinService = CheckinService();

  int _todayCheckinsCount = 0;
  int _todayAttendanceCount = 0;
  List<ActivityItem> _recentActivities = [];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.25, end: 0.65).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadRealStats();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadRealStats() async {
    try {
      final arrivals = await _checkinService.getTodayArrivalCheckinsCount();
      final attendance = await _checkinService.getTodayEventAttendanceCount();
      final activities = await _checkinService.getRecentActivities(limit: 3);

      if (!mounted) return;
      setState(() {
        _todayCheckinsCount = arrivals;
        _todayAttendanceCount = attendance;
        _recentActivities = activities;
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
    final userEmail = SupabaseService.instance.currentUserEmail ?? 'Volunteer';
    final volunteerName = userEmail.split('@').first.split('.').first;
    final capitalizedName = volunteerName.isNotEmpty
        ? volunteerName[0].toUpperCase() + volunteerName.substring(1)
        : 'Volunteer';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadRealStats,
          color: AppColors.electricBlue,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header: Brand & Greeting
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getFormattedDate().toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.electricBlue,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_getGreeting()}, $capitalizedName',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                    const SrishtiLogo(size: 44, compact: true),
                  ],
                ),
                const SizedBox(height: 20),

                // Search Bar Shortcut (Arrival Context)
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ParticipantSearchScreen(
                          mode: AttendanceMode.arrival,
                        ),
                      ),
                    ).then((_) => _loadRealStats());
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
                        SizedBox(width: 12),
                        Text(
                          'Search participant code, name, phone...',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Prominent Arrival Scan QR Hero with Subtle Glow
                AnimatedBuilder(
                  animation: _glowAnimation,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.cyan.withAlpha((_glowAnimation.value * 70).round()),
                            blurRadius: 24,
                            spreadRadius: 2,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: child,
                    );
                  },
                  child: Material(
                    color: AppColors.surfaceDark,
                    borderRadius: BorderRadius.circular(24),
                    child: InkWell(
                      onTap: () {
                        widget.onScanPressed();
                      },
                      borderRadius: BorderRadius.circular(24),
                      splashColor: AppColors.cyan.withAlpha(40),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: AppColors.cyan.withAlpha(120),
                            width: 1.5,
                          ),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF090D16),
                              Color(0xFF131B2E),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Scanner Icon Frame
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryGradient,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.cyan.withAlpha(80),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.qr_code_scanner_rounded,
                                  size: 30,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 18),

                            // Text Information
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SCAN ARRIVAL QR',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Festival arrival check-in • Gate entry',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textDarkSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 16,
                              color: AppColors.cyan,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Real Supabase Attendance Statistics Row
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: 'Today\'s Check-ins',
                        value: '$_todayCheckinsCount',
                        subtitle: 'Festival Arrivals',
                        icon: Icons.how_to_reg_rounded,
                        accentColor: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: StatCard(
                        title: 'Live Attendance',
                        value: '$_todayAttendanceCount',
                        subtitle: 'Event check-ins',
                        icon: Icons.fact_check_rounded,
                        accentColor: AppColors.electricBlue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Live / Upcoming Events Preview
                SectionHeader(
                  title: 'Featured Events',
                  actionLabel: 'View All',
                  onActionTap: widget.onEventsPressed,
                ),
                const SizedBox(height: 8),

                EventCard(
                  event: const EventModel(
                    id: 'e1',
                    eventCode: 'EV-01',
                    name: 'Code Sprint (Speed Coding)',
                    category: 'Coding',
                    venue: 'CS Lab 3',
                    date: 'Day 1',
                    time: '10:30 AM',
                    registrationCount: 64,
                    attendanceCount: 42,
                    status: 'Live',
                  ),
                  onTap: () {
                    EventDetailSheet.show(
                      context,
                      event: const EventModel(
                        id: 'e1',
                        eventCode: 'EV-01',
                        name: 'Code Sprint (Speed Coding)',
                        category: 'Coding',
                        venue: 'CS Lab 3',
                        date: 'Day 1',
                        time: '10:30 AM',
                        registrationCount: 64,
                        attendanceCount: 42,
                        status: 'Live',
                      ),
                      onAttendanceMarked: _loadRealStats,
                    );
                  },
                ),
                const SizedBox(height: 24),

                // Recent Scans Section with Real Data
                SectionHeader(
                  title: 'Recent Activity',
                  actionLabel: 'History',
                  onActionTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const HistoryScreen(),
                      ),
                    ).then((_) => _loadRealStats());
                  },
                ),
                const SizedBox(height: 8),

                if (_recentActivities.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Center(
                      child: Text(
                        'No check-ins recorded yet today.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                else
                  ..._recentActivities.map((act) => Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: _buildRecentScanTile(act),
                      )),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecentScanTile(ActivityItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: item.actionType == 'Arrival Check-in'
                  ? AppColors.success.withAlpha(20)
                  : AppColors.electricBlue.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item.actionType == 'Arrival Check-in'
                  ? Icons.how_to_reg_rounded
                  : Icons.event_available_rounded,
              size: 18,
              color: item.actionType == 'Arrival Check-in'
                  ? AppColors.success
                  : AppColors.electricBlue,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.participantName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${item.participantCode} • ${item.source}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.actionType == 'Arrival Check-in' ? 'Arrived' : 'Attended',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: item.actionType == 'Arrival Check-in'
                      ? AppColors.success
                      : AppColors.electricBlue,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatTimestamp(item.timestamp),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
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
