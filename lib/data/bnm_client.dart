import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

import '../domain/numbers.dart';
import '../domain/rates.dart';

class SourceFailure implements Exception {
  final String message;
  const SourceFailure(this.message);
  @override
  String toString() => message;
}

RateTable? parseBnm(String raw, {required DateTime fetchedAt}) {
  if (raw.trim().isEmpty) return null;
  if (raw.length > 1000000 ||
      raw.toUpperCase().contains('<!DOCTYPE') ||
      raw.toUpperCase().contains('<!ENTITY')) {
    throw const FormatException('Недопустимый XML.');
  }
  final root = XmlDocument.parse(raw).rootElement;
  if (root.name.local != 'ValCurs') {
    throw const FormatException('Ожидается ответ BNM.');
  }
  final text = root.getAttribute('Date') ?? '';
  final match = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$').firstMatch(text);
  if (match == null) {
    throw const FormatException('В ответе нет корректной даты.');
  }
  final date = parseDay('${match[3]}-${match[2]}-${match[1]}');
  final records = root.findElements('Valute').toList();
  if (records.isEmpty) return null;
  final result = <String, Exact>{};
  final seen = <String>{};
  for (final row in records) {
    String field(String name) {
      final elements = row.findElements(name).toList();
      if (elements.length != 1 || elements.single.innerText.trim().isEmpty) {
        throw FormatException('Поле $name отсутствует или повторяется.');
      }
      return elements.single.innerText.trim();
    }

    final code = field('CharCode').toUpperCase();
    if (!seen.add(code)) throw const FormatException('Повтор валюты в XML.');
    final nominal = field('Nominal');
    if (!RegExp(r'^[1-9]\d{0,8}$').hasMatch(nominal)) {
      throw const FormatException('Некорректный номинал.');
    }
    final value = Exact.parse(field('Value'));
    if (!value.isPositive) throw const FormatException('Некорректный курс.');
    if (currencies.contains(code)) result[code] = value / Exact.parse(nominal);
  }
  if (!result.keys.any((k) => k != 'MDL')) {
    throw const FormatException('В ответе нет поддерживаемых валют.');
  }
  if (result.containsKey('MDL') &&
      result['MDL']!.compareTo(Exact.integer(1)) != 0) {
    throw const FormatException('Неверный базовый курс.');
  }
  result['MDL'] = Exact.integer(1);
  return RateTable(date, fetchedAt, result);
}

abstract interface class RateSource {
  Future<RateTable?> fetch(DateTime date);
}

class BnmClient implements RateSource {
  final http.Client client;
  final DateTime Function() now;
  BnmClient({http.Client? client, DateTime Function()? now})
    : client = client ?? http.Client(),
      now = now ?? DateTime.now;
  @override
  Future<RateTable?> fetch(DateTime date) async {
    final uri = Uri.https('www.bnm.md', '/en/official_exchange_rates', {
      'get_xml': '1',
      'date': displayDate(date),
    });
    try {
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        throw SourceFailure(
          'Источник BNM недоступен (HTTP ${response.statusCode}).',
        );
      }
      final table = parseBnm(
        utf8.decode(response.bodyBytes),
        fetchedAt: now().toUtc(),
      );
      if (table != null && table.publication.isAfter(calendarDay(date))) {
        throw const FormatException('Дата курса позже запроса.');
      }
      return table;
    } on SourceFailure {
      rethrow;
    } on FormatException {
      throw const SourceFailure(
        'BNM вернул некорректные данные. Повторите запрос позже.',
      );
    } on TimeoutException {
      throw const SourceFailure('BNM не ответил за 10 секунд.');
    } on Exception {
      throw const SourceFailure('Нет соединения с BNM. Проверьте интернет.');
    }
  }

  void close() => client.close();
}
