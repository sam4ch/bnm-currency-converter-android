import 'numbers.dart';

const currencies = ['EUR', 'MDL', 'USD', 'RON', 'GBP'];
DateTime calendarDay(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);
String dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
String displayDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';
DateTime parseDay(String text) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
    throw const FormatException('Некорректная дата.');
  }
  final date = DateTime.parse('${text}T00:00:00Z');
  if (dateKey(date) != text) throw const FormatException('Некорректная дата.');
  return date;
}

class RateTable {
  final DateTime publication;
  final DateTime fetchedAt;
  final Map<String, Exact> mdlPerUnit;
  RateTable(this.publication, this.fetchedAt, Map<String, Exact> values)
    : mdlPerUnit = Map.unmodifiable(values) {
    if (values['MDL']?.compareTo(Exact.integer(1)) != 0 ||
        values.length < 2 ||
        values.entries.any(
          (e) => !currencies.contains(e.key) || !e.value.isPositive,
        )) {
      throw const FormatException('Некорректная таблица курсов.');
    }
  }
  Exact pair(String from, String to) {
    if (!currencies.contains(from) || !currencies.contains(to)) {
      throw const FormatException('Валюта не поддерживается.');
    }
    final source = mdlPerUnit[from];
    final target = mdlPerUnit[to];
    if (source == null || target == null) {
      throw const FormatException('Источник не предоставил выбранную валюту.');
    }
    return source / target;
  }

  Map<String, dynamic> toJson() => {
    'publication': dateKey(publication),
    'fetchedAt': fetchedAt.toIso8601String(),
    'rates': mdlPerUnit.map((k, v) => MapEntry(k, v.storage)),
  };
  factory RateTable.fromJson(Map<String, dynamic> json) => RateTable(
    parseDay(json['publication'] as String),
    DateTime.parse(json['fetchedAt'] as String),
    (json['rates'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, Exact.restore(v as String)),
    ),
  );
}

class RatePoint {
  final DateTime day;
  final DateTime publication;
  final Exact value;
  final bool cached;
  RatePoint(this.day, this.publication, this.value, {this.cached = false});
}

class PeriodStats {
  final Exact minimum, maximum, average, change, percent;
  final int count;
  const PeriodStats(
    this.minimum,
    this.maximum,
    this.average,
    this.change,
    this.percent,
    this.count,
  );
  String get trend => change.isZero
      ? 'Без изменений'
      : change.isPositive
      ? 'Рост'
      : 'Падение';
  static PeriodStats? calculate(List<RatePoint> values) {
    if (values.isEmpty) return null;
    final sorted = [...values]..sort((a, b) => a.day.compareTo(b.day));
    if (sorted.any((p) => !p.value.isPositive)) {
      throw const FormatException('Курс должен быть положительным.');
    }
    if (sorted.map((p) => dateKey(p.day)).toSet().length != sorted.length) {
      throw const FormatException('Повтор даты наблюдения.');
    }
    var min = sorted.first.value;
    var max = min;
    var sum = Exact.integer(0);
    for (final p in sorted) {
      if (p.value.compareTo(min) < 0) min = p.value;
      if (p.value.compareTo(max) > 0) max = p.value;
      sum = sum + p.value;
    }
    final change = sorted.last.value - sorted.first.value;
    return PeriodStats(
      min,
      max,
      sum / Exact.integer(sorted.length),
      change,
      change / sorted.first.value * Exact.integer(100),
      sorted.length,
    );
  }
}

class RateResult {
  final RateTable table;
  final bool cached;
  final String? warning;
  const RateResult(this.table, {this.cached = false, this.warning});
}

class HistoryResult {
  final List<RatePoint> points;
  final int requestedDays;
  final String? warning;
  const HistoryResult(this.points, this.requestedDays, {this.warning});
  bool get cached => points.any((p) => p.cached);
}
