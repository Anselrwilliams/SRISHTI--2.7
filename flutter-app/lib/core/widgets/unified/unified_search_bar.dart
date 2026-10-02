import 'package:flutter/material.dart';

/// Reusable search bar component matching the reference screenshot.
/// Large rounded white search pill with subtle shadow and an adjacent
/// rounded square filter/tune action button on the right.
class UnifiedSearchBar extends StatelessWidget {
  final String placeholder;
  final VoidCallback onTap;
  final VoidCallback? onFilterTap;
  final bool showFilterButton;

  const UnifiedSearchBar({
    super.key,
    required this.placeholder,
    required this.onTap,
    this.onFilterTap,
    this.showFilterButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Rounded search capsule
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(27),
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1.0),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A0F172A),
                    blurRadius: 18,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    size: 22,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      placeholder,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Rounded filter / settings button
        if (showFilterButton) ...[
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onFilterTap ?? onTap,
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1.0),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A0F172A),
                    blurRadius: 18,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
