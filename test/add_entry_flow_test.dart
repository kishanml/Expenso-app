import 'dart:io';

import 'package:expenso/core/format/money.dart';
import 'package:expenso/core/theme/app_theme.dart';
import 'package:expenso/data/hive/hive_boxes.dart';
import 'package:expenso/data/models/budget_item.dart';
import 'package:expenso/data/models/entry.dart';
import 'package:expenso/data/models/month_budget.dart';
import 'package:expenso/state/app_state.dart';
import 'package:expenso/ui/screens/add_entry/add_entry_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

/// Covers the two halves of Phase 2: the screen produces the right [Entry],
/// and saving one through [AppState] reaches Hive and moves the figures.
///
/// Hive writes are kept out of `testWidgets` bodies — the binding's fake clock
/// stops its file I/O from ever completing there.
void main() {
  final mockToday = DateTime(2026, 11, 10);
  const categories = [kDailyExpensesName, 'Rent', 'Bills'];

  group('Add entry screen', () {
    /// Pushes the screen, runs [drive], and returns whatever it popped.
    Future<AddEntryResult?> run(
      WidgetTester tester,
      Future<void> Function(WidgetTester) drive, {
      Entry? existing,
    }) async {
      AddEntryResult? captured;

      // Must match the phone frame the screen is designed for. In the default
      // 800x600 test window the category chips are clipped, and a tap aimed at
      // one lands on the keypad behind it.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              captured = await Navigator.of(context).push<AddEntryResult>(
                MaterialPageRoute(
                  builder: (_) => AddEntryScreen(
                    categories: categories,
                    today: mockToday,
                    existing: existing,
                  ),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await drive(tester);
      await tester.pumpAndSettle();
      return captured;
    }

    Future<void> typeAmount(WidgetTester tester, String digits) async {
      for (final key in digits.split('')) {
        await tester.tap(find.bySemanticsLabel(key == '.' ? 'Decimal point' : key));
        await tester.pump();
      }
    }

    testWidgets('Save does nothing until an amount is entered',
        (tester) async {
      final result = await run(tester, (tester) async {
        expect(find.text('Enter an amount'), findsOneWidget);

        // Tapping the disabled pill must not close the screen.
        await tester.tap(find.text('Save entry'));
        await tester.pumpAndSettle();
        expect(find.text('Add entry'), findsOneWidget);

        await typeAmount(tester, '1');
        await tester.pump();
        expect(find.text('−₹1'), findsOneWidget);
        expect(find.text('Enter an amount'), findsNothing);
      });

      expect(result, isNull);
    });

    testWidgets('produces a debit with the typed amount', (tester) async {
      final result = await run(tester, (tester) async {
        await typeAmount(tester, '180');
        await tester.tap(find.text('Save entry'));
      });

      final entry = (result! as SaveEntryResult).entry;
      expect(entry.amountPaise, 18000);
      expect(entry.isCredit, isFalse);
      expect(entry.category, kDailyExpensesName);
      expect(entry.date, mockToday);
      expect(Money.signed(entry.amountPaise), '−₹180');
    });

    testWidgets('produces a credit against the chosen category',
        (tester) async {
      final result = await run(tester, (tester) async {
        await typeAmount(tester, '120');
        await tester.tap(find.text('+ Credit'));
        await tester.pump();
        await tester.tap(find.text('Bills'));
        await tester.pump();
        await tester.tap(find.text('Save entry'));
      });

      final entry = (result! as SaveEntryResult).entry;
      expect(entry.amountPaise, 12000);
      expect(entry.isCredit, isTrue);
      expect(entry.category, 'Bills');
      expect(Money.signed(entry.amountPaise, credit: true), '+₹120');
    });

    testWidgets('keeps paise typed on the keypad', (tester) async {
      final result = await run(tester, (tester) async {
        await typeAmount(tester, '333.33');
        await tester.tap(find.text('Save entry'));
      });
      expect((result! as SaveEntryResult).entry.amountPaise, 33333);
    });

    testWidgets('an amount over ₹10 lakh asks before saving', (tester) async {
      final result = await run(tester, (tester) async {
        await typeAmount(tester, '1000001');
        await tester.pump();
        expect(
          find.text("Over ₹10 lakh — we'll ask you to confirm"),
          findsOneWidget,
        );

        await tester.tap(find.text('Save entry'));
        await tester.pumpAndSettle();
        expect(find.text('Confirm this amount'), findsOneWidget);

        await tester.tap(find.text('Go back'));
        await tester.pumpAndSettle();
      });

      // Declining leaves the screen open and saves nothing.
      expect(result, isNull);
      expect(find.text('Add entry'), findsOneWidget);
    });

    testWidgets('editing seeds the existing values and can delete',
        (tester) async {
      final existing = Entry(
        id: 'e1',
        amountPaise: 24500,
        isCredit: false,
        category: 'Bills',
        date: DateTime(2026, 11, 9),
        note: 'Dinner',
      );

      final result = await run(
        tester,
        (tester) async {
          expect(find.text('Edit entry'), findsOneWidget);
          expect(find.text('−₹245'), findsOneWidget);
          expect(find.text('Dinner'), findsOneWidget);

          await tester.tap(find.bySemanticsLabel('Delete entry'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Delete'));
        },
        existing: existing,
      );

      expect((result! as DeleteEntryResult).id, 'e1');
    });
  });

  group('Saving through AppState reaches Hive', () {
    late Directory tempDir;
    late AppState state;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('expenso_flow');
      await HiveBoxes.init(path: tempDir.path);
      await HiveBoxes.budgetsBox.put(
        '2026-11',
        const MonthBudget(
          monthKey: '2026-11',
          salaryPaise: 11273900,
          items: [
            BudgetItem(
              id: 'daily',
              name: kDailyExpensesName,
              amountPaise: 1000000,
              pinned: true,
            ),
            BudgetItem(id: 'bills', name: 'Bills', amountPaise: 250000),
          ],
        ),
      );
      state = AppState()..clock = () => mockToday;
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    test('an entry moves today, the month and the saved total', () async {
      final before = state.currentSummary;
      expect(before.todaySpentPaise, 0);
      expect(Money.rupees(before.todayRemainingPaise), '₹333');
      expect(Money.withSign(before.savedPaise), '+₹1,12,739');

      await state.saveEntry(Entry(
        id: 'a',
        amountPaise: 25000,
        isCredit: false,
        category: kDailyExpensesName,
        date: mockToday,
        note: 'Lunch',
      ));

      final after = state.currentSummary;
      expect(Money.rupees(after.todaySpentPaise), '₹250');
      expect(Money.rupees(after.todayRemainingPaise), '₹83');
      expect((after.todayProgress * 100).round(), 75);
      expect(Money.withSign(after.savedPaise), '+₹1,12,489');
      expect(after.todayWithinLimit, isTrue);
    });

    test('a credit does not count against the daily limit', () async {
      await state.saveEntry(Entry(
        id: 'b',
        amountPaise: 12000,
        isCredit: true,
        category: 'Bills',
        date: mockToday,
      ));

      final summary = state.currentSummary;
      expect(summary.todaySpentPaise, 0);
      expect(Money.rupees(summary.totalCreditsPaise), '₹120');
      expect(summary.totalDebitsPaise, 0);
    });

    test('a non-daily debit spends salary but not the daily limit', () async {
      await state.saveEntry(Entry(
        id: 'c',
        amountPaise: 124000,
        isCredit: false,
        category: 'Bills',
        date: mockToday,
      ));

      final summary = state.currentSummary;
      expect(summary.todaySpentPaise, 0);
      expect(Money.rupees(summary.totalDebitsPaise), '₹1,240');
      expect(Money.rupees(summary.dayStats[9].totalSpentPaise), '₹1,240');
    });

    test('going over the limit flips the day red', () async {
      await state.saveEntry(Entry(
        id: 'd',
        amountPaise: 52000,
        isCredit: false,
        category: kDailyExpensesName,
        date: mockToday,
      ));

      final summary = state.currentSummary;
      expect(summary.todayWithinLimit, isFalse);
      expect(summary.todayRemainingPaise.isNegative, isTrue);
      expect(summary.overLimitDayCount, 1);
    });

    test('the entry survives a reopen, and delete removes it', () async {
      await state.saveEntry(Entry(
        id: 'e',
        amountPaise: 25000,
        isCredit: false,
        category: kDailyExpensesName,
        date: mockToday,
        note: 'Lunch',
      ));

      // A fresh AppState reads the same boxes — proof it is on disk, not in
      // the controller's memory.
      final reopened = AppState()..clock = () => mockToday;
      expect(reopened.entriesForDay(mockToday).single.note, 'Lunch');

      await reopened.deleteEntry('e');
      expect(reopened.entriesForDay(mockToday), isEmpty);
      expect(reopened.currentSummary.todaySpentPaise, 0);
    });
  });
}
