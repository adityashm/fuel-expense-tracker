import 'package:flutter/material.dart';

/// Simple stagger animation wrapper for list items.
class StaggeredListItem extends StatelessWidget {
  const StaggeredListItem({
    super.key,
    required this.child,
    required this.index,
    this.baseDelay = const Duration(milliseconds: 40),
    this.duration = const Duration(milliseconds: 350),
    this.offsetY = 16,
  });

  final Widget child;
  final int index;
  final Duration baseDelay;
  final Duration duration;
  final double offsetY;

  @override
  Widget build(BuildContext context) {
    return _StaggerWrapper(
      delay: Duration(milliseconds: baseDelay.inMilliseconds * index),
      duration: duration,
      offsetY: offsetY,
      child: child,
    );
  }
}

class _StaggerWrapper extends StatefulWidget {
  const _StaggerWrapper({
    required this.delay,
    required this.duration,
    required this.offsetY,
    required this.child,
  });
  final Duration delay;
  final Duration duration;
  final double offsetY;
  final Widget child;

  @override
  State<_StaggerWrapper> createState() => _StaggerWrapperState();
}

class _StaggerWrapperState extends State<_StaggerWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final value = _controller.value;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * widget.offsetY),
            child: widget.child,
          ),
        );
      },
    );
  }
}
