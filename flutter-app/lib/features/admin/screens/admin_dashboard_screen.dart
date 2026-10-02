import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/floating_nav_bar.dart';
import '../../../core/widgets/unified/unified_design_system.dart';
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
      bottomNavigationBar: FloatingNavBar(
        currentIndex: _currentIndex,
        onTap: _navigateToTab,
        items: const [
          FloatingNavItem(
            icon: Icons.home_rounded,
            label: 'Home',
            testAlias: 'Overview',
          ),
          FloatingNavItem(
            icon: Icons.event_note_rounded,
            label: 'Event',
            testAlias: 'Events',
          ),
          FloatingNavItem(
            icon: Icons.people_alt_rounded,
            label: 'Directory',
            testAlias: 'Participants',
          ),
          FloatingNavItem(icon: Icons.person_rounded, label: 'Profile'),
        ],
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
      body: UnifiedBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadFestivalStats,
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
                    highlightedText: widget.volunteer.name.isNotEmpty
                        ? widget.volunteer.name
                        : 'Administrator',
                    roleSubtitle: 'Festival Administration • Central Operations',
                    statusIndicatorColor: AppColors.cyan,
                  ),
                  const SizedBox(height: 18),

                  // Unified Search Bar
                  UnifiedSearchBar(
                    placeholder: 'Search participant, event or record...',
                    onTap: () => _navigateToTab(2),
                  ),
                  const SizedBox(height: 18),

                  // Unified Primary Content Card
                  UnifiedEventCard(
                    category: '$_totalEvents EVENTS',
                    eventCode: '$_totalActiveVolunteers STAFF',
                    title: 'SRISHTI 2.7 Festival Control',
                    venue: 'Control Center',
                    date: 'Live System',
                    time: '$_totalEventAttendance Scans',
                    onTap: () => _navigateToTab(1),
                  ),
                  const SizedBox(height: 18),

                  // Unified Primary Action Card
                  UnifiedPrimaryActionCard(
                    title: 'FESTIVAL MONITOR',
                    subtitle: 'Quick scan and attendee verify',
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
                  const SizedBox(height: 18),

                  // Unified Statistics Cards (2 compact cards matching reference)
                  Row(
                    children: [
                      Expanded(
                        child: UnifiedStatsCard(
                          label: 'PARTICIPANTS',
                          value: '$_totalParticipants',
                          subtitle: '$_totalRegistrations slots',
                          icon: Icons.people_alt_rounded,
                          accentColor: AppColors.blue,
                          showWave: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: UnifiedStatsCard(
                          label: 'CAMPUS ARRIVALS',
                          value: '$_totalArrivals',
                          subtitle: 'Gate check-ins',
                          icon: Icons.check_circle_rounded,
                          accentColor: AppColors.success,
                          showWave: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Unified Activity Section
                  UnifiedActivitySection(
                    title: 'Live FEST Scans',
                    actionLabel: 'History',
                    onActionTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const HistoryScreen()),
                      ).then((_) => _loadFestivalStats());
                    },
                    emptyMessage: 'No scans recorded in the database yet.',
                    children: _recentActivities.take(6).map((act) {
                      final isArrival = act.actionType == 'Arrival Check-in';
                      return UnifiedActivityCard(
                        participantName: act.participantName,
                        participantCode: act.participantCode,
                        source: act.eventName ?? (isArrival ? 'Campus Arrival' : 'Manual Scan'),
                        statusLabel: isArrival ? 'Arrival' : 'Attended',
                        statusColor: isArrival ? AppColors.success : AppColors.electricBlue,
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
