import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/time_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/srishti_logo.dart';
import '../../../core/widgets/stat_card.dart';
import '../../auth/models/volunteer_model.dart';
import '../../checkin/models/attendance_mode.dart';
import '../../checkin/services/checkin_service.dart';
import '../../events/models/event_model.dart';
import '../../history/models/activity_item.dart';
import '../../history/screens/history_screen.dart';
import '../../participants/screens/participant_search_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../scanner/screens/scan_screen.dart';

/// Role-specific dashboard for Event Staff coordinators.
/// Loads only the events assigned to the authenticated volunteer via `event_staff`.
class EventStaffDashboardScreen extends StatefulWidget {
  final VolunteerModel volunteer;

  const EventStaffDashboardScreen({
    super.key,
    required this.volunteer,
  });

  @override
  State<EventStaffDashboardScreen> createState() => _EventStaffDashboardScreenState();
}

class _EventStaffDashboardScreenState extends State<EventStaffDashboardScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;
  List<EventModel> _assignedEvents = [];
  int _selectedEventIndex = 0;
  List<ActivityItem> _recentEventActivities = [];
  List<Map<String, dynamic>> _eventRoster = [];

  final CheckinService _checkinService = CheckinService();

  EventModel? get _currentEvent =>
      _assignedEvents.isNotEmpty && _selectedEventIndex < _assignedEvents.length
          ? _assignedEvents[_selectedEventIndex]
          : null;

  @override
  void initState() {
    super.initState();
    _loadAssignedEvents();
  }

  Future<void> _loadAssignedEvents() async {
    setState(() => _isLoading = true);

    try {
      final rawEvents =
          await SupabaseService.instance.getAssignedEvents(widget.volunteer.id);

      final List<EventModel> loaded = [];
      for (final raw in rawEvents) {
        final model = EventModel.fromMap(raw);
        // Fetch live registered and attendance counts from Supabase
        final counts = await _checkinService.getEventCounts(model.id);
        loaded.add(model.copyWith(
          registrationCount: counts['registered'] ?? 0,
          attendanceCount: counts['attended'] ?? 0,
        ));
      }

      if (!mounted) return;

      setState(() {
        _assignedEvents = loaded;
        _isLoading = false;
      });

      if (_assignedEvents.isNotEmpty) {
        _loadCurrentEventDetails();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadCurrentEventDetails() async {
    final event = _currentEvent;
    if (event == null) return;

    try {
      final counts = await _checkinService.getEventCounts(event.id);
      final activities =
          await _checkinService.getEventRecentActivities(event.id, limit: 5);
      final roster = await _checkinService.getEventRoster(event.id);

      if (!mounted) return;

      setState(() {
        _assignedEvents[_selectedEventIndex] = event.copyWith(
          registrationCount: counts['registered'] ?? 0,
          attendanceCount: counts['attended'] ?? 0,
        );
        _recentEventActivities = activities;
        _eventRoster = roster;
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

  void _navigateToTab(int index) {
    if (_currentIndex == index && index == 1) {
      ScanScreen.resumeActiveScanner();
      return;
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final event = _currentEvent;

    final List<Widget> screens = [
      _buildHomeTab(event),
      event != null
          ? ScanScreen(
              key: ValueKey('event_scan_${event.id}'),
              isActive: _currentIndex == 1,
              mode: AttendanceMode.event,
              eventId: event.id,
              eventName: event.name,
              onScanComplete: _loadCurrentEventDetails,
            )
          : const Scaffold(
              backgroundColor: AppColors.surfaceDark,
              body: Center(
                child: Text('No assigned event selected.', style: TextStyle(color: Colors.white)),
              ),
            ),
      _buildEventTab(event),
      ProfileScreen(volunteer: widget.volunteer),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: _currentIndex == 1 ? AppColors.surfaceDark : AppColors.surface,
          border: Border(
            top: BorderSide(
              color: _currentIndex == 1 ? AppColors.borderDarkSubtle : AppColors.borderLight,
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(_currentIndex == 1 ? 40 : 10),
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
                _buildNavItem(0, Icons.home_rounded, 'Home'),
                _buildScanNavItem(),
                _buildNavItem(2, Icons.event_note_rounded, 'Event'),
                _buildNavItem(3, Icons.person_rounded, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeTab(EventModel? event) {
    if (_assignedEvents.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Event Staff Portal')),
        body: EmptyStateView(
          title: 'No Assigned Events',
          description:
              'Hello ${widget.volunteer.name}, your account is not currently assigned to any events. '
              'Please contact the administrator.',
          icon: Icons.event_busy_rounded,
          actionLabel: 'Refresh',
          onActionPressed: _loadAssignedEvents,
        ),
      );
    }

    final effectiveEvent = event ?? _assignedEvents.first;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAssignedEvents,
          color: AppColors.electricBlue,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with Volunteer Real Name
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
                              color: AppColors.cyan,
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
                                  color: AppColors.cyan,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Event Coordinator',
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
                const SizedBox(height: 18),

                // Multiple Events Selector (if coordinator is assigned to > 1 event)
                if (_assignedEvents.length > 1) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(_assignedEvents.length, (index) {
                        final isSelected = _selectedEventIndex == index;
                        final ev = _assignedEvents[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(ev.name),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _selectedEventIndex = index);
                                _loadCurrentEventDetails();
                              }
                            },
                            selectedColor: AppColors.surfaceDark,
                            backgroundColor: AppColors.surface,
                            labelStyle: TextStyle(
                              color: isSelected ? AppColors.cyan : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isSelected ? AppColors.cyan : AppColors.borderLight,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Manual Participant Search (locked to this event)
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ParticipantSearchScreen(
                          mode: AttendanceMode.event,
                          eventId: effectiveEvent.id,
                          eventName: effectiveEvent.name,
                        ),
                      ),
                    ).then((_) => _loadCurrentEventDetails());
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Search participant for ${effectiveEvent.name}...',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Assigned Event Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppColors.softShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.cyan.withAlpha(25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              effectiveEvent.category.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.cyan,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.backgroundSecondary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              effectiveEvent.eventCode,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        effectiveEvent.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 15, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              effectiveEvent.venue ?? 'Main Campus',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ),
                          const Icon(Icons.schedule_rounded, size: 15, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            TimeFormatter.formatTimeOrRange(effectiveEvent.time).isNotEmpty
                                ? TimeFormatter.formatTimeOrRange(effectiveEvent.time)
                                : (effectiveEvent.time ?? 'Day 1'),
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Primary Hero: SCAN EVENT QR
                Material(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    onTap: () {
                      _navigateToTab(1);
                    },
                    borderRadius: BorderRadius.circular(24),
                    splashColor: AppColors.cyan.withAlpha(40),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.cyan.withAlpha(140),
                          width: 1.5,
                        ),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF0A101D),
                            Color(0xFF132038),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.cyan.withAlpha(60),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
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
                                size: 28,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'SCAN EVENT QR',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Mark attendance for ${effectiveEvent.name}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
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
                const SizedBox(height: 22),

                // Live Event Statistics Row
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: 'Registrations',
                        value: '${effectiveEvent.registrationCount}',
                        subtitle: 'Registered',
                        icon: Icons.group_rounded,
                        accentColor: AppColors.electricBlue,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: StatCard(
                        title: 'Present',
                        value: '${effectiveEvent.attendanceCount}',
                        subtitle: 'Attended',
                        icon: Icons.event_available_rounded,
                        accentColor: AppColors.cyan,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Recent Event Attendance Activity
                SectionHeader(
                  title: 'Event Scans',
                  actionLabel: 'History',
                  onActionTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const HistoryScreen()),
                    ).then((_) => _loadCurrentEventDetails());
                  },
                ),
                const SizedBox(height: 8),

                if (_recentEventActivities.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Center(
                      child: Text(
                        'No attendance records marked yet for ${effectiveEvent.name}.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                else
                  ..._recentEventActivities.map((act) => Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: _buildAttendanceTile(act),
                      )),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttendanceTile(ActivityItem item) {
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
              color: AppColors.cyan.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.event_available_rounded,
              size: 18,
              color: AppColors.cyan,
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
          Text(
            _formatTimestamp(item.timestamp),
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventTab(EventModel? event) {
    if (event == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text('No assigned event.')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(event.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadCurrentEventDetails,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        event.eventCode,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.cyan,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.cyan.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          event.status.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.cyan,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    event.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow('Category', event.category),
                  const Divider(height: 16),
                  _buildDetailRow('Venue', event.venue ?? 'TBD'),
                  const Divider(height: 16),
                  _buildDetailRow(
                    'Date & Time',
                    '${event.date ?? 'Day 1'}${TimeFormatter.formatTimeOrRange(event.time).isNotEmpty ? ' • ${TimeFormatter.formatTimeOrRange(event.time)}' : (event.time != null && event.time!.isNotEmpty ? ' • ${event.time}' : '')}',
                  ),
                  const Divider(height: 16),
                  _buildDetailRow('Registered', '${event.registrationCount} Participants'),
                  const Divider(height: 16),
                  _buildDetailRow('Present at Event', '${event.attendanceCount} Checked In'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SectionHeader(
              title: 'Registered Participants (${_eventRoster.length})',
              actionLabel: 'Search',
              onActionTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ParticipantSearchScreen(
                      mode: AttendanceMode.event,
                      eventId: event.id,
                      eventName: event.name,
                    ),
                  ),
                ).then((_) => _loadCurrentEventDetails());
              },
            ),
            const SizedBox(height: 10),

            if (_eventRoster.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: Text(
                    'No participants registered yet for this event.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ..._eventRoster.map((reg) {
                final participant = reg['participants'] as Map<String, dynamic>?;
                final pName = participant?['name']?.toString() ?? 'Participant';
                final pCode = participant?['participant_code']?.toString() ?? '—';
                final college = participant?['college']?.toString() ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.backgroundSecondary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            pName.isNotEmpty ? pName[0].toUpperCase() : 'P',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              college.isNotEmpty ? '$pCode • $college' : pCode,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final isScanActive = _currentIndex == 1;

    final unselectedColor = isScanActive ? AppColors.textDarkSecondary : AppColors.textMuted;
    final selectedColor = isScanActive ? AppColors.cyan : AppColors.electricBlue;

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
              color: isSelected ? selectedColor : unselectedColor,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? selectedColor : unselectedColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanNavItem() {
    final isScanSelected = _currentIndex == 1;

    return GestureDetector(
      onTap: () => _navigateToTab(1),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.cyan.withAlpha(isScanSelected ? 120 : 60),
              blurRadius: isScanSelected ? 16 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.qr_code_scanner_rounded,
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: 6),
            Text(
              'Scan',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.2,
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
