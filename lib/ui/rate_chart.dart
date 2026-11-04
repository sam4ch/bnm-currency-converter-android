import 'package:flutter/material.dart';

import '../domain/rates.dart';

class RateChart extends StatelessWidget {
  final List<RatePoint> points;
  final DateTime start, end;
  const RateChart({
    super.key,
    required this.points,
    required this.start,
    required this.end,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    label:
        'График курса с ${displayDate(start)} по ${displayDate(end)}, ${points.length} наблюдений. Статистика ниже.',
    child: Column(
      children: [
        SizedBox(
          height: 210,
          width: double.infinity,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 750),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) =>
                CustomPaint(painter: _Chart(points, start, end, value)),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [Text(displayDate(start)), Text(displayDate(end))],
        ),
      ],
    ),
  );
}

class _Chart extends CustomPainter {
  final List<RatePoint> points;
  final DateTime start, end;
  final double progress;
  _Chart(this.points, this.start, this.end, this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final values = points.map((p) => p.value.chartValue);
    var min = values.reduce((a, b) => a < b ? a : b),
        max = values.reduce((a, b) => a > b ? a : b);
    final padding = (max - min).abs() < 1e-12
        ? max.abs() * .02 + .01
        : (max - min) * .15;
    min -= padding;
    max += padding;
    final area = Rect.fromLTRB(56, 18, size.width - 4, size.height - 16);
    final grid = Paint()..color = const Color(0xff2a4153);
    for (var i = 0; i < 4; i++) {
      final y = area.top + area.height * i / 3;
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), grid);
      final text = TextPainter(
        text: TextSpan(
          text: (max - (max - min) * i / 3).toStringAsFixed(4),
          style: const TextStyle(color: Color(0xffa7bbcb), fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(0, y - 6));
    }
    Offset position(RatePoint p) => Offset(
      area.left +
          area.width *
              p.day.difference(start).inDays /
              (end.difference(start).inDays == 0
                  ? 1
                  : end.difference(start).inDays),
      area.bottom - area.height * (p.value.chartValue - min) / (max - min),
    );
    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(
        area.left - 4,
        area.top - 4,
        area.left + area.width * progress + 4,
        area.bottom + 4,
      ),
    );
    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x486be3bf), Color(0x006be3bf)],
      ).createShader(area);
    final line = Paint()
      ..color = const Color(0xff6be3bf)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < points.length; i++) {
      if (points[i].day.difference(points[i - 1].day).inDays <= 1) {
        final a = position(points[i - 1]), b = position(points[i]);
        canvas.drawPath(
          Path()
            ..moveTo(a.dx, area.bottom)
            ..lineTo(a.dx, a.dy)
            ..lineTo(b.dx, b.dy)
            ..lineTo(b.dx, area.bottom)
            ..close(),
          fill,
        );
        canvas.drawLine(position(points[i - 1]), position(points[i]), line);
      }
    }
    final dot = Paint()..color = const Color(0xff6be3bf);
    for (final point in points) {
      canvas.drawCircle(position(point), 3, dot);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _Chart old) =>
      old.points != points ||
      old.start != start ||
      old.end != end ||
      old.progress != progress;
}
