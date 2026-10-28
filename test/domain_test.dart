import 'package:flutter_test/flutter_test.dart';
import 'package:currency_insights/domain/numbers.dart';
import 'package:currency_insights/domain/rates.dart';
import 'package:currency_insights/data/bnm_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final testDate = DateTime.utc(2026, 10, 28);
const xml =
    '<ValCurs Date="28.10.2026"><Valute><CharCode>EUR</CharCode><Nominal>100</Nominal><Value>2000.0000</Value></Valute><Valute><CharCode>USD</CharCode><Nominal>1</Nominal><Value>18.0000</Value></Valute><Valute><CharCode>CHF</CharCode><Nominal>1</Nominal><Value>21</Value></Valute></ValCurs>';
RatePoint point(int offset, String value) => RatePoint(
  testDate.add(Duration(days: offset)),
  testDate,
  Exact.parse(value),
);

void main() {
  group('Exact money arithmetic', () {
    test('nominal, direct, reverse and cross rates', () {
      final rates = parseBnm(xml, fetchedAt: testDate)!;
      expect(rates.pair('EUR', 'MDL').fixed(4), '20.0000');
      expect(
        (Exact.integer(100) * rates.pair('EUR', 'MDL')).fixed(2),
        '2000.00',
      );
      expect(
        (Exact.integer(2000) * rates.pair('MDL', 'EUR')).fixed(2),
        '100.00',
      );
      expect(
        (Exact.integer(100) * rates.pair('EUR', 'USD')).fixed(2),
        '111.11',
      );
      expect(rates.mdlPerUnit.containsKey('CHF'), isFalse);
    });
    test('midpoint away from zero including negative', () {
      expect(Exact.parse('1.005').fixed(2), '1.01');
      expect((Exact.integer(0) - Exact.parse('1.005')).fixed(2), '-1.01');
      expect((Exact.integer(100) * Exact.parse('1.2345')).fixed(2), '123.45');
    });
    test('no binary rounding and exact persistence', () {
      final third = Exact.integer(1) / Exact.integer(3);
      expect((third * Exact.integer(3)).fixed(4), '1.0000');
      expect(Exact.restore(third.storage).compareTo(third), 0);
      expect(() => Exact.integer(1) / Exact.integer(0), throwsFormatException);
    });
  });
  group('Input validation', () {
    for (final value in [
      '10.50',
      '10,50',
      '0.0001',
      '1000000000000',
      ' 100 ',
    ]) {
      test(
        'accept $value',
        () => expect(validateAmount(value).isPositive, isTrue),
      );
    }
    for (final value in [
      '',
      ' ',
      '0',
      '0.0000',
      '-1',
      '+1',
      '1e2',
      '1 000',
      'abc',
      '.5',
      '1.',
      '1.12345',
      '1,2.3',
      '1000000000000.0001',
      '792281625142643375935439503360000000000000000000000000000000000000000000000000000000000000000000000000000000',
    ]) {
      test(
        'reject $value',
        () => expect(() => validateAmount(value), throwsFormatException),
      );
    }
    test(
      'both decimal forms are equal',
      () =>
          expect(validateAmount('10,50').compareTo(validateAmount('10.50')), 0),
    );
    for (final date in [
      '2026-02-30',
      '2026-13-01',
      '28.10.2026',
      '2026-1-01',
    ]) {
      test(
        'reject date $date',
        () => expect(() => parseDay(date), throwsFormatException),
      );
    }
  });
  group('BNM XML parsing', () {
    test('adds MDL and keeps publication separate', () {
      final value = parseBnm(
        xml,
        fetchedAt: testDate.add(const Duration(hours: 3)),
      )!;
      expect(value.publication, testDate);
      expect(value.fetchedAt.hour, 3);
      expect(value.mdlPerUnit['MDL']!.fixed(2), '1.00');
    });
    for (final empty in ['', '  ', '<ValCurs Date="28.10.2026"/>']) {
      test(
        'no publication $empty',
        () => expect(parseBnm(empty, fetchedAt: testDate), isNull),
      );
    }
    final malformed = <String>[
      '<ValCurs',
      xml.replaceAll('Date="28.10.2026"', ''),
      xml.replaceAll('28.10.2026', '31.02.2026'),
      xml.replaceFirst('<Nominal>100</Nominal>', ''),
      xml.replaceFirst('<Nominal>100</Nominal>', '<Nominal>0</Nominal>'),
      xml.replaceFirst('<Nominal>100</Nominal>', '<Nominal>-1</Nominal>'),
      xml.replaceFirst('<Value>2000.0000</Value>', ''),
      xml.replaceFirst('2000.0000', '-20'),
      xml.replaceFirst('2000.0000', '0'),
      xml.replaceFirst('2000.0000', '2,000.00'),
      xml.replaceFirst('2000.0000', '2e3'),
      xml.replaceFirst('<CharCode>USD</CharCode>', '<CharCode>EUR</CharCode>'),
      '<!DOCTYPE ValCurs [<!ENTITY x "20">]>$xml',
      '<ValCurs Date="28.10.2026"><Valute><CharCode>CHF</CharCode><Nominal>1</Nominal><Value>20</Value></Valute></ValCurs>',
    ];
    for (var i = 0; i < malformed.length; i++) {
      test(
        'reject invalid payload $i',
        () => expect(
          () => parseBnm(malformed[i], fetchedAt: testDate),
          throwsA(isA<Exception>()),
        ),
      );
    }
  });
  group('Period statistics', () {
    test('min max mean absolute and percentage ordered by date', () {
      final s = PeriodStats.calculate([
        point(2, '30'),
        point(0, '10'),
        point(1, '20'),
      ])!;
      expect(s.minimum.fixed(2), '10.00');
      expect(s.maximum.fixed(2), '30.00');
      expect(s.average.fixed(2), '20.00');
      expect(s.change.fixed(2), '20.00');
      expect(s.percent.fixed(2), '200.00');
      expect(s.trend, 'Рост');
    });
    test('falling trend and denominator is initial rate', () {
      final s = PeriodStats.calculate([point(0, '30'), point(1, '10')])!;
      expect(s.change.fixed(2), '-20.00');
      expect(s.percent.fixed(2), '-66.67');
      expect(s.trend, 'Падение');
    });
    test('one value, flat series and empty input', () {
      expect(PeriodStats.calculate([]), isNull);
      for (final data in [
        [point(0, '12')],
        [point(0, '12'), point(1, '12')],
      ]) {
        final s = PeriodStats.calculate(data)!;
        expect(s.average.fixed(2), '12.00');
        expect(s.percent.fixed(2), '0.00');
        expect(s.trend, 'Без изменений');
      }
    });
    test('gaps do not introduce zeroes in average', () {
      final s = PeriodStats.calculate([point(0, '10'), point(3, '30')])!;
      expect(s.average.fixed(2), '20.00');
      expect(s.count, 2);
    });
    test('zero rates and duplicate observation dates rejected', () {
      expect(
        () => PeriodStats.calculate([point(0, '0')]),
        throwsFormatException,
      );
      expect(
        () => PeriodStats.calculate([point(0, '10'), point(0, '11')]),
        throwsFormatException,
      );
    });
  });
  group('HTTP source without real network', () {
    test('correct query, XML and retrieval timestamp', () async {
      final client = BnmClient(
        client: MockClient((request) async {
          expect(request.url.scheme, 'https');
          expect(request.url.host, 'www.bnm.md');
          expect(request.url.queryParameters['date'], '28.10.2026');
          return http.Response(xml, 200);
        }),
        now: () => testDate,
      );
      expect((await client.fetch(testDate))!.publication, testDate);
      client.close();
    });
    for (final code in [404, 500]) {
      test('HTTP $code maps to friendly failure', () async {
        final client = BnmClient(
          client: MockClient((_) async => http.Response('', code)),
        );
        await expectLater(
          client.fetch(testDate),
          throwsA(isA<SourceFailure>()),
        );
        client.close();
      });
    }
    test('bad response and future publication rejected', () async {
      for (final body in [
        'bad xml',
        xml.replaceAll('28.10.2026', '29.10.2026'),
      ]) {
        final client = BnmClient(
          client: MockClient((_) async => http.Response(body, 200)),
        );
        await expectLater(
          client.fetch(testDate),
          throwsA(isA<SourceFailure>()),
        );
        client.close();
      }
    });
  });
}
