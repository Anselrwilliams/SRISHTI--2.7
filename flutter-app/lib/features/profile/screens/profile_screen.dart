import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/models/volunteer_model.dart';
import '../../checkin/services/checkin_service.dart';
import '../../history/screens/history_screen.dart';
import '../../scanner/services/qr_camera_manager.dart';

/// Volunteer profile and session management screen.
/// Displays authentic volunteer metadata and dynamic scan statistics from Supabase.
class ProfileScreen extends StatefulWidget {
  final VolunteerModel? volunteer;
  final PackageInfo? packageInfo;

  const ProfileScreen({
    super.key,
    this.volunteer,
    this.packageInfo,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final CheckinService _checkinService = CheckinService();
  VolunteerModel? _volunteer;
  bool _isLoadingProfile = false;
  bool _isLoggingOut = false;

  int _totalScans = 0;
  int _arrivalsScans = 0;
  int _eventsScans = 0;

  String _appName = 'FEST Volunteer';
  String _appVersion = '1.0.3';
  String _buildNumber = '4';

  @override
  void initState() {
    super.initState();
    _volunteer = widget.volunteer;
    _initAppInfo();
    _initializeData();
  }

  void _initAppInfo() {
    if (widget.packageInfo != null) {
      _applyPackageInfo(widget.packageInfo!);
    } else {
      _loadAppInfo();
    }
  }

  void _applyPackageInfo(PackageInfo info) {
    if (info.appName.isNotEmpty &&
        info.appName.toLowerCase() != 'srishti_volunteer') {
      _appName = info.appName;
    }
    if (info.version.isNotEmpty) {
      _appVersion = info.version;
    }
    if (info.buildNumber.isNotEmpty) {
      _buildNumber = info.buildNumber;
    }
  }

  Future<void> _loadAppInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _applyPackageInfo(info);
      });
    } catch (_) {
      // Gracefully fall back to defaults if platform metadata is unavailable
    }
  }

  Future<void> _initializeData() async {
    if (_volunteer == null) {
      setState(() => _isLoadingProfile = true);
      try {
        final profile = await SupabaseService.instance.getCurrentVolunteerProfile();
        if (profile != null) {
          _volunteer = VolunteerModel.fromMap(
            profile,
            email: SupabaseService.instance.currentUserEmail,
          );
        }
      } catch (_) {}
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }

    if (_volunteer != null) {
      _loadPersonalMetrics();
    }
  }

  Future<void> _loadPersonalMetrics() async {
    if (_volunteer == null) return;
    try {
      final counts = await _checkinService.getVolunteerActivityCounts(_volunteer!.id);
      if (!mounted) return;
      setState(() {
        _arrivalsScans = counts['arrivals'] ?? 0;
        _eventsScans = counts['events'] ?? 0;
        _totalScans = counts['total'] ?? 0;
      });
    } catch (_) {}
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceDarkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to log out from the volunteer portal?',
          style: TextStyle(color: AppColors.textDarkSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.cyan)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    setState(() => _isLoggingOut = true);

    try {
      await QrCameraManager.instance.stopAndDispose();
      await SupabaseService.instance.signOut();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to sign out: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final displayName = _volunteer?.name ?? 'Volunteer';
    final username = _volunteer?.username.isNotEmpty == true
        ? '@${_volunteer!.username}'
        : (SupabaseService.instance.currentUserEmail ?? 'authorized');
    final roleDisplay = _volunteer?.roleDisplay ?? 'Volunteer';
    final roleColor = _volunteer?.roleColor ?? AppColors.electricBlue;
    final roleIcon = _volunteer?.roleIcon ?? Icons.badge_rounded;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 100.0),
        child: Column(
          children: [
            // Avatar & Identity Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.borderLight, width: 1.2),
                boxShadow: AppColors.softShadow,
              ),
              child: Column(
                children: [
                  // Gradient Ring Avatar
                  Container(
                    width: 76,
                    height: 76,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [roleColor, AppColors.cyan],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceDark,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : 'V',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    displayName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    username,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Role Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: roleColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: roleColor.withAlpha(90)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(roleIcon, size: 15, color: roleColor),
                        const SizedBox(width: 6),
                        Text(
                          roleDisplay,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: roleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Personal Scans Metrics Summary
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.borderLight, width: 1.2),
                boxShadow: AppColors.softShadow,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetricItem('My Scans', '$_totalScans'),
                  Container(height: 32, width: 1, color: AppColors.borderLight),
                  _buildMetricItem('Arrivals', '$_arrivalsScans'),
                  Container(height: 32, width: 1, color: AppColors.borderLight),
                  _buildMetricItem('Events', '$_eventsScans'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Navigation Links
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.borderLight, width: 1.2),
                boxShadow: AppColors.softShadow,
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.history_rounded, color: AppColors.textPrimary),
                      title: const Text('Activity History', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: const Text('View recent scans and check-in timeline', style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const HistoryScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.security_rounded, color: AppColors.electricBlue),
                      title: const Text('Access Permissions', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text('Role: ${_volunteer?.role ?? 'volunteer'}', style: const TextStyle(fontSize: 12)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Sign Out Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.errorBorder),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _isLoggingOut
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error),
                    )
                  : const Icon(Icons.logout_rounded, size: 18),
              label: const Text(
                'Sign Out',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              onPressed: _isLoggingOut ? null : _handleLogout,
            ),
            const SizedBox(height: 24),

            // About this app section
            _buildAboutSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.surfaceDarkCard : AppColors.surface;
    final borderColor = isDark ? AppColors.borderDark : AppColors.borderLight;
    final titleColor = isDark ? AppColors.textDarkPrimary : AppColors.textPrimary;
    final subtitleColor = isDark ? AppColors.textDarkSecondary : AppColors.textSecondary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: isDark ? const [] : AppColors.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.cyan.withAlpha(isDark ? 35 : 20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.cyan.withAlpha(80),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: AppColors.cyan,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'About this app',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.blue.withAlpha(isDark ? 35 : 20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.blue.withAlpha(70),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  'v$_appVersion',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$_appName v$_appVersion (Build $_buildNumber)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 10),
          Divider(
            height: 1,
            color: isDark ? AppColors.borderDarkSubtle : AppColors.borderLight,
          ),
          const SizedBox(height: 10),
          _buildAboutRow('App name', _appName, subtitleColor, titleColor),
          const SizedBox(height: 6),
          _buildAboutRow('Version', 'v$_appVersion', subtitleColor, titleColor),
          const SizedBox(height: 6),
          _buildAboutRow('Build', _buildNumber, subtitleColor, titleColor),
        ],
      ),
    );
  }

  Widget _buildAboutRow(
    String label,
    String value,
    Color labelColor,
    Color valueColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: labelColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: valueColor,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
