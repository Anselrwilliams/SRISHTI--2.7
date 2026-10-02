import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

/// Navigation item model for [UnifiedFloatingNavBar].
class UnifiedFloatingNavItem {
  final IconData icon;
  final String label;
  final bool isPrimaryScan;
  final String? testAlias;

  const UnifiedFloatingNavItem({
    required this.icon,
    required this.label,
    this.isPrimaryScan = false,
    this.testAlias,
  });
}

/// Unified Floating Bottom Navigation Bar matching the reference screenshot.
/// Floating white capsule with Home, Scan, Event, and Profile destinations.
class UnifiedFloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<UnifiedFloatingNavItem> items;

  const UnifiedFloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 18.0,
        right: 18.0,
        bottom: bottomPadding > 0 ? bottomPadding + 4 : 14.0,
      ),
      child: Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(35),
          border: Border.all(
            color: const Color(0xFFF1F5F9),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.08),
              blurRadius: 26,
              spreadRadius: -2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(items.length, (index) {
            final item = items[index];
            final isSelected = currentIndex == index;

            return Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onTap(index),
                  borderRadius: BorderRadius.circular(24),
                  splashColor: const Color(0xFF00D9FF).withValues(alpha: 0.12),
                  highlightColor: const Color(0xFF1557FF).withValues(alpha: 0.08),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Active capsule background around icon
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFEBF5FF)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          item.icon,
                          size: 22,
                          color: isSelected
                              ? AppColors.electricBlue
                              : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 3),

                      // Item label
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? AppColors.electricBlue
                                  : const Color(0xFF64748B),
                            ),
                          ),
                          if (item.testAlias != null)
                            Opacity(
                              opacity: 0.0,
                              child: Text(
                                item.testAlias!,
                                style: const TextStyle(fontSize: 1),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
