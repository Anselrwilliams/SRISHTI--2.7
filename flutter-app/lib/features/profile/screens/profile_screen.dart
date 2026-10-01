import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../history/screens/history_screen.dart';

/// Volunteer profile and session management screen.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoggingOut = false;

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to log out from the volunteer portal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
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
    final user = SupabaseService.instance.currentUser;
    final email = user?.email ?? 'volunteer@srishti.org';
    final name = email.split('@').first.replaceAll('.', ' ').toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Volunteer Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Avatar Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.softShadow,
              ),
              child: Column(
                children: [
                  // Gradient Ring Avatar
                  Container(
                    width: 76,
                    height: 76,
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.primaryGradient,
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceDark,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          name.isNotEmpty ? name.substring(0, 1) : 'V',
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
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.cyan.withAlpha(25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.cyan.withAlpha(80)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_outlined, size: 14, color: AppColors.electricBlue),
                        SizedBox(width: 6),
                        Text(
                          'SRISHTI 2.7 Volunteer',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.electricBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Volunteer Metrics Summary
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.softShadow,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMetricItem('Today\'s Scans', '42'),
                  Container(height: 30, width: 1, color: AppColors.borderLight),
                  _buildMetricItem('Arrivals', '29'),
                  Container(height: 30, width: 1, color: AppColors.borderLight),
                  _buildMetricItem('Events', '13'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Actions & Activity Links
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
                boxShadow: AppColors.softShadow,
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.history_rounded, color: AppColors.textPrimary),
                    title: const Text('Activity History', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('View your recent scans and check-ins', style: TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const HistoryScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.cloud_done_outlined, color: AppColors.success),
                    title: const Text('Supabase Connection', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: const Text('Connected with Row Level Security', style: TextStyle(fontSize: 12)),
                    trailing: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
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
          ],
        ),
      ),
    );
  }

  Widget _buildMetricItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
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
