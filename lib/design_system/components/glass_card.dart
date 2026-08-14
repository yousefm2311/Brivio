import 'dart:ui';
import 'package:flutter/material.dart';
import '../tokens/colors.dart';

/// ─────────────────────────────────────────────────────────────────────────────
///  GlassCard — Frosted glass card with blur, border, and glow
/// ─────────────────────────────────────────────────────────────────────────────
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Color? color;
  final Color? borderColor;
  final double blur;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final List<BoxShadow>? boxShadow;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.color,
    this.borderColor,
    this.blur = 12.0,
    this.width,
    this.height,
    this.onTap,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(20);
    final glassColor = color ?? AppColors.glassMedium;
    final border = borderColor ?? AppColors.glassBorder;

    Widget content = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: glassColor,
            borderRadius: radius,
            border: Border.all(color: border, width: 0.6),
            boxShadow: boxShadow,
          ),
          padding: padding ?? const EdgeInsets.all(20),
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    );

    if (onTap != null) {
      content = GestureDetector(onTap: onTap, child: content);
    }

    return content;
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
///  GlassSurface — Lighter glass for non-interactive surfaces
/// ─────────────────────────────────────────────────────────────────────────────
class GlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final double blur;

  const GlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.blur = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(16);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.glassLight,
            borderRadius: radius,
            border: Border.all(color: AppColors.glassBorder, width: 0.5),
          ),
          padding: padding,
          child: Material(type: MaterialType.transparency, child: child),
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
///  GlowContainer — Container with colored glow shadow
/// ─────────────────────────────────────────────────────────────────────────────
class GlowContainer extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  final double glowRadius;
  final double glowOpacity;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final Gradient? gradient;
  final Color? color;

  const GlowContainer({
    super.key,
    required this.child,
    required this.glowColor,
    this.glowRadius = 24.0,
    this.glowOpacity = 0.35,
    this.padding,
    this.borderRadius,
    this.gradient,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(20);
    return Container(
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? glowColor) : null,
        gradient: gradient,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: glowOpacity),
            blurRadius: glowRadius,
            offset: const Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      padding: padding ?? const EdgeInsets.all(20),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
///  AppCard — Standard dark card
/// ─────────────────────────────────────────────────────────────────────────────
class AppCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final bool animate;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
    this.onTap,
    this.color,
    this.borderColor,
    this.animate = true,
  });

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = _ctrl;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(18);
    final cardColor = widget.color ?? AppColors.darkCard;
    final border = widget.borderColor ?? AppColors.darkBorder;

    Widget card = Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: radius,
        border: Border.all(color: border, width: 0.5),
      ),
      padding: widget.padding ?? const EdgeInsets.all(16),
      child: Material(type: MaterialType.transparency, child: widget.child),
    );

    if (widget.onTap == null) return card;

    return GestureDetector(
      onTapDown: widget.animate ? (_) => _ctrl.reverse() : null,
      onTapUp: widget.animate ? (_) => _ctrl.forward() : null,
      onTapCancel: widget.animate ? () => _ctrl.forward() : null,
      onTap: widget.onTap,
      child: ScaleTransition(scale: _scale, child: card),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
///  FadeInSlide — Entrance animation: fade + slide up
/// ─────────────────────────────────────────────────────────────────────────────
class FadeInSlide extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final double slideOffset;
  final Axis axis;

  const FadeInSlide({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 400),
    this.slideOffset = 24.0,
    this.axis = Axis.vertical,
  });

  @override
  State<FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<FadeInSlide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: widget.axis == Axis.vertical
          ? Offset(0, widget.slideOffset / 100)
          : Offset(widget.slideOffset / 100, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
///  PulsingDot — Small animated pulsing indicator dot
/// ─────────────────────────────────────────────────────────────────────────────
class PulsingDot extends StatefulWidget {
  final Color color;
  final double size;

  const PulsingDot({super.key, required this.color, this.size = 8.0});

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: _pulse.value),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: _pulse.value * 0.5),
              blurRadius: widget.size * 1.5,
              spreadRadius: widget.size * 0.2,
            ),
          ],
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
///  ShimmerBox — Skeleton loading placeholder
/// ─────────────────────────────────────────────────────────────────────────────
class ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _anim = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius ?? BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: const Alignment(-1, 0),
            end: const Alignment(2, 0),
            stops: [
              (_anim.value - 0.5).clamp(0.0, 1.0),
              _anim.value.clamp(0.0, 1.0),
              (_anim.value + 0.5).clamp(0.0, 1.0),
            ],
            colors: const [
              Color(0xFF1C1C1E),
              Color(0xFF2C2C2E),
              Color(0xFF1C1C1E),
            ],
          ),
        ),
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
///  StatusChip — Colored status pill (success/warning/error/info)
/// ─────────────────────────────────────────────────────────────────────────────
enum ChipStatus { success, warning, error, info, neutral, purple }

class StatusChip extends StatelessWidget {
  final String label;
  final ChipStatus status;
  final IconData? icon;
  final bool small;

  const StatusChip({
    super.key,
    required this.label,
    required this.status,
    this.icon,
    this.small = false,
  });

  Color get _color => switch (status) {
    ChipStatus.success => AppColors.success,
    ChipStatus.warning => AppColors.warning,
    ChipStatus.error => AppColors.error,
    ChipStatus.info => AppColors.primary,
    ChipStatus.neutral => AppColors.darkTextSecondary,
    ChipStatus.purple => AppColors.purple,
  };

  Color get _bg => switch (status) {
    ChipStatus.success => AppColors.successSubtle,
    ChipStatus.warning => AppColors.warningSubtle,
    ChipStatus.error => AppColors.errorSubtle,
    ChipStatus.info => AppColors.primarySubtle,
    ChipStatus.neutral => AppColors.darkSurface,
    ChipStatus.purple => AppColors.purpleSubtle,
  };

  @override
  Widget build(BuildContext context) {
    final fs = small ? 10.0 : 11.5;
    final px = small ? 8.0 : 10.0;
    final py = small ? 3.0 : 5.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: px, vertical: py),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: _color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fs + 1, color: _color),
            SizedBox(width: small ? 3 : 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fs,
              fontWeight: FontWeight.w600,
              color: _color,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
///  SectionHeader — Section title + optional action button
/// ─────────────────────────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.darkTextPrimary,
                letterSpacing: -0.4,
                height: 1.2,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// ─────────────────────────────────────────────────────────────────────────────
///  CircleIcon — Icon inside a tinted circle
/// ─────────────────────────────────────────────────────────────────────────────
class CircleIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;

  const CircleIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
    this.iconSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}
