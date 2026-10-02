import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/floating_nav_bar.dart';
import '../../../core/widgets/unified/unified_design_system.dart';
import '../../auth/models/volunteer_model.dart';
import '../../checkin/models/attendance_mode.dart';
import '../../checkin/services/checkin_service.dart';
import '../../history/models/activity_item.dart';
import '../../participants/models/participant_model.dart';
import '../../participants/screens/participant_detail_sheet.dart';
import '../../participants/screens/participant_search_screen.dart';
import '../../participants/services/participant_service.dart';
import '../../profile/screens/profile_screen.dart';
import '../../scanner/screens/scan_screen.dart';

/// Registration-focused dashboard for gate volunteers.
/// Focuses purely on Festival Arrival Check-ins with real Supabase metrics.
class RegistrationDashboardScreen extends StatefulWidget {
  final VolunteerModel volunteer;
  final CheckinService? checkinService;
  final ParticipantService? participantService;

  const RegistrationDashboardScreen({
    super.key,
    required this.volunteer,
    this.checkinService,
    this.participantService,
  });

  @override
  State<RegistrationDashboardScreen> createState() =>
      _RegistrationDashboardScreenState();
}

class _RegistrationDashboardScreenState
    extends State<RegistrationDashboardScreen> {
  int _currentIndex = 0;
  bool _isLoading = true;

  int _totalParticipants = 0;
  int _totalArrived = 0;
  int _remainingArrivals = 0;
  List<ActivityItem> _recentArrivals = [];

  late final CheckinService _checkinService;
  late final ParticipantService _participantService;
  bool _isOpeningParticipant = false;

  @override
  void initState() {
    super.initState();
    _checkinService = widget.checkinService ?? CheckinService();
    _participantService = widget.participantService ?? ParticipantService();
    _loadArrivalStats();
  }

  Future<void> _loadArrivalStats() async {
    setState(() => _isLoading = true);

    try {
      final totalP = await _checkinService.getTotalParticipantsCount();
      final totalA = await _checkinService.getTotalArrivalsCount();
      final recent = await _checkinService.getRecentArrivals(limit: 15);

      if (!mounted) return;

      setState(() {
        _totalParticipants = totalP;
        _totalArrived = totalA;
        _remainingArrivals = (totalP - totalA) > 0 ? (totalP - totalA) : 0;
        _recentArrivals = recent;
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
    final List<Widget> screens = [
      _buildHomeTab(),
      ScanScreen(
        key: const ValueKey('registration_scan_arrival'),
        isActive: _currentIndex == 1,
        mode: AttendanceMode.arrival,
        onScanComplete: _loadArrivalStats,
        onBackPressed: () => _navigateToTab(0),
      ),
      _buildArrivalsTab(),
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
        body: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
        bottomNavigationBar: FloatingNavBar(
          currentIndex: _currentIndex,
          isDark: _currentIndex == 1,
          onTap: _navigateToTab,
          items: const [
            FloatingNavItem(icon: Icons.home_rounded, label: 'Home'),
            FloatingNavItem(
              icon: Icons.qr_code_scanner_rounded,
              label: 'Scan',
              testAlias: 'Scan Arrival',
              isPrimaryScan: true,
            ),
            FloatingNavItem(
              icon: Icons.event_note_rounded,
              label: 'Event',
              testAlias: 'Arrivals',
            ),
            FloatingNavItem(icon: Icons.person_rounded, label: 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: UnifiedBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadArrivalStats,
            color: AppColors.blue,
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
                    highlightedText: widget.volunteer.name.isNotEmpty &&
                            !widget.volunteer.name.toLowerCase().contains('coordinator')
                        ? widget.volunteer.name
                        : 'Registration',
                    roleSubtitle: 'Registration Desk • Gate Entry',
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
                      ).then((_) => _loadArrivalStats());
                    },
                  ),
                  const SizedBox(height: 18),

                  // Unified Primary Content Card
                  UnifiedEventCard(
                    category: 'FESTIVAL',
                    eventCode: 'SRI-2026',
                    title: 'SRISHTI 2.7 Gate Operations',
                    venue: 'Main Gate Entry',
                    date: 'Today',
                    time: 'Gate Active',
                    onTap: () => _navigateToTab(2),
                  ),
                  const SizedBox(height: 18),

                  // Unified Primary Action Card (FEST CHECK-IN)
                  UnifiedPrimaryActionCard(
                    title: 'FEST CHECK-IN',
                    subtitle: 'Festival gate verification',
                    onTap: () => _navigateToTab(1),
                  ),
                  const SizedBox(height: 18),

                  // Unified Statistics Cards (2 compact cards matching reference)
                  Row(
                    children: [
                      Expanded(
                        child: UnifiedStatsCard(
                          label: 'REGISTERED',
                          value: '$_totalParticipants',
                          subtitle: '$_remainingArrivals pending',
                          icon: Icons.people_alt_rounded,
                          accentColor: AppColors.blue,
                          showWave: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: UnifiedStatsCard(
                          label: 'ARRIVED',
                          value: '$_totalArrived',
                          subtitle: 'Gate checked in',
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
                    title: 'Recent Arrivals',
                    actionLabel: 'History',
                    onActionTap: () => _navigateToTab(2),
                    emptyMessage: 'No arrivals recorded yet today.',
                    children: _recentArrivals.take(6).map((act) {
                      return UnifiedActivityCard(
                        participantName: act.participantName,
                        participantCode: act.participantCode,
                        source: act.source,
                        statusLabel: 'Arrived',
                        statusColor: AppColors.success,
                        timeString: _formatTimestamp(act.timestamp),
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

  Widget _buildArrivalsTab() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('FEST Arrivals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _loadArrivalStats,
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search Participant',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ParticipantSearchScreen(
                    mode: AttendanceMode.arrival,
                  ),
                ),
              ).then((_) => _loadArrivalStats());
            },
          ),
        ],
      ),
      body: _recentArrivals.isEmpty
          ? Center(
              child: Text(
                _isLoading ? 'Loading arrivals...' : 'No arrivals recorded yet.',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _recentArrivals.length,
              itemBuilder: (context, index) {
                final item = _recentArrivals[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.borderLight),
                      boxShadow: AppColors.softShadow,
                    ),
                    child: _buildArrivalTile(item),
                  ),
                );
              },
            ),
    );
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
        onActionSuccess: _loadArrivalStats,
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

  Widget _buildArrivalTile(ActivityItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openParticipantDetails(item),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              // Avatar with soft green icon
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.success.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(
                    Icons.how_to_reg_rounded,
                    size: 19,
                    color: AppColors.success,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Participant Name & Code
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.participantName,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.participantCode} • ${item.source}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Status and time
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Arrived',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatTimestamp(item.timestamp),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textMuted,
              ),
            ],
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
