import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../data/dreamdex_models.dart';
import '../theme.dart';

/// Candlestick chart drawn with a CustomPainter; no charting dependency.
class CandleChart extends StatelessWidget {
  const CandleChart({super.key, required this.candles, this.height = 240});

  final List<Candle> candles;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (candles.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('No trades in this window yet', style: TextStyle(color: AppColors.muted)),
        ),
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _CandlePainter(candles)),
    );
  }
}

class _CandlePainter extends CustomPainter {
  _CandlePainter(this.candles);

  final List<Candle> candles;

  @override
  void paint(Canvas canvas, Size size) {
    const labelWidth = 64.0;
    final chartW = size.width - labelWidth;
    var hi = candles.map((c) => c.high).reduce(math.max);
    var lo = candles.map((c) => c.low).reduce(math.min);
    if (hi == lo) {
      hi += hi.abs() * 0.01 + 1e-9;
      lo -= lo.abs() * 0.01 + 1e-9;
    }
    final pad = (hi - lo) * 0.06;
    hi += pad;
    lo -= pad;
    double y(double p) => size.height - (p - lo) / (hi - lo) * size.height;

    // Grid and price labels.
    final grid = Paint()
      ..color = AppColors.border.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final p = lo + (hi - lo) * i / 4;
      final gy = y(p);
      canvas.drawLine(Offset(0, gy), Offset(chartW, gy), grid);
      final tp = TextPainter(
        text: TextSpan(text: formatPrice(p), style: const TextStyle(color: AppColors.muted, fontSize: 10)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: labelWidth - 6);
      tp.paint(canvas, Offset(chartW + 6, (gy - tp.height / 2).clamp(0.0, math.max(0.0, size.height - tp.height)).toDouble()));
    }

    final step = chartW / candles.length;
    final bodyW = math.max(1.5, step * 0.62);
    for (var i = 0; i < candles.length; i++) {
      final c = candles[i];
      final x = step * i + step / 2;
      final color = c.isUp ? AppColors.up : AppColors.down;
      final wick = Paint()
        ..color = color
        ..strokeWidth = 1;
      canvas.drawLine(Offset(x, y(c.high)), Offset(x, y(c.low)), wick);
      final top = y(math.max(c.open, c.close));
      final bottom = y(math.min(c.open, c.close));
      canvas.drawRect(
        Rect.fromLTRB(x - bodyW / 2, top, x + bodyW / 2, math.max(bottom, top + 1)),
        Paint()..color = color,
      );
    }

    // Last price marker.
    final last = candles.last.close;
    final ly = y(last);
    final dash = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.7)
      ..strokeWidth = 1;
    for (double dx = 0; dx < chartW; dx += 6) {
      canvas.drawLine(Offset(dx, ly), Offset(math.min(dx + 3, chartW), ly), dash);
    }
  }

  @override
  bool shouldRepaint(covariant _CandlePainter old) => old.candles != candles;
}

/// Small line chart for equity curves on leaderboard rows and profiles.
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, this.width = 64, this.height = 24});

  final List<double> values;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _SparkPainter(values)),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) {
      final p = Paint()
        ..color = AppColors.border
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), p);
      return;
    }
    var hi = values.reduce(math.max);
    var lo = values.reduce(math.min);
    if (hi == lo) {
      hi += 1;
      lo -= 1;
    }
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height - (values[i] - lo) / (hi - lo) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..color = AppColors.pnl(values.last)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.values != values;
}
