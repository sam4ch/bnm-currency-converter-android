import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/rates.dart';
import 'bnm_client.dart';

abstract interface class CacheStorage {
  Future<String?> read();
  Future<void> write(String value);
}

class AndroidCache implements CacheStorage {
  final SharedPreferencesAsync preferences;
  AndroidCache({SharedPreferencesAsync? preferences})
    : preferences = preferences ?? SharedPreferencesAsync();
  @override
  Future<String?> read() => preferences.getString('bnm_cache_v1');
  @override
  Future<void> write(String value) =>
      preferences.setString('bnm_cache_v1', value);
}

class RateRepository {
  final RateSource source;
  final CacheStorage storage;
  final DateTime Function() now;
  final Map<String, RateTable> _cache = {};
  Future<void>? _initialization;
  Future<void> _writes = Future.value();
  bool _networkFailed = false;
  String? _storageWarning;
  RateRepository(this.source, this.storage, {DateTime Function()? now})
    : now = now ?? DateTime.now;

  Future<void> initialize() => _initialization ??= _read();
  Future<void> _read() async {
    try {
      final raw = await storage.read();
      if (raw == null) return;
      final root = jsonDecode(raw) as Map<String, dynamic>;
      if (root['version'] != 1) throw const FormatException('Версия кэша.');
      final parsed = <String, RateTable>{};
      for (final e in (root['tables'] as Map<String, dynamic>).entries) {
        final requested = parseDay(e.key);
        final table = RateTable.fromJson(e.value as Map<String, dynamic>);
        if (table.publication.isAfter(requested) ||
            requested.isAfter(calendarDay(now()))) {
          throw const FormatException('Дата кэша.');
        }
        parsed[e.key] = table;
      }
      _cache.addAll(parsed);
    } on Exception {
      _storageWarning = 'Сохранённые данные недоступны или повреждены. Нужна загрузка из сети.';
    }
  }

  Future<void> _save() async {
    final keys = _cache.keys.toList()..sort();
    while (keys.length > 120) {
      _cache.remove(keys.removeAt(0));
    }
    final json = jsonEncode({
      'version': 1,
      'tables': _cache.map((k, v) => MapEntry(k, v.toJson())),
    });
    _writes = _writes.then((_) => storage.write(json)).catchError((Object e) {
      _storageWarning = 'Расчёт выполнен, но сохранить кэш не удалось.';
    });
    await _writes;
  }

  void _validateDate(DateTime date) {
    if (calendarDay(date).isAfter(calendarDay(now())) || date.year < 2000) {
      throw const FormatException(
        'Выберите дату с 2000 года, не позже сегодняшней.',
      );
    }
  }

  Future<RateResult> load(
    DateTime date, {
    bool refresh = true,
    String from = 'EUR',
    String to = 'MDL',
  }) async {
    _validateDate(date);
    await initialize();
    final key = dateKey(date);
    if (!refresh && _cache.containsKey(key)) {
      return RateResult(_cache[key]!, cached: true, warning: _storageWarning);
    }
    try {
      for (var back = 0; back <= 31; back++) {
        final candidate = calendarDay(date).subtract(Duration(days: back));
        final table = await source.fetch(candidate);
        if (table == null) continue;
        if (table.publication.isAfter(calendarDay(date)) ||
            calendarDay(date).difference(table.publication).inDays > 31) {
          throw const SourceFailure('Дата курса вне допустимого периода.');
        }
        table.pair(from, to);
        _cache[key] = table;
        await _save();
        return RateResult(table, warning: _storageWarning);
      }
      throw const SourceFailure(
        'BNM не предоставил публикацию за последние 31 день.',
      );
    } on Exception catch (error) {
      RateTable? cached = _cache[key];
      if (cached == null) {
        final candidates =
            _cache.values
                .where(
                  (t) =>
                      !t.publication.isAfter(calendarDay(date)) &&
                      calendarDay(date).difference(t.publication).inDays <= 31,
                )
                .toList()
              ..sort((a, b) => b.publication.compareTo(a.publication));
        if (candidates.isNotEmpty) cached = candidates.first;
      }
      if (cached != null) {
        return RateResult(
          cached,
          cached: true,
          warning:
              'Источник недоступен. Использованы сохранённые данные от ${displayDate(cached.publication)}.',
        );
      }
      throw SourceFailure('$error Сохранённого курса на эту дату нет.');
    }
  }

  Future<HistoryResult> history(
    DateTime end,
    int days,
    String from,
    String to, {
    bool refresh = false,
    void Function(int, int)? progress,
  }) async {
    _validateDate(end);
    if (days != 7 && days != 30) {
      throw const FormatException('Период должен быть 7 или 30 дней.');
    }
    if (!currencies.contains(from) || !currencies.contains(to)) {
      throw const FormatException('Валюта не поддерживается.');
    }
    await initialize();
    _networkFailed = false;
    final points = <RatePoint>[];
    var completed = 0;
    final start = calendarDay(end).subtract(Duration(days: days - 1));
    // Small batches avoid overloading the public service. A source failure
    // stops subsequent batches; available cached dates remain usable.
    for (var offset = 0; offset < days; offset += 3) {
      await Future.wait(
        List.generate((days - offset).clamp(0, 3), (index) async {
          final date = start.add(Duration(days: offset + index));
          final key = dateKey(date);
          RateTable? table = _cache[key];
          var cached = table != null;
          if ((table == null || refresh) && !_networkFailed) {
            try {
              final fetched = await source.fetch(date);
              if (fetched != null) {
                fetched.pair(from, to);
                if (fetched.publication.isAfter(date) ||
                    date.difference(fetched.publication).inDays > 31) {
                  throw const SourceFailure('Некорректная дата публикации.');
                }
                table = fetched;
                _cache[key] = fetched;
                cached = false;
              }
            } on Exception {
              _networkFailed = true;
            }
          }
          if (table != null) {
            try {
              points.add(
                RatePoint(
                  date,
                  table.publication,
                  table.pair(from, to),
                  cached: cached,
                ),
              );
            } on FormatException {
              /* Missing currency is a gap, not a fake value. */
            }
          }
          completed++;
          progress?.call(completed, days);
        }),
      );
    }
    await _save();
    points.sort((a, b) => a.day.compareTo(b.day));
    final notices = <String>[
      if (_networkFailed)
        'Источник недоступен: показаны доступные сохранённые данные.',
      if (points.length < days)
        'Данные доступны за ${points.length} из $days дней. Пропуски не заполняются.',
      ?_storageWarning,
    ];
    return HistoryResult(
      List.unmodifiable(points),
      days,
      warning: notices.isEmpty ? null : notices.join(' '),
    );
  }
}
