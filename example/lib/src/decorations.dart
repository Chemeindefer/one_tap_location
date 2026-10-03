// Copyright 2026 Batuhan Delice. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Fills a rounded rectangle and draws a dashed outline inside its bounds.
class DashedOutlinePainter extends CustomPainter {
  const DashedOutlinePainter({
    required this.color,
    required this.fillColor,
    required this.cornerRadius,
  });

  /// The width of the outline.
  static const double strokeWidth = 1.5;

  static const double _dashLength = 5;
  static const double _gapLength = 4;

  final Color color;
  final Color fillColor;
  final double cornerRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect outline = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(strokeWidth / 2),
      Radius.circular(math.max(cornerRadius - strokeWidth / 2, 0)),
    );
    canvas.drawRRect(outline, Paint()..color = fillColor);
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (final PathMetric metric
        in (Path()..addRRect(outline)).computeMetrics()) {
      for (
        double distance = 0;
        distance < metric.length;
        distance += _dashLength + _gapLength
      ) {
        canvas.drawPath(
          metric.extractPath(distance, distance + _dashLength),
          stroke,
        );
      }
    }
  }

  @override
  bool shouldRepaint(DashedOutlinePainter oldDelegate) {
    return color != oldDelegate.color ||
        fillColor != oldDelegate.fillColor ||
        cornerRadius != oldDelegate.cornerRadius;
  }
}

/// A ring with a rotating arc, shown while the position is determined.
///
/// The arc stands still while the platform turns animations off, as Android
/// does with its Remove animations setting.
class ProgressSpinner extends StatefulWidget {
  const ProgressSpinner({super.key});

  /// The width and height of the spinner.
  static const double size = 30;

  @override
  State<ProgressSpinner> createState() => _ProgressSpinnerState();
}

class _ProgressSpinnerState extends State<ProgressSpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _rotation.stop();
    } else if (!_rotation.isAnimating) {
      _rotation.repeat();
    }
  }

  @override
  void dispose() {
    _rotation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ExampleColors colors = ExampleColors.of(context);
    return RotationTransition(
      turns: _rotation,
      child: CustomPaint(
        size: const Size.square(ProgressSpinner.size),
        painter: _SpinnerPainter(
          arcColor: colors.accent,
          trackColor: colors.spinnerTrack,
        ),
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  const _SpinnerPainter({required this.arcColor, required this.trackColor});

  final Color arcColor;
  final Color trackColor;

  static const double _strokeWidth = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = (Offset.zero & size).deflate(_strokeWidth / 2);
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;
    canvas
      ..drawOval(bounds, paint..color = trackColor)
      ..drawArc(
        bounds,
        -3 * math.pi / 4,
        math.pi / 2,
        false,
        paint..color = arcColor,
      );
  }

  @override
  bool shouldRepaint(_SpinnerPainter oldDelegate) {
    return arcColor != oldDelegate.arcColor ||
        trackColor != oldDelegate.trackColor;
  }
}

/// A target that marks a position: a small ring for a precise position and a
/// wide dashed ring for an approximate one.
class AccuracyRing extends StatelessWidget {
  const AccuracyRing({super.key, required this.isPrecise});

  /// The width and height of the ring.
  static const double size = 96;

  static const double _preciseRingSize = 43;
  static const double _approximateRingSize = 85;

  final bool isPrecise;

  @override
  Widget build(BuildContext context) {
    final ExampleColors colors = ExampleColors.of(context);
    final Widget dot = Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: colors.accent, shape: BoxShape.circle),
    );
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.ringBackground,
        shape: BoxShape.circle,
      ),
      child: isPrecise
          ? Container(
              width: _preciseRingSize,
              height: _preciseRingSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.preciseRingFill,
                shape: BoxShape.circle,
                border: Border.all(color: colors.ring, width: 1.5),
              ),
              child: dot,
            )
          : CustomPaint(
              painter: DashedOutlinePainter(
                color: colors.ring,
                fillColor: colors.approximateRingFill,
                cornerRadius: _approximateRingSize / 2,
              ),
              child: SizedBox.square(
                dimension: _approximateRingSize,
                child: Center(child: dot),
              ),
            ),
    );
  }
}
