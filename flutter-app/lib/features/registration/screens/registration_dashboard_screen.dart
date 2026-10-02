import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/srishti_logo.dart';
import '../../../core/widgets/stat_card.dart';
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
      ),
      _buildArrivalsTab(),
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
              color: _currentIndex == 1
                  ? AppColors.borderDarkSubtle
                  : AppColors.borderLight,
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
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_rounded, 'Home'),
                _buildScanNavItem(),
                _buildNavItem(2, Icons.how_to_reg_rounded, 'Arrivals'),
                _buildNavItem(3, Icons.person_rounded, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeTab() {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadArrivalStats,
          color: AppColors.success,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding:
                const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with Real Volunteer Name & Date
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
                              color: AppColors.success,
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
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Registration Desk • Gate Entry',
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
                const SizedBox(height: 20),

                // Manual Participant Search Shortcut
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const ParticipantSearchScreen(
                          mode: AttendanceMode.arrival,
                        ),
                      ),
                    ).then((_) => _loadArrivalStats());
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.search_rounded,
                            size: 20, color: AppColors.textSecondary),
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
                const SizedBox(height: 22),

                // Primary Hero: SCAN ARRIVAL QR
                Material(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    onTap: () {
                      _navigateToTab(1);
                    },
                    borderRadius: BorderRadius.circular(24),
                    splashColor: AppColors.success.withAlpha(40),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 22),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.success.withAlpha(140),
                          width: 1.5,
                        ),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF09140E),
                            Color(0xFF0E2419),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withAlpha(60),
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
                              gradient: const LinearGradient(
                                colors: [Color(0xFF10B981), Color(0xFF059669)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.success.withAlpha(80),
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
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Festival check-in • Fast gate verification',
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
                            color: AppColors.success,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // 3 Arrival Metrics Row
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        title: 'Registered',
                        value: '$_totalParticipants',
                        subtitle: 'Total Fest',
                        icon: Icons.people_outline_rounded,
                        accentColor: AppColors.electricBlue,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                        title: 'Arrived',
                        value: '$_totalArrived',
                        subtitle: 'Checked in',
                        icon: Icons.how_to_reg_rounded,
                        accentColor: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatCard(
                        title: 'Remaining',
                        value: '$_remainingArrivals',
                        subtitle: 'Pending',
                        icon: Icons.pending_actions_rounded,
                        accentColor: AppColors.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),

                // Recent Arrivals List
                SectionHeader(
                  title: 'Recent Arrivals',
                  actionLabel: 'View All',
                  onActionTap: () => _navigateToTab(2),
                ),
                const SizedBox(height: 8),

                if (_recentArrivals.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Center(
                      child: Text(
                        'No arrivals recorded yet today.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                else
                  ..._recentArrivals.take(6).map((act) => Padding(
                        padding: const EdgeInsets.only(bottom: 10.0),
                        child: _buildArrivalTile(act),
                      )),
                const SizedBox(height: 16),
              ],
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
        title: const Text('Festival Arrivals'),
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
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildArrivalTile(item),
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openParticipantDetails(item),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.success.withAlpha(20),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.how_to_reg_rounded,
                    size: 18,
                    color: AppColors.success,
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
                    const Text(
                      'Arrived',
                      style: TextStyle(
                        fontSize: 11,
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
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final isScanActive = _currentIndex == 1;

    final unselectedColor =
        isScanActive ? AppColors.textDarkSecondary : AppColors.textMuted;
    final selectedColor = isScanActive ? AppColors.success : AppColors.success;

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
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.success.withAlpha(isScanSelected ? 120 : 60),
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
              'Scan Arrival',
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
