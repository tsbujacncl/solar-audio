import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Ableton-style rotary pan knob
/// - 12 o'clock = center (0.0)
/// - Counter-clockwise = pan left (-1.0)
/// - Clockwise = pan right (+1.0)
class PanKnob extends StatelessWidget {
  final double pan; // -1.0 to 1.0
  final Function(double)? onChanged;
  final double size;

  const PanKnob({
    super.key,
    required this.pan,
    this.onChanged,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onVerticalDragUpdate: (details) {
            if (onChanged == null) return;
            // Drag up = pan right, drag down = pan left
            // Sensitivity: 200px drag = full range
            final delta = -details.delta.dy / 200.0;
            final newPan = (pan + delta).clamp(-1.0, 1.0);
            onChanged!(newPan);
          },
          onDoubleTap: () {
            // Reset to center on double-tap
            onChanged?.call(0.0);
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: CustomPaint(
              size: Size(size, size),
              painter: _PanKnobPainter(pan: pan),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _panToLabel(pan),
          style: const TextStyle(
            color: Color(0xFFE0E0E0),
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _panToLabel(double pan) {
    if (pan < -0.05) {
      return 'L${(pan.abs() * 50).toStringAsFixed(0)}';  // L50 max
    } else if (pan > 0.05) {
      return 'R${(pan * 50).toStringAsFixed(0)}';  // R50 max
    } else {
      return '0';  // Center shows "0"
    }
  }
}

class _PanKnobPainter extends CustomPainter {
  final double pan; // -1.0 to 1.0

  _PanKnobPainter({required this.pan});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 2;

    // Background circle (dark)
    final bgPaint = Paint()
      ..color = const Color(0xFF3a3a3a)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // Border
    final borderPaint = Paint()
      ..color = const Color(0xFF5a5a5a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, borderPaint);

    // Draw arc track (shows the range)
    final trackPaint = Paint()
      ..color = const Color(0xFF4a4a4a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    // Arc from -135° to +135° (270° range)
    // 0° is at 3 o'clock, so -135° from top means starting at 225° (7 o'clock)
    const startAngle = 135 * math.pi / 180; // 135° from 12 o'clock = 7 o'clock position
    const sweepAngle = 270 * math.pi / 180; // 270° sweep

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 4),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    // Draw active arc (from center to current position)
    if (pan.abs() > 0.02) {
      final activePaint = Paint()
        ..color = const Color(0xFF00BCD4) // Cyan
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      // Center is at top (270° or -90°)
      const centerAngle = -90 * math.pi / 180;
      // pan -1.0 = -135° from center, pan +1.0 = +135° from center
      final panAngle = pan * 135 * math.pi / 180;

      if (pan < 0) {
        // Draw from current position to center
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius - 4),
          centerAngle + panAngle,
          -panAngle,
          false,
          activePaint,
        );
      } else {
        // Draw from center to current position
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius - 4),
          centerAngle,
          panAngle,
          false,
          activePaint,
        );
      }
    }

    // Draw indicator line
    final indicatorPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Calculate indicator angle
    // 12 o'clock = -90° (or 270°), range is ±135°
    final angle = (-90 + pan * 135) * math.pi / 180;

    final innerRadius = radius * 0.3;
    final outerRadius = radius * 0.85;

    final start = Offset(
      center.dx + innerRadius * math.cos(angle),
      center.dy + innerRadius * math.sin(angle),
    );
    final end = Offset(
      center.dx + outerRadius * math.cos(angle),
      center.dy + outerRadius * math.sin(angle),
    );

    canvas.drawLine(start, end, indicatorPaint);

    // Draw center dot
    final dotPaint = Paint()
      ..color = const Color(0xFF5a5a5a)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3, dotPaint);
  }

  @override
  bool shouldRepaint(_PanKnobPainter oldDelegate) {
    return oldDelegate.pan != pan;
  }
}
