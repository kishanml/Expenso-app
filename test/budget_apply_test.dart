import 'dart:io';

import 'package:expenso/core/format/money.dart';
import 'package:expenso/data/hive/hive_boxes.dart';
import 'package:expenso/data/models/budget_item.dart';
import 'package:expenso/data/models/entry.dart';
import 'package:expenso/data/models/month_budget.dart';
import 'package:expenso/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

/// The promise the apply-from sheet makes: "Past months keep the budget they
/// had, so their colours and stats never change."
void main() {
  final november = DateTime(2026, 11, 10);

  MonthBudget budgetOf(String monthKey, int dailyRupees, int salaryRupees) =>
      MonthBudget(
        monthKey: monthKey,
        salaryPaise: salaryRupees * 100,
        items: [
          BudgetItem(
            id: 'daily',
            name: kDailyExpensesName,
            amountPaise: dailyRupees * 100,
            pinned: true,
          ),
        ],
      );

  late Directory tempDir;
  late AppState state;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('expenso_budget');
    await HiveBoxes.init(path: tempDir.path);
    state = AppState()..clock = () => november;
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  group('Applying from this month', () {
    test('changes this month and the ones after it', () async {
      await state.completeSetup(budgetOf('2026-11', 10000, 112739));

      await state.saveBudget(
        budgetOf('2026-11', 6000, 112739),
        from: DateTime(2026, 11),
      );

      expect(Money.rupees(state.budgetFor(november).dailyExpensesPaise),
          '₹6,000');
      expect(
        Money.rupees(state.budgetFor(DateTime(2027)).dailyExpensesPaise),
        '₹6,000',
      );
    });

    test('moves the daily limit for the current month', () async {
      await state.completeSetup(budgetOf('2026-11', 10000, 112739));
      expect(
        Money.rupeesPaise(state.currentSummary.dailyLimitRounded),
        '₹333.33',
      );

      await state.saveBudget(
        budgetOf('2026-11', 6000, 112739),
        from: DateTime(2026, 11),
      );

      expect(Money.rupeesPaise(state.currentSummary.dailyLimitRounded),
          '₹200.00');
    });
  });

  group('Applying from next month', () {
    test('leaves this month alone', () async {
      await state.completeSetup(budgetOf('2026-11', 10000, 112739));

      await state.saveBudget(
        budgetOf('2026-12', 6000, 112739),
        from: DateTime(2026, 12),
      );

      expect(Money.rupees(state.budgetFor(november).dailyExpensesPaise),
          '₹10,000');
      expect(
        Money.rupees(
          state.budgetFor(DateTime(2026, 12, 5)).dailyExpensesPaise,
        ),
        '₹6,000',
      );
    });

    test('this month keeps its limit and its day colours', () async {
      await state.completeSetup(budgetOf('2026-11', 10000, 112739));

      // ₹350 is over November's ₹333.33 limit.
      await state.saveEntry(Entry(
        id: 'over',
        amountPaise: 35000,
        isCredit: false,
        category: kDailyExpensesName,
        date: DateTime(2026, 11, 5),
      ));
      expect(state.currentSummary.overLimitDayCount, 1);

      // A roomier budget from December must not retrospectively make
      // 5 November an acceptable day.
      await state.saveBudget(
        budgetOf('2026-12', 30000, 112739),
        from: DateTime(2026, 12),
      );

      expect(state.currentSummary.overLimitDayCount, 1);
      expect(
        Money.rupeesPaise(state.currentSummary.dailyLimitRounded),
        '₹333.33',
      );
    });
  });

  group('A past month never changes', () {
    test('October keeps the budget it was given', () async {
      await state.saveBudget(
        budgetOf('2026-10', 9000, 100000),
        from: DateTime(2026, 10),
      );
      await state.saveBudget(
        budgetOf('2026-11', 10000, 112739),
        from: DateTime(2026, 11),
      );

      final october = state.summaryFor(DateTime(2026, 10, 15));
      expect(Money.rupees(october.budget.dailyExpensesPaise), '₹9,000');
      expect(Money.rupees(october.salaryPaise), '₹1,00,000');

      // 9000 / 31 days in October.
      expect(Money.rupeesPaise(october.dailyLimitRounded), '₹290.32');
    });

    test('editing November does not reach back into October', () async {
      await state.saveBudget(
        budgetOf('2026-10', 9000, 100000),
        from: DateTime(2026, 10),
      );
      await state.saveBudget(
        budgetOf('2026-11', 10000, 112739),
        from: DateTime(2026, 11),
      );

      await state.saveBudget(
        budgetOf('2026-11', 20000, 112739),
        from: DateTime(2026, 11),
      );

      expect(
        Money.rupees(
          state.budgetFor(DateTime(2026, 10, 15)).dailyExpensesPaise,
        ),
        '₹9,000',
      );
    });
  });

  group('Carry-forward', () {
    test('a month with no snapshot uses the latest earlier one', () async {
      await state.saveBudget(
        budgetOf('2026-11', 10000, 112739),
        from: DateTime(2026, 11),
      );

      // Nothing was ever written for March 2027.
      final march = state.budgetFor(DateTime(2027, 3, 4));
      expect(Money.rupees(march.dailyExpensesPaise), '₹10,000');
      expect(march.monthKey, '2027-03');
    });

    test('a month before every snapshot uses the earliest', () async {
      await state.saveBudget(
        budgetOf('2026-11', 10000, 112739),
        from: DateTime(2026, 11),
      );

      final september = state.budgetFor(DateTime(2026, 9, 4));
      expect(Money.rupees(september.dailyExpensesPaise), '₹10,000');
    });

    test('with no budget at all, the seed stands in', () {
      final fresh = state.budgetFor(november);
      expect(Money.rupees(fresh.salaryPaise), '₹1,12,739');
      expect(Money.rupees(fresh.budgetedPaise), '₹34,108');
    });
  });
}
