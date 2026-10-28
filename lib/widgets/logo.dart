import 'package:flutter/material.dart';

import '../theme.dart';

/// The Perps League mark: three candlesticks standing as a podium, first
/// place in solid lime with a gold point. Drawn in code so it is sharp at
/// any size on every platform.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 56, this.background = AppColors.background});

  final double size;

  /// Fill for the hollow candles; match whatever the mark sits on.
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Perps League logo',
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _LogoPainter(background)),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter(this.background);

  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 120;
    canvas.scale(s, s);
    final lime = Paint()..color = AppColors.accent;
    final stroke = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final hollow = Paint()..color = background;

    RRect rr(double x, double y, double w, double h) =>
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(4));

    // Wicks.
    canvas.drawLine(const Offset(33, 44), const Offset(33, 96), stroke);
    canvas.drawLine(const Offset(60, 16), const Offset(60, 96), stroke);
    canvas.drawLine(const Offset(87, 58), const Offset(87, 96), stroke);

    // 2nd and 3rd: hollow. 1st: solid.
    canvas.drawRRect(rr(23, 54, 20, 38), hollow);
    canvas.drawRRect(rr(23, 54, 20, 38), stroke);
    canvas.drawRRect(rr(50, 28, 20, 64), lime);
    canvas.drawRRect(rr(77, 66, 20, 26), hollow);
    canvas.drawRRect(rr(77, 66, 20, 26), stroke);

    // Podium base and gold point.
    canvas.drawRRect(rr(14, 96, 92, 8), lime);
    canvas.drawCircle(const Offset(60, 9), 6, Paint()..color = AppColors.gold);
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) => old.background != background;
}

/// Mark plus wordmark, for headers.
class LogoLockup extends StatelessWidget {
  const LogoLockup({super.key, this.markSize = 32, this.fontSize = 20});

  final double markSize;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LogoMark(size: markSize),
        SizedBox(width: markSize * 0.3),
        Text.rich(
          TextSpan(children: [
            const TextSpan(text: 'Perps '),
            const TextSpan(text: 'League', style: TextStyle(color: AppColors.accent)),
          ]),
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
      ],
    );
  }
}
