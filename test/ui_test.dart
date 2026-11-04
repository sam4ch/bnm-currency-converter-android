import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:currency_insights/ui/app.dart';
import 'package:currency_insights/data/rate_repository.dart';
import 'package:currency_insights/domain/rates.dart';

import 'repository_test.dart' show MemoryStore, FakeSource, table;

void main() {
  Future<FakeSource> mount(
    WidgetTester tester, {
    FakeSource? source,
    bool reducedMotion = true,
  }) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: reducedMotion);
    addTearDown(
      tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue,
    );
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fake = source ?? FakeSource((d) async => table(d));
    await tester.pumpWidget(
      CurrencyApp(repository: RateRepository(fake, MemoryStore())),
    );
    if (reducedMotion) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(seconds: 1));
    }
    return fake;
  }

  testWidgets('Android sized form, validation and exact conversion', (
    tester,
  ) async {
    await mount(tester);
    expect(find.text('Конвертер валют'), findsOneWidget);
    for (final invalid in ['', '0', 'abc', '1.12345']) {
      await tester.enterText(find.byKey(const Key('amount')), invalid);
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byKey(const Key('convert'))).onPressed,
        isNull,
      );
    }
    await tester.enterText(find.byKey(const Key('amount')), '100,50');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('convert')));
    await tester.tap(find.byKey(const Key('convert')));
    await tester.pumpAndSettle();
    expect(find.text('2010,00 MDL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('same currency keeps four digits without source calls', (
    tester,
  ) async {
    final source = await mount(tester);
    await tester.tap(find.byKey(const ValueKey('from_EUR')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('MDL').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('amount')), '10,1234');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('convert')));
    await tester.tap(find.byKey(const Key('convert')));
    await tester.pumpAndSettle();
    expect(find.text('10,1234 MDL'), findsOneWidget);
    expect(find.text('Курс не требуется'), findsOneWidget);
    expect(source.calls, 0);
  });
  testWidgets('week and month are separate functioning screens', (
    tester,
  ) async {
    await mount(tester);
    for (final days in [7, 30]) {
      await tester.tap(find.text('$days дней'));
      await tester.pumpAndSettle();
      expect(
        find.text(days == 7 ? 'Динамика за неделю' : 'Динамика за месяц'),
        findsOneWidget,
      );
      expect(find.text('$days/$days дней'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('trend')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Без изменений'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('loading disables conversion and removes previous result', (
    tester,
  ) async {
    final pending = Completer<RateTable?>();
    await mount(tester, source: FakeSource((_) => pending.future));
    await tester.ensureVisible(find.byKey(const Key('convert')));
    await tester.tap(find.byKey(const Key('convert')));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('convert'))).onPressed,
      isNull,
    );
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('conversionResult')), findsNothing);
    pending.complete(table(calendarDay(DateTime.now())));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('conversionResult')), findsOneWidget);
  });
  testWidgets('empty history shows a retry and no fabricated stats', (
    tester,
  ) async {
    await mount(tester, source: FakeSource((_) async => null));
    await tester.tap(find.text('30 дней'));
    await tester.pumpAndSettle();
    expect(find.text('Нет данных за этот период'), findsOneWidget);
    expect(find.text('Повторить загрузку'), findsOneWidget);
    expect(find.byKey(const Key('trend')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('floating artwork moves while form remains interactive', (
    tester,
  ) async {
    await mount(tester, reducedMotion: false);
    final motion = find.byKey(const Key('floatingCurrencyMotion'));
    final before = List<double>.of(
      tester.widget<Transform>(motion).transform.storage,
    );
    await tester.pump(const Duration(seconds: 3));
    expect(tester.widget<Transform>(motion).transform.storage, isNot(before));
    await tester.enterText(find.byKey(const Key('amount')), '25');
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('convert')));
    await tester.tap(find.byKey(const Key('convert')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('500,00 MDL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Android reduced motion stops decorative movement', (
    tester,
  ) async {
    await mount(tester, reducedMotion: false);
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        FakeAccessibilityFeatures(disableAnimations: true);
    await tester.pumpAndSettle();
    final motion = find.byKey(const Key('floatingCurrencyMotion'));
    final before = List<double>.of(
      tester.widget<Transform>(motion).transform.storage,
    );
    await tester.pump(const Duration(seconds: 3));
    expect(tester.widget<Transform>(motion).transform.storage, before);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });
}
