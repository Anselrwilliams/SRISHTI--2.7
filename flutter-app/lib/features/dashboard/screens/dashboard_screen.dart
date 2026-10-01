import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../events/screens/events_screen.dart';
import '../../home/screens/home_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../scanner/screens/scan_screen.dart';

/// Main Dashboard container managing tabs and prominent Scan QR navigation.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  void _navigateToTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeScreen(
        onScanPressed: () => _navigateToTab(1),
        onEventsPressed: () => _navigateToTab(2),
      ),
      ScanScreen(
        onScanComplete: () {
          // Can refresh stats
        },
      ),
      EventsScreen(
        onNavigateToScan: () => _navigateToTab(1),
      ),
      const ProfileScreen(),
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
                _buildNavItem(
                  index: 0,
                  icon: Icons.home_rounded,
                  label: 'Home',
                ),
                _buildScanNavItem(),
                _buildNavItem(
                  index: 2,
                  icon: Icons.event_note_rounded,
                  label: 'Events',
                ),
                _buildNavItem(
                  index: 3,
                  icon: Icons.person_rounded,
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
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
}
