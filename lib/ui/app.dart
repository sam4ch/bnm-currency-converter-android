import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../data/rate_repository.dart';
import '../data/bnm_client.dart';
import '../domain/numbers.dart';
import '../domain/rates.dart';
import 'rate_chart.dart';

class CurrencyApp extends StatelessWidget {
  final RateRepository repository;
  const CurrencyApp({super.key, required this.repository});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Курс BNM',
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff008775)),
      scaffoldBackgroundColor: const Color(0xfff3f6f8),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xfff3f6f8),
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xffdce5eb)),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
      ),
    ),
    home: ConverterHome(repository: repository),
  );
}

class ConverterHome extends StatefulWidget {
  final RateRepository repository;
  const ConverterHome({super.key, required this.repository});
  @override
  State<ConverterHome> createState() => _HomeState();
}

class _HomeState extends State<ConverterHome> {
  final _amount = TextEditingController(text: '100');
  String _from = 'EUR', _to = 'MDL';
  DateTime _date = calendarDay(DateTime.now());
  int _screen = 0, _progress = 0, _total = 0;
  bool _busy = false;
  String? _error, _converted;
  RateResult? _rate;
  HistoryResult? _history;
  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    try {
      validateAmount(value ?? '');
      return null;
    } on FormatException catch (e) {
      return e.message;
    }
  }

  void _reset() {
    _converted = null;
    _rate = null;
    _history = null;
    _error = null;
  }

  Future<void> _load({bool refresh = true}) async {
    if (_busy) return;
    if (_screen == 0 && _validate(_amount.text) != null) {
      setState(() => _error = _validate(_amount.text));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
      _converted = null;
      _rate = null;
      _history = null;
      _progress = 0;
      _total = 0;
    });
    try {
      if (_screen == 0) {
        final amount = validateAmount(_amount.text);
        if (_from == _to) {
          _converted = _amount.text.trim().replaceAll(',', '.');
        } else {
          _rate = await widget.repository.load(
            _date,
            refresh: refresh,
            from: _from,
            to: _to,
          );
          _converted = (amount * _rate!.table.pair(_from, _to)).fixed(2);
        }
      } else {
        _history = await widget.repository.history(
          _date,
          _screen == 1 ? 7 : 30,
          _from,
          _to,
          refresh: refresh,
          progress: (done, total) {
            if (mounted) {
              setState(() {
                _progress = done;
                _total = total;
              });
            }
          },
        );
      }
    } on FormatException catch (e) {
      _error = e.message;
    } on SourceFailure catch (e) {
      _error = e.message;
    } on Exception catch (e) {
      debugPrint('Load failed: $e');
      _error = 'Не удалось загрузить данные. Попробуйте ещё раз.';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Конечная дата периода',
    );
    if (selected != null) {
      setState(() {
        _date = calendarDay(selected);
        _reset();
      });
      if (_screen > 0) await _load(refresh: false);
    }
  }

  void _changePair(String? value, bool from) {
    if (value == null) return;
    setState(() {
      if (from) {
        _from = value;
      } else {
        _to = value;
      }
      _reset();
    });
    if (_screen > 0) _load(refresh: false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Row(
        children: [
          Icon(Icons.currency_exchange, color: Color(0xff008775)),
          SizedBox(width: 10),
          Text('Курс', style: TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
      actions: [
        IconButton(
          key: const Key('refresh'),
          tooltip: 'Обновить из BNM',
          onPressed: _busy ? null : () => _load(),
          icon: const Icon(Icons.refresh),
        ),
        const SizedBox(width: 8),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _screen,
      onDestinationSelected: (index) {
        if (_busy || _screen == index) return;
        setState(() {
          _screen = index;
          _reset();
        });
        if (index > 0) _load(refresh: false);
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.swap_horiz), label: 'Конвертер'),
        NavigationDestination(icon: Icon(Icons.show_chart), label: '7 дней'),
        NavigationDestination(
          icon: Icon(Icons.calendar_month),
          label: '30 дней',
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Text(
                _screen == 0
                  ? 'Конвертер валют'
                    : _screen == 1
                    ? 'Динамика за неделю'
                    : 'Динамика за месяц',
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.7,
                  color: Color(0xff142638),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _screen == 0
                    ? 'Официальные курсы Национального банка Молдовы'
                    : 'Курс 1 $_from в $_to · ${_screen == 1 ? 7 : 30} календарных дней',
                style: const TextStyle(color: Color(0xff617386), height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: _currency(true)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: IconButton(
                      key: const Key('swap'),
                      tooltip: 'Поменять валюты',
                      onPressed: _busy
                          ? null
                          : () {
                              setState(() {
                                final old = _from;
                                _from = _to;
                                _to = old;
                                _reset();
                              });
                              if (_screen > 0) _load(refresh: false);
                            },
                      icon: const Icon(Icons.swap_horiz),
                    ),
                  ),
                  Expanded(child: _currency(false)),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                key: const Key('date'),
                onPressed: _busy ? null : _pickDate,
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  '${_screen == 0 ? 'Дата курса' : 'Период до'} ${displayDate(_date)}',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_screen == 0) ..._converter(),
              if (_busy) ...[
                const SizedBox(height: 22),
                LinearProgressIndicator(
                  value: _total > 0 ? _progress / _total : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(height: 10),
                Text(
                  _total > 0
                      ? 'Загружаем историю: $_progress из $_total дней'
                      : 'Получаем официальный курс…',
                  textAlign: TextAlign.center,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                _notice(_error!, error: true),
              ],
              if (_screen > 0 && !_busy) ..._analytics(),
              const SizedBox(height: 24),
              const Text(
                'BNM · Официальный справочный курс\nwww.bnm.md',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xff738296),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _currency(bool from) => DropdownButtonFormField<String>(
    key: ValueKey('${from ? 'from' : 'to'}_${from ? _from : _to}'),
    initialValue: from ? _from : _to,
    decoration: InputDecoration(
      labelText: from ? 'Из валюты' : 'В валюту',
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
    ),
    items: currencies
        .map(
          (code) => DropdownMenuItem(
            value: code,
            child: Text(
              code,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        )
        .toList(),
    onChanged: _busy ? null : (value) => _changePair(value, from),
  );
  List<Widget> _converter() => [
    TextFormField(
      key: const Key('amount'),
      controller: _amount,
      enabled: !_busy,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: _validate,
      onChanged: (_) {
        setState(() {
          _converted = null;
          _rate = null;
          _error = null;
        });
      },
      decoration: const InputDecoration(
        labelText: 'Сумма',
        hintText: 'Например, 100,50',
        helperText: 'Точка или запятая · до 4 дробных знаков',
        errorMaxLines: 3,
      ),
      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
    ),
    const SizedBox(height: 20),
    FilledButton.icon(
      key: const Key('convert'),
      onPressed: _busy || _validate(_amount.text) != null
          ? null
          : () => _load(),
      icon: const Icon(Icons.arrow_forward),
      label: const Text('Конвертировать'),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    if (_converted != null) ...[
      const SizedBox(height: 24),
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _from == _to
                  ? 'Курс не требуется'
                  : _rate!.cached
                  ? 'Сохранённый курс'
                  : 'Официальный курс BNM',
              style: TextStyle(
                color: _rate?.cached == true
                    ? Colors.orange.shade800
                    : const Color(0xff008775),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '${_converted!.replaceAll('.', ',')} $_to',
              key: const Key('conversionResult'),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Color(0xff142638),
              ),
            ),
            if (_rate != null) ...[
              const SizedBox(height: 12),
              Text(
                '1 $_from = ${_rate!.table.pair(_from, _to).fixed(6).replaceAll('.', ',')} $_to',
              ),
              const Divider(height: 28),
              Text('Дата публикации: ${displayDate(_rate!.table.publication)}'),
              const SizedBox(height: 4),
              Text(
                'Получено: ${_rate!.table.fetchedAt.toUtc().toIso8601String().substring(0, 16).replaceAll('T', ' ')} UTC',
                style: const TextStyle(fontSize: 12, color: Color(0xff617386)),
              ),
              if (_rate!.table.publication != _date) ...[
                const SizedBox(height: 8),
                Text(
                  'Использован последний опубликованный курс до ${displayDate(_date)}.',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ],
          ],
        ),
      ),
      if (_rate?.warning != null) ...[
        const SizedBox(height: 12),
        _notice(_rate!.warning!),
      ],
    ],
  ];
  List<Widget> _analytics() {
    final history = _history;
    if (history == null || history.points.isEmpty) {
      return [
        _card(
          Column(
            children: [
              const Icon(Icons.query_stats, size: 48, color: Color(0xff7c8e9d)),
              const SizedBox(height: 12),
              const Text(
                'Нет данных за этот период',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text(
                'Проверьте интернет или выберите другую дату. История не заполняется вымышленными значениями.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _load(),
                child: const Text('Повторить загрузку'),
              ),
            ],
          ),
        ),
        if (history?.warning != null) ...[
          const SizedBox(height: 12),
          _notice(history!.warning!),
        ],
      ];
    }
    final stats = PeriodStats.calculate(history.points)!;
    final start = _date.subtract(Duration(days: history.requestedDays - 1));
    final publications = history.points.map((p) => p.publication).toList()
      ..sort();
    return [
      if (history.warning != null) ...[
        _notice(history.warning!),
        const SizedBox(height: 16),
      ],
      _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_from → $_to',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                Text(
                  '${stats.count}/${history.requestedDays} дней',
                  key: const Key('coverage'),
                  style: const TextStyle(color: Color(0xff617386)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            RateChart(points: history.points, start: start, end: _date),
            const SizedBox(height: 12),
            Text(
              history.cached
                  ? 'Есть сохранённые данные · публикации ${displayDate(publications.first)}–${displayDate(publications.last)}'
                  : 'BNM · публикации ${displayDate(publications.first)}–${displayDate(publications.last)}',
              key: const Key('historySource'),
              style: const TextStyle(fontSize: 12, color: Color(0xff617386)),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _card(
        Row(
          children: [
            Icon(
              stats.change.isZero
                  ? Icons.trending_flat
                  : stats.change.isPositive
                  ? Icons.trending_up
                  : Icons.trending_down,
              color: const Color(0xff008775),
              size: 36,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stats.trend,
                    key: const Key('trend'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  Text(
                    '${stats.change.isPositive ? '+' : ''}${stats.change.fixed(6)} $_to  (${stats.percent.isPositive ? '+' : ''}${stats.percent.fixed(2)} %)',
                    key: const Key('periodChange'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      LayoutBuilder(
        builder: (context, box) => Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _stat('Минимум', stats.minimum.fixed(6), box.maxWidth),
            _stat('Максимум', stats.maximum.fixed(6), box.maxWidth),
            _stat('Среднее', stats.average.fixed(6), box.maxWidth),
            _stat('Наблюдений', '${stats.count}', box.maxWidth),
          ],
        ),
      ),
      const SizedBox(height: 16),
      const Text(
        'Изменение: от первого к последнему доступному наблюдению. Среднее: по показанным дням. Дни без данных остаются пропусками.',
        style: TextStyle(fontSize: 12, color: Color(0xff617386), height: 1.5),
      ),
    ];
  }

  Widget _stat(String label, String value, double width) => SizedBox(
    width: (width - 12) / 2,
    child: _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xff617386))),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value.replaceAll('.', ','),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    ),
  );
  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xffe1e8ed)),
    ),
    child: child,
  );
  Widget _notice(String text, {bool error = false}) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: error ? const Color(0xffffeae8) : const Color(0xfffff3d9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            error ? Icons.error_outline : Icons.cloud_off_outlined,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ],
      ),
    ),
  );
}
