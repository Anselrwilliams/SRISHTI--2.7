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
import '../../participants/models/participant_model.dart';
import '../../participants/screens/participant_detail_sheet.dart';
import '../../participants/screens/participant_search_screen.dart';
import '../../participants/services/participant_service.dart';

/// Volunteer Home Dashboard displaying greetings, authoritative Supabase metrics
/// (Registered, Arrived, and Pending Arrival), prominent Festival Arrival Scan QR hero,
/// and accurate Recent Arrivals with timestamps and History navigation.
class HomeScreen extends StatefulWidget {
  final VoidCallback onScanPressed;
  final VoidCallback onEventsPressed;
  final VolunteerModel? volunteer;
  final CheckinService? checkinService;
  final ParticipantService? participantService;

  const HomeScreen({
    super.key,
    required this.onScanPressed,
    required this.onEventsPressed,
    this.volunteer,
    this.checkinService,
    this.participantService,
  });

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  late final CheckinService _checkinService;
  late final ParticipantService _participantService;

  FestivalStats? _stats;
  List<ActivityItem> _recentArrivals = [];
  EventModel? _featuredEvent;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isOpeningParticipant = false;
  int _latestRequestId = 0;

  @override
  void initState() {
    super.initState();
    _checkinService = widget.checkinService ?? CheckinService();
    _participantService = widget.participantService ?? ParticipantService();
    _loadRealStats();
  }

  @override
  void dispose() {
    _latestRequestId++; // Invalidate any in-flight async requests
    super.dispose();
  }

  /// Public reload trigger callable by parent navigator or tab transitions.
  void reloadStats() {
    _loadRealStats();
  }

  Future<void> _loadRealStats() async {
    final requestId = ++_latestRequestId;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final stats = await _checkinService.getFestivalArrivalStats();
      final arrivals = await _checkinService.getRecentArrivals(limit: 5);

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

      if (!mounted || requestId != _latestRequestId) return;

      setState(() {
        _stats = stats;
        _recentArrivals = arrivals;
        _featuredEvent = featured;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted || requestId != _latestRequestId) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load live attendance metrics. Check network connection.';
      });
    }
  }

  Future<void> _openParticipantDetails(ActivityItem item) async {
    if (_isOpeningParticipant) return;
    final cleanCode = item.participantCode.trim();
    if (cleanCode.isEmpty || cleanCode == '—') return;

    setState(() => _isOpeningParticipant = true);

    try {
      final participantData =
          await _participantService.getParticipantByCode(cleanCode);
      if (participantData == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Participant $cleanCode not found.')),
        );
        return;
      }

      if (!mounted) return;

      final participant = ParticipantModel.fromMap(
        participantData,
        isCheckedIn: true,
        checkedInAt: item.timestamp,
      );

      await ParticipantDetailSheet.show(
        context,
        participant: participant,
        mode: AttendanceMode.arrival,
        source: item.source.toLowerCase().contains('manual') ? 'manual' : 'qr',
        onActionSuccess: _loadRealStats,
        participantService: _participantService,
        checkinService: _checkinService,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load participant details: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isOpeningParticipant = false);
      }
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

  Widget _buildStatisticsSection() {
    if (_errorMessage != null && _stats == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.errorBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.errorBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.error, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _loadRealStats,
              icon: const Icon(Icons.refresh_rounded, size: 16, color: AppColors.electricBlue),
              label: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.electricBlue,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final registeredVal = _stats != null ? _stats!.registered.toString() : (_isLoading ? '...' : '—');
    final arrivedVal = _stats != null ? _stats!.arrived.toString() : (_isLoading ? '...' : '—');
    final pendingVal = _stats != null ? _stats!.pendingArrival.toString() : (_isLoading ? '...' : '—');

    return Row(
      children: [
        Expanded(
          child: UnifiedStatsCard(
            label: 'REGISTERED',
            value: registeredVal,
            subtitle: 'Total participants',
            icon: Icons.people_alt_rounded,
            accentColor: AppColors.blue,
            isCompact: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: UnifiedStatsCard(
            label: 'ARRIVED',
            value: arrivedVal,
            subtitle: 'Gate verified',
            icon: Icons.check_circle_rounded,
            accentColor: AppColors.success,
            isCompact: true,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: UnifiedStatsCard(
            label: 'PENDING',
            value: pendingVal,
            subtitle: 'Pending arrival',
            icon: Icons.pending_actions_rounded,
            accentColor: const Color(0xFFF59E0B),
            isCompact: true,
          ),
        ),
      ],
    );
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

                  // Unified Statistics Cards (3 compact cards: Registered, Arrived, Pending)
                  _buildStatisticsSection(),
                  const SizedBox(height: 24),

                  // Unified Activity Section (Recent Arrivals with History action)
                  UnifiedActivitySection(
                    title: 'Recent Arrivals',
                    actionLabel: 'History',
                    onActionTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => HistoryScreen(
                            initialFilter: 'Arrival',
                            checkinService: _checkinService,
                          ),
                        ),
                      ).then((_) => _loadRealStats());
                    },
                    emptyMessage: 'No arrivals recorded yet today.',
                    children: _recentArrivals.map((act) {
                      final isArrival = act.actionType == 'Arrival Check-in';
                      return UnifiedActivityCard(
                        participantName: act.participantName,
                        participantCode: act.participantCode,
                        source: act.source,
                        statusLabel: isArrival ? 'Arrived' : 'Attended',
                        statusColor: isArrival ? AppColors.success : AppColors.blue,
                        timeString: TimeFormatter.formatRelativeTime(act.timestamp),
                        exactTime: TimeFormatter.formatExactTime(act.timestamp),
                        eventOrGate: act.gateOrVenue,
                        onTap: () => _openParticipantDetails(act),
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
}
