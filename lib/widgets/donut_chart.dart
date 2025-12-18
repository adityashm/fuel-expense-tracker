import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Enhanced donut chart widget supporting animation, interaction, accessibility,
/// optional percentage display, custom center content and slice tap callbacks.
class DonutChart extends StatefulWidget {
  const DonutChart({
    super.key,
    required this.slices,
    this.centerLabel,
    this.centerWidget,
    this.thickness,
    this.animate = true,
    this.duration = const Duration(milliseconds: 900),
    this.curve = Curves.easeOutCubic,
    this.showCenterTotal = true,
    this.showPercentages = false,
    this.onSliceTap,
    this.sortDescending = false,
    this.gapRadians = 0.0,
  });

  final List<DonutSlice> slices;
  final String? centerLabel;
  final Widget? centerWidget;
  final double? thickness;
  final bool animate;
  final Duration duration;
  final Curve curve;
  final bool showCenterTotal;
  final bool showPercentages;
  final ValueChanged<DonutSlice>? onSliceTap;
  final bool sortDescending;
  final double gapRadians; // small gap between slices

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: widget.duration)..forward();
  DonutSlice? _highlighted;

  @override
  void didUpdateWidget(covariant DonutChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slices != widget.slices && widget.animate) {
      _controller
        ..reset()
        ..forward();
    }
    if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _total => widget.slices.fold(0, (sum, s) => sum + s.value);

  List<DonutSlice> get _effectiveSlices {
    final filtered = widget.slices.where((s) => s.value > 0).toList();
    if (widget.sortDescending) {
      filtered.sort((a, b) => b.value.compareTo(a.value));
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final total = _total;
    final effectiveSlices = _effectiveSlices;
    final thickness =
        widget.thickness ?? MediaQuery.of(context).size.shortestSide * 0.06;

    if (effectiveSlices.isEmpty || total <= 0) {
      return _EmptyDonut(
          thickness: thickness,
          center: _buildCenterContent(total, isEmpty: true),);
    }

    return Semantics(
      label: widget.centerLabel ?? 'Donut chart',
      value: 'Total ${total.toStringAsFixed(2)}'
          ', ${effectiveSlices.length} categories',
      child: AspectRatio(
        aspectRatio: 1,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final progress = widget.animate ? _controller.value : 1.0;
            return GestureDetector(
              onTapUp: (details) {
                final localPos = (context.findRenderObject() as RenderBox?)
                    ?.globalToLocal(details.globalPosition);
                if (localPos != null) {
                  final slice =
                      _hitTestSlice(localPos, thickness, effectiveSlices);
                  if (slice != null) {
                    setState(() => _highlighted = slice);
                    widget.onSliceTap?.call(slice);
                  }
                }
              },
              child: CustomPaint(
                painter: _DonutChartPainter(
                  slices: effectiveSlices,
                  progress: progress,
                  thickness: thickness,
                  gapRadians: widget.gapRadians,
                  highlighted: _highlighted,
                ),
                child: _buildCenterContent(total),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCenterContent(double total, {bool isEmpty = false}) {
    return Center(
      child: widget.centerWidget ??
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.centerLabel != null)
                Text(
                  widget.centerLabel!,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              if (widget.showCenterTotal)
                Text(
                  isEmpty ? '0' : total.toStringAsFixed(0),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              if (widget.showPercentages && _highlighted != null)
                Text(
                  '${_highlighted!.label}: ${(100 * _highlighted!.value / (total == 0 ? 1 : total)).toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
            ],
          ),
    );
  }

  DonutSlice? _hitTestSlice(
      Offset pos, double thickness, List<DonutSlice> slices,) {
    final boxSize = context.size;
    if (boxSize == null) return null;
    final center = Offset(boxSize.width / 2, boxSize.height / 2);
    final radius = boxSize.width / 2;
    final dist = (pos - center).distance;
    if (dist < radius - thickness || dist > radius) return null; // outside ring
    final angle =
        (math.atan2(pos.dy - center.dy, pos.dx - center.dx) + math.pi / 2) %
            (2 * math.pi);
    final total = slices.fold(0.0, (sum, s) => sum + s.value);
    double accum = 0.0;
    for (final s in slices) {
      final sweep = (s.value / total) * (2 * math.pi);
      if (angle >= accum && angle < accum + sweep) return s;
      accum += sweep;
    }
    return null;
  }
}

class DonutSlice {
  DonutSlice({
    required this.label,
    required this.value,
    required this.color,
    this.gradient,
  });
  final String label;
  final double value;
  final Color color;
  final Gradient? gradient; // optional gradient for slice
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({
    required this.slices,
    required this.progress,
    required this.thickness,
    required this.gapRadians,
    required this.highlighted,
  });
  final List<DonutSlice> slices;
  final double progress; // animation progress 0..1
  final double thickness;
  final double gapRadians;
  final DonutSlice? highlighted;

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold(0.0, (sum, s) => sum + s.value);
    if (total <= 0) return;
    final radius = size.width / 2;
    final rect = Rect.fromCircle(
        center: Offset(radius, radius), radius: radius - thickness / 2,);
    double start = -math.pi / 2; // top
    for (final slice in slices) {
      if (slice.value <= 0) continue;
      final sweep = (slice.value / total) * 2 * math.pi * progress - gapRadians;
      if (sweep <= 0) {
        start += (slice.value / total) * 2 * math.pi;
        continue;
      }
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.butt
        ..isAntiAlias = true;

      if (slice.gradient != null) {
        paint.shader = slice.gradient!.createShader(rect);
      } else {
        paint.color = slice.color.withValues(
            alpha: (highlighted == null || highlighted == slice ? 1.0 : 0.45),);
      }

      canvas.drawArc(rect, start, sweep, false, paint);
      start += (slice.value / total) * 2 * math.pi;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter old) {
    return old.slices != slices ||
        old.progress != progress ||
        old.highlighted != highlighted;
  }
}

class _EmptyDonut extends StatelessWidget {
  const _EmptyDonut({required this.thickness, required this.center});
  final double thickness;
  final Widget center;
  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _EmptyPainter(
                thickness: thickness,
                color: Theme.of(context).colorScheme.outlineVariant,),
          ),
          center,
        ],
      ),
    );
  }
}

class _EmptyPainter extends CustomPainter {
  _EmptyPainter({required this.thickness, required this.color});
  final double thickness;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final rect = Rect.fromCircle(
        center: Offset(radius, radius), radius: radius - thickness / 2,);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..color = color.withValues(alpha: 0.25);
    canvas.drawArc(rect, 0, 2 * math.pi, false, paint);
  }

  @override
  bool shouldRepaint(covariant _EmptyPainter oldDelegate) =>
      oldDelegate.thickness != thickness || oldDelegate.color != color;
}
