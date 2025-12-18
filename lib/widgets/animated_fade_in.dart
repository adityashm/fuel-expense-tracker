import 'package:flutter/material.dart';

/// Simple reusable fade + slide in animation wrapper.
class AnimatedFadeIn extends StatelessWidget {
  const AnimatedFadeIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
    this.delay,
    this.curve = Curves.easeOutCubic,
    this.offsetY = 12,
  });

  final Widget child;
  final Duration duration;
  final Duration? delay;
  final Curve curve;
  final double offsetY;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      curve: curve,
      // Manually implement delay since parameter not available on stable
      child: child,
      builder: (context, value, child) {
        return _DelayedRender(
          delay: delay,
          progress: value,
          offsetY: offsetY,
          child: child!,
        );
      },
    );
  }
}

class _DelayedRender extends StatefulWidget {
  const _DelayedRender({
    required this.delay,
    required this.progress,
    required this.offsetY,
    required this.child,
  });

  final Duration? delay;
  final double progress;
  final double offsetY;
  final Widget child;

  @override
  State<_DelayedRender> createState() => _DelayedRenderState();
}

class _DelayedRenderState extends State<_DelayedRender> {
  bool _shouldShow = false;

  @override
  void initState() {
    super.initState();
    if (widget.delay == null) {
      _shouldShow = true;
    } else {
      Future.delayed(widget.delay!, () {
        if (mounted) setState(() => _shouldShow = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow) {
      return const SizedBox.shrink();
    }
    final value = widget.progress;
    return Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, (1 - value) * widget.offsetY),
        child: widget.child,
      ),
    );
  }
}

/// Lightweight shimmer placeholder without external dependency.
class ShimmerPlaceholder extends StatefulWidget {
  const ShimmerPlaceholder({
    super.key,
    required this.height,
    required this.width,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  final double height;
  final double width;
  final BorderRadius borderRadius;

  @override
  State<ShimmerPlaceholder> createState() => _ShimmerPlaceholderState();
}

class _ShimmerPlaceholderState extends State<ShimmerPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    final highlight = baseColor.withValues(alpha: 140.0 / 255.0);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-1 + _controller.value * 2, 0),
              end: Alignment(1 + _controller.value * 2, 0),
              colors: [
                baseColor,
                highlight,
                baseColor,
              ],
              stops: const [0.1, 0.5, 0.9],
            ),
          ),
        );
      },
    );
  }
}
