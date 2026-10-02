import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Apple-style tactile button featuring the SRISHTI cyan-to-electric-blue gradient
/// with smooth micro-interaction press feedback.
class GradientButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool isLoading;
  final double height;
  final double borderRadius;
  final bool fullWidth;
  final Gradient? gradient;

  const GradientButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isLoading = false,
    this.height = 52,
    this.borderRadius = 18,
    this.fullWidth = true,
    this.gradient,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.onPressed != null && !widget.isLoading) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;
    final effectiveGradient = widget.gradient ?? AppColors.primaryGradient;

    Widget buttonContent = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (widget.isLoading) ...[
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 12),
        ] else if (widget.icon != null) ...[
          Icon(widget.icon, size: 20, color: Colors.white),
          const SizedBox(width: 8),
        ],
        Text(
          widget.label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: isEnabled ? widget.onPressed : null,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: isEnabled ? 1.0 : 0.6,
          child: Container(
            height: widget.height,
            width: widget.fullWidth ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              gradient: effectiveGradient,
              borderRadius: BorderRadius.circular(widget.borderRadius),
              boxShadow: isEnabled ? AppColors.glowShadow : null,
            ),
            child: Center(child: buttonContent),
          ),
        ),
      ),
    );
  }
}
