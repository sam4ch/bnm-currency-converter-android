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
          child: CustomPaint(painter: _Chart(points, start, end)),
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
  _Chart(this.points, this.start, this.end);
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
    final area = Rect.fromLTRB(4, 18, size.width - 4, size.height - 16);
    final grid = Paint()..color = const Color(0xffe5eaef);
    for (var i = 0; i < 4; i++) {
      final y = area.top + area.height * i / 3;
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), grid);
      final text = TextPainter(
        text: TextSpan(
          text: (max - (max - min) * i / 3).toStringAsFixed(4),
          style: const TextStyle(color: Color(0xff738296), fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(area.left, y - 13));
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
    final line = Paint()
      ..color = const Color(0xff008775)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < points.length; i++) {
      if (points[i].day.difference(points[i - 1].day).inDays <= 1) {
        canvas.drawLine(position(points[i - 1]), position(points[i]), line);
      }
    }
    final dot = Paint()..color = const Color(0xff008775);
    for (final point in points) {
      canvas.drawCircle(position(point), 3, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _Chart old) =>
      old.points != points || old.start != start || old.end != end;
}
