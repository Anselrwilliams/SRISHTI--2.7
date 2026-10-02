import 'package:flutter/material.dart';

/// Renders the official SRISHTI 2.7 logo using the original project asset.
/// Transparent background ensures it floats naturally on the light canvas
/// without any artificial black borders or custom painter redraws.
class SrishtiLogo extends StatelessWidget {
  final double size;
  final bool showBadge;
  final bool compact;

  const SrishtiLogo({
    super.key,
    this.size = 52,
    this.showBadge = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/srishti_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // Fallback to original jpg asset
        return Image.asset(
          'assets/images/srishti_logo.jpg',
          width: size,
          height: size,
          fit: BoxFit.contain,
        );
      },
    );
  }
}
