import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../data/rate_repository.dart';
import '../data/bnm_client.dart';
import '../domain/numbers.dart';
import '../domain/rates.dart';
import 'rate_chart.dart';
import 'animated_background.dart';

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
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xff6be3bf),
        brightness: Brightness.dark,
        primary: const Color(0xff6be3bf),
        surface: const Color(0xff13283a),
      ),
      scaffoldBackgroundColor: const Color(0xff0b1c2c),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xff0b1c2c),
        surfaceTintColor: Colors.transparent,
        foregroundColor: Color(0xfff4f8ff),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xf21a3043),
        labelStyle: const TextStyle(color: Color(0xffb4c8d8)),
        helperStyle: const TextStyle(color: Color(0xff8ba5b9)),
        floatingLabelStyle: const TextStyle(color: Color(0xff6be3bf)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0x22dce5eb)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0x22dce5eb)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Color(0xff6be3bf), width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xff0b1c2c),
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xff6be3bf).withValues(alpha: .16),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? const Color(0xff6be3bf)
                : const Color(0xff91a9bc),
          ),
        ),
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
  final _scroll = ScrollController();
  String _from = 'EUR', _to = 'MDL';
  DateTime _date = calendarDay(DateTime.now());
  int _screen = 0, _progress = 0, _total = 0;
  double _swapTurns = 0;
  bool _busy = false;
  String? _error, _converted;
  RateResult? _rate;
  HistoryResult? _history;
  @override
  void dispose() {
    _amount.dispose();
    _scroll.dispose();
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
          Icon(Icons.currency_exchange, color: Color(0xff6be3bf)),
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
        HapticFeedback.selectionClick();
        setState(() {
          _screen = index;
          _reset();
        });
        if (_scroll.hasClients) _scroll.jumpTo(0);
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
    body: FloatingCurrencyBackground(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                _hero(),
                const SizedBox(height: 8),
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
                                  _swapTurns += .5;
                                  final old = _from;
                                  _from = _to;
                                  _to = old;
                                  _reset();
                                });
                                HapticFeedback.selectionClick();
                                if (_screen > 0) _load(refresh: false);
                              },
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xff6be3bf)
                              .withValues(alpha: .14),
                          foregroundColor: const Color(0xff6be3bf),
                        ),
                        icon: AnimatedRotation(
                          turns: _swapTurns,
                          duration: MediaQuery.disableAnimationsOf(context)
                              ? Duration.zero
                              : const Duration(milliseconds: 300),
                          curve: Curves.easeInOutCubic,
                          child: const Icon(Icons.swap_horiz),
                        ),
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
                    color: Color(0xff8ba5b9),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _hero() => Container(
    constraints: const BoxConstraints(minHeight: 150),
    padding: EdgeInsets.only(
      right: MediaQuery.sizeOf(context).width < 360 ? 114 : 140,
      bottom: 12,
      top: 8,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xff6be3bf).withValues(alpha: .12),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: const Color(0xff6be3bf).withValues(alpha: .22),
            ),
          ),
          child: const Text(
            'BNM • ОБМЕН ВАЛЮТ',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: .8,
              color: Color(0xff6be3bf),
            ),
          ),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 260),
          child: Text(
            _screen == 0
                ? 'Конвертер валют'
                : _screen == 1
                ? 'Динамика за неделю'
                : 'Динамика за месяц',
            key: ValueKey(_screen),
            style: TextStyle(
              fontSize: MediaQuery.sizeOf(context).width < 360 ? 26 : 28,
              height: 1.12,
              fontWeight: FontWeight.w800,
              letterSpacing: -.7,
              color: Color(0xfff4f8ff),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _screen == 0
              ? 'Официальный курс.\nИстория и аналитика.'
              : '1 $_from в $_to\n${_screen == 1 ? 7 : 30} календарных дней',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xffa7bbcb),
            height: 1.5,
          ),
        ),
      ],
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
      style: const TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.w700,
        letterSpacing: -.5,
      ),
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
                    : const Color(0xff6be3bf),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${_converted!.replaceAll('.', ',')} $_to',
                key: const Key('conversionResult'),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.8,
                  color: Color(0xff6be3bf),
                ),
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
                style: const TextStyle(fontSize: 12, color: Color(0xffa7bbcb)),
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
              const Icon(Icons.query_stats, size: 48, color: Color(0xff91a9bc)),
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
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 16,
              runSpacing: 8,
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
                  style: const TextStyle(color: Color(0xffa7bbcb)),
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
              style: const TextStyle(fontSize: 12, color: Color(0xffa7bbcb)),
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
              color: const Color(0xff6be3bf),
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
        style: TextStyle(fontSize: 12, color: Color(0xffa7bbcb), height: 1.5),
      ),
    ];
  }

  Widget _stat(String label, String value, double width) => SizedBox(
    width: (width - 12) / 2,
    child: _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xffa7bbcb))),
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
  Widget _card(Widget child) => RevealCard(
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xff142b3e).withValues(alpha: .94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xffc3dfeb).withValues(alpha: .12),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 22,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    ),
  );
  Widget _notice(String text, {bool error = false}) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: error ? const Color(0xff3d2230) : const Color(0xff332e21),
        border: Border.all(
          color: error ? const Color(0x55ffb4b4) : const Color(0x55ead296),
        ),
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
