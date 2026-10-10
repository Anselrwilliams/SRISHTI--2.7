import 'package:flutter/material.dart';
import '../../../core/widgets/floating_nav_bar.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/time_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/unified/unified_design_system.dart';
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

  String _getCoordinatorTitle(EventModel? event) {
    if (widget.volunteer.name.isNotEmpty &&
        widget.volunteer.name.toLowerCase().contains('coordinator')) {
      return widget.volunteer.name;
    }
    if (event != null) {
      if (event.name.toLowerCase().contains('quiz')) {
        return 'Quiz Coordinator';
      }
      if (event.name.toLowerCase().contains('code') ||
          event.name.toLowerCase().contains('coding')) {
        return 'Coding Coordinator';
      }
      return '${event.name} Coordinator';
    }
    return widget.volunteer.name.isNotEmpty
        ? widget.volunteer.name
        : 'Event Coordinator';
  }

  void _navigateToTab(int index) {
    if (_currentIndex == 1 && index != 1) {
      ScanScreen.stopActiveScanner();
    }
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
              onBackPressed: () => _navigateToTab(0),
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

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex != 0) {
          _navigateToTab(0);
        }
      },
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
        bottomNavigationBar: FloatingNavBar(
          currentIndex: _currentIndex,
          onTap: _navigateToTab,
          isDark: _currentIndex == 1,
          items: const [
            FloatingNavItem(icon: Icons.home_rounded, label: 'Home'),
            FloatingNavItem(icon: Icons.qr_code_scanner_rounded, label: 'Scan', isPrimaryScan: true),
            FloatingNavItem(icon: Icons.event_note_rounded, label: 'Event'),
            FloatingNavItem(icon: Icons.person_rounded, label: 'Profile'),
          ],
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
      body: UnifiedBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadAssignedEvents,
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
                    highlightedText: _getCoordinatorTitle(effectiveEvent),
                    roleSubtitle: 'Event Coordinator',
                    statusIndicatorColor: AppColors.cyan,
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

                  // Unified Search Bar
                  UnifiedSearchBar(
                    placeholder: 'Search participant for ${effectiveEvent.name}...',
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
                  ),
                  const SizedBox(height: 18),

                  // Unified Primary Content Event Card
                  UnifiedEventCard(
                    category: effectiveEvent.category.isNotEmpty
                        ? effectiveEvent.category
                        : 'EVENT',
                    eventCode: effectiveEvent.eventCode,
                    title: effectiveEvent.name,
                    venue: effectiveEvent.venue ?? 'CS Lab 3',
                    date: effectiveEvent.date ?? 'Oct 2, 2026',
                    time: TimeFormatter.formatTimeOrRange(effectiveEvent.time).isNotEmpty
                        ? TimeFormatter.formatTimeOrRange(effectiveEvent.time)
                        : (effectiveEvent.time ?? '10:30 AM - 12:30 PM'),
                    onTap: () => _navigateToTab(2),
                  ),
                  const SizedBox(height: 18),

                  // Unified Primary Action Card (SCAN EVENT)
                  UnifiedPrimaryActionCard(
                    title: 'SCAN EVENT',
                    subtitle: 'Mark attendance for ${effectiveEvent.name}',
                    onTap: () => _navigateToTab(1),
                  ),
                  const SizedBox(height: 18),

                  // Unified Statistics Cards (2 compact cards side-by-side)
                  Row(
                    children: [
                      Expanded(
                        child: UnifiedStatsCard(
                          label: 'REGISTRATIONS',
                          value: '${effectiveEvent.registrationCount}',
                          subtitle: 'Total Registered',
                          icon: Icons.people_alt_rounded,
                          accentColor: AppColors.blue,
                          showWave: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: UnifiedStatsCard(
                          label: 'PRESENT',
                          value: '${effectiveEvent.attendanceCount}',
                          subtitle: 'Attended',
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
                    title: 'Event Scans',
                    actionLabel: 'History',
                    onActionTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const HistoryScreen()),
                      ).then((_) => _loadCurrentEventDetails());
                    },
                    emptyMessage: 'No attendance records marked yet for ${effectiveEvent.name}.',
                    children: _recentEventActivities.map((item) {
                      return UnifiedActivityCard(
                        participantName: item.participantName,
                        participantCode: item.participantCode,
                        source: item.source,
                        statusLabel: 'Attended',
                        statusColor: AppColors.success,
                        timeString: TimeFormatter.formatRelativeTime(item.timestamp),
                        exactTime: TimeFormatter.formatExactTime(item.timestamp),
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
        padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 100.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              padding: const EdgeInsets.all(22),
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
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderLight, width: 1.2),
                  boxShadow: AppColors.softShadow,
                ),
                child: const Center(
                  child: Text(
                    'No participants registered yet for this event.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.borderLight, width: 1.2),
                    boxShadow: AppColors.softShadow,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.backgroundSecondary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            pName.isNotEmpty ? pName[0].toUpperCase() : 'P',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
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
}
