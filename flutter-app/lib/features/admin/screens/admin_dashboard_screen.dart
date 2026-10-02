import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/srishti_logo.dart';
import '../../../core/widgets/stat_card.dart';
import '../../auth/models/volunteer_model.dart';
import '../../checkin/models/attendance_mode.dart';
import '../../checkin/services/checkin_service.dart';
import '../../events/screens/events_screen.dart';
import '../../history/models/activity_item.dart';
import '../../history/screens/history_screen.dart';
import '../../participants/screens/participant_search_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../scanner/screens/scan_screen.dart';

/// Admin overview dashboard showing festival-wide metrics, event statuses,
/// participant directories, and volunteer activity reports.
class AdminDashboardScreen extends StatefulWidget {
  final VolunteerModel volunteer;

  const AdminDashboardScreen({
    super.key,
    required this.volunteer,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;

  int _totalParticipants = 0;
  int _totalRegistrations = 0;
  int _totalArrivals = 0;
  int _totalEventAttendance = 0;
  int _totalEvents = 0;
  int _totalActiveVolunteers = 0;
  List<ActivityItem> _recentActivities = [];

  final CheckinService _checkinService = CheckinService();

  @override
  void initState() {
    super.initState();
    _loadFestivalStats();
  }

  Future<void> _loadFestivalStats() async {
    setState(() => _isLoading = true);

    try {
      final pCount = await _checkinService.getTotalParticipantsCount();
      final rCount = await _checkinService.getTotalRegistrationsCount();
      final aCount = await _checkinService.getTotalArrivalsCount();
      final attCount = await _checkinService.getTotalEventAttendanceCount();
      final eCount = await _checkinService.getTotalEventsCount();
      final vCount = await _checkinService.getTotalActiveVolunteersCount();
      final recents = await _checkinService.getRecentActivities(limit: 15);

      if (!mounted) return;

      setState(() {
        _totalParticipants = pCount;
        _totalRegistrations = rCount;
        _totalArrivals = aCount;
        _totalEventAttendance = attCount;
        _totalEvents = eCount;
        _totalActiveVolunteers = vCount;
        _recentActivities = recents;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
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

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      _buildOverviewTab(),
      const EventsScreen(),
      const ParticipantSearchScreen(mode: AttendanceMode.arrival),
      ProfileScreen(volunteer: widget.volunteer),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(
              color: AppColors.borderLight,
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.dashboard_rounded, 'Overview'),
                _buildNavItem(1, Icons.event_note_rounded, 'Events'),
                _buildNavItem(2, Icons.people_alt_rounded, 'Participants'),
                _buildNavItem(3, Icons.person_rounded, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadFestivalStats,
          color: AppColors.purple,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with Admin Name
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getFormattedDate().toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.purple,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_getGreeting()}, ${widget.volunteer.name}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.purple,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Festival Administrator • Full System Oversight',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SrishtiLogo(size: 42, compact: true),
                  ],
                ),
                const SizedBox(height: 22),

                // Quick Action Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildQuickActionButton(
                        icon: Icons.qr_code_scanner_rounded,
                        label: 'Arrival Scan',
                        color: AppColors.success,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const ScanScreen(
                                mode: AttendanceMode.arrival,
                              ),
                            ),
                          ).then((_) => _loadFestivalStats());
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickActionButton(
                        icon: Icons.search_rounded,
                        label: 'Find Participant',
                        color: AppColors.electricBlue,
                        onTap: () => _navigateToTab(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildQuickActionButton(
                        icon: Icons.assessment_outlined,
                        label: 'History Log',
                        color: AppColors.cyan,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const HistoryScreen(),
                            ),
                          ).then((_) => _loadFestivalStats());
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // Festival Statistics Grid (Row 1)
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: 'Participants',
                        value: '$_totalParticipants',
                        subtitle: 'Total registered',
                        icon: Icons.people_outline_rounded,
                        accentColor: AppColors.electricBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        title: 'Campus Arrivals',
                        value: '$_totalArrivals',
                        subtitle: 'Gate check-ins',
                        icon: Icons.how_to_reg_rounded,
                        accentColor: AppColors.success,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Festival Statistics Grid (Row 2)
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: 'Registrations',
                        value: '$_totalRegistrations',
                        subtitle: 'Event sign-ups',
                        icon: Icons.app_registration_rounded,
                        accentColor: AppColors.warning,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        title: 'Attendance',
                        value: '$_totalEventAttendance',
                        subtitle: 'Event marks',
                        icon: Icons.event_available_rounded,
                        accentColor: AppColors.cyan,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Festival Statistics Grid (Row 3)
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: 'Total Events',
                        value: '$_totalEvents',
                        subtitle: 'Competitions & talks',
                        icon: Icons.event_note_rounded,
                        accentColor: AppColors.purple,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        title: 'Active Staff',
                        value: '$_totalActiveVolunteers',
                        subtitle: 'Volunteers online',
                        icon: Icons.verified_user_outlined,
                        accentColor: const Color(0xFFE11D48),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),

                // Recent Festival Activity
                SectionHeader(
                  title: 'Live Festival Scans',
                  actionLabel: 'All Activity',
                  onActionTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const HistoryScreen()),
                    ).then((_) => _loadFestivalStats());
                  },
                ),
                const SizedBox(height: 8),

                if (_recentActivities.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Center(
                      child: Text(
                        'No scans recorded in the database yet.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                else
                  ..._recentActivities.take(8).map((act) => Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: _buildActivityTile(act),
                      )),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.softShadow,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityTile(ActivityItem item) {
    final isArrival = item.actionType == 'Arrival Check-in';
    final color = isArrival ? AppColors.success : AppColors.electricBlue;

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
              color: color.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isArrival ? Icons.how_to_reg_rounded : Icons.event_available_rounded,
              size: 18,
              color: color,
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
                  item.eventName != null
                      ? '${item.participantCode} • ${item.eventName}'
                      : '${item.participantCode} • Campus Arrival',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                isArrival ? 'Arrival' : 'Attended',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
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

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;

    return InkWell(
      onTap: () => _navigateToTab(index),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? AppColors.purple : AppColors.textMuted,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.purple : AppColors.textMuted,
              ),
            ),
          ],
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
