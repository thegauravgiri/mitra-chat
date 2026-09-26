import 'package:flutter/material.dart';

/// The Mitra brand mark: an "M" whose two humps are rounded into bodies,
/// each topped by a circle head -- reads as the letter M and as two
/// companions standing side by side.
class MitraMark extends StatelessWidget {
  const MitraMark({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _MitraMarkPainter(resolvedColor)),
    );
  }
}

class _MitraMarkPainter extends CustomPainter {
  _MitraMarkPainter(this.color);

  final Color color;

  static const double _viewWidth = 100;
  static const double _viewTop = -8;
  static const double _viewHeight = 108;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _viewWidth < size.height / _viewHeight
        ? size.width / _viewWidth
        : size.height / _viewHeight;
    final dx = (size.width - _viewWidth * scale) / 2;
    final dy = (size.height - _viewHeight * scale) / 2 - _viewTop * scale;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);

    final path = Path()
      ..moveTo(14, 84)
      ..lineTo(14, 38)
      ..cubicTo(14, 12, 42, 12, 42, 38)
      ..lineTo(50, 84)
      ..lineTo(58, 38)
      ..cubicTo(58, 12, 86, 12, 86, 38)
      ..lineTo(86, 84);

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(const Offset(28, 3.5), 9, fillPaint);
    canvas.drawCircle(const Offset(72, 3.5), 9, fillPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MitraMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
