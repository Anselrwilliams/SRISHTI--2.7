import 'package:flutter/material.dart';
import '../../../core/widgets/floating_nav_bar.dart';
import '../../auth/models/volunteer_model.dart';
import '../../events/screens/events_screen.dart';
import '../../home/screens/home_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../scanner/screens/scan_screen.dart';

/// Main Dashboard container managing tabs and prominent Scan QR navigation for general volunteers.
class DashboardScreen extends StatefulWidget {
  final VolunteerModel? volunteer;

  const DashboardScreen({
    super.key,
    this.volunteer,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

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
      HomeScreen(
        volunteer: widget.volunteer,
        onScanPressed: () => _navigateToTab(1),
        onEventsPressed: () => _navigateToTab(2),
      ),
      ScanScreen(
        isActive: _currentIndex == 1,
        onScanComplete: () {
          // Can refresh stats
        },
        onBackPressed: () => _navigateToTab(0),
      ),
      EventsScreen(
        onNavigateToScan: () => _navigateToTab(1),
      ),
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
          FloatingNavItem(
            icon: Icons.qr_code_scanner_rounded,
            label: 'Scan',
            isPrimaryScan: true,
          ),
          FloatingNavItem(
            icon: Icons.event_note_rounded,
            label: 'Event',
            testAlias: 'Events',
          ),
          FloatingNavItem(icon: Icons.person_rounded, label: 'Profile'),
        ],
      ),
    ),
    );
  }
}
