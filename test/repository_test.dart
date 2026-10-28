import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:currency_insights/data/bnm_client.dart';
import 'package:currency_insights/data/rate_repository.dart';
import 'package:currency_insights/domain/numbers.dart';
import 'package:currency_insights/domain/rates.dart';

class MemoryStore implements CacheStorage {
  String? value;
  bool fail = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String text) async {
    if (fail) throw Exception('disk');
    value = text;
  }
}

class FakeSource implements RateSource {
  final Future<RateTable?> Function(DateTime) reply;
  int calls = 0;
  FakeSource(this.reply);
  @override
  Future<RateTable?> fetch(DateTime date) {
    calls++;
    return reply(date);
  }
}

final today = DateTime.utc(2026, 10, 28);
RateTable table(DateTime date, {String rate = '20'}) => RateTable(date, today, {
  'MDL': Exact.integer(1),
  'EUR': Exact.parse(rate),
  'USD': Exact.integer(18),
});
FakeSource offline() =>
    FakeSource((_) async => throw const SourceFailure('offline'));
RateRepository repo(RateSource source, MemoryStore store) =>
    RateRepository(source, store, now: () => today);

void main() {
  test('cache survives a completely new repository instance', () async {
    final storage = MemoryStore();
    final first = await repo(
      FakeSource((d) async => table(d)),
      storage,
    ).load(today);
    expect(first.cached, isFalse);
    expect(storage.value, isNotNull);
    final second = await repo(offline(), storage).load(today);
    expect(second.cached, isTrue);
    expect(second.table.pair('EUR', 'MDL').fixed(2), '20.00');
    expect(second.warning, contains('сохранённые'));
    expect(second.table.publication, today);
  });
  test('offline without cache reports failure', () async {
    await expectLater(
      repo(offline(), MemoryStore()).load(today),
      throwsA(isA<SourceFailure>()),
    );
  });
  for (final raw in [
    'bad json',
    '{}',
    '{"version":2,"tables":{}}',
    '{"version":1,"tables":{"bad":null}}',
  ]) {
    test('corrupt cache $raw does not crash', () async {
      final storage = MemoryStore()..value = raw;
      final result = await repo(
        FakeSource((d) async => table(d)),
        storage,
      ).load(today);
      expect(result.cached, isFalse);
    });
  }
  test('future cache never answers historical request', () async {
    final store = MemoryStore();
    await repo(FakeSource((d) async => table(d)), store).load(today);
    await expectLater(
      repo(offline(), store).load(today.subtract(const Duration(days: 1))),
      throwsA(isA<SourceFailure>()),
    );
  });
  test('future requested date rejected before network', () async {
    final source = FakeSource((d) async => table(d));
    await expectLater(
      repo(source, MemoryStore()).load(today.add(const Duration(days: 1))),
      throwsFormatException,
    );
    expect(source.calls, 0);
  });
  test(
    'missing publication searches previous day and records real date',
    () async {
      final source = FakeSource((d) async => d == today ? null : table(d));
      final value = await repo(source, MemoryStore()).load(today);
      expect(value.table.publication, today.subtract(const Duration(days: 1)));
      expect(source.calls, 2);
    },
  );
  test('network error stops lookup instead of 32 retries', () async {
    final source = offline();
    await expectLater(
      repo(source, MemoryStore()).load(today),
      throwsA(isA<SourceFailure>()),
    );
    expect(source.calls, 1);
  });
  test('empty publication window has bounded requests', () async {
    final source = FakeSource((_) async => null);
    await expectLater(
      repo(source, MemoryStore()).load(today),
      throwsA(isA<SourceFailure>()),
    );
    expect(source.calls, 32);
  });
  test(
    'invalid publication and missing currency do not replace good cache',
    () async {
      final store = MemoryStore();
      await repo(FakeSource((d) async => table(d)), store).load(today);
      final saved = store.value;
      final bad = FakeSource(
        (d) async => RateTable(d, today, {
          'MDL': Exact.integer(1),
          'USD': Exact.integer(18),
        }),
      );
      final result = await repo(bad, store).load(today);
      expect(result.cached, isTrue);
      expect(store.value, saved);
      final future = await repo(
        FakeSource((d) async => table(d.add(const Duration(days: 1)))),
        store,
      ).load(today);
      expect(future.cached, isTrue);
      expect(store.value, saved);
    },
  );
  test('write error preserves calculation with warning', () async {
    final result = await repo(
      FakeSource((d) async => table(d)),
      MemoryStore()..fail = true,
    ).load(today);
    expect(result.table.pair('EUR', 'MDL').fixed(2), '20.00');
    expect(result.warning, contains('сохранить'));
  });
  for (final days in [7, 30]) {
    test(
      '$days-day history and offline restart have real complete series',
      () async {
        final store = MemoryStore();
        final start = today.subtract(Duration(days: days - 1));
        final source = FakeSource(
          (d) async => table(d, rate: '${d.difference(start).inDays + 1}'),
        );
        final live = await repo(
          source,
          store,
        ).history(today, days, 'EUR', 'MDL');
        expect(live.points.length, days);
        expect(live.cached, isFalse);
        expect(live.warning, isNull);
        final stats = PeriodStats.calculate(live.points)!;
        expect(stats.minimum.fixed(2), '1.00');
        expect(stats.maximum.fixed(2), '$days.00');
        expect(stats.average.fixed(2), days == 7 ? '4.00' : '15.50');
        final restored = await repo(
          offline(),
          store,
        ).history(today, days, 'EUR', 'MDL', refresh: true);
        expect(restored.points.length, days);
        expect(restored.cached, isTrue);
        expect(
          PeriodStats.calculate(restored.points)!.average.fixed(2),
          stats.average.fixed(2),
        );
        expect(restored.warning, isNotNull);
      },
    );
  }
  test('missing days remain gaps and show partial coverage', () async {
    final result = await repo(
      FakeSource((d) async => d == today ? null : table(d)),
      MemoryStore(),
    ).history(today, 7, 'EUR', 'MDL');
    expect(result.points.length, 6);
    expect(result.warning, contains('6 из 7'));
  });
  test('empty history has no stats and no fabricated points', () async {
    final result = await repo(
      FakeSource((_) async => null),
      MemoryStore(),
    ).history(today, 30, 'EUR', 'MDL');
    expect(result.points, isEmpty);
    expect(PeriodStats.calculate(result.points), isNull);
    expect(result.warning, contains('0 из 30'));
  });
  test('corrupt numeric cache is rejected as a whole', () async {
    final store = MemoryStore();
    await repo(FakeSource((d) async => table(d)), store).load(today);
    final root = jsonDecode(store.value!) as Map<String, dynamic>;
    root['tables'][dateKey(today)]['rates']['MDL'] = '0/1';
    store.value = jsonEncode(root);
    await expectLater(
      repo(offline(), store).load(today),
      throwsA(isA<SourceFailure>()),
    );
  });
}
